import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../providers/settings_provider.dart';

class AnomalyScreen extends StatefulWidget {
  const AnomalyScreen({super.key});
  @override
  State<AnomalyScreen> createState() => _AnomalyScreenState();
}

class _AnomalyScreenState extends State<AnomalyScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  double _chartWidthScale = 1.0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final d = await DataService.loadAnomaly();
    setState(() { _data = d; _isLoading = false; });
    _animCtrl.forward();
  }

  Map<String, dynamic> get _stats => _data['stats'] ?? {};
  List get _dailyAnom => _data['daily_anomalies'] ?? [];
  List get _custAnom => _data['customer_anomalies'] ?? [];
  List get _series => _data['daily_series'] ?? [];

  static const _spikeColor = Color(0xFFEF4444);
  static const _dropColor = Color(0xFFF59E0B);
  static const _lineColor = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()));
    }
    final vi = Provider.of<SettingsProvider>(context).isVietnamese;
    final mob = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                title: Text(vi ? 'Phát hiện Bất thường' : 'Anomaly Detection',
                  style: TextStyle(
                    fontSize: mob ? 19 : 24,
                    fontWeight: FontWeight.bold,
                  )),
                centerTitle: mob,
                titlePadding: EdgeInsets.only(
                  left: mob ? 0 : 24, 
                  bottom: mob ? 14 : 20))),

            // ── 1. Stat Cards ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: mob ? 2 : 4, crossAxisSpacing: 14, mainAxisSpacing: 14,
                  childAspectRatio: mob ? 0.85 : 1.6),
                delegate: SliverChildListDelegate([
                  _statCard(label: vi ? 'Tổng ngày' : 'Total Days',
                    value: '${_stats["total_days"] ?? 0}',
                    sub: vi ? 'trong dataset' : 'in dataset',
                    icon: Icons.calendar_month_rounded, color: const Color(0xFF3B82F6)),
                  _statCard(label: vi ? 'Ngày bất thường' : 'Anomaly Days',
                    value: '${_stats["anomaly_days"] ?? 0}',
                    sub: vi ? 'phát hiện được' : 'detected',
                    icon: Icons.warning_amber_rounded, color: const Color(0xFFEF4444)),
                  _statCard(label: vi ? 'Ngày tăng đột biến' : 'Spike Days',
                    value: '${_stats["spike_days"] ?? 0}',
                    sub: vi ? 'vượt ngưỡng trên' : 'above upper bound',
                    icon: Icons.trending_up_rounded, color: const Color(0xFFF59E0B)),
                  _statCard(label: vi ? 'KH bất thường' : 'Anomaly Customers',
                    value: '${_stats["anomaly_customers"] ?? 0}',
                    sub: '${_stats["pct_anomaly_customers"] ?? 0}%',
                    icon: Icons.person_off_rounded, color: const Color(0xFF8B5CF6)),
                ]),
              ),
            ),

            // ── 2. Daily Timeline Chart ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _section(
                  title: vi ? 'Giao dịch theo ngày' : 'Daily Transactions',
                  icon: Icons.timeline_rounded,
                  actionWidget: Row(
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 14, color: Colors.grey.shade500),
                      SizedBox(
                        width: 100,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _chartWidthScale,
                            min: 1.0,
                            max: 15.0, // Tăng giới hạn zoom lên 15x
                            activeColor: _lineColor,
                            inactiveColor: Colors.white10,
                            onChanged: (v) => setState(() => _chartWidthScale = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 320,
                    child: _buildScrollableChart(
                      builder: (targetWidth) => _buildDailyChart(vi, targetWidth),
                      scale: _chartWidthScale,
                    ),
                  ),
                ),
              ),
            ),

            // ── 3. Daily Anomaly List ──
            if (_dailyAnom.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'Ngày bất thường nổi bật' : 'Notable Anomaly Days',
                    icon: Icons.event_busy_rounded,
                    child: Column(children: _dailyAnom.take(10).map((a) => _buildDayRow(a, vi)).toList()),
                  ),
                ),
              ),

            // ── 4. Customer Anomaly List ──
            if (_custAnom.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'Khách hàng bất thường' : 'Anomalous Customers',
                    icon: Icons.person_search_rounded,
                    child: Column(children: _custAnom.take(15).map((c) => _buildCustRow(c, vi)).toList()),
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════ DAILY CHART ════════════════════════

  Widget _buildDailyChart(bool vi, double targetWidth) {
    if (_series.isEmpty) return const SizedBox.shrink();

    final spots = _series.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble())).toList();

    // Find max count for Y axis scaling
    final maxCount = spots.isEmpty ? 10.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    // Find anomaly indices
    final anomSpots = <ScatterSpot>[];
    for (int i = 0; i < _series.length; i++) {
      if (_series[i]['is_anomaly'] == true) {
        final count = (_series[i]['count'] as int).toDouble();
        final upper = (_stats['iqr_upper'] as num?)?.toDouble() ?? 0;
        final isSpike = count > upper;
        anomSpots.add(ScatterSpot(i.toDouble(), count,
          dotPainter: FlDotCirclePainter(
            radius: 6, color: isSpike ? _spikeColor : _dropColor,
            strokeWidth: 2, strokeColor: Colors.white)));
      }
    }

    // Tính toán mod dựa trên độ rộng truyền vào (targetWidth)
    // Mỗi nhãn cần khoảng 70px để hiển thị thoải mái
    double spacePerPoint = targetWidth / _series.length;
    int mod = (70 / spacePerPoint).ceil();
    if (mod < 1) mod = 1;
    // Đảm bảo mod là các số đẹp
    if (mod > 1 && mod <= 2) mod = 2;
    else if (mod > 2 && mod <= 5) mod = 5;
    else if (mod > 5 && mod <= 7) mod = 7;
    else if (mod > 7 && mod <= 14) mod = 14;
    else if (mod > 14 && mod <= 30) mod = 30;
    else if (mod > 30) mod = 60;

    return Stack(children: [
      LineChart(LineChartData(
        minX: 0,
        maxX: (_series.length - 1).toDouble(),
        minY: 0,
        maxY: maxCount,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1, dashArray: [4, 4]),
          getDrawingVerticalLine: (_) => FlLine(color: Colors.white.withOpacity(0.03), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            drawBelowEverything: true,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50, // Tăng thêm để xoay chữ không bị cắt
              interval: mod.toDouble(), 
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= _series.length) return const SizedBox.shrink();
                
                return SideTitleWidget(
                  meta: meta,
                  space: 12,
                  fitInside: SideTitleFitInsideData(
                    enabled: true,
                    distanceFromEdge: 0,
                    axisPosition: meta.axisPosition,
                    parentAxisSize: meta.parentAxisSize,
                  ),
                  angle: -0.7, // Nghiêng cố định để trông chuyên nghiệp và tiết kiệm diện tích
                  child: Text(_series[i]['date'].toString().substring(5),
                    style: TextStyle(
                      fontSize: 9, 
                      color: Colors.grey.shade400,
                      fontWeight: mod <= 7 ? FontWeight.bold : FontWeight.normal
                    )),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (v, _) {
                if (v == 0) return const SizedBox.shrink();
                return Text(v.toInt().toString(),
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500), textAlign: TextAlign.right);
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            left: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          )
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: Colors.white.withOpacity(0.8), // Đổi thanh chỉ báo sang màu trắng sáng
                  strokeWidth: 2,
                  dashArray: [5, 5],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 5,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: _lineColor,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            // Tạm thời xóa tooltipBgColor để tránh lỗi tương thích phiên bản
            tooltipRoundedRadius: 12,
            getTooltipItems: (spots) => spots.map((s) {
              final idx = s.x.toInt();
              final date = idx < _series.length ? _series[idx]['date'] : '';
              final isAnom = idx < _series.length && _series[idx]['is_anomaly'] == true;
              return LineTooltipItem(
                '$date\n${s.y.toInt()} ${vi ? "GD" : "txns"}${isAnom ? " ⚠" : ""}',
                TextStyle(
                  color: isAnom ? _spikeColor : Colors.white, 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: _lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [_lineColor.withOpacity(0.2), _lineColor.withOpacity(0.0)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          ),
        ],
      )),
      // Overlay anomaly dots
      if (anomSpots.isNotEmpty)
        Positioned.fill(
          child: IgnorePointer(
            child: ScatterChart(ScatterChartData(
              minY: 0, maxY: maxCount,
              minX: 0, maxX: (_series.length - 1).toDouble(),
              scatterSpots: anomSpots,
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              scatterTouchData: ScatterTouchData(enabled: false),
            )),
          ),
        ),
    ]);
  }

  // ════════════════════════ CHART WRAPPERS ════════════════════════

  Widget _buildScrollableChart({required Widget Function(double) builder, required double scale}) {
    return LayoutBuilder(builder: (context, constraints) {
      final baseWidth = constraints.maxWidth;
      final targetWidth = baseWidth * scale;
      
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: targetWidth,
          padding: const EdgeInsets.only(right: 24, top: 10),
          child: builder(targetWidth),
        ),
      );
    });
  }

  // Giữ lại hàm cũ nếu cần cho các biểu đồ khác, hoặc xóa nếu không dùng
  Widget _buildZoomableChart({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }

  Widget _buildDayRow(dynamic a, bool vi) {
    final isSpike = a['type'] == 'spike';
    final color = isSpike ? _spikeColor : _dropColor;
    final items = List<String>.from(a['top_items'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Date
            Text(a['date'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 8),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(isSpike ? (vi ? 'Tăng đột biến' : 'Spike') : (vi ? 'Sụt giảm' : 'Drop'),
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('${a["count"]} ${vi ? "GD" : "txns"}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 6),
            Text('+${a["deviation_pct"]}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          // Top items chips
          Wrap(spacing: 6, runSpacing: 4,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8)),
              child: Text(item, style: TextStyle(color: Colors.grey.shade300, fontSize: 10)),
            )).toList()),
        ],
      ),
    );
  }

  // ════════════════════════ CUSTOMER ANOMALY ROW ════════════════════════

  Widget _buildCustRow(dynamic c, bool vi) {
    final score = (c['anomaly_score'] as num).toDouble();
    // Normalize score for visual bar (score is negative, more negative = more anomalous)
    final barVal = (score.abs()).clamp(0.0, 0.5) / 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.15)),
      ),
      child: Row(children: [
        // Member ID
        SizedBox(width: 50,
          child: Text('#${c["member_id"]}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
            overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        // Score bar
        Expanded(flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Score: ${score.toStringAsFixed(3)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
            const SizedBox(height: 3),
            ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barVal, minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)))),
          ]),
        ),
        const SizedBox(width: 10),
        // Stats
        SizedBox(width: 40,
          child: Column(children: [
            Text('${c["total_transactions"]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
            Text(vi ? 'GD' : 'txns', style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
          ])),
        SizedBox(width: 40,
          child: Column(children: [
            Text('${c["avg_basket"]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
            Text(vi ? 'Giỏ TB' : 'basket', style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
          ])),
        const SizedBox(width: 8),
        // Reason badge
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
            child: Text(vi ? c['reason_vi'] : c['reason_en'],
              style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════ REUSABLE ════════════════════════

  Widget _section({required String title, required IconData icon, Widget? actionWidget, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: Colors.grey.shade300)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.95)))),
          if (actionWidget != null) actionWidget,
        ]),
        const SizedBox(height: 24),
        child,
      ]),
    );
  }

  Widget _statCard({required String label, required String value, required String sub,
      required IconData icon, required Color color}) {
    final mob = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.all(mob ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor.withOpacity(0.8), Theme.of(context).cardColor.withOpacity(0.4)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
              shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5))),
            child: Icon(icon, color: color, size: 18)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ],
      ),
    );
  }
}
