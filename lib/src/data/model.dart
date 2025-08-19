class Component {
  final String? skuId;
  final String name;
  final String boxNo;
  final int stock;
  final int? warning;

  Component({
    this.skuId,
    required this.name,
    required this.boxNo,
    required this.stock,
    this.warning,
  });

  // Factory constructor to create Component from Supabase JSON
  factory Component.fromJson(Map<String, dynamic> json) {
    return Component(
      skuId: json['skuid'] as String?,
      name: json['name'] as String,
      boxNo: json['boxno'] as String,
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
