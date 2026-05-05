import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../providers/settings_provider.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  int? _selectedCat;
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
    final d = await DataService.loadCategory();
    setState(() { _data = d; _isLoading = false; });
    _animCtrl.forward();
  }

  Map<String, dynamic> get _stats => _data['stats'] ?? {};
  List get _cats => _data['categories'] ?? [];
  List get _topProds => _data['top_products_overall'] ?? [];

  Color _hex(String h) => Color(int.parse('FF${h.replaceFirst("#", "")}', radix: 16));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()));
    }
    final s = Provider.of<SettingsProvider>(context);
    final vi = s.isVietnamese;
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
                title: Text(vi ? 'Phân tích Danh mục' : 'Category Analysis',
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
                  crossAxisCount: mob ? 2 : 3, crossAxisSpacing: 14, mainAxisSpacing: 14,
                  childAspectRatio: mob ? 1.0 : 2.2),
                delegate: SliverChildListDelegate([
                  _statCard(label: vi ? 'Tổng giao dịch' : 'Total Transactions',
                    value: '${_stats["total_transactions"] ?? 0}',
                    sub: vi ? 'trong dataset' : 'in dataset',
                    icon: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6)),
                  _statCard(label: vi ? 'DM phổ biến nhất' : 'Most Popular',
                    value: vi ? '${_stats["most_popular_vi"]}' : '${_stats["most_popular_en"]}',
                    sub: '${_stats["most_popular_count"]} ${vi ? "GD" : "txns"}',
                    icon: Icons.star_rounded, color: const Color(0xFFF59E0B)),
                  if (!mob || true)
                    _statCard(label: vi ? 'SP bán chạy nhất' : 'Top Product',
                      value: '${_stats["top_product"] ?? ""}',
                      sub: '${_stats["top_product_count"]} ${vi ? "lần" : "times"}',
                      icon: Icons.local_fire_department_rounded, color: const Color(0xFFEF4444)),
                ]),
              ),
            ),

            // ── 2. Treemap ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _section(
                  title: vi ? 'Tỷ trọng danh mục' : 'Category Share',
                  icon: Icons.grid_view_rounded,
                  child: _buildTreemap(vi, mob),
                ),
              ),
            ),

            // ── 3. Detail Panel ──
            if (_selectedCat != null && _selectedCat! < _cats.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _buildDetailPanel(vi, mob),
                ),
              ),

            // ── 4. Bar chart ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _section(
                  title: vi ? 'So sánh giao dịch theo danh mục' : 'Transactions by Category',
                  icon: Icons.bar_chart_rounded,
                  child: SizedBox(height: 240, child: _buildCatBar(vi)),
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════ TREEMAP ════════════════════════

  Widget _buildTreemap(bool vi, bool mob) {
    if (_cats.isEmpty) return const SizedBox.shrink();
    final totalAll = _cats.fold<int>(0, (sum, c) => sum + (c['total'] as int));

    return Wrap(
      spacing: 10, runSpacing: 10,
      children: _cats.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        final color = _hex(c['color']);
        final pct = c['pct'] as double;
        final isSelected = _selectedCat == i;
        // Width proportional to pct, min 80
        final w = mob
            ? (MediaQuery.of(context).size.width - 48 - 10) * (pct / 100.0) * 1.8
            : (MediaQuery.of(context).size.width - 400) * (pct / 100.0) * 1.5;
        final clampedW = w.clamp(mob ? 100.0 : 120.0, mob ? 220.0 : 300.0);

        return GestureDetector(
          onTap: () => setState(() => _selectedCat = _selectedCat == i ? null : i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: clampedW,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : color.withOpacity(0.3),
                width: isSelected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vi ? c['name_vi'] : c['name_en'],
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${c["total"]}', style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('${c["pct"]}%', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ════════════════════════ DETAIL PANEL ════════════════════════

  Widget _buildDetailPanel(bool vi, bool mob) {
    final c = _cats[_selectedCat!];
    final color = _hex(c['color']);
    final top3 = c['top_3'] as List;
    final trend = List<int>.from(c['monthly_trend'] ?? []);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(width: 14, height: 14,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 10),
            Expanded(child: Text(vi ? c['name_vi'] : c['name_en'],
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16))),
            GestureDetector(
              onTap: () => setState(() => _selectedCat = null),
              child: Icon(Icons.close, color: Colors.grey.shade500, size: 18)),
          ]),
          const SizedBox(height: 6),
          Text('${c["total"]} ${vi ? "giao dịch" : "transactions"} • ${c["pct"]}% ${vi ? "tổng" : "total"} • ${c["unique_products"]} ${vi ? "sản phẩm" : "products"}',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 16),

          // Top 3 products
          Text(vi ? 'Top 3 sản phẩm' : 'Top 3 Products',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          ...top3.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(
                    vi ? DataService.translateItem(p['name']) : p['name'],
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
                  Text('${p["count"]} (${p["pct_in_category"]}%)',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (p['pct_in_category'] as num) / 100.0,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          )),

          // Mini trend chart
          const SizedBox(height: 12),
          Text(vi ? 'Xu hướng 24 tháng' : '24-Month Trend',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: trend.isEmpty ? const SizedBox.shrink() : LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) =>
                    LineTooltipItem('${s.y.toInt()}', TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))
                  ).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                  isCurved: true, curveSmoothness: 0.3, color: color, barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  // ════════════════════════ BAR CHART ════════════════════════

  Widget _buildCatBar(bool vi) {
    if (_cats.isEmpty) return const SizedBox.shrink();
    final maxVal = _cats.map((c) => (c['total'] as int).toDouble()).reduce((a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItem: (g, gi, r, ri) {
            final name = vi ? _cats[g.x.toInt()]['name_vi'] : _cats[g.x.toInt()]['name_en'];
            return BarTooltipItem('$name\n${r.toY.toInt()}',
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
          },
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= _cats.length) return const SizedBox.shrink();
            final name = vi ? _cats[i]['name_vi'] : _cats[i]['name_en'];
            final short = name.length > 8 ? '${name.substring(0, 8)}…' : name;
            return Padding(padding: const EdgeInsets.only(top: 10),
              child: Text(short, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)));
          })),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: _cats.asMap().entries.map((entry) {
        final c = entry.value;
        final color = _hex(c['color']);
        return BarChartGroupData(x: entry.key, barRods: [
          BarChartRodData(toY: (c['total'] as int).toDouble(), width: 28,
            gradient: LinearGradient(colors: [color.withOpacity(0.7), color],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true, toY: maxVal * 1.2, color: Colors.white.withOpacity(0.03))),
        ]);
      }).toList(),
    ));
  }

  // ════════════════════════ REUSABLE ════════════════════════

  Widget _section({required String title, required IconData icon, required Widget child}) {
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
      padding: EdgeInsets.all(mob ? 14 : 18),
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
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1))),
            const SizedBox(height: 4),
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
