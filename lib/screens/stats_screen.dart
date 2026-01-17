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
  // TAB相关变量
  late TabController _tabController;
  final List<String> _tabs = ['所有', '店1', '店2', '店3'];
  
  // 刷新状态
  bool _isRefreshing = false;
  final ValueNotifier<bool> _refreshNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }
  
  // 手动刷新方法
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // 触发所有Tab重新加载数据
      _refreshNotifier.value = !_refreshNotifier.value;
      await Future.delayed(Duration(milliseconds: 500)); // 添加轻微延迟，提供更好的用户体验
    } finally {
      setState(() {
        _isRefreshing = false;
      });
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
            source: source,
            tab: tab,
            refreshNotifier: _refreshNotifier,
          );
        }).toList(),
      ),
    );
  }
}

// 统计页面Tab内容组件，保持状态不丢失
class _StatsTabContent extends StatefulWidget {
  final String source;
  final String tab;
  final ValueNotifier<bool> refreshNotifier;

  const _StatsTabContent({
    required this.source,
    required this.tab,
    required this.refreshNotifier,
  });

  @override
  State<_StatsTabContent> createState() => _StatsTabContentState();
}

class _StatsTabContentState extends State<_StatsTabContent> with AutomaticKeepAliveClientMixin {
  // 本地状态管理
  final Map<String, bool> _expandedItems = {};
  final Map<String, List<Order>> _orderDetails = {};
  final Map<String, bool> _loadingStatus = {};

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  // 点击处理函数
  Future<void> _onItemTapped(String itemName, String unit) async {
    final itemKey = '$itemName-$unit';
    
    // 切换展开状态
    setState(() {
      _expandedItems[itemKey] = !(_expandedItems[itemKey] ?? false);
    });
    
    // 如果是展开操作，并且还没有加载过订单详情，则加载订单
    if (_expandedItems[itemKey] == true && !_orderDetails.containsKey(itemKey)) {
      setState(() {
        _loadingStatus[itemKey] = true;
      });
      
      try {
        final orders = await Provider.of<AppDatabase>(context, listen: false)
            .getOrdersByItem(itemName, unit, source: widget.source.isEmpty ? null : widget.source);
        
        // 按来源排序，使同一来源的订单分组显示
        orders.sort((a, b) => a.source.compareTo(b.source));
        
        // 缓存订单详情并更新状态
        setState(() {
          _orderDetails[itemKey] = orders;
          _loadingStatus[itemKey] = false;
        });
      } catch (e) {
        setState(() {
          _loadingStatus[itemKey] = false;
        });
        
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
    super.build(context); // 必须调用super.build(context)
    return ValueListenableBuilder(
      valueListenable: widget.refreshNotifier,
      builder: (context, _, __) {
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
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final item = stats[index];
                String itemName = item['itemName'] as String;
                String unit = item['unit'] as String? ?? 'N/A'; // 获取单位
                final itemKey = '$itemName-$unit';
                
                bool isExpanded = _expandedItems[itemKey] ?? false;
                bool isLoading = _loadingStatus[itemKey] ?? false;
                List<Order>? orders = _orderDetails[itemKey];

                return Column(
                  children: [
                    // 货物统计行 - 参考首页样式设计
                    InkWell(
                      onTap: () => _onItemTapped(itemName, unit),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
              backgroundColor: Color.fromARGB(51, 33, 149, 243), // 20% opacity blue
              labelStyle: TextStyle(color: Colors.blue[800], fontSize: 12),
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ],
        ),
      ),
    );
  }
}
