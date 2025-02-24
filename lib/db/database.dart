import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';

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
      version: 4, // 增加版本号以支持修改
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE orders ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE orders ADD COLUMN unit TEXT NOT NULL DEFAULT ""');
    }
    if (oldVersion < 4) { // 新增版本，用于升级 quantity 到 REAL
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
    return result.map((json) => Order.fromMap(json)).toList();
  }

  Future<List<String>> getAllCustomerNames() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT customerName FROM orders WHERE isDeleted = 0');
    return result.map((row) => row['customerName'] as String).toList();
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