import 'package:flutter/material.dart';
import 'api/inventory_api.dart';
import 'models/inventory_document.dart';
import 'document_details_screen.dart';
import 'storage/local_storage.dart';
import 'saved_documents_screen.dart';
import 'warehouse_select_screen.dart';

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
  String? _selectedWarehouseCode;
  String? _selectedWarehouseName;

  @override
  void initState() {
    super.initState();
    _loadSaved();
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
            // Warehouse pick button
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: const Text('Склад'),
                subtitle: Text(
                  _selectedWarehouseCode == null
                      ? 'Не выбран'
                      : _selectedWarehouseName == null ||
                            _selectedWarehouseName!.isEmpty
                      ? _selectedWarehouseCode!
                      : '${_selectedWarehouseCode!} — ${_selectedWarehouseName!}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selected = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WarehouseSelectScreen(),
                    ),
                  );
                  if (!mounted) return;
                  if (selected != null) {
                    setState(() {
                      _selectedWarehouseCode =
                          selected.code as String? ?? selected.code;
                      _selectedWarehouseName = selected.name as String?;
                      _controller.text = _selectedWarehouseCode ?? '';
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            // Saved documents button
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Сохранённые документы'),
                subtitle: Text(
                  _saved.isEmpty
                      ? 'Нет сохранённых'
                      : 'Количество: ${_saved.length}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SavedDocumentsScreen(),
                    ),
                  );
                  if (!mounted) return;
                  await _loadSaved();
                },
              ),
            ),
            const SizedBox(height: 8),
            // Search
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Код склада',
                          hintText: 'Например: MAIN',
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.search),
                      label: const Text('Найти'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          dense: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: const Icon(Icons.description_outlined),
                          ),
                          title: Text(
                            '№ ${d.number} • ${d.warehouseCode}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                        ),
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
