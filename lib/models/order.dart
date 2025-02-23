class Order {
  int? id;
  final String customerName;
  final DateTime orderDate;
  final String itemName;
  final double quantity; // 修改为双精度浮点数
  final String unit;
  final int isDeleted;

  Order({
    this.id,
    required this.customerName,
    required this.orderDate,
    required this.itemName,
    required this.quantity, // 修改为双精度浮点数
    required this.unit,
    this.isDeleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'orderDate': orderDate.toIso8601String(),
      'itemName': itemName,
      'quantity': quantity, // 双精度浮点数
      'unit': unit,
      'isDeleted': isDeleted,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      customerName: map['customerName'] as String,
      orderDate: DateTime.parse(map['orderDate'] as String),
      itemName: map['itemName'] as String,
      quantity: (map['quantity'] as num).toDouble(), // 双精度浮点数
      unit: map['unit'] as String? ?? '',
      isDeleted: map['isDeleted'] as int,
    );
  }
}