import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../models/order.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  // 为每个Tab创建独立的状态管理
  Map<String, ValueNotifier<Map<String, bool>>> _expandedItemsNotifiers = {};
  Map<String, ValueNotifier<Map<String, List<Order>>>> _orderDetailsNotifiers = {};
  Map<String, ValueNotifier<Map<String, bool>>> _loadingStatusNotifiers = {};
  
  // 当前正在加载的货物信息
  String? _currentLoadingItemName;
  String? _currentLoadingUnit;
  
  // TAB相关变量
  late TabController _tabController;
  final List<String> _tabs = ['所有', '店1', '店2', '店3'];
  String _selectedSource = ''; // ''表示所有来源
  
  // 刷新状态
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 初始化TAB控制器
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // 为每个Tab初始化独立的状态管理ValueNotifier
    for (String tab in _tabs) {
      _expandedItemsNotifiers[tab] = ValueNotifier({});
      _orderDetailsNotifiers[tab] = ValueNotifier({});
      _loadingStatusNotifiers[tab] = ValueNotifier({});
      // 初始化每个Tab的GlobalKey
      _tabKeys[tab] = GlobalKey<_StatsTabContentState>();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // 释放所有Tab的ValueNotifier资源
    _expandedItemsNotifiers.forEach((key, value) => value.dispose());
    _orderDetailsNotifiers.forEach((key, value) => value.dispose());
    _loadingStatusNotifiers.forEach((key, value) => value.dispose());
    super.dispose();
  }
  
  // 为Tab内容组件添加全局键，用于调用刷新方法
  final Map<String, GlobalKey<_StatsTabContentState>> _tabKeys = {};
  
  // 手动刷新方法
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // 获取当前选中的Tab
      String currentTab = _tabs[_tabController.index];
      
      // 重置当前Tab的状态
      _expandedItemsNotifiers[currentTab]?.value = {};
      _orderDetailsNotifiers[currentTab]?.value = {};
      _loadingStatusNotifiers[currentTab]?.value = {};
      
      // 调用当前Tab的刷新方法
      if (_tabKeys.containsKey(currentTab)) {
        _tabKeys[currentTab]?.currentState?._loadStatsData();
      }
      
      await Future.delayed(Duration(milliseconds: 500)); // 添加轻微延迟，提供更好的用户体验
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
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
      
      // 不再重置所有状态，每个Tab现在有独立的状态管理
    });
  }

  // 点击处理函数
  Future<void> _onItemTapped(String itemName, String unit, String source, String tab) async {
    final itemKey = '$itemName-$unit';
    
    // 从当前Tab的ValueNotifier获取状态
    final expandedItemsNotifier = _expandedItemsNotifiers[tab];
    final orderDetailsNotifier = _orderDetailsNotifiers[tab];
    final loadingStatusNotifier = _loadingStatusNotifiers[tab];
    
    if (expandedItemsNotifier == null || orderDetailsNotifier == null || loadingStatusNotifier == null) {
      return; // 安全检查
    }
    
    // 获取当前状态
    final expandedItems = Map<String, bool>.from(expandedItemsNotifier.value);
    final orderDetails = Map<String, List<Order>>.from(orderDetailsNotifier.value);
    final loadingStatus = Map<String, bool>.from(loadingStatusNotifier.value);
    
    // 切换展开状态
    expandedItems[itemKey] = !(expandedItems[itemKey] ?? false);
    expandedItemsNotifier.value = expandedItems;
    
    // 如果是展开操作，并且还没有加载过订单详情，则加载订单
    if (expandedItems[itemKey] == true && !orderDetails.containsKey(itemKey)) {
      // 更新加载状态
      loadingStatus[itemKey] = true;
      loadingStatusNotifier.value = loadingStatus;
      
      try {
        final orders = await Provider.of<AppDatabase>(context, listen: false)
            .getOrdersByItem(itemName, unit, source: source.isEmpty ? null : source);
        
        // 按来源排序，使同一来源的订单分组显示
        orders.sort((a, b) => a.source.compareTo(b.source));
        
        // 缓存订单详情并更新状态
        orderDetails[itemKey] = orders;
        loadingStatus[itemKey] = false;
        
        // 使用ValueNotifier更新状态，实现局部刷新
        orderDetailsNotifier.value = orderDetails;
        loadingStatusNotifier.value = loadingStatus;
      } catch (e) {
        // 更新加载状态
        loadingStatus[itemKey] = false;
        loadingStatusNotifier.value = loadingStatus;
        
        // 显示错误信息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载订单失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('货物统计'),
        actions: [
          // 手动刷新按钮
          IconButton(
            icon: _isRefreshing
                ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '刷新数据',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          String source = tab == '所有' ? '' : tab;
          return _StatsTabContent(
            key: _tabKeys[tab], // 使用GlobalKey保持组件状态
            parentState: this,
            source: source,
            tab: tab,
          );
        }).toList(),
      ),
    );
  }


}

