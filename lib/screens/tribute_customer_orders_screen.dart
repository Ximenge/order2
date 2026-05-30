import 'package:flutter/material.dart';
import 'package:pinyin/pinyin.dart';
import '../db/tribute_database.dart';
import '../models/tribute_order.dart';

class TributeCustomerOrdersScreen extends StatefulWidget {
  const TributeCustomerOrdersScreen({super.key});

  @override
  State<TributeCustomerOrdersScreen> createState() =>
      _TributeCustomerOrdersScreenState();
}

class _TributeCustomerOrdersScreenState
    extends State<TributeCustomerOrdersScreen> {
  String? selectedCustomerName;
  ValueNotifier<bool>? _refreshNotifier;
  List<TributeOrder> _orders = [];
  final ScrollController _scrollController = ScrollController();
  bool _refreshFlag = false;

  @override
  void initState() {
    super.initState();
    _refreshNotifier = ValueNotifier(false);
    _loadOrders();
  }

  @override
  void dispose() {
    _refreshNotifier?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      List<TributeOrder> newOrders;
      final tributeDb = TributeDatabase.instance;

      if (selectedCustomerName == null) {
        newOrders = await tributeDb.getActiveOrders();
      } else {
        newOrders =
            await tributeDb.getOrdersByCustomer(selectedCustomerName!);
      }

      newOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      setState(() {
        _orders = newOrders;
      });
    } catch (e) {
      print('加载贡品订单信息出错: $e');
    }
  }

  void _deleteOrderLocally(TributeOrder order) {
    setState(() {
      _orders.removeWhere((o) => o.id == order.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('贡品客户订货信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _TributeCustomerListState._cachedCustomerNames.clear();
                _refreshFlag = !_refreshFlag;
              });
              _loadOrders();
              _refreshNotifier?.value = !_refreshNotifier!.value;
            },
            tooltip: '刷新所有数据',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: TributeCustomerList(
              selectedCustomerName: selectedCustomerName,
              onCustomerSelected: (name) {
                setState(() {
                  selectedCustomerName = name;
                });
                _loadOrders();
              },
              scrollController: _scrollController,
              refreshFlag: _refreshFlag,
            ),
          ),
          Expanded(
            flex: 3,
            child: TributeOrderList(
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

class TributeCustomerList extends StatefulWidget {
  final String? selectedCustomerName;
  final Function(String?) onCustomerSelected;
  final ScrollController scrollController;
  final bool refreshFlag;

  const TributeCustomerList({
    super.key,
    required this.selectedCustomerName,
    required this.onCustomerSelected,
    required this.scrollController,
    required this.refreshFlag,
  });

  @override
  State<TributeCustomerList> createState() => _TributeCustomerListState();
}

class _TributeCustomerListState extends State<TributeCustomerList> {
  static List<String> _cachedCustomerNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerNames();
  }

  @override
  void didUpdateWidget(covariant TributeCustomerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshFlag != widget.refreshFlag) {
      _isLoading = true;
      _loadCustomerNames();
    }
  }

  Future<void> _loadCustomerNames() async {
    try {
      final tributeDb = TributeDatabase.instance;
      final names = await tributeDb.getAllCustomerNames();

      Map<String, DateTime?> customerFirstOrderDates = {};
      for (String name in names) {
        customerFirstOrderDates[name] =
            await tributeDb.getCustomerFirstOrderDate(name);
      }

      names.sort((a, b) {
        if (a.isNotEmpty && b.isNotEmpty && a[0] != b[0]) {
          String pinyinA = PinyinHelper.getShortPinyin(a[0]);
          String pinyinB = PinyinHelper.getShortPinyin(b[0]);
          int compare = pinyinA.compareTo(pinyinB);
          if (compare != 0) return compare;
        }

        int minLength = a.length < b.length ? a.length : b.length;
        for (int i = 0; i < minLength; i++) {
          if (a[i] != b[i]) {
            String pinyinA = PinyinHelper.getShortPinyin(a[i]);
            String pinyinB = PinyinHelper.getShortPinyin(b[i]);
            int compare = pinyinA.compareTo(pinyinB);
            if (compare != 0) return compare;
          }
        }

        if (a.length != b.length) {
          return a.length.compareTo(b.length);
        }

        DateTime? dateA = customerFirstOrderDates[a];
        DateTime? dateB = customerFirstOrderDates[b];
        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA);
        }
        if (dateA != null) return 1;
        if (dateB != null) return -1;

        return a.compareTo(b);
      });

      setState(() {
        _cachedCustomerNames = names;
        _isLoading = false;
      });
    } catch (e) {
      print('加载贡品客户名称出错: $e');
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

    if (_cachedCustomerNames.isEmpty) {
      return const Center(child: Text('暂无客户信息'));
    }

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () {
              widget.onCustomerSelected(null);
            },
            child: const Text('全部'),
          ),
          ..._cachedCustomerNames.map((name) => OutlinedButton(
                onPressed: widget.selectedCustomerName == name
                    ? null
                    : () {
                        widget.onCustomerSelected(name);
                      },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => widget.selectedCustomerName == name
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16)),
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

class TributeOrderList extends StatelessWidget {
  final List<TributeOrder> orders;
  final ValueNotifier<bool> refreshNotifier;
  final Function(TributeOrder) deleteOrderLocally;
  final String? selectedCustomerName;

  const TributeOrderList({
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
                return const Center(child: Text('暂无贡品订货信息'));
              }
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return TributeCustomerOrderCard(
                    order: order,
                    refreshParent: () =>
                        refreshNotifier.value = !refreshNotifier.value,
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

class TributeCustomerOrderCard extends StatelessWidget {
  final TributeOrder order;
  final VoidCallback refreshParent;
  final Function(TributeOrder) deleteOrderLocally;

  const TributeCustomerOrderCard({
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
            Text(
              '客户: ${order.customerName}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('货物名称: ${order.itemName}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('下单日期: ${order.orderDate}'),
                      SizedBox(height: 4),
                      Text('数量: ${order.quantity} ${order.unit}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
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

  Future<void> _deleteOrder(
      BuildContext context, TributeOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认删除'),
          content: Text('是否删除该贡品订单？'),
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

    if (confirmed == true) {
      try {
        await TributeDatabase.instance.deleteOrder(order);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('贡品订单已删除')),
        );
        deleteOrderLocally(order);
      } catch (e) {
        print('删除贡品订单信息出错: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${e.toString()}')),
        );
      }
    }
  }
}
