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
  // 使用ValueNotifier来管理状态，实现局部刷新
  ValueNotifier<Map<String, bool>> _expandedItemsNotifier = ValueNotifier({});
  ValueNotifier<Map<String, List<Order>>> _orderDetailsNotifier = ValueNotifier({});
  ValueNotifier<Map<String, bool>> _loadingStatusNotifier = ValueNotifier({});
  
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expandedItemsNotifier.dispose();
    _orderDetailsNotifier.dispose();
    _loadingStatusNotifier.dispose();
    super.dispose();
  }
  
  // 手动刷新方法
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // 重置所有状态
      _expandedItemsNotifier.value = {};
      _orderDetailsNotifier.value = {};
      _loadingStatusNotifier.value = {};
      
      // 触发FutureBuilder重新加载数据
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
      
      // 重置选择状态，但保持滚动位置
      _expandedItemsNotifier.value = {};
      _orderDetailsNotifier.value = {};
      _loadingStatusNotifier.value = {};
    });
  }

  // 点击处理函数
  Future<void> _onItemTapped(String itemName, String unit, String source) async {
    final itemKey = '$itemName-$unit';
    
    // 从ValueNotifier获取当前状态
    final expandedItems = Map<String, bool>.from(_expandedItemsNotifier.value);
    final orderDetails = Map<String, List<Order>>.from(_orderDetailsNotifier.value);
    final loadingStatus = Map<String, bool>.from(_loadingStatusNotifier.value);
    
    // 切换展开状态
    expandedItems[itemKey] = !(expandedItems[itemKey] ?? false);
    _expandedItemsNotifier.value = expandedItems;
    
    // 如果是展开操作，并且还没有加载过订单详情，则加载订单
    if (expandedItems[itemKey] == true && !orderDetails.containsKey(itemKey)) {
      // 更新加载状态
      loadingStatus[itemKey] = true;
      _loadingStatusNotifier.value = loadingStatus;
      
      try {
        final orders = await Provider.of<AppDatabase>(context, listen: false)
            .getOrdersByItem(itemName, unit, source: source.isEmpty ? null : source);
        
        // 按来源排序，使同一来源的订单分组显示
        orders.sort((a, b) => a.source.compareTo(b.source));
        
        // 缓存订单详情并更新状态
        orderDetails[itemKey] = orders;
        loadingStatus[itemKey] = false;
        
        // 使用ValueNotifier更新状态，实现局部刷新
        _orderDetailsNotifier.value = orderDetails;
        _loadingStatusNotifier.value = loadingStatus;
      } catch (e) {
        // 更新加载状态
        loadingStatus[itemKey] = false;
        _loadingStatusNotifier.value = loadingStatus;
        
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

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super.build(context)
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<AppDatabase>(context).getItemStats(source: widget.source.isEmpty ? null : widget.source),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('暂无统计数据'));
        }

        final stats = snapshot.data!;

        return ListView.builder(
          controller: _scrollController,
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            String itemName = item['itemName'] as String;
            String unit = item['unit'] as String? ?? 'N/A'; // 获取单位
            final itemKey = '$itemName-$unit';
            
            // 使用ValueListenableBuilder监听状态变化，实现局部刷新
            return ValueListenableBuilder(
              valueListenable: widget.parentState._expandedItemsNotifier,
              builder: (context, expandedItems, child) {
                return ValueListenableBuilder(
                  valueListenable: widget.parentState._loadingStatusNotifier,
                  builder: (context, loadingStatus, child) {
                    return ValueListenableBuilder(
                      valueListenable: widget.parentState._orderDetailsNotifier,
                      builder: (context, orderDetails, child) {
                        bool isExpanded = expandedItems[itemKey] ?? false;
                        bool isLoading = loadingStatus[itemKey] ?? false;
                        List<Order>? orders = orderDetails[itemKey];

                        return Column(
                          children: [
                            // 货物统计行 - 参考首页样式设计
                            InkWell(
                              onTap: () => widget.parentState._onItemTapped(itemName, unit, widget.source),
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
      },
    );
  }
}