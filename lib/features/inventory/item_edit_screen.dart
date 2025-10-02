import 'package:flutter/material.dart';

import 'api/inventory_api.dart';
import 'models/inventory_document_details.dart';
import 'storage/local_storage.dart';

class ItemEditScreen extends StatefulWidget {
  const ItemEditScreen({
    super.key,
    required this.documentId,
    required this.line,
  });

  final String documentId;
  final InventoryLineSummary line;

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _api = InventoryApi();
  late TextEditingController _qtyCtrl;
  String? _selectedBarcode;
  final _manualBarcodeCtrl = TextEditingController();
  bool _saving = false;
  final FocusNode _qtyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _fmtNumber(0));
    _selectedBarcode = widget.line.barcodes.isNotEmpty
        ? widget.line.barcodes.first
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _qtyFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _manualBarcodeCtrl.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  Future<void> _saveSet() => _saveImpl(additive: true);
  Future<void> _saveDelta(double delta) async {
    setState(() => _saving = true);
    try {
      final storage = InventoryLocalStorage();
      var doc = await storage.getDocumentById(widget.documentId);
      if (doc == null) {
        final fresh = await _api.getDocumentDetails(widget.documentId);
        await storage.saveDocument(fresh);
        doc = await storage.getDocumentById(widget.documentId);
      }
      if (doc == null) {
        throw Exception('Не удалось загрузить документ из памяти');
      }

      final idx = doc.lines.indexWhere((l) => l.id == widget.line.id);
      if (idx == -1) throw Exception('Строка не найдена');

      final old = doc.lines[idx];
      final newCounted = (old.countedQty ?? 0) + delta;
      final newDelta = newCounted - old.qtyFrom1C;

      final updatedLine = InventoryLineSummary(
        id: old.id,
        name: old.name,
        sku: old.sku,
        unit: old.unit,
        qtyFrom1C: old.qtyFrom1C,
        countedQty: newCounted,
        correctedQty: old.correctedQty,
        deltaQty: newDelta,
        barcodes: old.barcodes,
        note: old.note,
        lastKnownModified: DateTime.now().toIso8601String(),
      );
      final newLines = [...doc.lines];
      newLines[idx] = updatedLine;

      final updatedDoc = InventoryDocumentDetails(
        id: doc.id,
        number: doc.number,
        warehouseCode: doc.warehouseCode,
        createdAt: doc.createdAt,
        lines: newLines,
        version: doc.version,
      );
      await storage.saveDocument(updatedDoc);

      // Try to send change to API immediately, but continue if it fails (delta method)
      try {
        await _api.uploadItemsV2(
          documentId: widget.documentId,
          items: [
            {
              'sku': old.sku,
              'countedQty': newCounted.toString(),
              if (old.note != null && old.note!.isNotEmpty) 'note': old.note,
              'lastKnownModified': updatedLine.lastKnownModified,
            },
          ],
          version: doc.version,
        );
      } catch (apiError) {
        // Log API error but don't fail the operation
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Сохранено локально. ')));
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop<InventoryDocumentDetails>(updatedDoc);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Восстанавливаем фокус после ошибки в delta
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _qtyFocus.requestFocus();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  Future<void> _saveImpl({required bool additive}) async {
    final input = _qtyCtrl.text.trim().replaceAll(',', '.');
    final entered = double.tryParse(input);
    if (entered == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите корректное число')));
      return;
    }

    String? barcode = _selectedBarcode;
    if ((barcode == null || barcode.isEmpty) &&
        _manualBarcodeCtrl.text.isNotEmpty) {
      barcode = _manualBarcodeCtrl.text.trim();
    }

    if (barcode == null || barcode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите штрихкод')));
      return;
    }

    final prev = widget.line.countedQty ?? 0.0;
    final targetCounted = additive ? (prev + entered) : entered;

    setState(() => _saving = true);
    try {
      final storage = InventoryLocalStorage();
      // Ensure we have the document locally
      var doc = await storage.getDocumentById(widget.documentId);
      if (doc == null) {
        // fetch once from API and save if missing
        final fresh = await _api.getDocumentDetails(widget.documentId);
        await storage.saveDocument(fresh);
        doc = await storage.getDocumentById(widget.documentId);
      }
      if (doc == null) {
        throw Exception('Не удалось загрузить документ из памяти');
      }

      final idx = doc.lines.indexWhere((l) => l.id == widget.line.id);
      if (idx == -1) throw Exception('Строка не найдена');

      final old = doc.lines[idx];
      final newCounted = targetCounted;
      final newDelta = newCounted - old.qtyFrom1C;

      final updatedLine = InventoryLineSummary(
        id: old.id,
        name: old.name,
        sku: old.sku,
        unit: old.unit,
        qtyFrom1C: old.qtyFrom1C,
        countedQty: newCounted,
        correctedQty: old.correctedQty,
        deltaQty: newDelta,
        barcodes: old.barcodes,
        note: old.note,
        lastKnownModified: DateTime.now().toIso8601String(),
      );
      final newLines = [...doc.lines];
      newLines[idx] = updatedLine;

      final updatedDoc = InventoryDocumentDetails(
        id: doc.id,
        number: doc.number,
        warehouseCode: doc.warehouseCode,
        createdAt: doc.createdAt,
        lines: newLines,
        version: doc.version,
      );
      await storage.saveDocument(updatedDoc);

      // Try to send change to API immediately, but continue if it fails (main method)
      // try {
      //   await _api.uploadItemsV2(
      //     documentId: widget.documentId,
      //     items: [
      //       {
      //         'sku': old.sku,
      //         'countedQty': newCounted.toString(),
      //         if (old.note != null && old.note!.isNotEmpty) 'note': old.note,
      //         'lastKnownModified': updatedLine.lastKnownModified,
      //       },
      //     ],
      //     version: doc.version,
      //   );
      // } catch (apiError) {
      //   // Log API error but don't fail the operation
      //   if (mounted) {
      //     ScaffoldMessenger.of(
      //       context,
      //     ).showSnackBar(SnackBar(content: Text('Сохранено локально. ')));
      //   }
      // }

      if (!mounted) return;
      Navigator.of(context).pop<InventoryDocumentDetails>(updatedDoc);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Восстанавливаем фокус после ошибки в saveImpl
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _qtyFocus.requestFocus();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _saveSet,
        child: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Товар: ${l.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (_) {
                // final factText = _qtyCtrl.text.trim();
                // final fact = factText.isEmpty
                //     ? _fmtNumber(l.countedQty ?? 0)
                //     : factText;
                final fact = widget.line.countedQty;
                return Text(
                  'Факт: $fact ${l.unit}',
                  style: const TextStyle(fontSize: 16),
                );
              },
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (_) {
                final prev = widget.line.countedQty ?? 0.0;
                final entered = double.tryParse(
                  _qtyCtrl.text.trim().replaceAll(',', '.'),
                );
                final predicted = prev + (entered ?? 0.0);
                return Text(
                  'Будет: ${_fmtNumber(predicted)} ${l.unit}',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                );
              },
            ),
            const SizedBox(height: 12),
            Text('SKU: ${l.sku}'),
            const SizedBox(height: 4),
            Text('План: ${_fmtNumber(l.qtyFrom1C)} ${l.unit}'),
            const SizedBox(height: 12),
            if (l.barcodes.isNotEmpty)
              Row(
                children: [
                  const Text('Штрихкод:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBarcode,
                      items: l.barcodes
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBarcode = v),
                    ),
                  ),
                ],
              )
            else
              TextField(
                controller: _manualBarcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Штрихкод',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              focusNode: _qtyFocus,
              autofocus: true,
              controller: _qtyCtrl,
              keyboardType: TextInputType.none,
              decoration: const InputDecoration(
                labelText: 'Добавочное количество',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveSet(),
              onChanged: (_) {
                setState(() {});
                // Восстанавливаем фокус после setState
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_qtyFocus.hasFocus) {
                    _qtyFocus.requestFocus();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveDelta(-1),
                  icon: const Icon(Icons.remove),
                  label: const Text('-1'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveDelta(1),
                  icon: const Icon(Icons.add),
                  label: const Text('+1'),
                ),
              ],
            ),
            const Spacer(),
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton.icon(
            //     onPressed: _saving ? null : _saveSet,
            //     icon: _saving
            //         ? const SizedBox(
            //             width: 16,
            //             height: 16,
            //             child: CircularProgressIndicator(strokeWidth: 2),
            //           )
            //         : const Icon(Icons.add),
            //     label: const Text('Добавить'),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  String _fmtNumber(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}
