import 'package:flutter/material.dart';
import 'api/inventory_api.dart';
import 'models/inventory_document.dart';
import 'document_details_screen.dart';
import 'models/warehouse.dart';
import 'storage/local_storage.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _controller = TextEditingController(text: 'MAIN');
  final _api = InventoryApi();
  Future<List<InventoryDocumentSummary>>? _future;
  List<InventoryDocumentSummary> _saved = const [];
  bool _savedExpanded = true;
  Future<List<Warehouse>>? _warehousesFuture;
  String? _selectedWarehouseCode;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _warehousesFuture = _api.getWarehouses();
  }

  Future<void> _loadSaved() async {
    final stored = await InventoryLocalStorage().getSavedDocuments();
    // map details to summary for display
    final mapped = stored
        .map(
          (d) => InventoryDocumentSummary(
            id: d.id,
            number: d.number,
            warehouseCode: d.warehouseCode,
            createdAt: d.createdAt,
            linesCount: d.lines.length,
          ),
        )
        .toList();
    setState(() => _saved = mapped);
  }

  void _load() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _future = _api.getDocumentsByWarehouse(code);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Инвентаризация — документы')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Warehouses section
            FutureBuilder<List<Warehouse>>(
              future: _warehousesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Ошибка складов: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final warehouses = snap.data ?? const <Warehouse>[];
                if (warehouses.isEmpty) {
                  return const SizedBox.shrink();
                }
                final items = warehouses
                    .map(
                      (w) => DropdownMenuItem<String>(
                        value: w.code,
                        child: Text(
                          w.name == null || w.name!.isEmpty
                              ? w.code
                              : '${w.code} — ${w.name}',
                        ),
                      ),
                    )
                    .toList();
                _selectedWarehouseCode ??= _controller.text.trim().isNotEmpty
                    ? _controller.text.trim()
                    : warehouses.first.code;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      const Text(
                        'Склады:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedWarehouseCode,
                          items: items,
                          isExpanded: true,
                          selectedItemBuilder: (_) => warehouses
                              .map(
                                (w) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    (w.name == null || w.name!.isEmpty)
                                        ? w.code
                                        : '${w.code} — ${w.name}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedWarehouseCode = v;
                              if (v != null) _controller.text = v;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Обновить склады',
                        onPressed: () => setState(() {
                          _warehousesFuture = _api.getWarehouses();
                        }),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                );
              },
            ),
            Row(
              children: [
                const Text(
                  'Сохранённые документы',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: _loadSaved,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: _savedExpanded ? 'Свернуть' : 'Развернуть',
                  onPressed: () =>
                      setState(() => _savedExpanded = !_savedExpanded),
                  icon: Icon(
                    _savedExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
            if (_savedExpanded)
              SizedBox(
                height: 140,
                child: _saved.isEmpty
                    ? const Center(child: Text('Нет сохранённых документов'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _saved.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final d = _saved[i];
                          return SizedBox(
                            width: 260,
                            child: Card(
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DocumentDetailsScreen(
                                        documentId: d.id,
                                        title: 'Документ №${d.number}',
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '№ ${d.number}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Склад: ${d.warehouseCode}'),
                                      const Spacer(),
                                      Text('Строк: ${d.linesCount}'),
                                      Text(
                                        _fmtDate(d.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Код склада',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                  label: const Text('Найти'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<InventoryDocumentSummary>>(
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
                  final docs = snap.data;
                  if (docs == null) {
                    return const Center(
                      child: Text('Введите код склада и нажмите Найти'),
                    );
                  }
                  if (docs.isEmpty) {
                    return const Center(child: Text('Документы не найдены'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text('№ ${d.number} • ${d.warehouseCode}'),
                        subtitle: Text(
                          'Строк: ${d.linesCount} • ${_fmtDate(d.createdAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DocumentDetailsScreen(
                                documentId: d.id,
                                title: 'Документ №${d.number}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${_two(dt.day)}.${_two(dt.month)}.${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
