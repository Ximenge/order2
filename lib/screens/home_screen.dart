import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database.dart';
import '../models/order.dart';
import './stats_screen.dart';
import '../customer_orders_screen.dart';
import '../screens/history_orders_screen.dart';
import '../utils/test_data_generator.dart'; // 导入测试数据生成器

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final List<TextEditingController> _itemControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _unitControllers = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedSource = '店1'; // 新增来源选择状态，默认店1
  final ScrollController _scrollController = ScrollController();
  
  // 来源列表
  final List<String> _sources = ['店1', '店2', '店3'];
  
  // 测试按钮显示状态
  bool _isTestButtonVisible = false;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addItemRow() {
    setState(() {
      _itemControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController());
      _unitControllers.add(TextEditingController());
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      _itemControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _unitControllers.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final customerName = _customerController.text;
      
      // 检查是否所有项目的货物名称和单位都是特定值
      bool allItemsMatchCSZ = true;
      bool allItemsMatchZSC = true;
      
      for (int i = 0; i < _itemControllers.length; i++) {
        final itemName = _itemControllers[i].text;
        final unit = _unitControllers[i].text;
        
        // 检查是否所有项目都匹配"csz"模式
        if (itemName != 'csz' || unit != 'csz') {
          allItemsMatchCSZ = false;
        }
        
        // 检查是否所有项目都匹配"zsc"模式
        if (itemName != 'zsc' || unit != 'zsc') {
          allItemsMatchZSC = false;
        }
      }
      
      // 根据特定输入组合控制测试按钮的显示/隐藏
      if (!_isTestButtonVisible && customerName == 'csz' && allItemsMatchCSZ) {
        // 显示测试按钮
        setState(() {
          _isTestButtonVisible = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('测试功能已启用')),
          );
        }
      } else if (_isTestButtonVisible && customerName == 'zsc' && allItemsMatchZSC) {
        // 隐藏测试按钮
        setState(() {
          _isTestButtonVisible = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('测试功能已禁用')),
          );
        }
      } else {
        // 正常保存订单
        List<Order> orders = [];
        for (int i = 0; i < _itemControllers.length; i++) {
          final itemName = _itemControllers[i].text;
          final quantityText = _quantityControllers[i].text;
          final unit = _unitControllers[i].text;
          final quantity = (quantityText.isNotEmpty && double.tryParse(quantityText) != null)
              ? double.parse(quantityText)
              : 0.0;

          if (itemName.isNotEmpty && quantity > 0) {
            final newOrder = Order(
              customerName: customerName,
              orderDate: _selectedDate,
              itemName: itemName,
              quantity: quantity,
              unit: unit,
              source: _selectedSource, // 新增来源信息
            );
            orders.add(newOrder);
          }
        }

        try {
          final appDatabase = Provider.of<AppDatabase>(context, listen: false);
          for (final order in orders) {
            await appDatabase.createOrder(order);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('订单已保存')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('保存订单失败')),
            );
          }
        }
      }

      // 无论哪种情况，都清空表单
      _customerController.clear();
      _itemControllers.clear();
      _quantityControllers.clear();
      _unitControllers.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _addItemRow(); // 清空后添加一行空数据
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始化时添加一行空数据
    _addItemRow();
  }

  // 生成测试数据的方法
  Future<void> _generateTestData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成测试数据'),
        content: const Text('确定要生成120个客户的测试数据吗？这将向数据库中添加大量记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final appDatabase = Provider.of<AppDatabase>(context, listen: false);
      final generator = TestDataGenerator();
      
      try {
        // 显示加载指示器
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('正在生成数据'),
            content: SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
        
        // 生成400个订单，满足新的测试数据要求
        await generator.generateTestData(
          database: appDatabase,
        );
        
        // 关闭加载指示器并显示成功消息
        if (mounted) {
          Navigator.pop(context); // 关闭加载指示器
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('测试数据生成成功！')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // 关闭加载指示器
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成测试数据失败: ${e.toString()}')),
          );
        }
      }}
  }

  // 导出数据方法
  Future<void> _exportData() async {
    // 显示导出确认对话框
    final bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出数据'),
        content: const Text('确定要导出所有数据吗？导出的文件将保存到设备的下载目录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) as bool;

    if (confirmed && mounted) {
      try {
        // 显示加载指示器
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('正在导出数据'),
            content: SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );

        final appDatabase = Provider.of<AppDatabase>(context, listen: false);
        
        // 获取所有订单数据
        final orders = await appDatabase.getAllOrders();
        
        // 准备导出数据结构
        final exportData = {
          'exportInfo': {
            'timestamp': DateTime.now().toIso8601String(),
            'appVersion': '1.0.3',
            'dataFormatVersion': '1.0',
            'orderCount': orders.length
          },
          'orders': orders.map((order) => order.toMap()).toList()
        };
        
        // 转换为JSON字符串
        final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
        
        // 获取Download目录
        final downloadsDirectory = Directory('/storage/emulated/0/Download');
        final filePath = '${downloadsDirectory.path}/order_export_${DateTime.now().millisecondsSinceEpoch}.json';
        
        // 写入文件
        final file = File(filePath);
        await file.writeAsString(jsonString);
        
        // 关闭加载指示器并显示成功消息
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('数据导出成功！文件保存路径：$filePath')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('数据导出失败: ${e.toString()}')),
          );
        }
      }
    }
  }

  // 导入数据方法
  Future<void> _importData() async {
    // 显示导入警告对话框
    final bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入数据'),
        content: const Text('确定要导入数据吗？这将覆盖当前所有数据！请确保您已备份当前数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) as bool;

    if (confirmed && mounted) {
      try {
        // 选择文件
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        
        if (result == null || result.files.isEmpty) {
          return;
        }
        
        // 显示加载指示器
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('正在导入数据'),
            content: SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
        
        // 读取文件内容
        final filePath = result.files.single.path;
        final jsonString = await File(filePath!).readAsString();
        
        // 解析JSON
        final importData = json.decode(jsonString);
        
        // 验证数据格式
        if (!importData.containsKey('exportInfo') || !importData.containsKey('orders')) {
          throw Exception('无效的数据格式');
        }
        
        final appDatabase = Provider.of<AppDatabase>(context, listen: false);
        final db = await appDatabase.database;
        
        // 开始事务
        await db.transaction((txn) async {
          // 清空现有数据
          await txn.delete('orders');
          
          // 插入导入的订单数据
          final orders = importData['orders'] as List<dynamic>;
          for (final orderData in orders) {
            // 确保id字段不被导入（使用自动生成）
            final orderMap = Map<String, dynamic>.from(orderData);
            orderMap.remove('id');
            
            // 添加创建时间（如果不存在）
            if (!orderMap.containsKey('createdAt')) {
              orderMap['createdAt'] = DateTime.now().toIso8601String();
            }
            
            await txn.insert('orders', orderMap);
          }
        });
        
        // 关闭加载指示器并显示成功消息
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据导入成功！')),
          );
        }
        
        // 显示导入文件信息
        final exportInfo = importData['exportInfo'];
        if (mounted && exportInfo != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('导入信息'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导出时间: ${DateTime.parse(exportInfo['timestamp']).toString()}'),
                  Text('应用版本: ${exportInfo['appVersion']}'),
                  Text('数据格式版本: ${exportInfo['dataFormatVersion']}'),
                  Text('导入订单数: ${exportInfo['orderCount']}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('数据导入失败: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customerController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    for (var controller in _unitControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('订货记录'),
        actions: [
          IconButton(
            icon: Icon(Icons.assessment),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StatsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CustomerOrdersScreen()),
            ),
          ),
          // 测试数据生成按钮 - 根据_isTestButtonVisible条件显示
          if (_isTestButtonVisible)
            IconButton(
              icon: Icon(Icons.developer_mode),
              tooltip: '生成测试数据',
              onPressed: _generateTestData,
            ),

          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HistoryOrdersScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _customerController,
                decoration: InputDecoration(
                  labelText: '客户姓名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入客户姓名';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '下单日期',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      ),
                      Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // 新增来源选择下拉菜单
              DropdownButtonFormField<String>(
                value: _selectedSource,
                decoration: InputDecoration(
                  labelText: '来源',
                  border: OutlineInputBorder(),
                ),
                items: _sources.map((String source) {
                  return DropdownMenuItem<String>(
                    value: source,
                    child: Text(source),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSource = newValue!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择来源';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              ...List.generate(_itemControllers.length, (index) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextFormField(
                              controller: _itemControllers[index],
                              decoration: InputDecoration(
                                labelText: '货物名称',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入货物名称';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextFormField(
                              controller: _quantityControllers[index],
                              decoration: InputDecoration(
                                labelText: '数量',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入数量';
                                }
                                if (double.tryParse(value) == null) {
                                  return '请输入有效数字';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextFormField(
                              controller: _unitControllers[index],
                              decoration: InputDecoration(
                                labelText: '单位',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入单位';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _removeItemRow(index),
                        ),
                      ],
                    ),
                  ],
                );
              }),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addItemRow,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Text('添加货物'),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Text('保存订单'),
                ),
              ),
              SizedBox(height: 24),
              // 数据管理按钮组
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 导出数据按钮
                  ElevatedButton.icon(
                    onPressed: _exportData,
                    icon: Icon(Icons.download),
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('导出数据'),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 12),
                  // 导入数据按钮
                  ElevatedButton.icon(
                    onPressed: _importData,
                    icon: Icon(Icons.upload),
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('导入数据'),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}