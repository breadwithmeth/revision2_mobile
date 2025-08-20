import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/inventory_document.dart';
import '../models/inventory_document_details.dart';
import '../storage/local_storage.dart';
import '../models/warehouse.dart';

class InventoryApi {
  InventoryApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? 'https://rev2.naliv.kz';
  // _baseUrl = baseUrl ?? 'http://localhost:3000';

  final http.Client _client;
  final String _baseUrl;

  /// GET /inventory-documents/warehouse/:warehouseCode
  Future<List<InventoryDocumentSummary>> getDocumentsByWarehouse(
    String warehouseCode,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/inventory-documents/warehouse/$warehouseCode',
    );
    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List<dynamic> data = json.decode(res.body) as List<dynamic>;

      return data
          .map(
            (e) => InventoryDocumentSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw HttpException(
        'Failed to load documents: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// GET /warehouses
  Future<List<Warehouse>> getWarehouses() async {
    final uri = Uri.parse('$_baseUrl/warehouses');
    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List<dynamic> data = json.decode(res.body) as List<dynamic>;
      return data
          .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw HttpException(
      'Failed to load warehouses: ${res.statusCode} ${res.body}',
    );
  }

  /// GET /inventory-documents/:id
  Future<InventoryDocumentDetails> getDocumentDetails(String id) async {
    final uri = Uri.parse('$_baseUrl/inventory-documents/$id');
    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final Map<String, dynamic> data =
          json.decode(res.body) as Map<String, dynamic>;
      final serverDoc = InventoryDocumentDetails.fromJson(data);

      // merge with local edits if any to avoid overwriting countedQty
      final storage = InventoryLocalStorage();
      final localDoc = await storage.getDocumentById(id);
      if (localDoc == null) {
        await storage.saveDocument(serverDoc);
        return serverDoc;
      }

      // Build index for local lines by id and sku
      final byId = {for (final l in localDoc.lines) l.id: l};
      final bySku = {for (final l in localDoc.lines) l.sku: l};

      final mergedLines = serverDoc.lines.map((srv) {
        final local = byId[srv.id] ?? bySku[srv.sku];
        if (local == null) return srv;
        final counted = local.countedQty ?? srv.countedQty;
        final delta = (counted != null)
            ? (counted - srv.qtyFrom1C)
            : srv.deltaQty;
        return InventoryLineSummary(
          id: srv.id,
          name: srv.name,
          sku: srv.sku,
          unit: srv.unit,
          qtyFrom1C: srv.qtyFrom1C,
          countedQty: counted,
          correctedQty: srv.correctedQty,
          deltaQty: delta,
          barcodes: srv.barcodes,
          note: local.note ?? srv.note,
          lastKnownModified: local.lastKnownModified ?? srv.lastKnownModified,
        );
      }).toList();

      final mergedDoc = InventoryDocumentDetails(
        id: serverDoc.id,
        number: serverDoc.number,
        warehouseCode: serverDoc.warehouseCode,
        createdAt: serverDoc.createdAt,
        lines: mergedLines,
        version: serverDoc.version ?? localDoc.version,
      );
      await storage.saveDocument(mergedDoc);
      return mergedDoc;
    } else {
      throw HttpException(
        'Failed to load document: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// PATCH /inventory-documents/:id/lines/by-barcode
  /// body: { barcode: string, deltaQuantity: number }
  Future<InventoryDocumentDetails> patchQuantityByBarcode({
    required String documentId,
    required String barcode,
    required double deltaQuantity,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/inventory-documents/$documentId/lines/by-barcode',
    );
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({'barcode': barcode, 'deltaQuantity': deltaQuantity}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final Map<String, dynamic> data =
          json.decode(res.body) as Map<String, dynamic>;
      final details = InventoryDocumentDetails.fromJson(data);
      return details;
    } else {
      throw HttpException(
        'Failed to update qty: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// POST /inventory-documents/:id/items/v2
  /// Upload all counted items with countedQty > 0. Returns response JSON
  /// including conflicts when status 206.
  Future<Map<String, dynamic>> uploadItemsV2({
    required String documentId,
    required String deviceId,
    required List<Map<String, dynamic>> items,
    int? version,
  }) async {
    final uri = Uri.parse('$_baseUrl/inventory-documents/$documentId/items/v2');
    final payload = <String, dynamic>{
      'version': version ?? 1,
      'deviceId': deviceId,
      'items': items,
    };
    print(uri);

    final res = await _client.patch(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );
    print(res.body);

    if (res.statusCode == 200 || res.statusCode == 206) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw HttpException(
      'Failed to upload items: ${res.statusCode} ${res.body}',
    );
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
