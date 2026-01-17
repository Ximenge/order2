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
  // 状态变量
  String? _selectedItemName;
  String? _selectedUnit;
  List<Order>? _selectedItemOrders;
  bool _isLoadingOrders = false;
  
  // TAB相关变量
  late TabController _tabController;
  final List<String> _tabs = ['所有', '店1', '店2', '店3'];
  String _selectedSource = ''; // ''表示所有来源

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
    super.dispose();
  }

  // TAB选择处理函数
  void _handleTabSelection() {
    setState(() {
      // 重置选择状态
      _selectedItemName = null;
      _selectedUnit = null;
      _selectedItemOrders = null;
      
      // 设置当前选中的来源
      if (_tabController.index == 0) {
        _selectedSource = ''; // 所有来源
      } else {
        _selectedSource = _tabs[_tabController.index];
      }
    });
  }

  // 点击处理函数
  Future<void> _onItemTapped(String itemName, String unit, String source) async {
    // 如果点击的是同一个项目，则切换展开/折叠状态
    if (_selectedItemName == itemName && _selectedUnit == unit) {
      setState(() {
        _selectedItemName = null;
        _selectedUnit = null;
        _selectedItemOrders = null;
      });
      return;
    }

    // 加载选中货物的订单
    setState(() {
      _selectedItemName = itemName;
      _selectedUnit = unit;
      _isLoadingOrders = true;
      _selectedItemOrders = null;
    });

    try {
      final orders = await Provider.of<AppDatabase>(context, listen: false)
          .getOrdersByItem(itemName, unit, source: source.isEmpty ? null : source);
      
      // 按来源排序，使同一来源的订单分组显示
      orders.sort((a, b) => a.source.compareTo(b.source));
      
      setState(() {
        _selectedItemOrders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingOrders = false;
      });
      // 显示错误信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载订单失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('货物统计'),
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
          return _buildStatsBody(context, source);
        }).toList(),
      ),
    );
  }

  // 构建统计页面内容
  Widget _buildStatsBody(BuildContext context, String source) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<AppDatabase>(context).getItemStats(source: source.isEmpty ? null : source),
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
            bool isSelected = _selectedItemName == itemName && _selectedUnit == unit;

            return Column(
              children: [
                // 货物统计行
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 左侧：货物名称（单位）
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$itemName ($unit)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      // 右侧：数量
                      Expanded(
                        flex: 1,
                        child: Container(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${item['total'].toStringAsFixed(2)}', // 格式化为两位小数
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '数量单位：$unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: () => _onItemTapped(itemName, unit, source),
                  trailing: Icon(
                    isSelected ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue,
                  ),
                ),
                Divider(),
                  
                // 订单详情列表（如果当前货物被选中）
                if (isSelected)
                  _isLoadingOrders
                      ? Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ))
                      : _selectedItemOrders != null && _selectedItemOrders!.isNotEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '订购记录 (${_selectedItemOrders!.length}条)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ..._selectedItemOrders!.map((order) => OrderDetailCard(order: order)),
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