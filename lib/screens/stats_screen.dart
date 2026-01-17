import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('货物统计'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Provider.of<AppDatabase>(context).getItemStats(),
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
              String unit = item['unit'] as String? ?? 'N/A'; // 获取单位

              return Column(
                children: [
                  ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 左侧：货物名称（单位）
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${item['itemName']} ($unit)',
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
                  ),
                  Divider(), // 添加分隔线
                ],
              );
            },
          );
        },
      ),
    );
  }
}