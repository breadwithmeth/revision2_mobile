class InventoryDocumentSummary {
  final String id;
  final String number;
  final String warehouseCode;
  final DateTime createdAt;
  final int linesCount;

  InventoryDocumentSummary({
    required this.id,
    required this.number,
    required this.warehouseCode,
    required this.createdAt,
    required this.linesCount,
  });

  factory InventoryDocumentSummary.fromJson(Map<String, dynamic> json) {
    return InventoryDocumentSummary(
      id: json['id'] as String,
      // API: onecNumber holds the human-readable document number
      number: (json['onecNumber'] ?? json['number']) as String,
      warehouseCode:
          (json['warehouseCode'] ?? (json['warehouse']?['code'])) as String,
      // Prefer onecDate if present, fallback to createdAt
      createdAt: DateTime.parse(
        (json['onecDate'] ?? json['createdAt']) as String,
      ),
      // Prefer explicit linesCount, else try lines.length, else 0
      linesCount:
          (json['linesCount'] as num?)?.toInt() ??
          ((json['lines'] as List?)?.length ?? 0),
    );
  }
}
