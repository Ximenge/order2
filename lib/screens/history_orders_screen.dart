import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../models/order.dart';

class HistoryOrdersScreen extends StatefulWidget {
  const HistoryOrdersScreen({super.key});

  @override
  State<HistoryOrdersScreen> createState() => _HistoryOrdersScreenState();
}

class _HistoryOrdersScreenState extends State<HistoryOrdersScreen> {
  Future<List<Order>>? ordersFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      ordersFuture = Provider.of<AppDatabase>(context, listen: false).getDeletedOrders();
    });
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认操作'),
          content: Text('是否清除所有历史订单记录？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final appDatabase = Provider.of<AppDatabase>(context, listen: false);
      try {
        await appDatabase.clearAllHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('所有历史订单已清除')),
          );
          _refreshData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除历史订单失败: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('历史订单'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: _clearAllHistory,
            tooltip: '清除所有历史订单',
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('暂无历史订单'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return HistoryOrderCard(order: order, refreshParent: _refreshData);
            },
          );
        },
      ),
    );
  }
}

class HistoryOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback refreshParent;

  const HistoryOrderCard({super.key, required this.order, required this.refreshParent});

  Future<void> _deleteOrder(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认删除'),
          content: Text('是否删除该历史订单？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final appDatabase = Provider.of<AppDatabase>(context, listen: false);
      try {
        await appDatabase.physicalDeleteOrder(order);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('历史订单已删除')),
          );
          refreshParent();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除历史订单失败: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 突出显示客户姓名
            Text(
              '客户: ${order.customerName}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            // 突出显示货物名称
            Text(
              '货物名称: ${order.itemName}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下单日期: ${order.orderDate}'),
            // 突出显示数量和单位
            Text(
              '数量: ${order.quantity} ${order.unit}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _restoreOrder(context, order),
              child: Text('恢复订单'),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteOrder(context, order),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreOrder(BuildContext context, Order order) async {
    if (context.mounted) {
      final appDatabase = Provider.of<AppDatabase>(context, listen: false);
      try {
        await appDatabase.restoreOrder(order);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('订单已恢复')),
          );
          refreshParent(); // 刷新父页面
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('恢复订单失败: ${e.toString()}')),
          );
        }
      }
    }
  }
}