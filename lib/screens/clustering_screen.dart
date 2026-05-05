import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../providers/settings_provider.dart';

class ClusteringScreen extends StatefulWidget {
  const ClusteringScreen({super.key});
  @override
  State<ClusteringScreen> createState() => _ClusteringScreenState();
}

class _ClusteringScreenState extends State<ClusteringScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  int? _selectedCluster;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
    final d = await DataService.loadClustering();
    setState(() {
      _data = d;
      _isLoading = false;
    });
    _animCtrl.forward();
  }

  // helpers
  Map<String, dynamic> get _stats => _data['stats'] ?? {};
  List get _clusters => _data['cluster_summary'] ?? [];
  List get _scatter => _data['scatter_sample'] ?? [];

  Color _hexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: mob ? 60 : 100,
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
                    vi ? 'Phân cụm Khách hàng' : 'Customer Clustering',
                    style: TextStyle(
                      fontSize: mob ? 19 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: mob,
                  titlePadding: EdgeInsets.only(
                    left: mob ? 0 : 24, 
                    bottom: mob ? 14 : 16
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
                    childAspectRatio: mob ? 0.95 : 1.6,
                  ),
                  delegate: SliverChildListDelegate([
                    _card(
                      label: vi ? 'Tổng khách hàng' : 'Total Customers',
                      value: '${_stats["total_customers"] ?? 0}',
                      sub: vi ? 'trong dataset' : 'in dataset',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                    _card(
                      label: 'Silhouette Score',
                      value: '${_stats["silhouette_score"] ?? 0}',
                      sub: vi ? 'Độ tách biệt cụm' : 'Cluster separation',
                      icon: Icons.hub_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    _card(
                      label: vi ? 'Cụm lớn nhất' : 'Largest Cluster',
                      value: vi ? '${_stats["biggest_cluster_vi"]}' : '${_stats["biggest_cluster_en"]}',
                      sub: '${_stats["biggest_count"]} ${vi ? "KH" : "customers"}',
                      icon: Icons.arrow_circle_up_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    _card(
                      label: vi ? 'Cụm nhỏ nhất' : 'Smallest Cluster',
                      value: vi ? '${_stats["smallest_cluster_vi"]}' : '${_stats["smallest_cluster_en"]}',
                      sub: '${_stats["smallest_count"]} ${vi ? "KH" : "customers"}',
                      icon: Icons.arrow_circle_down_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                  ]),
                ),
              ),

              // ── 2. Scatter Plot ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'Phân bố cụm (PCA 2D)' : 'Cluster Distribution (PCA 2D)',
                    icon: Icons.scatter_plot_rounded,
                    child: Column(children: [
                      SizedBox(
                        height: 350,
                        child: _buildZoomableChart(child: _buildScatterChart()),
                      ),
                      const SizedBox(height: 24),
                      _buildLegend(vi),
                    ]),
                  ),
                ),
              ),

              // ── 3. Cluster Detail Cards ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'Chi tiết các cụm' : 'Cluster Details',
                    icon: Icons.dashboard_customize_rounded,
                    actionWidget: _selectedCluster != null
                      ? GestureDetector(
                          onTap: () => setState(() => _selectedCluster = null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: Text(vi ? 'Bỏ chọn' : 'Deselect', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ))
                      : null,
                    child: Column(children: [
                      SizedBox(
                        height: mob ? 200 : 180,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          itemCount: _clusters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (ctx, i) => _buildClusterCard(i, vi, mob),
                        ),
                      ),
                      // Expanded detail panel
                      if (_selectedCluster != null && _selectedCluster! < _clusters.length)
                        _buildClusterDetail(_selectedCluster!, vi),
                    ]),
                  ),
                ),
              ),

              // ── 4. Bar Chart: avg basket size ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _section(
                    title: vi ? 'So sánh giỏ hàng TB theo cụm' : 'Avg Basket Size by Cluster',
                    icon: Icons.shopping_basket_rounded,
                    child: SizedBox(
                      height: 320, // Tăng chiều cao để render trục Y thoải mái
                      child: _buildZoomableChart(child: _buildBasketBar(vi)),
                    ),
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

  // ════════════════════════ CHART WRAPPER (ZOOM/PAN) ════════════════════════

  Widget _buildZoomableChart({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        boundaryMargin: const EdgeInsets.symmetric(horizontal: 20),
        panEnabled: true,
        scaleEnabled: true,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 10),
          child: child,
        ),
      ),
    );
  }

  // ════════════════════════ CHARTS ════════════════════════

  Widget _buildScatterChart() {
    // Highlight selected cluster by dimming others
    if (_scatter.isEmpty) return const SizedBox.shrink();

    // Tính giới hạn trục X Y để Grid vẽ đẹp hơn
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (var p in _scatter) {
      final x = (p['x'] as num).toDouble();
      final y = (p['y'] as num).toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // Nới rộng thêm 1 chút margin cho biểu đồ Scatter
    minX -= 1; maxX += 1;
    minY -= 1; maxY += 1;

    return ScatterChart(ScatterChartData(
      minX: minX, maxX: maxX,
      minY: minY, maxY: maxY,
      scatterSpots: _scatter.map<ScatterSpot>((p) {
        final cid = p['cluster'] as int;
        final baseColor = cid < _clusters.length ? _hexColor(_clusters[cid]['color']) : Colors.grey;
        final isSelected = _selectedCluster == null || _selectedCluster == cid;
        final color = isSelected ? baseColor : baseColor.withOpacity(0.15);
        final radius = (_selectedCluster == cid) ? 6.0 : 4.5;
        return ScatterSpot(
          (p['x'] as num).toDouble(),
          (p['y'] as num).toDouble(),
          dotPainter: FlDotCirclePainter(radius: radius, color: color.withOpacity(isSelected ? 0.85 : 0.15), strokeWidth: _selectedCluster == cid ? 1.5 : 0, strokeColor: baseColor),
        );
      }).toList(),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('Principal Component 1 (PC1)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          axisNameSize: 24,
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(v.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                );
              }
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Text('PC2', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          axisNameSize: 24,
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(v.toStringAsFixed(1), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                );
              }
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1, dashArray: [4,4]),
        getDrawingVerticalLine: (_) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1, dashArray: [4,4]),
      ),
      borderData: FlBorderData(
          show: true,
          border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
              left: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
              top: BorderSide.none, right: BorderSide.none
          )
      ),
      scatterTouchData: ScatterTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: ScatterTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItems: (spot) {
            return ScatterTooltipItem(
              'X: ${spot.x.toStringAsFixed(2)}\nY: ${spot.y.toStringAsFixed(2)}',
              textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
    ));
  }

  Widget _buildLegend(bool vi) {
    return Wrap(
      spacing: 20, runSpacing: 12,
      alignment: WrapAlignment.center,
      children: _clusters.map<Widget>((c) {
        final color = _hexColor(c['color']);
        final name = vi ? c['name_vi'] : c['name_en'];
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 13, color: Colors.grey.shade300, fontWeight: FontWeight.w600)),
        ]);
      }).toList(),
    );
  }

  Widget _buildClusterCard(int i, bool vi, bool mob) {
    final c = _clusters[i];
    final color = _hexColor(c['color']);
    final name = vi ? c['name_vi'] : c['name_en'];
    final topCat = vi ? c['top_category_vi'] : c['top_category_en'];
    final isSelected = _selectedCluster == i;

    return GestureDetector(
      onTap: () => setState(() => _selectedCluster = _selectedCluster == i ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: mob ? 220 : 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(isSelected ? 0.8 : 0.4), width: isSelected ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(isSelected ? 0.25 : 0.1), blurRadius: isSelected ? 24 : 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSelected ? 14 : 12, height: isSelected ? 14 : 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : [])),
              const SizedBox(width: 10),
              Expanded(child: Text(name,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: isSelected ? 15 : 14),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 18),
            ]),
            const SizedBox(height: 14),
            Text('${c["count"]} ${vi ? "KH" : "cust."} (${c["pct"]}%)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            _miniRow(Icons.repeat_rounded, vi ? 'TB giao dịch' : 'Avg txns', '${c["avg_transactions"]}'),
            const SizedBox(height: 6),
            _miniRow(Icons.shopping_basket_rounded, vi ? 'Giỏ hàng TB' : 'Avg basket', '${c["avg_basket"]}'),
            const SizedBox(height: 6),
            _miniRow(Icons.category_rounded, vi ? 'Danh mục top' : 'Top cat.', topCat),
          ],
        ),
      ),
    );
  }

  // ════════════════════════ CLUSTER DETAIL PANEL ════════════════════════

  Widget _buildClusterDetail(int i, bool vi) {
    final c = _clusters[i];
    final color = _hexColor(c['color']);
    final name = vi ? c['name_vi'] : c['name_en'];
    final topCat = vi ? c['top_category_vi'] : c['top_category_en'];
    final count = c['count'] as int;
    final pct = c['pct'];
    final avgTxn = c['avg_transactions'];
    final avgBasket = c['avg_basket'];
    final avgUnique = c['avg_unique_items'];

    // Compare to overall averages
    final allAvgTxn = _clusters.fold<double>(0, (s, x) => s + (x['avg_transactions'] as num)) / _clusters.length;
    final allAvgBasket = _clusters.fold<double>(0, (s, x) => s + (x['avg_basket'] as num)) / _clusters.length;

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4))),
              child: Icon(Icons.analytics_rounded, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 2),
              Text('$count ${vi ? "khách hàng" : "customers"} • $pct% ${vi ? "tổng" : "total"}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () => setState(() => _selectedCluster = null),
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close, color: Colors.grey.shade500, size: 16))),
          ]),
          const SizedBox(height: 20),
          // Metrics row
          Row(children: [
            _metricTile(vi ? 'TB Giao dịch' : 'Avg Txns', '$avgTxn', color, (avgTxn as num) > allAvgTxn),
            const SizedBox(width: 12),
            _metricTile(vi ? 'Giỏ hàng TB' : 'Avg Basket', '$avgBasket', color, (avgBasket as num) > allAvgBasket),
            const SizedBox(width: 12),
            _metricTile(vi ? 'SP đa dạng' : 'Unique Items', '$avgUnique', color, true),
            const SizedBox(width: 12),
            _metricTile(vi ? 'Danh mục top' : 'Top Category', topCat, color, null),
          ]),
          const SizedBox(height: 16),
          // Proportion bar
          Text(vi ? 'Tỷ lệ trong tổng KH' : 'Share of total customers',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 12, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6))),
              FractionallySizedBox(widthFactor: (pct as num) / 100,
                child: Container(height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.6), color]),
                    borderRadius: BorderRadius.circular(6)))),
            ])),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight,
            child: Text('$pct%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color, bool? isAboveAvg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (isAboveAvg != null)
              Icon(isAboveAvg ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 12, color: isAboveAvg ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          ]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }

  Widget _miniRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildBasketBar(bool vi) {
    if (_clusters.isEmpty) return const SizedBox.shrink();
    final maxVal = _clusters.map((c) => (c['avg_basket'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.3,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              r.toY.toStringAsFixed(2),
              const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxVal / 4 > 0 ? maxVal / 4 : 1,
        getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.08), strokeWidth: 1, dashArray: [4, 4]),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 45, // Tăng size cho chữ dài
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= _clusters.length) return const SizedBox.shrink();
            final name = vi ? _clusters[i]['name_vi'] : _clusters[i]['name_en'];

            // Xử lý xuống dòng cho tên cụm nếu quá dài
            return Padding(padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: 80,
                  child: Text(name, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ));
          },
        )),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 40,
            interval: maxVal / 4 > 0 ? maxVal / 4 : 1,
            getTitlesWidget: (v, _) {
              if (v == 0) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(right: 8),
                  child: Text(v.toStringAsFixed(1), textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)));
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
          left: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
          top: BorderSide.none, right: BorderSide.none,
        ),
      ),
      barGroups: _clusters.asMap().entries.map((entry) {
        final c = entry.value;
        final color = _hexColor(c['color']);
        return BarChartGroupData(x: entry.key, barRods: [
          BarChartRodData(
            toY: (c['avg_basket'] as num).toDouble(), width: 32, // Thanh to hơn xíu
            gradient: LinearGradient(
                colors: [color.withOpacity(0.7), color],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
                show: true, toY: maxVal * 1.3, color: Colors.white.withOpacity(0.04)),
          ),
        ]);
      }).toList(),
    ));
  }

  // ════════════════════════ REUSABLE WIDGETS ════════════════════════

  Widget _section({required String title, required IconData icon, Widget? actionWidget, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: Colors.grey.shade300),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.95), letterSpacing: 0.3)),
                ),
              ]),
            ),
            if (actionWidget != null) actionWidget,
          ],
        ),
        const SizedBox(height: 24),
        child,
      ]),
    );
  }

  Widget _card({required String label, required String value, required String sub,
    required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor.withOpacity(0.8), Theme.of(context).cardColor.withOpacity(0.4)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5), width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown,
                  child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.5, height: 1))),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}