import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';
import 'database_migration.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('orders.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7, // 增加版本号以应用删除时间字段
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // 使用迁移助手执行数据库迁移
        await DatabaseMigration.migrate(db, oldVersion, newVersion);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 创建主表
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT NOT NULL,
        orderDate TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL, /* 修改为 REAL 类型 */
        unit TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT '店1', /* 新增来源字段 */
        createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        deletedAt TEXT, /* 新增删除时间字段 */
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // 添加索引以提高查询性能
    await db.execute('CREATE INDEX idx_orders_customerName ON orders(customerName)');
    await db.execute('CREATE INDEX idx_orders_orderDate ON orders(orderDate)');
    await db.execute('CREATE INDEX idx_orders_isDeleted ON orders(isDeleted)');
    await db.execute('CREATE INDEX idx_orders_customerDate ON orders(customerName, orderDate)');
    await db.execute('CREATE INDEX idx_orders_source ON orders(source)'); /* 新增来源字段索引 */
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE orders ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE orders ADD COLUMN unit TEXT NOT NULL DEFAULT ""');
    }
    if (oldVersion < 4) { // 新增版本，用于升级 quantity 到 REAL 并添加索引
      await db.execute(
        'ALTER TABLE orders RENAME TO old_orders',
      );
      await db.execute(
        '''CREATE TABLE orders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerName TEXT NOT NULL,
          orderDate TEXT NOT NULL,
          itemName TEXT NOT NULL,
          quantity REAL NOT NULL, /* 修改为 REAL 类型 */
          unit TEXT NOT NULL DEFAULT '',
          createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          isDeleted INTEGER NOT NULL DEFAULT 0
        )'''
      );
      await db.execute(
        'INSERT INTO orders SELECT * FROM old_orders',
      );
      await db.execute(
        'DROP TABLE old_orders',
      );
      
      // 添加索引
      await db.execute('CREATE INDEX idx_orders_customerName ON orders(customerName)');
      await db.execute('CREATE INDEX idx_orders_orderDate ON orders(orderDate)');
      await db.execute('CREATE INDEX idx_orders_isDeleted ON orders(isDeleted)');
      await db.execute('CREATE INDEX idx_orders_customerDate ON orders(customerName, orderDate)');
    } else if (oldVersion == 4) {
      // 如果是从版本4升级到更高版本，只添加索引
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_customerName ON orders(customerName)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_orderDate ON orders(orderDate)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_isDeleted ON orders(isDeleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_customerDate ON orders(customerName, orderDate)');
    }
  }

  Future<int> createOrder(Order order) async {
    final db = await instance.database;
    return await db.insert('orders', order.toMap());
  }

  Future<List<Order>> getAllOrders() async {
    final db = await instance.database;
    final result = await db.query('orders', orderBy: 'orderDate DESC');
    return result.map((json) => Order.fromMap(json)).toList();
  }

  Future<List<Order>> getActiveOrders() async {
    final db = await instance.database;
    final result = await db.query('orders', where: 'isDeleted = 0', orderBy: 'orderDate DESC');
    return result.map((json) => Order.fromMap(json)).toList();
  }

  Future<List<Order>> getDeletedOrders() async {
    final db = await instance.database;
    final result = await db.query('orders', where: 'isDeleted = 1', orderBy: 'deletedAt DESC');
    return result.map((json) => Order.fromMap(json)).toList();
  }

  Future<List<Order>> getOrdersByCustomer(String customerName) async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      where: 'customerName = ? AND isDeleted = 0',
      whereArgs: [customerName],
      orderBy: 'orderDate DESC',
    );
    
    // 预分配列表以减少内存重新分配
    final List<Order> orders = List.generate(result.length, (index) => Order.fromMap(result[index]));
    return orders;
  }

  Future<List<String>> getAllCustomerNames() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT customerName FROM orders WHERE isDeleted = 0');
    return result.map((row) => row['customerName'] as String).toList();
  }

  // 按来源获取客户名称列表
  Future<List<String>> getCustomerNamesBySource(String? source) async {
    final db = await instance.database;
    if (source == null || source.isEmpty) {
      // 如果来源为空，获取所有客户名称
      return getAllCustomerNames();
    }
    final result = await db.rawQuery(
      'SELECT DISTINCT customerName FROM orders WHERE isDeleted = 0 AND source = ?',
      [source],
    );
    return result.map((row) => row['customerName'] as String).toList();
  }

  // 优化后的按姓氏排序获取客户名称列表
  Future<List<String>> getCustomerNamesSortedByLastName() async {
    final db = await instance.database;
    // 优化查询，减少不必要的数据转换
    final result = await db.query(
      'orders',
      columns: ['customerName'],
      where: 'isDeleted = 0',
      distinct: true,
    );
    
    // 使用List.generate创建固定大小列表，减少内存分配
    final int count = result.length;
    List<String> customerNames = List.generate(count, (i) => result[i]['customerName'] as String);
    
    // 优化的汉字排序实现
    customerNames.sort((a, b) {
      return a.compareTo(b); // Dart的默认字符串比较已支持Unicode字符排序
    });
    
    return customerNames;
  }

  // 优化后的按最后下单时间排序获取客户名称列表
  Future<List<String>> getCustomerNamesSortedByLastOrderDate() async {
    final db = await instance.database;
    // 使用GROUP BY和MAX聚合函数代替子查询，提高性能
    final result = await db.rawQuery('''
      SELECT customerName 
      FROM orders 
      WHERE isDeleted = 0 
      GROUP BY customerName
      ORDER BY MAX(orderDate) DESC
    ''');
    return result.map((row) => row['customerName'] as String).toList();
  }

  // 新增方法：检查客户是否存在
  Future<bool> hasCustomer(String customerName) async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      columns: ['customerName'],
      where: 'customerName = ? AND isDeleted = 0',
      whereArgs: [customerName],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  
  // 新增方法：根据来源获取订单
  Future<List<Order>> getOrdersBySource(String source) async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      where: 'source = ? AND isDeleted = 0',
      whereArgs: [source],
      orderBy: 'orderDate DESC',
    );
    
    final List<Order> orders = List.generate(result.length, (index) => Order.fromMap(result[index]));
    return orders;
  }
  
  // 新增方法：根据客户名称和来源获取订单
  Future<List<Order>> getOrdersByCustomerAndSource(String customerName, String source) async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      where: 'customerName = ? AND source = ? AND isDeleted = 0',
      whereArgs: [customerName, source],
      orderBy: 'orderDate DESC',
    );
    
    final List<Order> orders = List.generate(result.length, (index) => Order.fromMap(result[index]));
    return orders;
  }

  Future<List<Map<String, dynamic>>> getItemStats({String? source}) async {
    final db = await instance.database;
    String whereClause = 'isDeleted = 0';
    List<String> whereArgs = [];
    
    if (source != null && source.isNotEmpty) {
      whereClause += ' AND source = ?';
      whereArgs.add(source);
    }
    
    return await db.rawQuery('''
      SELECT 
        itemName, 
        unit, 
        SUM(quantity) as total 
      FROM orders 
      WHERE $whereClause
      GROUP BY itemName, unit
    ''', whereArgs);
  }

  // 获取某个货物的所有订单
  Future<List<Order>> getOrdersByItem(String itemName, String unit, {String? source}) async {
    final db = await instance.database;
    String whereClause = 'itemName = ? AND unit = ? AND isDeleted = 0';
    List<String> whereArgs = [itemName, unit];
    
    if (source != null && source.isNotEmpty) {
      whereClause += ' AND source = ?';
      whereArgs.add(source);
    }
    
    final result = await db.query(
      'orders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'source ASC, customerName ASC, orderDate DESC', // 按来源和客户名称排序
    );
    return result.map((json) => Order.fromMap(json)).toList();
  }

  Future<void> deleteOrder(Order order) async {
    final db = await instance.database;
    await db.update(
      'orders',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()}, // 设置删除时间
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> restoreOrder(Order order) async {
    final db = await instance.database;
    await db.update(
      'orders',
      {'isDeleted': 0, 'deletedAt': null}, // 清除删除时间
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> clearAllHistory() async {
    final db = await instance.database;
    await db.delete('orders', where: 'isDeleted = 1');
  }

  // 添加 physicalDeleteOrder 方法
  Future<void> physicalDeleteOrder(Order order) async {
    final db = await instance.database;
    await db.delete('orders', where: 'id = ?', whereArgs: [order.id]);
  }
}