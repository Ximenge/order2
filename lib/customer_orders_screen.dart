import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../models/order.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  _CustomerOrdersScreenState createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> with SingleTickerProviderStateMixin {
  String? selectedCustomerName;
  ValueNotifier<bool>? _refreshNotifier;
  List<Order> _orders = [];
  
  // TAB相关变量
  late TabController _tabController;
  final List<String> _tabs = ['所有', '店1', '店2', '店3'];
  String _selectedSource = ''; // ''表示所有来源
  
  // 为每个TAB创建独立的ScrollController
  Map<String, ScrollController> _scrollControllers = {};

  @override
  void initState() {
    super.initState();
    _refreshNotifier = ValueNotifier(false);
    // 初始化TAB控制器
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // 初始化每个TAB的ScrollController
    for (String tab in _tabs) {
      _scrollControllers[tab] = ScrollController();
    }
    
    _loadOrders();
  }

  @override
  void dispose() {
    _refreshNotifier?.dispose();
    _tabController.dispose();
    // 清理所有的ScrollController
    for (ScrollController controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // TAB选择处理函数
  void _handleTabSelection() {
    setState(() {
      // 保存当前选中的来源
      if (_tabController.index == 0) {
        _selectedSource = ''; // 所有来源
      } else {
        _selectedSource = _tabs[_tabController.index];
      }
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    try {
      List<Order> newOrders;
      if (selectedCustomerName == null) {
        // 没有选中客户，获取所有或按来源过滤的订单
        if (_selectedSource.isEmpty) {
          newOrders = await Provider.of<AppDatabase>(context, listen: false).getActiveOrders();
        } else {
          newOrders = await Provider.of<AppDatabase>(context, listen: false).getOrdersBySource(_selectedSource);
        }
      } else {
        // 选中了客户，获取该客户的订单
        if (_selectedSource.isEmpty) {
          newOrders = await Provider.of<AppDatabase>(context, listen: false).getOrdersByCustomer(selectedCustomerName!);
        } else {
          newOrders = await Provider.of<AppDatabase>(context, listen: false)
              .getOrdersByCustomerAndSource(selectedCustomerName!, _selectedSource);
        }
      }
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
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 添加刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 点击刷新按钮时重新加载订单数据
              _loadOrders();
            },
            tooltip: '刷新订单数据',
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧客户列表
          Expanded(
            flex: 1,
            // 使用IndexedStack保持所有CustomerList实例的状态
            child: IndexedStack(
              index: _tabController.index,
              children: _tabs.map((tab) {
                // 为每个Tab创建独立的CustomerList实例
                String source = tab == '所有' ? '' : tab;
                return CustomerList(
                  selectedCustomerName: selectedCustomerName,
                  onCustomerSelected: (name) {
                    setState(() {
                      selectedCustomerName = name;
                    });
                    _loadOrders();
                  },
                  source: source, // 传入当前Tab对应的来源
                  // 传递当前Tab对应的ScrollController
                  scrollController: _scrollControllers[tab]!, 
                );
              }).toList(),
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
  final String? source; // 来源参数
  final ScrollController scrollController; // 外部ScrollController

  const CustomerList({
    super.key,
    required this.selectedCustomerName,
    required this.onCustomerSelected,
    required this.source,
    required this.scrollController,
  });

  @override
  State<CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<CustomerList> {
  // 为每个来源缓存独立的客户列表
  Map<String?, List<String>> _cachedCustomerNamesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerNames();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果来源参数变化，检查是否已有缓存
    if (oldWidget.source != widget.source) {
      // 如果已有缓存，直接使用，不重新加载
      if (_cachedCustomerNamesMap.containsKey(widget.source)) {
        setState(() {
          _isLoading = false;
        });
      } else {
        // 没有缓存，重新加载
        _isLoading = true;
        _loadCustomerNames();
      }
    }
  }

  Future<void> _loadCustomerNames() async {
    try {
      final names = await Provider.of<AppDatabase>(context, listen: false).getCustomerNamesBySource(widget.source);
      setState(() {
        // 将客户列表缓存到对应的来源
        _cachedCustomerNamesMap[widget.source] = names;
        _isLoading = false;
      });
    } catch (e) {
      print('加载客户名称出错: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 获取当前来源的客户列表
  List<String> get _currentCustomerNames {
    return _cachedCustomerNamesMap[widget.source] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentCustomerNames.isEmpty) {
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
          ..._currentCustomerNames.map((name) => OutlinedButton(
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认删除'),
          content: Text('是否删除该订单？'),
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
}