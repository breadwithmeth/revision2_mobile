class Warehouse {
  final String code;
  final String? name;

  Warehouse({required this.code, this.name});

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? json['id'] ?? json['warehouseCode'])
        .toString();
    final name = (json['name'] ?? json['title'] ?? json['description'])
        ?.toString();
    return Warehouse(code: code, name: name);
  }
}