// 订单详情卡片组件
class OrderDetailCard extends StatelessWidget {
  final Order order;

  const OrderDetailCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.customerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd').format(order.orderDate),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '数量: ${order.quantity} ${order.unit}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Chip(
              label: Text('来源: ${order.source}'),
              backgroundColor: Colors.blue.withOpacity(0.2),
              labelStyle: TextStyle(color: Colors.blue[800], fontSize: 12),
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ],
        ),
      ),
    );
  }
}

// 统计页面Tab内容组件，保持状态不丢失
class _StatsTabContent extends StatefulWidget {
  final _StatsScreenState parentState;
  final String source;
  final String tab;

  const _StatsTabContent({
    super.key, // 处理key参数
    required this.parentState,
    required this.source,
    required this.tab,
  });

  @override
  State<_StatsTabContent> createState() => _StatsTabContentState();
}

class _StatsTabContentState extends State<_StatsTabContent> with AutomaticKeepAliveClientMixin {
  // 本地滚动控制器，确保每个Tab有自己独立的滚动位置
  final ScrollController _scrollController = ScrollController();
  
  // 存储Future，避免每次build都重新创建
  Future<List<Map<String, dynamic>>>? _statsFuture;
  
  // 存储统计数据
  List<Map<String, dynamic>>? _stats;

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();
    // 在initState之后获取数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatsData();
    });
  }
  
  // 加载统计数据
  void _loadStatsData() {
    setState(() {
      _stats = null; // 重置状态，显示加载指示器
    });
    
    // 获取数据库实例并加载数据
    final appDatabase = Provider.of<AppDatabase>(context, listen: false);
    _statsFuture = appDatabase.getItemStats(source: widget.source.isEmpty ? null : widget.source);
    
    // 存储数据到本地变量
    _statsFuture!.then((data) {
      if (mounted) {
        setState(() {
          _stats = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super.build(context)
    
    // 如果数据还在加载中
    if (_stats == null) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('加载数据失败'));
          }
          
          // 这里不需要设置_stats，因为在initState中已经处理了
          return Center(child: CircularProgressIndicator());
        },
      );
    }

    if (_stats!.isEmpty) {
      return Center(child: Text('暂无统计数据'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _stats!.length,
      itemBuilder: (context, index) {
        final item = _stats![index];
        String itemName = item['itemName'] as String;
        String unit = item['unit'] as String? ?? 'N/A'; // 获取单位
        final itemKey = '$itemName-$unit';
            
            // 使用ValueListenableBuilder监听状态变化，实现局部刷新
            return ValueListenableBuilder(
              valueListenable: widget.parentState._expandedItemsNotifiers[widget.tab]!,
              builder: (context, expandedItems, child) {
                return ValueListenableBuilder(
                  valueListenable: widget.parentState._loadingStatusNotifiers[widget.tab]!,
                  builder: (context, loadingStatus, child) {
                    return ValueListenableBuilder(
                      valueListenable: widget.parentState._orderDetailsNotifiers[widget.tab]!,
                      builder: (context, orderDetails, child) {
                        bool isExpanded = expandedItems[itemKey] ?? false;
                        bool isLoading = loadingStatus[itemKey] ?? false;
                        List<Order>? orders = orderDetails[itemKey];

                        return Column(
                          children: [
                            // 货物统计行 - 参考首页样式设计
                            InkWell(
                              onTap: () => widget.parentState._onItemTapped(itemName, unit, widget.source, widget.tab),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 左侧：货物名称（单位）
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            itemName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '单位：$unit',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 右侧：数量和展开图标
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // 数量
                                          Text(
                                            '${item['total'].toStringAsFixed(2)}', // 格式化为两位小数
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                          // 展开/折叠图标
                                          Icon(
                                            isExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                  
                // 订单详情列表（如果当前货物被展开）
                if (isExpanded)
                  isLoading
                      ? Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ))
                      : orders != null && orders.isNotEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '订购记录 (${orders.length}条)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ...orders.map((order) => OrderDetailCard(order: order)),
                                  SizedBox(height: 16),
                                ],
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('暂无订购记录'),
                            ),
              ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
  }
}