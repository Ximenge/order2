import 'package:flutter/material.dart';
import '../db/tribute_database.dart';
import '../models/tribute_order.dart';

class TributeHistoryOrdersScreen extends StatefulWidget {
  const TributeHistoryOrdersScreen({super.key});

  @override
  State<TributeHistoryOrdersScreen> createState() =>
      _TributeHistoryOrdersScreenState();
}

class _TributeHistoryOrdersScreenState
    extends State<TributeHistoryOrdersScreen> {
  Future<List<TributeOrder>>? ordersFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      ordersFuture = TributeDatabase.instance.getDeletedOrders();
    });
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认操作'),
          content: Text('是否清除所有贡品历史订单记录？'),
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
      try {
        await TributeDatabase.instance.clearAllHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('所有贡品历史订单已清除')),
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
        title: Text('贡品历史订单'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: _clearAllHistory,
            tooltip: '清除所有贡品历史订单',
          ),
        ],
      ),
      body: FutureBuilder<List<TributeOrder>>(
        future: ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('暂无贡品历史订单'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return TributeHistoryOrderCard(
                  order: order, refreshParent: _refreshData);
            },
          );
        },
      ),
    );
  }
}

class TributeHistoryOrderCard extends StatelessWidget {
  final TributeOrder order;
  final VoidCallback refreshParent;

  const TributeHistoryOrderCard(
      {super.key, required this.order, required this.refreshParent});

  Future<void> _deleteOrder(
      BuildContext context, TributeOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认删除'),
          content: Text('是否永久删除该贡品历史订单？'),
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
      try {
        await TributeDatabase.instance.physicalDeleteOrder(order);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('贡品历史订单已删除')),
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

  Future<void> _restoreOrder(
      BuildContext context, TributeOrder order) async {
    if (context.mounted) {
      try {
        await TributeDatabase.instance.restoreOrder(order);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('贡品订单已恢复')),
          );
          refreshParent();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('恢复贡品订单失败: ${e.toString()}')),
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
            Text(
              '客户: ${order.customerName}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
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
            Text(
              '数量: ${order.quantity} ${order.unit}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              '删除时间: ${order.deletedAt != null ? order.deletedAt.toString() : '未知'}',
              style: TextStyle(color: Colors.grey[600]),
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
}
