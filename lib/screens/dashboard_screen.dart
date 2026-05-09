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
import 'clustering_screen.dart';
import 'category_screen.dart';
import 'anomaly_screen.dart';
import 'forecast_screen.dart';
import 'pipeline_screen.dart';
import 'realtime_screen.dart';
import 'nlp_screen.dart';
import 'agent_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _selectedIndex = 0;
  Map<String, dynamic> _edaData = {};

  // Chart interaction state
  int? _touchedPieIndex;
  int? _touchedBarIndex;
  String? _hoveredMonth;

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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: isMobile ? _buildDrawer(context, settings) : null,
      body: Row(
        children: [
          if (!isMobile)
            LayoutBuilder(
              builder: (context, constraints) {
                final isExtended = MediaQuery.of(context).size.width > 1200;
                return Container(
                  width: isExtended ? 240 : 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: isExtended 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor, size: 32),
                                const SizedBox(width: 12),
                                const Text('Hệ Thống KHDL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            )
                          : const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor, size: 32),
                      ),
                      
                      // Main Navigation Items (Scrollable)
                      Expanded(
                        child: SingleChildScrollView(
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              backgroundColor: Colors.transparent,
                              extended: isExtended,
                              selectedIndex: _selectedIndex == 14 ? null : _selectedIndex,
                              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                              labelType: isExtended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
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
                        icon: const Icon(Icons.hub_outlined),
                        selectedIcon: const Icon(Icons.hub_rounded),
                        label: Text(settings.isVietnamese ? 'Phân cụm' : 'Cluster'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.category_outlined),
                        selectedIcon: const Icon(Icons.category_rounded),
                        label: Text(settings.isVietnamese ? 'Danh mục' : 'Category'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.bug_report_outlined),
                        selectedIcon: const Icon(Icons.bug_report_rounded),
                        label: Text(settings.isVietnamese ? 'Bất thường' : 'Anomaly'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.trending_up_outlined),
                        selectedIcon: const Icon(Icons.trending_up_rounded),
                        label: Text(settings.isVietnamese ? 'Dự báo' : 'Forecast'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.schema_outlined),
                        selectedIcon: const Icon(Icons.schema_rounded),
                        label: Text(settings.isVietnamese ? 'Kiến trúc' : 'Pipeline'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.stream_outlined),
                        selectedIcon: const Icon(Icons.stream_rounded),
                        label: Text(settings.isVietnamese ? 'Live' : 'Live'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.psychology_outlined),
                        selectedIcon: const Icon(Icons.psychology_rounded),
                        label: Text(settings.isVietnamese ? 'NLP' : 'NLP'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.smart_toy_outlined),
                        selectedIcon: const Icon(Icons.smart_toy_rounded),
                        label: Text(settings.isVietnamese ? 'AI Agent' : 'AI Agent'),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const Divider(height: 1, color: Colors.white10, indent: 10, endIndent: 10),
              
              // Settings at bottom
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: Text(settings.isVietnamese ? 'Cài đặt' : 'Settings'),
                ).toRailDestination(context, 14, _selectedIndex, (idx) => setState(() => _selectedIndex = 14), isExtended),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
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
                const ClusteringScreen(),
                const CategoryScreen(),
                const AnomalyScreen(),
                const ForecastScreen(),
                const PipelineScreen(),
                const RealtimeScreen(),
                const NLPScreen(),
                const AgentScreen(),
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
        unselectedItemColor: Colors.grey.withOpacity(0.6),
        currentIndex: _selectedIndex == 0
            ? 0
            : _selectedIndex == 1
            ? 1
            : _selectedIndex == 4
            ? 2
            : _selectedIndex == 8
            ? 3
            : 0,
        onTap: (index) {
          if (index == 4) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            int realIndex = [0, 1, 4, 8][index];
            setState(() => _selectedIndex = realIndex);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard_rounded),
              label: settings.isVietnamese ? 'T.Quan' : 'Home'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_outlined),
              activeIcon: const Icon(Icons.auto_awesome_rounded),
              label: 'B.Chéo'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.people_alt_outlined),
              activeIcon: const Icon(Icons.people_alt_rounded),
              label: 'RFM'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.bug_report_outlined),
              activeIcon: const Icon(Icons.bug_report_rounded),
              label: settings.isVietnamese ? 'B.Thường' : 'Anomaly'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.menu_rounded),
              label: settings.isVietnamese ? 'Thêm' : 'More'),
        ],
      )
          : null,
    );
  }

  // ── DRAWER ──────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, SettingsProvider settings) {
    final navItems = [
      {'icon': Icons.dashboard_rounded, 'label': settings.isVietnamese ? 'Tổng quan' : 'Overview', 'index': 0},
      {'icon': Icons.auto_awesome_rounded, 'label': settings.isVietnamese ? 'AI Gợi ý' : 'AI Recs', 'index': 1},
      {'icon': Icons.compare_arrows_rounded, 'label': settings.isVietnamese ? 'So sánh dữ liệu' : 'Comparison', 'index': 2},
      {'icon': Icons.table_rows_rounded, 'label': settings.isVietnamese ? 'Khám phá dữ liệu' : 'Data Explorer', 'index': 3},
      {'icon': Icons.people_alt_rounded, 'label': settings.isVietnamese ? 'Phân tích RFM' : 'RFM Analysis', 'index': 4},
      {'icon': Icons.insights_rounded, 'label': settings.isVietnamese ? 'Phân tích Mùa vụ' : 'Seasonality', 'index': 5},
      {'icon': Icons.hub_rounded, 'label': settings.isVietnamese ? 'Phân cụm Khách hàng' : 'Clustering', 'index': 6},
      {'icon': Icons.category_rounded, 'label': settings.isVietnamese ? 'Phân tích Danh mục' : 'Category', 'index': 7},
      {'icon': Icons.bug_report_rounded, 'label': settings.isVietnamese ? 'Phát hiện Bất thường' : 'Anomaly', 'index': 8},
      {'icon': Icons.trending_up_rounded, 'label': settings.isVietnamese ? 'Dự báo Doanh thu' : 'Forecast', 'index': 9},
      {'icon': Icons.schema_rounded, 'label': settings.isVietnamese ? 'Kiến trúc Dữ liệu' : 'Data Pipeline', 'index': 10},
      {'icon': Icons.stream_rounded, 'label': settings.isVietnamese ? 'Thời gian thực' : 'Real-time Analytics', 'index': 11},
      {'icon': Icons.psychology_rounded, 'label': settings.isVietnamese ? 'Phân tích Cảm xúc' : 'NLP Sentiment', 'index': 12},
      {'icon': Icons.smart_toy_rounded, 'label': settings.isVietnamese ? 'Trợ lý AI Agent' : 'AI Agent Chat', 'index': 13},
    ];

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_rounded, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    settings.isVietnamese ? 'HỆ THỐNG KHDL' : 'DS SYSTEM',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isSelected = _selectedIndex == item['index'];
                return ListTile(
                  leading: Icon(item['icon'] as IconData,
                      color: isSelected ? AppTheme.primaryColor : Colors.grey),
                  title: Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() => _selectedIndex = item['index'] as int);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ListTile(
            leading: Icon(Icons.settings_rounded, 
                color: _selectedIndex == 14 ? AppTheme.primaryColor : Colors.grey),
            title: Text(
              settings.isVietnamese ? 'Cài đặt hệ thống' : 'System Settings',
              style: TextStyle(
                color: _selectedIndex == 14 ? AppTheme.primaryColor : Colors.grey.shade400,
                fontWeight: _selectedIndex == 14 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: _selectedIndex == 14,
            onTap: () {
              setState(() => _selectedIndex = 14);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text('Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── DASHBOARD CONTENT ───────────────────────────────────────────
  Widget _buildDashboardContent(
      BuildContext context, SettingsProvider settings, bool isMobile) {
    if (_edaData.isEmpty) {
      return Center(
        child: Text(settings.isVietnamese
            ? 'Chưa có dữ liệu EDA. Vui lòng chạy Python script.'
            : 'No EDA data. Run python script.'),
      );
    }

    final topItems = Map<String, dynamic>.from(_edaData['top_items']);
    final monthlyTrend = Map<String, dynamic>.from(_edaData['monthly_trend']);
    final basketSizes = Map<String, dynamic>.from(_edaData['basket_sizes']);
    final sortedMonths = monthlyTrend.keys.toList()..sort();

    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          expandedHeight: isMobile ? 60 : 120,
          floating: false,
          pinned: false,
          backgroundColor: Colors.transparent,
          leading: isMobile
              ? IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          )
              : null,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              settings.isVietnamese ? 'Hệ thống Phân tích Bán lẻ' : 'Retail Analytics System',
              style: TextStyle(fontSize: isMobile ? 16 : 22, fontWeight: FontWeight.bold),
            ),
            centerTitle: isMobile,
            titlePadding: EdgeInsets.only(left: isMobile ? 0 : 20, bottom: 16),
          ),
        ),

        if (isMobile) const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // Stat Cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isMobile ? 1.1 : 1.8,
            ),
            delegate: SliverChildListDelegate([
              _buildSummaryCard(
                settings.isVietnamese ? 'Mặt hàng' : 'Items',
                '${topItems.length}',
                subtitle: 'Top ${topItems.length} SKUs',
                icon: Icons.shopping_bag_rounded,
                color: Colors.blue,
              ),
              _buildSummaryCard(
                settings.isVietnamese ? 'Số tháng' : 'Months',
                '${monthlyTrend.length}',
                subtitle: '2014 – 2015',
                icon: Icons.calendar_month_rounded,
                color: Colors.orange,
              ),
              _buildSummaryCard(
                settings.isVietnamese ? 'Giỏ 1 món' : '1-item Baskets',
                '${basketSizes["1"]}',
                subtitle: settings.isVietnamese ? 'giao dịch' : 'transactions',
                icon: Icons.shopping_cart_rounded,
                color: Colors.purple,
              ),
              _buildSummaryCard(
                settings.isVietnamese ? 'Bán chạy' : 'Top Item',
                DataService.translateItem(topItems.keys.first, settings.isVietnamese),
                subtitle: '${topItems.values.first} ${settings.isVietnamese ? "lần" : "times"}',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF1D9E75),
              ),
            ]),
          ),
        ),

        // ── Line Chart: Monthly Trend (UPGRADED) ──────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _buildChartContainer(
              context: context,
              title: settings.isVietnamese
                  ? 'Xu hướng Giao dịch theo Tháng'
                  : 'Monthly Transaction Trend',
              subtitle: settings.isVietnamese
                  ? 'Tổng số giao dịch mỗi tháng • 2014–2015'
                  : 'Total transactions per month • 2014–2015',
              height: 360,
              child: _buildMonthlyLineChart(sortedMonths, monthlyTrend, settings),
            ),
          ),
        ),

        // ── Pie + Bar (UPGRADED) ──────────────────────────────────
        if (!isMobile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildBasketSizePieChart(context, settings, basketSizes),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 6,
                    child: _buildTopItemsBarChart(context, settings, topItems),
                  ),
                ],
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _buildBasketSizePieChart(context, settings, basketSizes),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _buildTopItemsBarChart(context, settings, topItems),
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── MONTHLY LINE CHART (UPGRADED) ──────────────────────────────
  Widget _buildMonthlyLineChart(
      List<String> sortedMonths,
      Map<String, dynamic> monthlyTrend,
      SettingsProvider settings,
      ) {
    final List<double> values = sortedMonths.map((m) => (monthlyTrend[m] as num).toDouble()).toList();
    final maxVal = values.reduce((a, b) => max(a, b));
    final minVal = values.reduce((a, b) => min(a, b));
    final maxY = ((maxVal * 1.1) / 200).ceil() * 200.0;
    final minY = ((minVal * 0.9) / 200).floor() * 200.0;

    // Find peak month
    final peakIdx = values.indexOf(maxVal);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 200,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            left: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= sortedMonths.length) return const SizedBox();
                // Show every 3rd label to avoid clutter
                if (i % 3 != 0) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  angle: -45 * pi / 180,
                  space: 8,
                  child: Text(
                    sortedMonths[i],
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                settings.isVietnamese ? 'Giao dịch' : 'Transactions',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
            axisNameSize: 18,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: 200,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF1E2333),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (spots) => spots.map((spot) {
              final i = spot.x.toInt();
              final month = i >= 0 && i < sortedMonths.length ? sortedMonths[i] : '';
              return LineTooltipItem(
                '$month\n',
                const TextStyle(color: Colors.grey, fontSize: 11),
                children: [
                  TextSpan(
                    text: '${spot.y.toInt()} ${settings.isVietnamese ? "giao dịch" : "transactions"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          handleBuiltInTouches: true,
        ),
        lineBarsData: [
          // Gradient fill line
          LineChartBarData(
            spots: sortedMonths.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), monthlyTrend[e.value].toDouble())).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.primaryColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.x.toInt() == peakIdx,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppTheme.primaryColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.25),
                  AppTheme.primaryColor.withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
        // Vertical touch line
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: true,
          verticalLines: _hoveredMonth != null
              ? [
            VerticalLine(
              x: sortedMonths.indexOf(_hoveredMonth!).toDouble(),
              color: Colors.white.withOpacity(0.15),
              strokeWidth: 1,
              dashArray: [4, 4],
            )
          ]
              : [],
        ),
      ),
    );
  }

  // ── PIE CHART (UPGRADED — interactive) ─────────────────────────
  Widget _buildBasketSizePieChart(
      BuildContext context, SettingsProvider settings, Map<String, dynamic> basketSizes) {
    // Richer color palette
    final colors = [
      const Color(0xFF378ADD),
      const Color(0xFF1D9E75),
      const Color(0xFFD4A017),
      const Color(0xFF534AB7),
      const Color(0xFFD85A30),
    ];

    final entries = basketSizes.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + (e.value as int));

    return _buildChartContainer(
      context: context,
      title: settings.isVietnamese ? 'Phân bổ Kích thước Giỏ hàng' : 'Basket Size Distribution',
      subtitle: settings.isVietnamese ? 'Nhấn vào từng phần để xem chi tiết' : 'Tap a slice for details',
      height: 480,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Donut chart
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 48,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (response?.touchedSection != null) {
                                  _touchedPieIndex = response!
                                      .touchedSection!.touchedSectionIndex;
                                } else if (event is FlTapUpEvent ||
                                    event is FlLongPressEnd) {
                                  _touchedPieIndex = null;
                                }
                              });
                            },
                          ),
                          sections: entries.asMap().entries.map((entry) {
                            final i = entry.key;
                            final e = entry.value;
                            final isTouched = _touchedPieIndex == i;
                            final pct = (e.value as int) / total * 100;
                            return PieChartSectionData(
                              color: colors[i % colors.length],
                              value: e.value.toDouble(),
                              title: isTouched
                                  ? '${pct.toStringAsFixed(1)}%'
                                  : '',
                              radius: isTouched ? 72 : 60,
                              titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                      // Center label
                      if (_touchedPieIndex != null &&
                          _touchedPieIndex! >= 0 &&
                          _touchedPieIndex! < entries.length)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${entries[_touchedPieIndex!].value}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              settings.isVietnamese ? 'giao dịch' : 'transactions',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              settings.isVietnamese ? 'tổng' : 'total',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Legend
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      final isSelected = _touchedPieIndex == i;
                      final pct = (e.value as int) / total * 100;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _touchedPieIndex = isSelected ? null : i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors[i % colors.length].withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(
                                color: colors[i % colors.length]
                                    .withOpacity(0.4))
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      settings.isVietnamese
                                          ? '${e.key} món'
                                          : '${e.key} item${(int.tryParse(e.key) ?? 2) > 1 ? "s" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade400,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colors[i % colors.length],
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Detail bar when touched
          if (_touchedPieIndex != null && _touchedPieIndex! >= 0 && _touchedPieIndex! < entries.length)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors[_touchedPieIndex! % colors.length].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: colors[_touchedPieIndex! % colors.length]
                        .withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    settings.isVietnamese
                        ? 'Giỏ ${entries[_touchedPieIndex!].key} món'
                        : '${entries[_touchedPieIndex!].key}-item basket',
                    style: TextStyle(
                        color: colors[_touchedPieIndex! % colors.length],
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  Text(
                    '${entries[_touchedPieIndex!].value} (${((entries[_touchedPieIndex!].value as int) / total * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── TOP ITEMS BAR CHART (UPGRADED) ─────────────────────────────
  Widget _buildTopItemsBarChart(
      BuildContext context, SettingsProvider settings, Map<String, dynamic> topItems) {
    final entries = topItems.entries.take(10).toList();
    final maxVal = entries.first.value.toDouble();

    // Gradient color per bar: purple → pink
    Color barColor(int i) {
      final colors = [
        const Color(0xFF7F77DD),
        const Color(0xFF6E6BD4),
        const Color(0xFF5E5ECB),
        const Color(0xFF5170C2),
        const Color(0xFF4782B9),
        const Color(0xFF3D94B0),
        const Color(0xFF32A69A),
        const Color(0xFF28B884),
        const Color(0xFFE87D6A),
        const Color(0xFFEF9F27),
      ];
      return colors[i % colors.length];
    }

    return _buildChartContainer(
      context: context,
      title: settings.isVietnamese ? 'Top 10 Sản phẩm bán chạy nhất' : 'Top 10 Best Selling Items',
      subtitle: settings.isVietnamese
          ? 'Nhấn vào cột để xem số liệu chi tiết'
          : 'Tap a bar for details',
      height: 480,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    setState(() {
                      if (response?.spot != null) {
                        _touchedBarIndex =
                            response!.spot!.touchedBarGroupIndex;
                      } else if (event is FlTapUpEvent ||
                          event is FlLongPressEnd) {
                        _touchedBarIndex = null;
                      }
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1E2333),
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final name = settings.isVietnamese
                          ? DataService.translateItem(
                          entries[groupIndex].key)
                          : entries[groupIndex].key;
                      return BarTooltipItem(
                        '$name\n',
                        const TextStyle(color: Colors.grey, fontSize: 11),
                        children: [
                          TextSpan(
                            text:
                            '${rod.toY.toInt()} ${settings.isVietnamese ? "lần" : "times"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        settings.isVietnamese ? 'Sản phẩm' : 'Product',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ),
                    axisNameSize: 24,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= entries.length) return const SizedBox();
                        final label = settings.isVietnamese
                            ? DataService.translateItem(entries[i].key)
                            .split(' ')
                            .first
                            : entries[i].key.split('/').first.split(' ').first;
                        final isSelected = _touchedBarIndex == i;
                        return SideTitleWidget(
                          meta: meta,
                          angle: -45 * pi / 180,
                          space: 4,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? barColor(i)
                                  : Colors.grey.shade500,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        settings.isVietnamese ? 'Số lần' : 'Count',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ),
                    axisNameSize: 18,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: (maxVal / 4).roundToDouble(),
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toInt().toString(),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal / 4).roundToDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1), width: 1),
                    left: BorderSide(
                        color: Colors.white.withOpacity(0.1), width: 1),
                  ),
                ),
                barGroups: entries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final isTouched = _touchedBarIndex == i;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: isTouched
                            ? barColor(i)
                            : barColor(i).withOpacity(0.55),
                        width: isTouched ? 22 : 18,
                        borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.2,
                          color: Colors.white.withOpacity(0.03),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: isTouched ? [0] : [],
                  );
                }).toList(),
              ),
            ),
          ),
          // Selected item detail
          if (_touchedBarIndex != null && _touchedBarIndex! >= 0 && _touchedBarIndex! < entries.length)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 10),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: barColor(_touchedBarIndex!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: barColor(_touchedBarIndex!).withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      settings.isVietnamese
                          ? DataService.translateItem(
                          entries[_touchedBarIndex!].key)
                          : entries[_touchedBarIndex!].key,
                      style: TextStyle(
                          color: barColor(_touchedBarIndex!),
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entries[_touchedBarIndex!].value} ${settings.isVietnamese ? "giao dịch" : "transactions"}'
                        '  •  ${(entries[_touchedBarIndex!].value / entries[0].value * 100).toStringAsFixed(1)}% top',
                    style:
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── SHARED WIDGETS ──────────────────────────────────────────────
  Widget _buildChartContainer({
    required BuildContext context,
    required String title,
    required double height,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle,
                style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title,
      String value, {
        required String subtitle,
        required IconData icon,
        required Color color,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

extension on NavigationRailDestination {
  Widget toRailDestination(BuildContext context, int index, int selectedIndex, Function(int) onTap, bool isExtended) {
    final isSelected = index == selectedIndex;
    final color = isSelected ? AppTheme.primaryColor : Colors.grey;
    
    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: isExtended ? 16 : 0),
        child: isExtended 
          ? Row(
              children: [
                IconTheme(
                  data: IconThemeData(color: color, size: 24),
                  child: isSelected ? (selectedIcon ?? icon) : icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DefaultTextStyle(
                    style: TextStyle(color: color, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    child: label,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                IconTheme(
                  data: IconThemeData(color: color, size: 24),
                  child: isSelected ? (selectedIcon ?? icon) : icon,
                ),
                const SizedBox(height: 4),
                DefaultTextStyle(
                  style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  child: label,
                ),
              ],
            ),
      ),
    );
  }
}