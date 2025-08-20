import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_document_details.dart';

class InventoryLocalStorage {
  static const _docsKey = 'inventory.savedDocs';

  Future<void> saveDocument(InventoryDocumentDetails doc) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = _docToJson(doc);
    final newEntry = json.encode(jsonMap);

    final List<String> list = prefs.getStringList(_docsKey) ?? [];

    // Remove existing with same id
    final filtered = list.where((e) {
      try {
        final m = json.decode(e) as Map<String, dynamic>;
        return m['id'] != doc.id;
      } catch (_) {
        return true;
      }
    }).toList();

    filtered.insert(0, newEntry);
    await prefs.setStringList(_docsKey, filtered);
  }

  Future<List<InventoryDocumentDetails>> getSavedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_docsKey) ?? [];
    return list
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
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_docsKey) ?? [];
    for (final e in list) {
      try {
        final m = json.decode(e) as Map<String, dynamic>;
        if (m['id'] == id) {
          return InventoryDocumentDetails.fromJson(m);
        }
      } catch (_) {
        // ignore broken entry
      }
    }
    return null;
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
