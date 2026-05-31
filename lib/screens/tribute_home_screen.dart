import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/tribute_database.dart';
import '../models/tribute_order.dart';
import 'tribute_customer_orders_screen.dart';
import 'tribute_stats_screen.dart';
import 'tribute_history_orders_screen.dart';

class TributeHomeScreen extends StatefulWidget {
  const TributeHomeScreen({super.key});

  @override
  State<TributeHomeScreen> createState() => _TributeHomeScreenState();
}

class _TributeHomeScreenState extends State<TributeHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final Map<String, TextEditingController> _quantityControllers = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    for (var item in TributeOrder.fixedItems) {
      _quantityControllers[item.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customerController.dispose();
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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

  void _fillOneSet() {
    setState(() {
      for (var controller in _quantityControllers.values) {
        controller.text = '1';
      }
    });
  }

  void _decreaseAll() {
    setState(() {
      for (var controller in _quantityControllers.values) {
        final current = double.tryParse(controller.text) ?? 0;
        final newVal = (current - 1).clamp(0, 99999);
        controller.text = newVal == newVal.roundToDouble() ? newVal.toInt().toString() : newVal.toString();
      }
    });
  }

  void _increaseAll() {
    setState(() {
      for (var controller in _quantityControllers.values) {
        final current = double.tryParse(controller.text) ?? 0;
        final newVal = current + 1;
        controller.text = newVal == newVal.roundToDouble() ? newVal.toInt().toString() : newVal.toString();
      }
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final customerName = _customerController.text.trim();
      if (customerName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请输入客户姓名')),
        );
        return;
      }

      List<TributeOrder> orders = [];
      for (var item in TributeOrder.fixedItems) {
        final quantityText = _quantityControllers[item.key]?.text ?? '';
        final quantity =
            (quantityText.isNotEmpty && double.tryParse(quantityText) != null)
                ? double.parse(quantityText)
                : 0.0;

        if (quantity > 0) {
          orders.add(TributeOrder(
            customerName: customerName,
            orderDate: _selectedDate,
            itemName: item.key,
            quantity: quantity,
            unit: item.value,
          ));
        }
      }

      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请至少填写一项数量')),
        );
        return;
      }

      try {
        final tributeDb = TributeDatabase.instance;
        for (final order in orders) {
          await tributeDb.createOrder(order);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('贡品订单已保存')),
          );
        }

        _customerController.clear();
        for (var controller in _quantityControllers.values) {
          controller.clear();
        }
        setState(() {
          _selectedDate = DateTime.now();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存订单失败')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('贡品订货'),
        actions: [
          IconButton(
            icon: Icon(Icons.assessment),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TributeStatsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      TributeCustomerOrdersScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      TributeHistoryOrdersScreen()),
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
                  if (value == null || value.trim().isEmpty) {
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
                        child: Text(DateFormat('yyyy-MM-dd')
                            .format(_selectedDate)),
                      ),
                      Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: IconButton(
                      onPressed: _decreaseAll,
                      icon: Icon(Icons.remove_circle_outline),
                      iconSize: 42,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _fillOneSet,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, 44),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      '贡品一套',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 16),
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: IconButton(
                      onPressed: _increaseAll,
                      icon: Icon(Icons.add_circle_outline),
                      iconSize: 42,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '货物清单',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ...TributeOrder.fixedItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          item.key,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          onPressed: () {
                            final controller = _quantityControllers[item.key]!;
                            final current = double.tryParse(controller.text) ?? 0;
                            final newVal = (current - 1).clamp(0, 99999);
                            controller.text = newVal == newVal.roundToDouble() ? newVal.toInt().toString() : newVal.toString();
                          },
                          icon: Icon(Icons.remove_circle_outline),
                          padding: EdgeInsets.zero,
                          iconSize: 28,
                          color: Colors.red,
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _quantityControllers[item.key],
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: '数量',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return '无效数字';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          onPressed: () {
                            final controller = _quantityControllers[item.key]!;
                            final current = double.tryParse(controller.text) ?? 0;
                            final newVal = current + 1;
                            controller.text = newVal == newVal.roundToDouble() ? newVal.toInt().toString() : newVal.toString();
                          },
                          icon: Icon(Icons.add_circle_outline),
                          padding: EdgeInsets.zero,
                          iconSize: 28,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          item.value,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
