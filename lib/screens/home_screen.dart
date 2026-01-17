import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  final ScrollController _scrollController = ScrollController();

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
            customerName: _customerController.text,
            orderDate: _selectedDate,
            itemName: itemName,
            quantity: quantity,
            unit: unit,
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
        
        // 生成120个客户，每个客户最多10个订单
        await generator.generateTestData(
          customerCount: 120,
          maxOrdersPerCustomer: 10,
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
          // 测试数据生成按钮 - 仅用于开发测试
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
            ],
          ),
        ),
      ),
    );
  }
}