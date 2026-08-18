class Component {
  final String? skuId;
  final String name;
  final String boxNo;
  final int stock;
  final int availableStock;
  final int issuedStock;
  final int? warning;

  Component({
  this.skuId,
  required this.name,
  required this.boxNo,
  required this.stock,
  this.availableStock = 0,
  this.issuedStock = 0,
  this.warning,
});

  factory Component.fromJson(Map<String, dynamic> json) {
    return Component(
      skuId: (json['skuid'] ?? json['skuId'] ?? json['sku_id'])?.toString(),
      name: (json['name'] ?? json['compname'] ?? json['component_name'] ?? 'Unknown Component').toString(),
      boxNo: (json['boxno'] ??
              json['boxNo'] ??
              json['box_no'] ??
              json['box'] ??
              'Not Assigned')
          .toString(),
      stock: _parseToInt(json['stock']),
      warning: _parseToIntNullable(json['warning']),
    );
  }

  // Helper method to safely parse to int
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper method to safely parse to nullable int
  static int? _parseToIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Convert Component to JSON for Supabase operations
  Map<String, dynamic> toJson() {
    return {
      'skuid': skuId,
      'name': name,
      'boxno': boxNo,
      'stock': stock,
      'warning': warning,
    };
  }
}
