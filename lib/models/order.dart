// 优化的订单模型，使用const构造函数和更高效的数据转换
class Order {
  final int? id;
  final String customerName;
  final DateTime orderDate;
  final String itemName;
  final double quantity;
  final String unit;
  final String source;
  final int isDeleted;
  final DateTime? deletedAt;

  // 使用const构造函数，允许对象被缓存
  const Order({
    this.id,
    required this.customerName,
    required this.orderDate,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.source = '店1',
    this.isDeleted = 0,
    this.deletedAt,
  });

  // 优化的toMap方法，避免不必要的对象创建
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'customerName': customerName,
      'orderDate': orderDate.toIso8601String(),
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'source': source,
      'isDeleted': isDeleted,
    };
    
    // 只在id非空时添加，避免不必要的null值
    if (id != null) {
      map['id'] = id;
    }
    
    // 只在deletedAt非空时添加，避免不必要的null值
    if (deletedAt != null) {
      map['deletedAt'] = deletedAt!.toIso8601String();
    }
    
    return map;
  }

  // 优化的fromMap方法，减少不必要的类型转换
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      customerName: map['customerName'] as String,
      orderDate: DateTime.parse(map['orderDate'] as String),
      itemName: map['itemName'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? '',
      source: map['source'] as String? ?? '店1',
      isDeleted: map['isDeleted'] as int,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt'] as String) : null,
    );
  }
  
  // 添加相等性比较，用于优化列表操作
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && 
           other.id == id &&
           other.customerName == customerName &&
           other.itemName == itemName &&
           other.quantity == quantity &&
           other.unit == unit &&
           other.source == source;
  }
  
  // 添加hashCode以支持集合操作
  @override
  int get hashCode => Object.hash(id, customerName, itemName, quantity, unit, source);
}