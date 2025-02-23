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

  @override
  void initState() {
    super.initState();
    _refreshNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    _refreshNotifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('客户订货信息'),
      ),
      body: Column(
        children: [
          // 客户姓名筛选按钮
          FutureBuilder<List<String>>(
            future: Provider.of<AppDatabase>(context).getAllCustomerNames(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Text('暂无客户信息');
              }

              final customerNames = snapshot.data!;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedCustomerName = null;
                        });
                      },
                      child: Text('全部'),
                    ),
                    ...customerNames.map((name) => ElevatedButton(
                      onPressed: selectedCustomerName == name ? null : () {
                        setState(() {
                          selectedCustomerName = name;
                        });
                      },
                      child: Text(name),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith(
                          (states) => selectedCustomerName == name ? Colors.blue : Colors.grey,
                        ),
                      ),
                    )),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 16),
          // 订单列表
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _refreshNotifier!,
              builder: (context, _, __) {
                return FutureBuilder<List<Order>>(
                  future: selectedCustomerName == null
                      ? Provider.of<AppDatabase>(context, listen: false).getActiveOrders()
                      : Provider.of<AppDatabase>(context, listen: false).getOrdersByCustomer(selectedCustomerName!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('暂无订货信息'));
                    }

                    final orders = snapshot.data!;
                    return ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return CustomerOrderCard(
                          order: order,
                          refreshParent: () => _refreshNotifier?.value = !_refreshNotifier!.value,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback refreshParent;

  const CustomerOrderCard({super.key, required this.order, required this.refreshParent});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '客户: ${order.customerName}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('下单日期: ${order.orderDate}'),
                      SizedBox(height: 4),
                      Text('货物名称: ${order.itemName}'),
                      SizedBox(height: 4),
                      Text('数量: ${order.quantity} ${order.unit}'), // 支持浮点数
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
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
    await Provider.of<AppDatabase>(context, listen: false).deleteOrder(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('订单已删除')),
    );
    refreshParent(); // 刷新父页面
  }
}