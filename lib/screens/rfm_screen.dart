import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';
import '../models/rfm_model.dart';

class RFMScreen extends StatefulWidget {
  RFMScreen({Key? key}) : super(key: key);

  @override
  State<RFMScreen> createState() => _RFMScreenState();
}

class _RFMScreenState extends State<RFMScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<RFMSegment> _segments = [];
  List<CustomerRFM> _topCustomers = [];
  Map<String, dynamic> _stats = {};

  // Filter state
  String? _selectedSegment; // null = show all
  int? _touchedPieIndex;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await DataService.loadRFM();
    if (data.isNotEmpty) {
      final segmentsData = data['segments'] as List;
      _segments = segmentsData.map((e) => RFMSegment(
        name: e['name'],
        count: e['count'],
        pct: e['pct'].toDouble(),
        color: RFMSegment.getColorForSegment(e['name']),
      )).toList();

      // Sort segments by count descending
      _segments.sort((a, b) => b.count.compareTo(a.count));

      final topCustomersData = data['top_customers'] as List;
      _topCustomers = topCustomersData.map((e) => CustomerRFM(
        memberId: e['member_id'],
        r: e['r'],
        f: e['f'],
        m: e['m'],
        score: e['score'],
        segment: e['segment'],
      )).toList();

      _stats = data['stats'];
    }

    setState(() => _isLoading = false);
    _fadeController.forward();
  }

  List<CustomerRFM> get _filteredCustomers {
    if (_selectedSegment == null) {
      // For "All", show only the global top 10
      return _topCustomers.take(10).toList();
    }
    // For specific segment, show all available (we exported top 5 for each)
    return _topCustomers.where((c) => c.segment == _selectedSegment).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;
    final totalCustomers = (_stats['total_customers'] ?? 1) as int;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  settings.isVietnamese ? 'Phân tích RFM Khách hàng' : 'Customer RFM Analysis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
            ),

            // ── Stat Cards (4) ───────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isMobile ? 1.1 : 2.0,
                ),
            delegate: SliverChildListDelegate([
                  _buildStatCard(
                    label: _selectedSegment ?? (settings.isVietnamese ? 'Tổng khách hàng' : 'Total Customers'),
                    value: '${_selectedSegment != null ? _segments.firstWhere((s) => s.name == _selectedSegment).count : (_stats["total_customers"] ?? 0)}',
                    subtitle: _selectedSegment == null 
                        ? (settings.isVietnamese ? 'Trong dataset' : 'In dataset')
                        : (settings.isVietnamese ? 'Thuộc nhóm này' : 'In this segment'),
                    icon: Icons.people_rounded,
                    color: _selectedSegment != null ? _segments.firstWhere((s) => s.name == _selectedSegment).color : Colors.blue,
                  ),
                  _buildStatCard(
                    label: 'Champions',
                    value: '${_stats["champions_count"] ?? 0}',
                    subtitle: '${((_stats["champions_count"] ?? 0) / totalCustomers * 100).toStringAsFixed(1)}% ${settings.isVietnamese ? "tổng KH" : "of total"}',
                    icon: Icons.star_rounded,
                    color: const Color(0xFF7F77DD),
                  ),
                  _buildStatCard(
                    label: settings.isVietnamese ? 'Cần giữ' : 'At Risk',
                    value: '${_stats["at_risk_count"] ?? 0}',
                    subtitle: '${((_stats["at_risk_count"] ?? 0) / totalCustomers * 100).toStringAsFixed(1)}% ${settings.isVietnamese ? "cần tái kích hoạt" : "need reactivation"}',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFD85A30),
                  ),
                  _buildStatCard(
                    label: settings.isVietnamese ? 'Tần suất TB' : 'Avg Frequency',
                    value: '${_stats["avg_frequency"] ?? 0}',
                    subtitle: settings.isVietnamese ? 'lần mua / khách' : 'purchases / customer',
                    icon: Icons.repeat_rounded,
                    color: const Color(0xFF1D9E75),
                  ),
                ]),
              ),
            ),

            // ── Donut + Segment Bar Chart ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _buildSectionCard(
                  title: settings.isVietnamese ? 'Phân bố nhóm khách hàng' : 'Segment Distribution',
                  child: isMobile
                      ? Column(children: [
                          SizedBox(height: 200, child: _buildDonut()),
                          const SizedBox(height: 20),
                          _buildSegmentBars(totalCustomers),
                        ])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 220, height: 260, child: _buildDonut()),
                            const SizedBox(width: 32),
                            Expanded(child: _buildSegmentBars(totalCustomers)),
                          ],
                        ),
                ),
              ),
            ),

            // ── Insight panel (shown when segment selected on donut) ──
            if (_touchedPieIndex != null && _touchedPieIndex! >= 0 && _touchedPieIndex! < _segments.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _buildInsightPanel(_segments[_touchedPieIndex!], settings),
                ),
              ),

            // ── Chip filters ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedSegment == null 
                        ? (settings.isVietnamese ? 'Top 10 khách hàng VIP' : 'Top 10 VIP Customers')
                        : (settings.isVietnamese ? 'Top khách hàng ${_selectedSegment}' : 'Top ${_selectedSegment} Customers'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: settings.isVietnamese ? 'Tất cả' : 'All',
                            isSelected: _selectedSegment == null,
                            color: Colors.white,
                            onTap: () => setState(() => _selectedSegment = null),
                          ),
                          const SizedBox(width: 8),
                          ..._segments.map((seg) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(
                              label: seg.name,
                              isSelected: _selectedSegment == seg.name,
                              color: seg.color,
                              onTap: () => setState(() =>
                                _selectedSegment = _selectedSegment == seg.name ? null : seg.name,
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Customer List ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildSectionCard(
                  title: '',
                  showTitle: false,
                  child: _filteredCustomers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              settings.isVietnamese
                                  ? 'Không có khách hàng trong nhóm này'
                                  : 'No customers in this segment',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredCustomers.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: Colors.white.withOpacity(0.05), height: 1),
                          itemBuilder: (context, index) =>
                              _buildCustomerRow(_filteredCustomers[index], index),
                        ),
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  // ── DONUT CHART ────────────────────────────────────────────────
  Widget _buildDonut() {
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 52,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (response?.touchedSection != null && response!.touchedSection!.touchedSectionIndex >= 0) {
                _touchedPieIndex = response.touchedSection!.touchedSectionIndex;
              } else {
                _touchedPieIndex = null;
              }
            });
          },
        ),
        sections: _segments.asMap().entries.map((entry) {
          final i = entry.key;
          final seg = entry.value;
          final isTouched = _touchedPieIndex == i;
          return PieChartSectionData(
            color: seg.color,
            value: seg.pct,
            title: isTouched ? '${seg.pct.toStringAsFixed(1)}%' : '',
            radius: isTouched ? 68 : 58,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SEGMENT HORIZONTAL BAR CHART ──────────────────────────────
  Widget _buildSegmentBars(int totalCustomers) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final maxCount = _segments.isNotEmpty
        ? _segments.map((s) => s.count).reduce((a, b) => a > b ? a : b)
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _segments.map((seg) {
        final barFraction = seg.count / maxCount;
        final isSelected = _selectedSegment == seg.name;
        return GestureDetector(
          onTap: () => setState(() =>
            _selectedSegment = _selectedSegment == seg.name ? null : seg.name,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? seg.color.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: seg.color.withOpacity(0.3))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                // Segment name
                SizedBox(
                  width: isMobile ? 100 : 130,
                  child: Text(
                    seg.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? seg.color : Colors.grey,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                // Bar
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barFraction,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: seg.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Count + pct
                SizedBox(
                  width: 72,
                  child: Text(
                    '${seg.count}  ${seg.pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : Colors.grey,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── INSIGHT PANEL ──────────────────────────────────────────────
  Widget _buildInsightPanel(RFMSegment seg, SettingsProvider settings) {
    final insights = _getInsight(seg.name, settings.isVietnamese);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: seg.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: seg.color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: seg.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(insights['icon'] as IconData, color: seg.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seg.name,
                  style: TextStyle(
                    color: seg.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insights['text'] as String,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _touchedPieIndex = null),
            child: Icon(Icons.close, color: Colors.grey, size: 18),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getInsight(String segment, bool isVi) {
    final insights = {
      'Khách hàng tinh hoa': {
        'icon': Icons.star_rounded,
        'text': isVi
            ? 'Khách mua thường xuyên & gần đây nhất. Tặng ưu đãi độc quyền, mời thử sản phẩm mới trước. Đây là nhóm mang lại doanh thu lớn nhất.'
            : 'Most frequent & recent buyers. Reward with exclusive offers, early access to new products. Highest revenue contributors.',
      },
      'Khách hàng thân thiết': {
        'icon': Icons.favorite_rounded,
        'text': isVi
            ? 'Mua đều đặn nhưng chưa chi nhiều nhất. Gợi ý cross-sell, bundle deal để tăng giá trị giỏ hàng.'
            : 'Regular buyers but not top spenders. Suggest cross-sell and bundle deals to increase basket value.',
      },
      'Khách hàng tiềm năng': {
        'icon': Icons.trending_up_rounded,
        'text': isVi
            ? 'Mới mua gần đây nhưng ít lần. Nuôi dưỡng bằng coupon lần mua thứ 2, chương trình tích điểm để tạo thói quen.'
            : 'Recent buyers with low frequency. Nurture with 2nd-purchase coupons and loyalty programs to build habits.',
      },
      'Khách hàng mới': {
        'icon': Icons.waving_hand_rounded,
        'text': isVi
            ? 'Vừa mua lần đầu. Onboard kỹ ngay lúc này — hướng dẫn sản phẩm, tặng voucher lần kế tiếp để chuyển thành loyal.'
            : 'First-time buyers. Onboard now — product guides and a next-purchase voucher can convert them to loyal.',
      },
      'Khách hàng rủi ro': {
        'icon': Icons.warning_amber_rounded,
        'text': isVi
            ? 'Từng là khách tốt nhưng đang xa dần. Gửi email "Chúng tôi nhớ bạn" + ưu đãi mạnh ngay trong tuần này.'
            : 'Previously good customers drifting away. Send "We miss you" + strong offer this week before they\'re gone.',
      },
      'Khách hàng ngủ đông': {
        'icon': Icons.bedtime_rounded,
        'text': isVi
            ? 'Đã lâu không mua. Chi phí tái kích hoạt cao — chỉ nên chạy win-back campaign với ưu đãi rất lớn hoặc bỏ qua nhóm này.'
            : 'Long inactive. High reactivation cost — only run win-back with very large incentives, or deprioritize.',
      },
    };
    return insights[segment] ?? {
      'icon': Icons.info_outline,
      'text': isVi ? 'Phân tích nhóm khác.' : 'Other segment.',
    };
  }

  // ── CUSTOMER ROW ───────────────────────────────────────────────
  Widget _buildCustomerRow(CustomerRFM cust, int index) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final segColor = RFMSegment.getColorForSegment(cust.segment);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: segColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: segColor.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  color: segColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Member info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member ${cust.memberId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _buildRFMBadge('R', cust.r, const Color(0xFF378ADD)),
                    const SizedBox(width: 6),
                    _buildRFMBadge('F', cust.f, const Color(0xFF1D9E75)),
                    const SizedBox(width: 6),
                    _buildRFMBadge('M', cust.m, const Color(0xFFBA7517)),
                  ],
                ),
              ],
            ),
          ),
          // Score + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: isMobile ? 100 : 140),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: segColor.withOpacity(0.15),
                  border: Border.all(color: segColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cust.segment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: segColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                cust.score,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FILTER CHIP ────────────────────────────────────────────────
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.6) : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── STAT CARD ──────────────────────────────────────────────────
  Widget _buildStatCard({
    required String label,
    required String value,
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
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
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

  // ── RFM BADGE ──────────────────────────────────────────────────
  Widget _buildRFMBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$label:$value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // ── SECTION CARD ───────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required Widget child,
    bool showTitle = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}