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
}