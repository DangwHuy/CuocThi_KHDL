import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../providers/settings_provider.dart';

class SeasonalityScreen extends StatefulWidget {
  const SeasonalityScreen({super.key});
  @override
  State<SeasonalityScreen> createState() => _SeasonalityScreenState();
}

class _SeasonalityScreenState extends State<SeasonalityScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // Tăng thời gian animation một chút để mượt hơn
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final d = await DataService.loadSeasonality();
    setState(() {
      _data = d;
      _isLoading = false;
    });
    _animCtrl.forward();
  }

  // helpers
  Map<String, dynamic> get _stats => _data['stats'] ?? {};
  List<int> get _t2014 => List<int>.from(_data['trend_2014'] ?? List.filled(12, 0));
  List<int> get _t2015 => List<int>.from(_data['trend_2015'] ?? List.filled(12, 0));
  List get _avgMonthly => _data['avg_monthly'] ?? [];
  List get _dow => _data['day_of_week'] ?? [];
  List get _yoyMonthly => _data['yoy_monthly'] ?? [];
  List<String> _mNames(bool vi) =>
      List<String>.from(_data[vi ? 'month_names_vi' : 'month_names_en'] ?? []);

  Map<String, dynamic> get _seasonalProducts =>
      Map<String, dynamic>.from(_data['seasonal_products'] ?? {});

  List<Map<String, String>> _buildInsights(bool vi) {
    final insights = <Map<String, String>>[];
    final peakName = vi ? _stats['peak_month_name_vi'] : _stats['peak_month_name_en'];
    final peakCount = _stats['peak_count'] ?? 0;
    final yoy = _stats['yoy_growth'] ?? 0;

    insights.add({
      'icon': '📈',
      'title': vi ? 'Tăng trưởng mạnh' : 'Strong Growth',
      'text': vi
          ? 'Năm 2015 tăng $yoy% so với 2014 — doanh nghiệp đang mở rộng thị phần thành công.'
          : '2015 grew $yoy% YoY — business is successfully expanding market share.',
    });
    insights.add({
      'icon': '🔥',
      'title': vi ? 'Tháng cao điểm: $peakName' : 'Peak Month: $peakName',
      'text': vi
          ? '$peakCount giao dịch — tháng 8 là mùa tựu trường, nhu cầu mua sắm tăng vọt. Nên tăng tồn kho trước tháng 7.'
          : '$peakCount transactions — August is back-to-school season. Stock up before July.',
    });

    // Find weakest month
    if (_avgMonthly.isNotEmpty) {
      int minCount = 999999;
      int minMonth = 0;
      for (final m in _avgMonthly) {
        if ((m['count'] as int) < minCount) {
          minCount = m['count'] as int;
          minMonth = m['month'] as int;
        }
      }
      final mNames = _mNames(vi);
      final weakName = minMonth > 0 && minMonth <= mNames.length ? mNames[minMonth - 1] : '$minMonth';
      insights.add({
        'icon': '⚠️',
        'title': vi ? 'Tháng thấp điểm: $weakName' : 'Low Month: $weakName',
        'text': vi
            ? 'Chỉ $minCount giao dịch — cần chiến lược khuyến mãi đặc biệt để kích cầu.'
            : 'Only $minCount transactions — needs special promotions to boost demand.',
      });
    }

    // Day of week insight
    if (_dow.isNotEmpty) {
      int maxDow = 0, maxDowCount = 0;
      for (int i = 0; i < _dow.length; i++) {
        if ((_dow[i]['count'] as int) > maxDowCount) {
          maxDowCount = _dow[i]['count'] as int;
          maxDow = i;
        }
      }
      final dayName = vi ? _dow[maxDow]['name_vi'] : _dow[maxDow]['name_en'];
      insights.add({
        'icon': '📅',
        'title': vi ? 'Ngày bán chạy nhất: $dayName' : 'Best Day: $dayName',
        'text': vi
            ? '$maxDowCount giao dịch — nên tập trung nhân sự và khuyến mãi vào ngày này.'
            : '$maxDowCount transactions — focus staffing and promotions on this day.',
      });
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final s = Provider.of<SettingsProvider>(context);
    final vi = s.isVietnamese;
    final mob = MediaQuery.of(context).size.width < 800;
    final mNames = _mNames(vi);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // AppBar
              SliverAppBar(
                expandedHeight: mob ? 60 : 120,
                floating: false,
                pinned: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: mob ? IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ) : null,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    vi ? 'Mùa vụ & Xu hướng' : 'Seasonality & Trend',
                    style: TextStyle(
                      fontSize: mob ? 19 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: mob,
                  titlePadding: EdgeInsets.only(
                    left: mob ? 0 : 24, 
                    bottom: mob ? 14 : 20
                  ),
                ),
              ),

              // ── 1. Stat Cards ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: mob ? 2 : 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: mob ? 1.0 : 1.8,
                  ),
                  delegate: SliverChildListDelegate([
                    _card(
                        label: vi ? 'Tổng GD 2014' : 'Total 2014',
                        value: '${_stats["total_2014"] ?? 0}',
                        sub: vi ? 'giao dịch' : 'transactions',
                        icon: Icons.auto_graph_rounded,
                        color: const Color(0xFF3B82F6)), // Modern Blue
                    _card(
                        label: vi ? 'Tổng GD 2015' : 'Total 2015',
                        value: '${_stats["total_2015"] ?? 0}',
                        sub: vi ? 'giao dịch' : 'transactions',
                        icon: Icons.insights_rounded,
                        color: const Color(0xFF10B981)), // Modern Green
                    _card(
                        label: vi ? 'Tăng trưởng YoY' : 'YoY Growth',
                        value: '+${_stats["yoy_growth"] ?? 0}%',
                        sub: '2015 vs 2014',
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFFF59E0B)), // Modern Amber
                    _card(
                        label: vi ? 'Tháng cao điểm' : 'Peak Month',
                        value: vi
                            ? '${_stats["peak_month_name_vi"]}'
                            : '${_stats["peak_month_name_en"]}',
                        sub: '${_stats["peak_count"]} ${vi ? "giao dịch" : "txns"}',
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFEF4444)), // Modern Red
                   ]),
                ),
              ),

              // ── NEW: AI Insights ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? '🧠 Phân tích AI tự động' : '🧠 AI Auto-Insights',
                    icon: Icons.psychology_rounded,
                    child: Column(
                      children: _buildInsights(vi).map((insight) =>
                          _buildInsightCard(insight, vi)).toList(),
                    ),
                  ),
                ),
              ),

              // ── NEW: Seasonal Products ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? '🌿 Sản phẩm bán chạy theo Mùa' : '🌿 Seasonal Best Sellers',
                    icon: Icons.eco_rounded,
                    child: _buildSeasonalGrid(vi, mob),
                  ),
                ),
              ),

              // ── 2. Line chart: 2014 vs 2015 ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'So sánh 2014 vs 2015' : '2014 vs 2015 Comparison',
                    icon: Icons.stacked_line_chart_rounded,
                    child: SizedBox(
                      height: 300,
                      child: _buildLineChart(mNames),
                    ),
                  ),
                ),
              ),

              // ── 3. Bar chart: average monthly ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'Giao dịch TB hàng tháng' : 'Avg Monthly Transactions',
                    icon: Icons.bar_chart_rounded,
                    child: SizedBox(height: 280, child: _buildAvgMonthlyBar(mNames)),
                  ),
                ),
              ),

              // ── 4. Two small charts side-by-side (or stacked on mobile) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: mob
                      ? Column(children: [
                    _section(
                      title: vi ? 'Theo ngày trong tuần' : 'By Day of Week',
                      icon: Icons.calendar_view_week_rounded,
                      child: SizedBox(height: 240, child: _buildDowBar(vi)),
                    ),
                    const SizedBox(height: 24),
                    _section(
                      title: vi ? 'Tăng trưởng YoY (%)' : 'YoY Growth (%)',
                      icon: Icons.percent_rounded,
                      child: SizedBox(height: 240, child: _buildYoyBar(mNames)),
                    ),
                  ])
                      : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _section(
                            title: vi ? 'Theo ngày trong tuần' : 'By Day of Week',
                            icon: Icons.calendar_view_week_rounded,
                            child: SizedBox(height: 260, child: _buildDowBar(vi)),
                          )),
                      const SizedBox(width: 24),
                      Expanded(
                          child: _section(
                            title: vi ? 'Tăng trưởng YoY (%)' : 'YoY Growth (%)',
                            icon: Icons.percent_rounded,
                            child: SizedBox(height: 260, child: _buildYoyBar(mNames)),
                          )),
                    ],
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════ CHARTS ════════════════════════

  Widget _buildLineChart(List<String> mNames) {
    final spots14 = _t2014.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
    final spots15 = _t2015.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();

    return LineChart(LineChartData(
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
            dashArray: [5, 5], // Đường lưới nét đứt hiện đại
          )),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= mNames.length) return const SizedBox.shrink();
                  return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(mNames[i],
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500)));
                })),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) {
                  if (v == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('${v.toInt()}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  );
                })),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 12,
          getTooltipItems: (spots) => spots.map((s) {
            final is2014 = s.barIndex == 0;
            return LineTooltipItem(
              '${is2014 ? "2014" : "2015"}: ${s.y.toInt()}',
              TextStyle(
                  color: is2014 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
            spots: spots14,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF3B82F6),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF3B82F6),
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).cardColor),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.2),
                  const Color(0xFF3B82F6).withOpacity(0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )),
        LineChartBarData(
            spots: spots15,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF10B981),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF10B981),
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).cardColor),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFF10B981).withOpacity(0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )),
      ],
    ));
  }

  Widget _buildAvgMonthlyBar(List<String> mNames) {
    if (_avgMonthly.isEmpty) return const SizedBox.shrink();
    final maxVal = _avgMonthly.map((e) => (e['count'] as int)).reduce((a, b) => a > b ? a : b);
    final peakMonth = _stats['peak_month'] ?? 0;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.15,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              '${r.toY.toInt()}',
              const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= mNames.length) return const SizedBox.shrink();
                  return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(mNames[i],
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500)));
                })),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: _avgMonthly.asMap().entries.map((entry) {
        final m = entry.value['month'] as int;
        final c = (entry.value['count'] as int).toDouble();
        final isPeak = m == peakMonth;
        return BarChartGroupData(x: entry.key, barRods: [
          BarChartRodData(
              toY: c,
              width: 20,
              gradient: LinearGradient(
                colors: isPeak
                    ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)] // Red Gradient
                    : [const Color(0xFF60A5FA), const Color(0xFF3B82F6)], // Blue Gradient
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxVal * 1.15,
                  color: Colors.white.withOpacity(0.04))),
        ]);
      }).toList(),
    ));
  }

  Widget _buildDowBar(bool vi) {
    if (_dow.isEmpty) return const SizedBox.shrink();
    final maxVal = _dow.map((e) => (e['count'] as int)).reduce((a, b) => a > b ? a : b);
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.12,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              '${r.toY.toInt()}',
              const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _dow.length) return const SizedBox.shrink();
                  final name = vi ? _dow[i]['name_vi'] : _dow[i]['name_en'];
                  String displayLabel;
                  if (vi) {
                    // Chuyển "Thứ 2" -> "T2", "CN" giữ nguyên
                    displayLabel = name.contains('Thứ') ? name.replaceFirst('Thứ ', 'T') : name;
                  } else {
                    displayLabel = name.length >= 3 ? name.substring(0, 3) : name;
                  }
                  
                  return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(displayLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500)));
                })),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: _dow.asMap().entries.map((entry) {
        final c = (entry.value['count'] as int).toDouble();
        final baseColor = colors[entry.key % colors.length];
        return BarChartGroupData(x: entry.key, barRods: [
          BarChartRodData(
              toY: c,
              width: 24,
              gradient: LinearGradient(
                colors: [baseColor.withOpacity(0.7), baseColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxVal * 1.12,
                  color: Colors.white.withOpacity(0.04))),
        ]);
      }).toList(),
    ));
  }

  Widget _buildYoyBar(List<String> mNames) {
    if (_yoyMonthly.isEmpty) return const SizedBox.shrink();
    final maxAbs = _yoyMonthly.map((e) => (e['pct'] as num).abs()).reduce((a, b) => a > b ? a : b);
    final maxY = maxAbs * 1.3;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      minY: -maxY * 0.3,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItem: (g, gi, r, ri) {
            final pct = r.toY;
            return BarTooltipItem(
                '${pct > 0 ? "+" : ""}${pct.toStringAsFixed(1)}%',
                TextStyle(
                    color: pct >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.bold));
          },
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= mNames.length) return const SizedBox.shrink();
                  return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(mNames[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500)));
                })),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => v == 0
              ? FlLine(color: Colors.white.withOpacity(0.2), strokeWidth: 1.5)
              : const FlLine(color: Colors.transparent)),
      borderData: FlBorderData(show: false),
      barGroups: _yoyMonthly.asMap().entries.map((entry) {
        final pct = (entry.value['pct'] as num).toDouble();
        final isPositive = pct >= 0;
        final baseColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        return BarChartGroupData(x: entry.key, barRods: [
          BarChartRodData(
              toY: pct,
              width: 16,
              gradient: LinearGradient(
                colors: isPositive
                    ? [baseColor.withOpacity(0.7), baseColor]
                    : [baseColor, baseColor.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: isPositive
                  ? const BorderRadius.vertical(top: Radius.circular(4))
                  : const BorderRadius.vertical(bottom: Radius.circular(4))),
        ]);
      }).toList(),
    ));
  }

  // ════════════════════════ REUSABLE WIDGETS ════════════════════════

  Widget _section({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.6), // Kính mờ nhẹ
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade300),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ]),
    );
  }

  Widget _card({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    final mob = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.all(mob ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor.withOpacity(0.8),
            Theme.of(context).cardColor.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 1),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════ NEW: AI INSIGHT CARD ════════════════════════

  Widget _buildInsightCard(Map<String, String> insight, bool vi) {
    final colors = {
      '📈': const Color(0xFF10B981),
      '🔥': const Color(0xFFEF4444),
      '⚠️': const Color(0xFFF59E0B),
      '📅': const Color(0xFF3B82F6),
    };
    final color = colors[insight['icon']] ?? const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(insight['icon']!, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight['title']!,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight['text']!,
                  style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════ NEW: SEASONAL GRID ════════════════════════

  static const _seasonMeta = {
    'spring': {'icon': '🌸', 'color': 0xFFF472B6, 'gradient1': 0xFFFBCFE8, 'gradient2': 0xFFF9A8D4},
    'summer': {'icon': '☀️', 'color': 0xFFFBBF24, 'gradient1': 0xFFFDE68A, 'gradient2': 0xFFF59E0B},
    'autumn': {'icon': '🍂', 'color': 0xFFF97316, 'gradient1': 0xFFFDBA74, 'gradient2': 0xFFEA580C},
    'winter': {'icon': '❄️', 'color': 0xFF38BDF8, 'gradient1': 0xFF7DD3FC, 'gradient2': 0xFF0EA5E9},
  };

  Widget _buildSeasonalGrid(bool vi, bool mob) {
    final sp = _seasonalProducts;
    if (sp.isEmpty) {
      return Center(
        child: Text(
          vi ? 'Chưa có dữ liệu mùa vụ' : 'No seasonal data available',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    final seasons = ['spring', 'summer', 'autumn', 'winter'];
    Widget grid = GridView.count(
      crossAxisCount: mob ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: mob ? 1.7 : 3.0, // Tăng tỉ lệ để card mỏng đẹp khi trải rộng toàn màn hình
      children: seasons.where((s) => sp.containsKey(s)).map((season) {
        final data = sp[season] as Map<String, dynamic>;
        final meta = _seasonMeta[season]!;
        final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final seasonName = vi ? data['name_vi'] : data['name_en'];
        final color = Color(meta['color'] as int);

        return _buildSeasonCard(
          seasonName: seasonName as String,
          icon: meta['icon'] as String,
          color: color,
          products: products,
          vi: vi,
        );
      }).toList(),
    );

    if (mob) return grid;
    
    return grid;
  }

  Widget _buildSeasonCard({
    required String seasonName,
    required String icon,
    required Color color,
    required List<Map<String, dynamic>> products,
    required bool vi,
  }) {
    final maxCount = products.isNotEmpty
        ? products.map((p) => p['count'] as int).reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                seasonName,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${products.length} ${vi ? "SP" : "items"}',
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: products.take(5).map((p) {
              final name = p['name'] as String;
              final count = p['count'] as int;
              final fraction = count / maxCount;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        vi ? DataService.translateItem(name) : name,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$count',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontFamily: 'monospace'),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}