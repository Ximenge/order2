class TributeOrder {
  final int? id;
  final String customerName;
  final DateTime orderDate;
  final String itemName;
  final double quantity;
  final String unit;
  final int isDeleted;
  final DateTime? deletedAt;

  const TributeOrder({
    this.id,
    required this.customerName,
    required this.orderDate,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.isDeleted = 0,
    this.deletedAt,
  });

  static const List<MapEntry<String, String>> fixedItems = [
    MapEntry('小鸡（贡）', '只'),
    MapEntry('肉（贡）', '块'),
    MapEntry('鱼（贡）', '条'),
    MapEntry('粉条（贡）', '个'),
    MapEntry('豆腐（贡）', '块'),
  ];

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'customerName': customerName,
      'orderDate': orderDate.toIso8601String(),
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'isDeleted': isDeleted,
    };

    if (id != null) {
      map['id'] = id;
    }

    if (deletedAt != null) {
      map['deletedAt'] = deletedAt!.toIso8601String();
    }

    return map;
  }

  factory TributeOrder.fromMap(Map<String, dynamic> map) {
    return TributeOrder(
      id: map['id'] as int?,
      customerName: map['customerName'] as String,
      orderDate: DateTime.parse(map['orderDate'] as String),
      itemName: map['itemName'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? '',
      isDeleted: map['isDeleted'] as int,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TributeOrder &&
        other.id == id &&
        other.customerName == customerName &&
        other.itemName == itemName &&
        other.quantity == quantity &&
        other.unit == unit;
  }

  @override
  int get hashCode =>
      Object.hash(id, customerName, itemName, quantity, unit);
}
