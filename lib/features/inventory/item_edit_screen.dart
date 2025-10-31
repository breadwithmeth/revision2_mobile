import 'package:flutter/material.dart';

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
  late TextEditingController _qtyCtrl;
  String? _selectedBarcode;
  final _manualBarcodeCtrl = TextEditingController();
  bool _saving = false;
  final FocusNode _qtyFocus = FocusNode();
  bool _isAdjustingQty = false;

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

  Future<void> _onEditQuantityPressed() async {
    final current = widget.line.countedQty ?? 0.0;
    final controller = TextEditingController(text: _fmtNumber(current));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить количество'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Новое количество',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final normalized = result.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите корректное число')));
      return;
    }
    _qtyCtrl.text = value.toString();
    await _saveImpl(additive: false);
  }

  Future<void> _saveDelta(double delta) async {
    setState(() => _saving = true);
    try {
      final storage = InventoryLocalStorage();
      final doc = await storage.getDocumentById(widget.documentId);
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

      // API вызов убран — работаем только локально, чтобы не блокировать UX

      if (!mounted) return;
      // Показать уведомление об успешном изменении количества
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Количество изменено'),
          duration: Duration(seconds: 1),
        ),
      );
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
    // Штрихкод больше не обязателен для сохранения — убрано требование

    final prev = widget.line.countedQty ?? 0.0;
    final targetCounted = additive ? (prev + entered) : entered;

    setState(() => _saving = true);
    try {
      final storage = InventoryLocalStorage();
      // Ensure we have the document locally
      final doc = await storage.getDocumentById(widget.documentId);
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

      // API вызов намеренно отключен — оффлайн-first сохранение

      if (!mounted) return;
      // Показать уведомление об успешном изменении количества
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Количество изменено'),
          duration: Duration(seconds: 1),
        ),
      );
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
    return WillPopScope(
      onWillPop: () async {
        // Авто-сохранение перед выходом если введено число и еще не сохранялось
        if (!_saving) {
          final text = _qtyCtrl.text.trim();
          if (text.isNotEmpty && text != '0') {
            await _saveImpl(additive: true); // добавляем введённое
            return false; // _saveImpl сам закроет экран
          }
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(toolbarHeight: 0),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Builder(
                            builder: (_) {
                              final fact = widget.line.countedQty;
                              return Text(
                                'Факт: ${_fmtNumber((fact ?? 0))} ${l.unit}',
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (_) {
                              final prev = widget.line.countedQty ?? 0.0;
                              final entered = double.tryParse(
                                _qtyCtrl.text.trim().replaceAll(',', '.'),
                              );
                              final predicted = prev + (entered ?? 0.0);
                              return Text(
                                'Будет: ${_fmtNumber(predicted)} ${l.unit}',
                                style: const TextStyle(color: Colors.black87),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SKU: ${l.sku}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'План: ${_fmtNumber(l.qtyFrom1C)} ${l.unit}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (l.barcodes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: l.barcodes
                              .map(
                                (b) => ChoiceChip(
                                  label: Text(b),
                                  selected: _selectedBarcode == b,
                                  onSelected: (_) =>
                                      setState(() => _selectedBarcode = b),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Quantity Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        focusNode: _qtyFocus,
                        autofocus: true,
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.none,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Добавочное количество',
                          suffixText: l.unit,
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _saveSet(),
                        onChanged: (_) {
                          if (_isAdjustingQty) return;
                          final raw = _qtyCtrl.text.trim().replaceAll(',', '.');
                          final val = double.tryParse(raw);
                          if (val != null && val > 10000) {
                            _isAdjustingQty = true;
                            _qtyCtrl.text = '0';
                            _qtyCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: _qtyCtrl.text.length),
                            );
                            _isAdjustingQty = false;
                          }
                          setState(() {});
                          // Восстанавливаем фокус после setState
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_qtyFocus.hasFocus) {
                              _qtyFocus.requestFocus();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : () => _saveDelta(-1),
                              icon: const Icon(Icons.remove),
                              label: const Text('-1'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : () => _saveDelta(1),
                              icon: const Icon(Icons.add),
                              label: const Text('+1'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _onEditQuantityPressed,
                    icon: const Icon(Icons.edit),
                    label: const Text('Изменить количество'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtNumber(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}
