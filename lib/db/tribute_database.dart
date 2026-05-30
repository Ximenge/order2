import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tribute_order.dart';

class TributeDatabase {
  static final TributeDatabase instance = TributeDatabase._init();
  static Database? _database;

  TributeDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tribute_orders.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tribute_orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT NOT NULL,
        orderDate TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        deletedAt TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_tribute_orders_customerName ON tribute_orders(customerName)');
    await db.execute(
        'CREATE INDEX idx_tribute_orders_orderDate ON tribute_orders(orderDate)');
    await db.execute(
        'CREATE INDEX idx_tribute_orders_isDeleted ON tribute_orders(isDeleted)');
    await db.execute(
        'CREATE INDEX idx_tribute_orders_customerDate ON tribute_orders(customerName, orderDate)');
    await db.execute(
        'CREATE INDEX idx_tribute_orders_deletedAt ON tribute_orders(deletedAt)');
  }

  Future<int> createOrder(TributeOrder order) async {
    final db = await instance.database;
    return await db.insert('tribute_orders', order.toMap());
  }

  Future<List<TributeOrder>> getAllOrders() async {
    final db = await instance.database;
    final result =
        await db.query('tribute_orders', orderBy: 'orderDate DESC');
    return result.map((json) => TributeOrder.fromMap(json)).toList();
  }

  Future<List<TributeOrder>> getActiveOrders() async {
    final db = await instance.database;
    final result = await db.query('tribute_orders',
        where: 'isDeleted = 0', orderBy: 'orderDate DESC');
    return result.map((json) => TributeOrder.fromMap(json)).toList();
  }

  Future<List<TributeOrder>> getDeletedOrders() async {
    final db = await instance.database;
    final result = await db.query('tribute_orders',
        where: 'isDeleted = 1', orderBy: 'deletedAt DESC');
    return result.map((json) => TributeOrder.fromMap(json)).toList();
  }

  Future<List<TributeOrder>> getOrdersByCustomer(
      String customerName) async {
    final db = await instance.database;
    final result = await db.query(
      'tribute_orders',
      where: 'customerName = ? AND isDeleted = 0',
      whereArgs: [customerName],
      orderBy: 'orderDate DESC',
    );
    return List.generate(
        result.length, (index) => TributeOrder.fromMap(result[index]));
  }

  Future<List<String>> getAllCustomerNames() async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT DISTINCT customerName FROM tribute_orders WHERE isDeleted = 0');
    return result.map((row) => row['customerName'] as String).toList();
  }

  Future<DateTime?> getCustomerFirstOrderDate(
      String customerName) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT MIN(orderDate) as firstOrderDate 
      FROM tribute_orders 
      WHERE customerName = ? AND isDeleted = 0
    ''', [customerName]);

    if (result.isNotEmpty && result[0]['firstOrderDate'] != null) {
      return DateTime.parse(result[0]['firstOrderDate'] as String);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getItemStats() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        itemName, 
        unit, 
        SUM(quantity) as total 
      FROM tribute_orders 
      WHERE isDeleted = 0
      GROUP BY itemName, unit
    ''');
  }

  Future<List<TributeOrder>> getOrdersByItem(
      String itemName, String unit) async {
    final db = await instance.database;
    final result = await db.query(
      'tribute_orders',
      where: 'itemName = ? AND unit = ? AND isDeleted = 0',
      whereArgs: [itemName, unit],
      orderBy: 'customerName ASC, orderDate DESC',
    );
    return result.map((json) => TributeOrder.fromMap(json)).toList();
  }

  Future<void> deleteOrder(TributeOrder order) async {
    final db = await instance.database;
    await db.update(
      'tribute_orders',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> restoreOrder(TributeOrder order) async {
    final db = await instance.database;
    await db.update(
      'tribute_orders',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> physicalDeleteOrder(TributeOrder order) async {
    final db = await instance.database;
    await db.delete('tribute_orders', where: 'id = ?', whereArgs: [order.id]);
  }

  Future<void> clearAllHistory() async {
    final db = await instance.database;
    await db.delete('tribute_orders', where: 'isDeleted = 1');
  }
}
