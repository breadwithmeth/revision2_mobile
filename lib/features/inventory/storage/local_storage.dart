import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/inventory_document_details.dart';

/// Simple singleton database provider for the app's local storage
class _InventoryDatabase {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'inventory.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE docs (id TEXT PRIMARY KEY, json TEXT NOT NULL, updatedAt INTEGER NOT NULL)',
        );
        await db.execute('CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return _db!;
  }
}

class InventoryLocalStorage {
  /// Key for device id in kv table
  static const _deviceIdKey = 'inventory.deviceId';

  Future<void> saveDocument(InventoryDocumentDetails doc) async {
    final db = await _InventoryDatabase.instance();
    final Map<String, dynamic> jsonMap = _docToJson(doc);
    final newEntry = json.encode(jsonMap);
    await db.insert('docs', {
      'id': doc.id,
      'json': newEntry,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<InventoryDocumentDetails>> getSavedDocuments() async {
    final db = await _InventoryDatabase.instance();
    final rows = await db.query(
      'docs',
      columns: ['json'],
      orderBy: 'updatedAt DESC',
    );
    return rows
        .map((r) => r['json'] as String)
        .map((e) {
          try {
            final m = json.decode(e) as Map<String, dynamic>;
            return InventoryDocumentDetails.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<InventoryDocumentDetails>()
        .toList();
  }

  Future<InventoryDocumentDetails?> getDocumentById(String id) async {
    final db = await _InventoryDatabase.instance();
    final rows = await db.query(
      'docs',
      columns: ['json'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final m =
          json.decode(rows.first['json'] as String) as Map<String, dynamic>;
      return InventoryDocumentDetails.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// Returns existing device id or generates and stores a new one in kv table
  static Future<String> getOrCreateDeviceId() async {
    final db = await _InventoryDatabase.instance();
    final kv = await db.query(
      'kv',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_deviceIdKey],
      limit: 1,
    );
    if (kv.isNotEmpty) {
      final v = kv.first['value'] as String?;
      if (v != null && v.isNotEmpty) return v;
    }

    // Generate new device ID similar to previous format
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (now % 99999).toString().padLeft(5, '0');
    final deviceId = 'TSD-$random-${now.toString().substring(8)}';
    await db.insert('kv', {
      'key': _deviceIdKey,
      'value': deviceId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return deviceId;
  }

  Map<String, dynamic> _docLineToJson(InventoryLineSummary l) => {
    'id': l.id,
    'name': l.name,
    'sku': l.sku,
    'unit': l.unit,
    'qtyFrom1C': l.qtyFrom1C,
    'countedQty': l.countedQty,
    'correctedQty': l.correctedQty,
    'deltaQty': l.deltaQty,
    'barcodes': l.barcodes,
    if (l.note != null) 'note': l.note,
    if (l.lastKnownModified != null) 'lastKnownModified': l.lastKnownModified,
  };

  Map<String, dynamic> _docToJson(InventoryDocumentDetails d) => {
    'id': d.id,
    'onecNumber': d.number,
    'warehouseCode': d.warehouseCode,
    'createdAt': d.createdAt.toIso8601String(),
    'items': d.lines.map(_docLineToJson).toList(),
    if (d.version != null) 'version': d.version,
  };
}
