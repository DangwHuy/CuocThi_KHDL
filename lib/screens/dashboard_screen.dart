import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';
import 'recommendation_screen.dart';
import 'comparison_screen.dart';
import 'data_explorer_screen.dart';
import 'rfm_screen.dart';
import 'seasonality_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _selectedIndex = 0;
  Map<String, dynamic> _edaData = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final eda = await DataService.loadEDA();
    setState(() {
      _edaData = eda;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isMobile = MediaQuery.of(context).size.width < 800;
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          if (!isMobile)
            NavigationRail(
              backgroundColor: Theme.of(context).cardColor,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded),
                  label: Text(settings.isVietnamese ? 'Tổng quan' : 'Overview'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(settings.isVietnamese ? 'AI Gợi ý' : 'AI Recs'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.compare_arrows_outlined),
                  selectedIcon: const Icon(Icons.compare_arrows_rounded),
                  label: Text(settings.isVietnamese ? 'So sánh' : 'Compare'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.table_rows_outlined),
                  selectedIcon: const Icon(Icons.table_rows_rounded),
                  label: Text(settings.isVietnamese ? 'Dữ liệu' : 'Data'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.people_alt_outlined),
                  selectedIcon: const Icon(Icons.people_alt_rounded),
                  label: Text(settings.isVietnamese ? 'RFM' : 'RFM'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights_rounded),
                  label: Text(settings.isVietnamese ? 'Mùa vụ' : 'Season'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: Text(settings.isVietnamese ? 'Cài đặt' : 'Settings'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboardContent(context, settings, isMobile),
                const RecommendationScreen(),
                const ComparisonScreen(),
                DataExplorerScreen(allItems: _edaData['all_items'] ?? {}),
                RFMScreen(),
                const SeasonalityScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              backgroundColor: Theme.of(context).cardColor,
              selectedItemColor: AppTheme.primaryColor,
              unselectedItemColor: Colors.grey,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() => _selectedIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.dashboard_outlined), activeIcon: const Icon(Icons.dashboard_rounded), label: settings.isVietnamese ? 'T.Quan' : 'Overview'),
                BottomNavigationBarItem(icon: const Icon(Icons.auto_awesome_outlined), activeIcon: const Icon(Icons.auto_awesome_rounded), label: settings.isVietnamese ? 'AI' : 'AI'),
                BottomNavigationBarItem(icon: const Icon(Icons.compare_arrows_outlined), activeIcon: const Icon(Icons.compare_arrows_rounded), label: settings.isVietnamese ? 'S.Sánh' : 'Comp'),
                BottomNavigationBarItem(icon: const Icon(Icons.table_rows_outlined), activeIcon: const Icon(Icons.table_rows_rounded), label: settings.isVietnamese ? 'Dữ liệu' : 'Data'),
                BottomNavigationBarItem(icon: const Icon(Icons.people_alt_outlined), activeIcon: const Icon(Icons.people_alt_rounded), label: settings.isVietnamese ? 'RFM' : 'RFM'),
                BottomNavigationBarItem(icon: const Icon(Icons.insights_outlined), activeIcon: const Icon(Icons.insights_rounded), label: settings.isVietnamese ? 'Mùa vụ' : 'Season'),
                BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), activeIcon: const Icon(Icons.settings_rounded), label: settings.isVietnamese ? 'C.Đặt' : 'Set'),
              ],
            )
          : null,
    );
  }

  Widget _buildDashboardContent(BuildContext context, SettingsProvider settings, bool isMobile) {
    if (_edaData.isEmpty) {
      return Center(
        child: Text(settings.isVietnamese ? 'Chưa có dữ liệu EDA. Vui lòng chạy Python script.' : 'No EDA data. Run python script.'),
      );
    }

    final topItems = Map<String, dynamic>.from(_edaData['top_items']);
    final monthlyTrend = Map<String, dynamic>.from(_edaData['monthly_trend']);
    final basketSizes = Map<String, dynamic>.from(_edaData['basket_sizes']);

    // Sort trends by date
    final sortedMonths = monthlyTrend.keys.toList()..sort();
    
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              settings.isVietnamese ? 'Hệ thống Phân tích Bán lẻ' : 'Retail Analytics System',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            centerTitle: false,
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: isMobile ? 1.2 : 1.5,
            ),
            delegate: SliverChildListDelegate([
              _buildSummaryCard(settings.isVietnamese ? 'Số mặt hàng (Top 10)' : 'Top 10 Items', '${topItems.length}', Icons.shopping_bag_rounded, Colors.blue),
              _buildSummaryCard(settings.isVietnamese ? 'Số tháng (GD)' : 'Months', '${monthlyTrend.length}', Icons.calendar_month_rounded, Colors.orange),
              _buildSummaryCard(settings.isVietnamese ? 'Giỏ hàng 1 món' : '1-item Baskets', '${basketSizes["1"]}', Icons.shopping_cart_rounded, Colors.purple),
              _buildSummaryCard(settings.isVietnamese ? 'Bán chạy nhất' : 'Top Item', DataService.translateItem(topItems.keys.first), Icons.trending_up_rounded, Colors.green),
            ]),
          ),
        ),
        
        // 1. Line Chart: Monthly Trend
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: _buildChartContainer(
              context: context,
              title: settings.isVietnamese ? 'Xu hướng Giao dịch theo Tháng' : 'Monthly Transaction Trend',
              height: 350,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 || value.toInt() >= sortedMonths.length) return const Text('');
                          if (value.toInt() % 2 != 0) return const Text(''); // Show every other month to avoid clutter
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              sortedMonths[value.toInt()],
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sortedMonths.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), monthlyTrend[e.value].toDouble());
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Row of Pie Chart and Bar Chart
        if (!isMobile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: _buildBasketSizePieChart(context, settings, basketSizes)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildTopItemsBarChart(context, settings, topItems)),
                ],
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildBasketSizePieChart(context, settings, basketSizes),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildTopItemsBarChart(context, settings, topItems),
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildBasketSizePieChart(BuildContext context, SettingsProvider settings, Map<String, dynamic> basketSizes) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    int i = 0;
    return _buildChartContainer(
      context: context,
      title: settings.isVietnamese ? 'Phân bổ Kích thước Giỏ hàng' : 'Basket Size Distribution',
      height: 350,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: basketSizes.entries.map((e) {
                  final color = colors[i % colors.length];
                  i++;
                  return PieChartSectionData(
                    color: color,
                    value: e.value.toDouble(),
                    title: '${e.key}',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: basketSizes.keys.toList().asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, color: colors[e.key % colors.length]),
                    const SizedBox(width: 8),
                    Text(
                      settings.isVietnamese ? '${e.value} món' : '${e.value} items',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildTopItemsBarChart(BuildContext context, SettingsProvider settings, Map<String, dynamic> topItems) {
    final maxVal = topItems.values.first.toDouble() * 1.2;
    return _buildChartContainer(
      context: context,
      title: settings.isVietnamese ? 'Top 10 Sản phẩm bán chạy nhất' : 'Top 10 Best Selling Items',
      height: 350,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= topItems.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      settings.isVietnamese 
                        ? DataService.translateItem(topItems.keys.elementAt(value.toInt())).split(' ').first 
                        : topItems.keys.elementAt(value.toInt()).split(' ').first,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: topItems.entries.toList().asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: AppTheme.secondaryColor,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChartContainer({required BuildContext context, required String title, required double height, required Widget child}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
