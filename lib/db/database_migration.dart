import 'package:sqflite/sqflite.dart';

/// 数据库迁移助手类
class DatabaseMigration {
  /// 执行数据库迁移
  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    // 确保按顺序应用迁移
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 5:
          await _migrateToVersion5(db);
          break;
        case 6:
          await _migrateToVersion6(db);
          break;
        // 未来版本可以在这里添加更多迁移
      }
    }
  }

  /// 迁移到版本5 - 添加索引以提高性能
  static Future<void> _migrateToVersion5(Database db) async {
    // 使用事务执行所有索引创建操作
    await db.transaction((txn) async {
      // 添加客户名称索引
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_orders_customer_name ON orders(customerName)');
      // 添加订单日期索引
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(orderDate)');
      // 添加删除状态索引
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_orders_is_deleted ON orders(isDeleted)');
      // 添加复合索引，优化按客户名称和日期排序的查询
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_orders_customer_date ON orders(customerName, orderDate)');
    });
  }

  /// 迁移到版本6 - 添加来源字段
  static Future<void> _migrateToVersion6(Database db) async {
    // 使用事务执行字段添加操作
    await db.transaction((txn) async {
      // 添加来源字段，默认为"店1"
      await txn.execute('ALTER TABLE orders ADD COLUMN source TEXT NOT NULL DEFAULT "店1"');
      // 添加来源索引以提高查询性能
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_orders_source ON orders(source)');
    });
  }
}
