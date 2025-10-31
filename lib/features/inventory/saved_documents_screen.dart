import 'package:flutter/material.dart';

import 'document_details_screen.dart';
import 'models/inventory_document.dart';
import 'storage/local_storage.dart';

class SavedDocumentsScreen extends StatefulWidget {
  const SavedDocumentsScreen({super.key});

  @override
  State<SavedDocumentsScreen> createState() => _SavedDocumentsScreenState();
}

class _SavedDocumentsScreenState extends State<SavedDocumentsScreen> {
  late Future<List<InventoryDocumentSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<InventoryDocumentSummary>> _load() async {
    final stored = await InventoryLocalStorage().getSavedDocuments();
    return stored
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сохранённые документы'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<InventoryDocumentSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Ошибка: ${snap.error}'),
              ),
            );
          }
          final list = snap.data ?? const <InventoryDocumentSummary>[];
          if (list.isEmpty) {
            return const Center(child: Text('Нет сохранённых документов'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12.0),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = list[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
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
    );
  }

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
