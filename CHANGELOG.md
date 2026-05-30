# 订货管理系统 (HHX Order)

## 项目概述

订货管理系统是一款基于 Flutter 开发的移动端应用，用于管理客户订货信息、货物统计和历史订单。系统支持多来源（多店铺）订单管理，提供客户订货信息查看、货物统计汇总、历史订单恢复等功能。

**当前版本：1.1.0**

---

## 版本历史

### v1.1.0 (2026-05-30)

#### 新增功能
- **贡品订货模块**：全新的独立子功能模块，与原有订货系统并列但数据完全隔离
  - 贡品订货主页面：固定5种货物（小鸡（贡）/只、肉（贡）/块、鱼（贡）/条、粉条（贡）/个、豆腐（贡）/块）
  - 数量输入框左右增加 +/- 按钮，便于手动点击修改数量
  - "贡品一套"按钮：一键将所有货物数量重置为1
  - 贡品客户订货信息子页面：按拼音排序的客户列表 + 订单详情
  - 贡品货物统计子页面：按货物汇总统计，可展开查看订购记录
  - 贡品历史订单子页面：支持恢复和永久删除
- **贡品订货入口**：主界面保存订单按钮下方，橙色边框醒目按钮
- **导出/导入数据兼容贡品**：导出包含贡品订单数据，导入时同时恢复贡品数据

#### 数据隔离保障
- 贡品模块使用独立数据库文件 `tribute_orders.db`
- 独立数据表 `tribute_orders`，与原有 `orders` 表完全分离
- 独立模型类 `TributeOrder`，独立数据库操作类 `TributeDatabase`
- 所有贡品页面只引用贡品专用数据库和模型，绝不交叉引用

#### 其他改进
- 数据格式版本升级至 1.1（支持贡品订单数据）
- Gradle 仓库配置优化，阿里云镜像优先，解决国内构建网络问题

### v1.0.3
- 客户订货信息页面Tab切换时保持滚动位置
- 客户名称按拼音排序（首字拼音优先，逐字比较，字少在前，最早下单排后）
- 客户订货信息右上角刷新按钮
- 隐藏测试数据生成功能（输入"csz"显示，"zsc"隐藏）
- 数据导出/导入功能（JSON格式，保存到Download目录）
- 导出文件包含导出时间和软件版本
- 导入时警告覆盖，显示文件导出时间和版本

### v1.0.2
- 添加来源选择功能（店1/店2/店3）
- 来源标签显示
- 按来源分类的货物统计TAB
- 历史订单按删除时间排序

### v1.0.1
- 修复Tab切换刷新问题
- 优化滚动位置保持
- 改进UI设计

### v1.0.0
- 初始版本
- 基本订货功能
- 客户订货信息查看
- 货物统计
- 历史订单管理

---

## 功能模块

### 一、订货记录（主页面）

主页面用于录入日常订货信息。

**功能：**
- 输入客户姓名
- 选择下单日期
- 选择来源（店1/店2/店3）
- 添加货物（货物名称 + 数量 + 单位，支持多行）
- 保存订单
- 导出数据（JSON格式，保存到Download目录）
- 导入数据（选择JSON文件，覆盖当前数据）
- 进入贡品订货模块

**隐藏功能：**
- 在客户姓名输入"csz"，货物名称和单位都输入"csz"，点击保存 → 显示测试数据生成按钮
- 在客户姓名输入"zsc"，货物名称和单位都输入"zsc"，点击保存 → 隐藏测试数据生成按钮

### 二、客户订货信息

查看按客户分类的订货信息。

**功能：**
- 左侧客户列表，按拼音排序
- 右侧订单详情列表
- Tab切换：所有 / 店1 / 店2 / 店3
- 点击客户名称筛选该客户订单
- 同一来源的订单分组显示
- 刷新按钮重新加载数据
- 删除订单（软删除，移入历史订单）

