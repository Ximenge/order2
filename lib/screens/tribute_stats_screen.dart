import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/tribute_database.dart';
import '../models/tribute_order.dart';

class TributeStatsScreen extends StatefulWidget {
  const TributeStatsScreen({super.key});

  @override
  State<TributeStatsScreen> createState() => _TributeStatsScreenState();
}

class _TributeStatsScreenState extends State<TributeStatsScreen> {
  Map<String, bool> _expandedItems = {};
  Map<String, List<TributeOrder>> _orderDetails = {};
  Map<String, bool> _loadingStatus = {};
  List<Map<String, dynamic>>? _stats;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadStatsData();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      _expandedItems.clear();
      _orderDetails.clear();
      _loadingStatus.clear();
      _loadStatsData();
      await Future.delayed(Duration(milliseconds: 300));
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _loadStatsData() {
    setState(() {
      _stats = null;
    });

    final tributeDb = TributeDatabase.instance;
    tributeDb.getItemStats().then((data) {
      if (mounted) {
        setState(() {
          _stats = data;
        });
      }
    });
  }

  Future<void> _onItemTapped(String itemName, String unit) async {
    final itemKey = '$itemName-$unit';

    setState(() {
      _expandedItems[itemKey] = !(_expandedItems[itemKey] ?? false);
    });

    if (_expandedItems[itemKey] == true &&
        !_orderDetails.containsKey(itemKey)) {
      setState(() {
        _loadingStatus[itemKey] = true;
      });

      try {
        final orders =
            await TributeDatabase.instance.getOrdersByItem(itemName, unit);

        setState(() {
          _orderDetails[itemKey] = orders;
          _loadingStatus[itemKey] = false;
        });
      } catch (e) {
        setState(() {
          _loadingStatus[itemKey] = false;
        });
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
        title: Text('贡品货物统计'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_stats == null) {
      return Center(child: CircularProgressIndicator());
    }

    if (_stats!.isEmpty) {
      return Center(child: Text('暂无贡品统计数据'));
    }

    return ListView.builder(
      itemCount: _stats!.length,
      itemBuilder: (context, index) {
        final item = _stats![index];
        String itemName = item['itemName'] as String;
        String unit = item['unit'] as String? ?? 'N/A';
        final itemKey = '$itemName-$unit';
        bool isExpanded = _expandedItems[itemKey] ?? false;
        bool isLoading = _loadingStatus[itemKey] ?? false;
        List<TributeOrder>? orders = _orderDetails[itemKey];

        return Column(
          children: [
            InkWell(
              onTap: () => _onItemTapped(itemName, unit),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item['total'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
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
            if (isExpanded)
              isLoading
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
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
                              ...orders.map((order) =>
                                  TributeOrderDetailCard(order: order)),
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
  }
}

class TributeOrderDetailCard extends StatelessWidget {
  final TributeOrder order;

  const TributeOrderDetailCard({super.key, required this.order});

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
          ],
        ),
      ),
    );
  }
}
