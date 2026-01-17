import '../models/order.dart';
import '../db/database.dart';
import 'dart:math';

/// 测试数据生成工具类
/// 用于生成测试用的客户和订单数据
class TestDataGenerator {
  // 常用中文姓氏 - 使用const常量提高性能
  static const List<String> _lastNames = const [
    '王', '李', '张', '刘', '陈', '杨', '黄', '赵', '吴', '周',
    '徐', '孙', '马', '朱', '胡', '郭', '何', '高', '林', '罗',
    '郑', '梁', '谢', '宋', '唐', '许', '韩', '冯', '邓', '曹',
    '彭', '曾', '肖', '田', '董', '袁', '潘', '于', '蒋', '蔡',
    '余', '杜', '叶', '程', '苏', '魏', '吕', '丁', '任', '沈',
  ];

  // 常用中文名字 - 使用const常量提高性能
  static const List<String> _firstNames = const [
    '伟', '芳', '娜', '秀英', '敏', '静', '强', '磊', '军', '洋',
    '勇', '艳', '杰', '秀英', '娟', '涛', '明', '超', '秀兰', '霞',
    '平', '刚', '梅', '英', '莉', '敏', '静', '丽', '强', '磊',
  ];

  // 常用货物名称 - 使用const常量提高性能
  static const List<String> _itemNames = const [
    '钢材', '木材', '水泥', '砖块', '沙子', '石子', '玻璃', '铝材', '铜材', '塑料',
    '纸张', '布料', '皮革', '橡胶', '化工原料', '电子产品', '机械设备', '工具', '零件', '配件',
    '食品', '饮料', '日用品', '化妆品', '办公用品', '家具', '电器', '汽车配件', '建材', '装饰材料',
  ];

  // 常用单位 - 使用const常量提高性能
  static const List<String> _units = const [
    '吨', '千克', '克', '米', '厘米', '毫米', '平方米', '立方米', '个', '件',
    '箱', '包', '袋', '桶', '瓶', '支', '条', '卷', '捆', '打',
  ];

  final Random _random = Random();

  /// 生成随机客户姓名
  String _generateCustomerName() {
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    // 70%概率生成双字名
    if (_random.nextDouble() < 0.7) {
      return lastName + firstName + _firstNames[_random.nextInt(_firstNames.length)];
    }
    return lastName + firstName;
  }

  /// 生成随机订单数据
  Order _generateOrder(String customerName) {
    return Order(
      customerName: customerName,
      orderDate: DateTime.now().subtract(Duration(days: _random.nextInt(365))),
      itemName: _itemNames[_random.nextInt(_itemNames.length)],
      quantity: _random.nextDouble() * 1000 + 1, // 1-1001之间的随机数
      unit: _units[_random.nextInt(_units.length)],
      isDeleted: 0,
    );
  }

  /// 生成测试数据
  /// [customerCount] - 客户数量
  /// [maxOrdersPerCustomer] - 每个客户最多生成的订单数
  Future<void> generateTestData({
    required int customerCount,
    required int maxOrdersPerCustomer,
    required AppDatabase database,
  }) async {
    final db = await database.database;
    
    // 使用事务进行批量插入，提高性能
    await db.transaction((txn) async {
      // 预分配随机数，减少Random调用
      final List<int> orderCounts = List.generate(
        customerCount, 
        (_) => _random.nextInt(maxOrdersPerCustomer) + 1
      );
      
      // 批量生成所有数据
      for (int i = 0; i < customerCount; i++) {
        final customerName = _generateCustomerName();
        final orderCount = orderCounts[i];
        
        // 对每个客户使用单独的批处理，避免批处理过大
        final batch = txn.batch();
        
        for (int j = 0; j < orderCount; j++) {
          // 直接生成Map，避免中间Order对象的创建
          batch.insert('orders', {
            'customerName': customerName,
            'orderDate': DateTime.now().subtract(Duration(days: _random.nextInt(365))).toIso8601String(),
            'itemName': _itemNames[_random.nextInt(_itemNames.length)],
            'quantity': _random.nextDouble() * 1000 + 1,
            'unit': _units[_random.nextInt(_units.length)],
            'isDeleted': 0,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
        
        // 每100个客户提交一次批处理，避免内存压力
        if (i % 100 == 0 || i == customerCount - 1) {
          await batch.commit(noResult: true); // noResult: true 进一步提高性能
        }
      }
    });
  }
}