**客户排序规则：**
1. 首字相同的客户名靠在一起
2. 整体按首字拼音字母顺序排列
3. 首字拼音相同则比较第二个字拼音，以此类推
4. 拼音完全相同则字少的在前
5. 拼音和字数都相同则最早下单的排后面

### 三、货物统计

按货物汇总统计数量。

**功能：**
- Tab切换：所有 / 店1 / 店2 / 店3
- 显示每种货物的总数量
- 点击展开查看订购记录详情
- 刷新按钮

### 四、历史订单

查看已删除的订单。

**功能：**
- 按删除时间倒序排列
- 恢复订单（回到活跃订单）
- 永久删除订单
- 清除所有历史订单

### 五、贡品订货（新增 v1.1.0）

独立的贡品订货模块，数据与原有订货系统完全隔离。

**贡品订货主页面：**
- 输入客户姓名
- 选择下单日期
- 固定5种货物，每种有 +/- 按钮调整数量
- "贡品一套"按钮：所有数量重置为1
- 保存订单

**贡品客户订货信息：**
- 与原有客户订货信息界面相同
- 无分店Tab（只有一个店）
- 客户按拼音排序
- 支持删除订单

**贡品货物统计：**
- 与原有货物统计界面相同
- 无分店Tab
- 点击展开查看订购记录

**贡品历史订单：**
- 与原有历史订单界面相同
- 支持恢复和永久删除

---

## 技术架构

### 技术栈
- **框架**：Flutter 3.6.1+
- **语言**：Dart
- **数据库**：SQLite (sqflite)
- **状态管理**：Provider
- **拼音排序**：pinyin 包

### 项目结构

```
lib/
├── main.dart                              # 应用入口
├── customer_orders_screen.dart            # 客户订货信息页面
├── db/
│   ├── database.dart                      # 订货系统数据库（orders.db）
│   ├── database_migration.dart            # 数据库迁移
│   └── tribute_database.dart              # 贡品订货数据库（tribute_orders.db）
├── models/
│   ├── order.dart                         # 订货系统订单模型
│   └── tribute_order.dart                 # 贡品订单模型
├── screens/
│   ├── home_screen.dart                   # 订货记录主页面
│   ├── stats_screen.dart                  # 货物统计页面
│   ├── history_orders_screen.dart         # 历史订单页面
│   ├── tribute_home_screen.dart           # 贡品订货主页面
│   ├── tribute_customer_orders_screen.dart # 贡品客户订货信息页面
│   ├── tribute_stats_screen.dart          # 贡品货物统计页面
│   └── tribute_history_orders_screen.dart # 贡品历史订单页面
└── utils/
    └── test_data_generator.dart           # 测试数据生成器
```

### 数据库设计

#### 订货系统数据库 (orders.db)

**表：orders**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| customerName | TEXT | 客户姓名，非空 |
| orderDate | TEXT | 下单日期（ISO8601），非空 |
| itemName | TEXT | 货物名称，非空 |
| quantity | REAL | 数量，非空 |
| unit | TEXT | 单位，非空 |
| source | TEXT | 来源（店1/店2/店3），默认"店1" |
| createdAt | TEXT | 创建时间，默认当前时间 |
| deletedAt | TEXT | 删除时间，可为空 |
| isDeleted | INTEGER | 是否删除（0/1），默认0 |

**索引：**
- idx_orders_customerName (customerName)
- idx_orders_orderDate (orderDate)
- idx_orders_isDeleted (isDeleted)
- idx_orders_customerDate (customerName, orderDate)
- idx_orders_source (source)
- idx_orders_deleted_at (deletedAt)

**数据库版本：7**

#### 贡品订货数据库 (tribute_orders.db)

**表：tribute_orders**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| customerName | TEXT | 客户姓名，非空 |
| orderDate | TEXT | 下单日期（ISO8601），非空 |
| itemName | TEXT | 货物名称，非空 |
| quantity | REAL | 数量，非空 |
| unit | TEXT | 单位，非空 |
| createdAt | TEXT | 创建时间，默认当前时间 |
| deletedAt | TEXT | 删除时间，可为空 |
| isDeleted | INTEGER | 是否删除（0/1），默认0 |

