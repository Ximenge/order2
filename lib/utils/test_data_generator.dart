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

  // 订单来源列表
  static const List<String> _sources = const ['店1', '店2', '店3'];

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
      source: _sources[_random.nextInt(_sources.length)], // 随机选择订单来源
      isDeleted: 0,
    );
  }

  /// 生成测试数据
  /// 满足新需求：
  /// 1. 每次生成400个订单
  /// 2. 至少10个不同的客户
  /// 3. 每个客户至少5个订单
  /// 4. 每个客户都需要有三个来源的订单
  /// 5. 同一个货物名称至少要两个不同的单位和不同的数量
  Future<void> generateTestData({
    required AppDatabase database,
  }) async {
    final db = await database.database;
    
    // 配置参数
    const int totalOrders = 400;
    const int minCustomers = 10;
    const int minOrdersPerCustomer = 5;
    const List<String> sources = ['店1', '店2', '店3'];
    
    // 计算客户数量和每个客户的订单数
    // 确保每个客户至少有minOrdersPerCustomer个订单，并且总订单数为totalOrders
    final int customerCount = _random.nextInt(10) + minCustomers; // 10-19个客户
    final int baseOrdersPerCustomer = totalOrders ~/ customerCount;
    final int extraOrders = totalOrders % customerCount;
    
    final List<String> customerNames = [];
    final List<int> orderCounts = [];
    
    // 生成客户名称和订单数
    for (int i = 0; i < customerCount; i++) {
      customerNames.add(_generateCustomerName());
      // 确保每个客户至少有minOrdersPerCustomer个订单
      final int orders = baseOrdersPerCustomer + (i < extraOrders ? 1 : 0);
      orderCounts.add(orders < minOrdersPerCustomer ? minOrdersPerCustomer : orders);
    }
    
    // 确保总订单数至少为400
    int actualTotalOrders = orderCounts.reduce((a, b) => a + b);
    if (actualTotalOrders < totalOrders) {
      // 分配剩余订单
      int remaining = totalOrders - actualTotalOrders;
      int index = 0;
      while (remaining > 0) {
        orderCounts[index]++;
        index = (index + 1) % customerCount;
        remaining--;
      }
    }
    
    // 跟踪每个货物使用的单位，确保同一个货物至少有两个不同的单位
    final Map<String, Set<String>> itemUnits = {};
    
    // 使用事务进行批量插入，提高性能
    await db.transaction((txn) async {
      // 对每个客户使用单独的批处理，避免批处理过大
      for (int i = 0; i < customerCount; i++) {
        final customerName = customerNames[i];
        final orderCount = orderCounts[i];
        final batch = txn.batch();
        
        // 确保每个客户都有三个来源的订单
        final Map<String, int> sourceOrderCounts = {
          '店1': 0,
          '店2': 0,
          '店3': 0,
        };
        
        // 先分配每个来源至少1个订单
        for (String source in sources) {
          sourceOrderCounts[source] = 1;
        }
        
        // 分配剩余的订单
        int remainingOrders = orderCount - sources.length;
        while (remainingOrders > 0) {
          final source = sources[_random.nextInt(sources.length)];
          sourceOrderCounts[source] = (sourceOrderCounts[source] ?? 0) + 1;
          remainingOrders--;
        }
        
        // 生成订单
        for (String source in sources) {
          int count = sourceOrderCounts[source] ?? 0;
          for (int j = 0; j < count; j++) {
            // 随机选择货物名称
            String itemName = _itemNames[_random.nextInt(_itemNames.length)];
            
            // 确保同一个货物至少有两个不同的单位
            Set<String> usedUnits = itemUnits[itemName] ?? {};
            String unit;
            
            if (usedUnits.isEmpty) {
              // 第一次使用这个货物，随机选择一个单位
              unit = _units[_random.nextInt(_units.length)];
              usedUnits.add(unit);
            } else if (usedUnits.length == 1) {
              // 第二次使用这个货物，必须选择一个不同的单位
              do {
                unit = _units[_random.nextInt(_units.length)];
              } while (usedUnits.contains(unit));
              usedUnits.add(unit);
            } else {
              // 已经有两个以上的单位，随机选择一个
              unit = _units[_random.nextInt(_units.length)];
            }
            
            // 更新货物使用的单位记录
            itemUnits[itemName] = usedUnits;
            
            // 生成数量，确保同一个货物不同单位有不同的数量范围
            double quantity;
            if (unit == '吨' || unit == '千克' || unit == '克') {
              // 重量单位，数量范围较大
              quantity = _random.nextDouble() * 10000 + 1;
            } else if (unit == '米' || unit == '厘米' || unit == '毫米') {
              // 长度单位，中等数量范围
              quantity = _random.nextDouble() * 1000 + 1;
            } else {
              // 其他单位，较小数量范围
              quantity = _random.nextDouble() * 100 + 1;
            }
            
            // 直接生成Map，避免中间Order对象的创建
            batch.insert('orders', {
              'customerName': customerName,
              'orderDate': DateTime.now().subtract(Duration(days: _random.nextInt(365))).toIso8601String(),
              'itemName': itemName,
              'quantity': quantity,
              'unit': unit,
              'source': source,
              'isDeleted': 0,
            });
          }
        }
        
        // 提交批处理
        await batch.commit(noResult: true); // noResult: true 进一步提高性能
      }
    });
  }
}