import 'package:flutter/material.dart';

import 'api/inventory_api.dart';
import 'models/warehouse.dart';

class WarehouseSelectScreen extends StatefulWidget {
  const WarehouseSelectScreen({super.key});

  @override
  State<WarehouseSelectScreen> createState() => _WarehouseSelectScreenState();
}

class _WarehouseSelectScreenState extends State<WarehouseSelectScreen> {
  final _api = InventoryApi();
  late Future<List<Warehouse>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _api.getWarehouses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор склада'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => setState(() => _future = _api.getWarehouses()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск склада по коду или имени',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Warehouse>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Ошибка загрузки складов: ${snap.error}'),
                    ),
                  );
                }
                final all = snap.data ?? const <Warehouse>[];
                final list = _query.isEmpty
                    ? all
                    : all.where((w) {
                        final name = (w.name ?? '').toLowerCase();
                        return w.code.toLowerCase().contains(_query) ||
                            name.contains(_query);
                      }).toList();
                if (list.isEmpty) {
                  return const Center(child: Text('Склады не найдены'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final w = list[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.warehouse_outlined),
                        title: Text(
                          w.code,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: (w.name == null || w.name!.isEmpty)
                            ? null
                            : Text(w.name!),
                        trailing: const Icon(Icons.check),
                        onTap: () => Navigator.of(context).pop<Warehouse>(w),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