**索引：**
- idx_tribute_orders_customerName (customerName)
- idx_tribute_orders_orderDate (orderDate)
- idx_tribute_orders_isDeleted (isDeleted)
- idx_tribute_orders_customerDate (customerName, orderDate)
- idx_tribute_orders_deletedAt (deletedAt)

**数据库版本：1**

**注意：** 贡品数据库无 source 字段，因为只有一个店。

### 数据隔离设计

| 维度 | 订货系统 | 贡品订货 |
|------|----------|----------|
| 数据库文件 | orders.db | tribute_orders.db |
| 数据表 | orders | tribute_orders |
| 模型类 | Order | TributeOrder |
| 数据库操作类 | AppDatabase | TributeDatabase |
| 页面文件 | home_screen.dart 等 | tribute_home_screen.dart 等 |

两个模块的代码无交叉引用，确保统计数据、操作、删除、恢复等功能完全独立。

---

## 数据导出/导入

### 导出格式

```json
{
  "exportInfo": {
    "timestamp": "2026-05-30T10:00:00.000",
    "appVersion": "1.1.0",
    "dataFormatVersion": "1.1",
    "orderCount": 100,
    "tributeOrderCount": 50
  },
  "orders": [
    {
      "customerName": "张三",
      "orderDate": "2026-05-30T00:00:00.000",
      "itemName": "鸡",
      "quantity": 2.0,
      "unit": "只",
      "source": "店1",
      "isDeleted": 0
    }
  ],
  "tributeOrders": [
    {
      "customerName": "李四",
      "orderDate": "2026-05-30T00:00:00.000",
      "itemName": "小鸡（贡）",
      "quantity": 1.0,
      "unit": "只",
      "isDeleted": 0
    }
  ]
}
```

### 导出位置
- 安卓设备内部存储 `/storage/emulated/0/Download/`
- 文件名格式：`order_export_{时间戳}.json`

### 兼容性
- v1.1 导出文件包含 `tributeOrders` 字段
- 导入时兼容旧版（v1.0）导出文件，无 `tributeOrders` 字段不会报错
- 数据格式版本：1.1（含贡品数据）/ 1.0（不含贡品数据）

---

## 贡品订货固定货物

| 货物名称 | 单位 |
|----------|------|
| 小鸡（贡） | 只 |
| 肉（贡） | 块 |
| 鱼（贡） | 条 |
| 粉条（贡） | 个 |
| 豆腐（贡） | 块 |

---

## 构建与部署

### 环境要求
- Flutter SDK 3.6.1+
- Dart SDK 3.6.1+
- Android SDK (API 35)
- Java 17

### 构建命令

```bash
# 调试版
flutter run

# 发布版APK
flutter build apk --release

# 发布版APK路径
# build/app/outputs/flutter-apk/app-release.apk
```

### Gradle 配置
- Gradle 版本：8.12.1
- Android Gradle Plugin：8.2.1
- Kotlin 版本：1.8.22
- 仓库镜像：阿里云（优先）→ Google → Maven Central

---

## 依赖包

| 包名 | 版本 | 用途 |
|------|------|------|
| sqflite | ^2.3.3 | SQLite数据库 |
| provider | ^6.1.1 | 状态管理 |
| intl | ^0.19.0 | 日期格式化 |
| pinyin | ^3.3.0 | 中文拼音排序 |
| path_provider | ^2.1.2 | 文件路径 |
| file_picker | ^8.0.6 | 文件选择 |
| flutter_localizations | SDK | 中文本地化 |
| flutter_slidable | ^3.0.0 | 滑动操作 |
| json_annotation | ^4.8.1 | JSON序列化 |
| logger | ^2.0.0 | 日志 |
