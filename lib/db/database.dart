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
      version: 5, // 增加版本号以应用新索引和hasCustomer方法
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
        createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // 添加索引以提高查询性能
    await db.execute('CREATE INDEX idx_orders_customerName ON orders(customerName)');
    await db.execute('CREATE INDEX idx_orders_orderDate ON orders(orderDate)');
    await db.execute('CREATE INDEX idx_orders_isDeleted ON orders(isDeleted)');
    await db.execute('CREATE INDEX idx_orders_customerDate ON orders(customerName, orderDate)');
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
    final result = await db.query('orders', where: 'isDeleted = 1', orderBy: 'orderDate DESC');
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

  Future<List<Map<String, dynamic>>> getItemStats() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        itemName, 
        unit, 
        SUM(quantity) as total 
      FROM orders 
      WHERE isDeleted = 0
      GROUP BY itemName, unit
    ''');
  }

  Future<void> deleteOrder(Order order) async {
    final db = await instance.database;
    await db.update(
      'orders',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> restoreOrder(Order order) async {
    final db = await instance.database;
    await db.update(
      'orders',
      {'isDeleted': 0},
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