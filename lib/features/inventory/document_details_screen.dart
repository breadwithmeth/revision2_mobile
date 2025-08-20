import 'package:flutter/material.dart';
import 'api/inventory_api.dart';
import 'models/inventory_document_details.dart';
import 'item_edit_screen.dart';
import 'storage/local_storage.dart';

class DocumentDetailsScreen extends StatefulWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
    this.title,
  });

  final String documentId;
  final String? title;

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  final _api = InventoryApi();
  late Future<InventoryDocumentDetails> _future;
  final _barcodeCtrl = TextEditingController();
  bool _uploading = false;
  final FocusNode _barcodeFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _loadInitial();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barcodeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _submitBarcode() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    try {
      // Get current document from local storage (fallback to API once)
      final storage = InventoryLocalStorage();
      var doc = await storage.getDocumentById(widget.documentId);
      if (doc == null) {
        final fresh = await _api.getDocumentDetails(widget.documentId);
        await storage.saveDocument(fresh);
        if (!mounted) return;
        doc = await storage.getDocumentById(widget.documentId);
      }
      if (doc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Документ не найден в памяти')),
        );
        return;
      }

      InventoryLineSummary? target;
      for (final l in doc.lines) {
        if (l.barcodes.contains(code)) {
          target = l;
          break;
        }
      }
      if (target == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Штрихкод не найден: $code')));
        return;
      }

      if (!mounted) return;
      final updated = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ItemEditScreen(documentId: widget.documentId, line: target!),
        ),
      );
      if (updated is InventoryDocumentDetails) {
        if (!mounted) return;
        setState(() {
          _future = Future.value(updated);
        });
      }
      _barcodeCtrl.clear();
      _barcodeFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      _barcodeFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Документ'),
        actions: [
          IconButton(
            onPressed: _uploading ? null : _onUpload,
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Выгрузка',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _future = _api.getDocumentDetails(widget.documentId);
              });
              _barcodeFocus.requestFocus();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск по строкам (название, SKU, ШК)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<InventoryDocumentDetails>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Ошибка: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final doc = snap.data!;
                final q = _searchQuery.trim().toLowerCase();
                final lines = q.isEmpty
                    ? doc.lines
                    : doc.lines.where((l) {
                        final name = l.name.toLowerCase();
                        final sku = l.sku.toLowerCase();
                        final bcs = l.barcodes.join(' ').toLowerCase();
                        return name.contains(q) ||
                            sku.contains(q) ||
                            bcs.contains(q);
                      }).toList();
                if (lines.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final line = lines[i];
                    final primaryBc = line.barcodes.isNotEmpty
                        ? line.barcodes.first
                        : null;
                    final counted = line.countedQty ?? 0;
                    return ListTile(
                      title: Text(line.name),
                      subtitle: Text(
                        'SKU: ${line.sku}${primaryBc != null ? ' • ШК: $primaryBc' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_fmt(counted)} / ${_fmt(line.qtyFrom1C)} ${line.unit}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (line.deltaQty != null)
                            Text(
                              'Δ ${_fmt(line.deltaQty!)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      onTap: () async {
                        final updated = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItemEditScreen(
                              documentId: widget.documentId,
                              line: line,
                            ),
                          ),
                        );
                        if (updated is InventoryDocumentDetails) {
                          if (!mounted) return;
                          setState(() {
                            _future = Future.value(updated);
                          });
                        }
                        _barcodeFocus.requestFocus();
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    focusNode: _barcodeFocus,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Штрихкод',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submitBarcode(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _submitBarcode,
                  icon: const Icon(Icons.edit),
                  label: const Text('Открыть'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  Future<InventoryDocumentDetails> _loadInitial() async {
    final storage = InventoryLocalStorage();
    final local = await storage.getDocumentById(widget.documentId);
    if (local != null) return local;
    return _api.getDocumentDetails(widget.documentId);
  }

  Future<void> _onUpload() async {
    setState(() => _uploading = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      // Take current (possibly locally edited) document from storage
      final storage = InventoryLocalStorage();
      final doc =
          await storage.getDocumentById(widget.documentId) ??
          await _api.getDocumentDetails(widget.documentId);

      // Build items payload: only countedQty>0
      final items = <Map<String, dynamic>>[];
      for (final l in doc.lines) {
        final q = l.countedQty ?? 0;
        if (q > 0) {
          items.add({
            'sku': l.sku,
            'countedQty': q.toString(),
            if (l.note != null && l.note!.isNotEmpty) 'note': l.note,
            if (l.lastKnownModified != null)
              'lastKnownModified': l.lastKnownModified,
          });
        }
      }

      if (items.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Нечего выгружать')),
        );
        return;
      }

      final resp = await _api.uploadItemsV2(
        documentId: widget.documentId,
        deviceId: 'TSD-001',
        items: items,
        version: doc.version,
      );

      if (!mounted) return;
      final applied = resp['appliedChanges'] ?? items.length;
      final conflicts = (resp['conflicts'] as List?)?.length ?? 0;
      final newVersion = resp['version'];

      // Show summary
      messenger.showSnackBar(
        SnackBar(content: Text('Выгружено: $applied, конфликтов: $conflicts')),
      );
      _barcodeFocus.requestFocus();

      // If server returned new version, persist it for future uploads
      if (newVersion is int) {
        final updatedDoc = InventoryDocumentDetails(
          id: doc.id,
          number: doc.number,
          warehouseCode: doc.warehouseCode,
          createdAt: doc.createdAt,
          lines: doc.lines,
          version: newVersion,
        );
        await storage.saveDocument(updatedDoc);
        if (mounted) {
          setState(() {
            _future = Future.value(updatedDoc);
          });
        }
      }

      // If there are conflicts, optionally show details
      if (conflicts > 0) {
        if (!mounted) return;
        final details = (resp['conflicts'] as List)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .cast<Map<String, dynamic>>()
            .toList();
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Конфликты'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: details.length,
                itemBuilder: (_, i) {
                  final c = details[i];
                  return ListTile(
                    dense: true,
                    title: Text('${c['sku']} — ${c['field']}'),
                    subtitle: Text(
                      'Ваше: ${c['yourValue']} | Текущее: ${c['currentValue']}\n${c['lastModified'] ?? ''} ${c['modifiedBy'] ?? ''}',
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _barcodeFocus.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(content: Text('Ошибка выгрузки: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
      if (mounted) _barcodeFocus.requestFocus();
    }
  }
}
