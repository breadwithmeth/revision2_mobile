class InventoryLineSummary {
  final String id;
  final String name;
  final String sku;
  final String unit;
  final double qtyFrom1C;
  final double? countedQty;
  final double? correctedQty;
  final double? deltaQty;
  final List<String> barcodes;
  // Optional metadata for conflict handling
  final String? note;
  final String? lastKnownModified; // ISO string from server if provided

  InventoryLineSummary({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.qtyFrom1C,
    this.countedQty,
    this.correctedQty,
    this.deltaQty,
    required this.barcodes,
    this.note,
    this.lastKnownModified,
  });

  factory InventoryLineSummary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> bcs = (json['barcodes'] as List<dynamic>? ?? []);
    return InventoryLineSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String,
      unit: (json['unit'] as String? ?? ''),
      qtyFrom1C: _toDouble(json['qtyFrom1C']),
      countedQty: _toDoubleOrNull(json['countedQty']),
      correctedQty: _toDoubleOrNull(json['correctedQty']),
      deltaQty: _toDoubleOrNull(json['deltaQty']),
      barcodes: bcs
          .map(
            (e) => (e is Map<String, dynamic>)
                ? e['barcode'] as String
                : e.toString(),
          )
          .toList(),
      note: (json['note'] as String?)?.toString(),
      lastKnownModified: (json['lastKnownModified'] as String?)?.toString(),
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class InventoryDocumentDetails {
  final String id;
  final String number;
  final String warehouseCode;
  final DateTime createdAt;
  final List<InventoryLineSummary> lines;
  final int? version; // optional optimistic version from server

  InventoryDocumentDetails({
    required this.id,
    required this.number,
    required this.warehouseCode,
    required this.createdAt,
    required this.lines,
    this.version,
  });

  factory InventoryDocumentDetails.fromJson(Map<String, dynamic> json) {
    // Items array from server maps to lines
    final linesJson = (json['items'] as List<dynamic>? ?? []);
    return InventoryDocumentDetails(
      id: json['id'] as String,
      number: (json['onecNumber'] ?? json['number']) as String,
      warehouseCode:
          (json['warehouseCode'] ?? (json['warehouse']?['code'])) as String,
      createdAt: DateTime.parse(
        (json['onecDate'] ?? json['createdAt']) as String,
      ),
      lines: linesJson
          .map((e) => InventoryLineSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: (json['version'] is int)
          ? (json['version'] as int)
          : int.tryParse((json['version']?.toString() ?? '')),
    );
  }
}
