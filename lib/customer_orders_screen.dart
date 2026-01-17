import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../models/order.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  _CustomerOrdersScreenState createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  String? selectedCustomerName;
  ValueNotifier<bool>? _refreshNotifier;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    _refreshNotifier = ValueNotifier(false);
    _loadOrders();
  }

  @override
  void dispose() {
    _refreshNotifier?.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      List<Order> newOrders = selectedCustomerName == null
         ? await Provider.of<AppDatabase>(context, listen: false).getActiveOrders()
          : await Provider.of<AppDatabase>(context, listen: false).getOrdersByCustomer(selectedCustomerName!);
      setState(() {
        _orders = newOrders;
      });
    } catch (e) {
      // 可以添加详细的错误处理逻辑
      print('加载订单信息出错: $e');
    }
  }

  void _deleteOrderLocally(Order order) {
    setState(() {
      _orders.removeWhere((o) => o.id == order.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('客户订货信息'),
      ),
      body: Row(
        children: [
          // 左侧客户列表
          Expanded(
            flex: 1,
            child: CustomerList(
              selectedCustomerName: selectedCustomerName,
              onCustomerSelected: (name) {
                setState(() {
                  selectedCustomerName = name;
                });
                _loadOrders();
              },
            ),
          ),
          // 右侧订单列表
          Expanded(
            flex: 3,
            child: OrderList(
              orders: _orders,
              refreshNotifier: _refreshNotifier!,
              deleteOrderLocally: _deleteOrderLocally,
              selectedCustomerName: selectedCustomerName,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerList extends StatefulWidget {
  final String? selectedCustomerName;
  final Function(String?) onCustomerSelected;

  const CustomerList({
    super.key,
    required this.selectedCustomerName,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<CustomerList> {
  late ScrollController _scrollController;
  List<String>? _cachedCustomerNames;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadCustomerNames();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerNames() async {
    try {
      final names = await Provider.of<AppDatabase>(context, listen: false).getAllCustomerNames();
      setState(() {
        _cachedCustomerNames = names;
        _isLoading = false;
      });
    } catch (e) {
      print('加载客户名称出错: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cachedCustomerNames == null || _cachedCustomerNames!.isEmpty) {
      return const Center(child: Text('暂无客户信息'));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () {
              widget.onCustomerSelected(null);
            },
            child: const Text('全部'),
          ),
          ..._cachedCustomerNames!.map((name) => OutlinedButton(
            onPressed: widget.selectedCustomerName == name ? null : () {
              widget.onCustomerSelected(name);
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith(
                (states) => widget.selectedCustomerName == name ? Colors.blue : Colors.grey,
              ),
              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 8, horizontal: 16)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textSpan = TextSpan(
                  text: name,
                  style: const TextStyle(color: Colors.white),
                );
                final textPainter = TextPainter(
                  text: textSpan,
                  textDirection: TextDirection.ltr,
                );
                textPainter.layout(maxWidth: constraints.maxWidth);
                if (textPainter.didExceedMaxLines) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }
                return Text(
                  name,
                  style: const TextStyle(color: Colors.white),
                );
              },
            ),
          )),
        ],
      ),
    );
  }
}

class OrderList extends StatelessWidget {
  final List<Order> orders;
  final ValueNotifier<bool> refreshNotifier;
  final Function(Order) deleteOrderLocally;
  final String? selectedCustomerName;

  const OrderList({
    super.key,
    required this.orders,
    required this.refreshNotifier,
    required this.deleteOrderLocally,
    required this.selectedCustomerName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.grey[200],
          child: Text(
            '当前客户: ${selectedCustomerName ?? '全部'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: refreshNotifier,
            builder: (context, _, __) {
              if (orders.isEmpty) {
                return const Center(child: Text('暂无订货信息'));
              }
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return CustomerOrderCard(
                    order: order,
                    refreshParent: () => refreshNotifier.value = !refreshNotifier.value,
                    deleteOrderLocally: deleteOrderLocally,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class CustomerOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback refreshParent;
  final Function(Order) deleteOrderLocally;

  const CustomerOrderCard({
    super.key,
    required this.order,
    required this.refreshParent,
    required this.deleteOrderLocally,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 突出显示客户姓名
            Text(
              '客户: ${order.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 突出显示货物名称
                      Text('货物名称: ${order.itemName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('下单日期: ${order.orderDate}'),
                      SizedBox(height: 4),
                      // 突出显示数量和单位
                      Text('数量: ${order.quantity} ${order.unit}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      // 新增来源信息显示
                      Chip(
                        label: Text('来源: ${order.source}'),
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        labelStyle: TextStyle(color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteOrder(context, order),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOrder(BuildContext context, Order order) async {
    try {
      await Provider.of<AppDatabase>(context, listen: false).deleteOrder(order);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('订单已删除')),
      );
      deleteOrderLocally(order);
      // 移除refreshParent()调用，避免触发整体刷新
    } catch (e) {
      // 可以添加详细的错误处理逻辑
      print('删除订单信息出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: ${e.toString()}')),
      );
    }
  }
}