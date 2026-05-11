import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

// ═══════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════

class _AlgoInfo {
  final String id, nameEn, nameVi, categoryEn, categoryVi, descEn, descVi;
  final IconData icon;
  final Color color;
  const _AlgoInfo({
    required this.id,
    required this.nameEn, required this.nameVi,
    required this.categoryEn, required this.categoryVi,
    required this.descEn, required this.descVi,
    required this.icon, required this.color,
  });
}

const _algos = [
  _AlgoInfo(
    id: 'fpgrowth',
    nameEn: 'FP-Growth', nameVi: 'FP-Growth',
    categoryEn: 'Association Rule Mining', categoryVi: 'Khai thác luật kết hợp',
    descEn: 'Finds item relationships by compressing transactions into a prefix tree — no candidate generation needed.',
    descVi: 'Tìm mối liên hệ giữa sản phẩm bằng cách nén giao dịch vào cây tiền tố — không cần sinh ứng viên.',
    icon: Icons.hub_rounded, color: Color(0xFF3B82F6),
  ),
  _AlgoInfo(
    id: 'kmeans',
    nameEn: 'K-Means Clustering', nameVi: 'K-Means Clustering',
    categoryEn: 'Unsupervised Clustering', categoryVi: 'Phân cụm không giám sát',
    descEn: 'Partitions customers into K groups by iteratively minimising distance to cluster centroids.',
    descVi: 'Phân khách hàng thành K nhóm bằng cách lặp lại tối thiểu hoá khoảng cách tới tâm cụm.',
    icon: Icons.groups_rounded, color: Color(0xFFF59E0B),
  ),
  _AlgoInfo(
    id: 'prophet',
    nameEn: 'Prophet Forecasting', nameVi: 'Dự báo Prophet',
    categoryEn: 'Time-Series Forecasting', categoryVi: 'Dự báo chuỗi thời gian',
    descEn: "Facebook's additive model decomposes revenue into trend + seasonality + holidays to forecast future sales.",
    descVi: 'Mô hình cộng tính của Facebook phân tích doanh thu thành xu hướng + mùa vụ + lễ tết để dự báo.',
    icon: Icons.trending_up_rounded, color: Color(0xFF8B5CF6),
  ),
  _AlgoInfo(
    id: 'rfm',
    nameEn: 'RFM Analysis', nameVi: 'Phân tích RFM',
    categoryEn: 'Customer Segmentation', categoryVi: 'Phân khúc khách hàng',
    descEn: 'Scores every customer on Recency, Frequency and Monetary value to identify VIPs, dormant, and churn-risk.',
    descVi: 'Chấm điểm khách hàng theo Recency, Frequency, Monetary để nhận ra VIP, ngủ đông và sắp rời bỏ.',
    icon: Icons.assignment_ind_rounded, color: Color(0xFF10B981),
  ),
];

// ═══════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════

class AlgorithmScreen extends StatefulWidget {
  const AlgorithmScreen({super.key});
  @override
  State<AlgorithmScreen> createState() => _AlgorithmScreenState();
}

class _AlgorithmScreenState extends State<AlgorithmScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedId = 'fpgrowth';
  int _detailStep = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _AlgoInfo get _selected =>
      _algos.firstWhere((a) => a.id == _selectedId);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.isVietnamese ? 'Thư viện Thuật toán' : 'Algorithm Lab'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: settings.isVietnamese ? 'Thư viện' : 'Library'),
            Tab(text: settings.isVietnamese ? 'Giải thích' : 'Deep Dive'),
            Tab(text: settings.isVietnamese ? 'So sánh' : 'Comparison'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LibraryTab(
            selected: _selectedId,
            onSelect: (id) {
              setState(() { _selectedId = id; _detailStep = 0; });
              _tabController.animateTo(1);
            },
            settings: settings,
          ),
          _DetailTab(
            key: ValueKey(_selectedId),
            algo: _selected,
            settings: settings,
            isMobile: isMobile,
          ),
          _ComparisonTab(settings: settings),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 1: LIBRARY
// ═══════════════════════════════════════════════════════

class _LibraryTab extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final SettingsProvider settings;
  const _LibraryTab({required this.selected, required this.onSelect, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            settings.isVietnamese
                ? 'Chọn thuật toán để xem giải thích chi tiết'
                : 'Select an algorithm to explore its mechanics',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ),
        ..._algos.map((a) => _AlgoCard(
          algo: a, isSelected: selected == a.id,
          onTap: () => onSelect(a.id),
          settings: settings,
        )),
      ],
    );
  }
}

class _AlgoCard extends StatelessWidget {
  final _AlgoInfo algo;
  final bool isSelected;
  final VoidCallback onTap;
  final SettingsProvider settings;
  const _AlgoCard({required this.algo, required this.isSelected, required this.onTap, required this.settings});

  @override
  Widget build(BuildContext context) {
    final c = algo.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.12) : c.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c : c.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: c.withOpacity(0.2), blurRadius: 16, spreadRadius: 0)]
              : [],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(algo.icon, color: c, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(settings.isVietnamese ? algo.nameVi : algo.nameEn,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 3),
              Text(settings.isVietnamese ? algo.categoryVi : algo.categoryEn,
                  style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(settings.isVietnamese ? algo.descVi : algo.descEn,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4)),
            ],
          )),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: isSelected ? c : Colors.white24, size: 14),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 2: DETAIL
// ═══════════════════════════════════════════════════════

class _DetailTab extends StatefulWidget {
  final _AlgoInfo algo;
  final SettingsProvider settings;
  final bool isMobile;
  const _DetailTab({super.key, required this.algo, required this.settings, required this.isMobile});
  @override
  State<_DetailTab> createState() => _DetailTabState();
}

class _DetailTabState extends State<_DetailTab> {
  int _step = 0;

  List<_StepData> get _steps {
    final vi = widget.settings.isVietnamese;
    switch (widget.algo.id) {
      case 'fpgrowth': return _fpGrowthSteps(vi);
      case 'kmeans':   return _kmeansSteps(vi);
      case 'prophet':  return _prophetSteps(vi);
      case 'rfm':      return _rfmSteps(vi);
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    if (steps.isEmpty) return const Center(child: Text('Coming soon'));
    final c = widget.algo.color;
    final s = steps[_step];

    return Column(children: [
      // step indicator pills
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: List.generate(steps.length, (i) {
          final active = i == _step;
          final done   = i < _step;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _step = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              margin: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
              decoration: BoxDecoration(
                color: done || active ? c : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ));
        })),
      ),
      // step label
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withOpacity(0.4)),
            ),
            child: Text(
              '${widget.settings.isVietnamese ? "Bước" : "Step"} ${_step + 1}/${steps.length}',
              style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Text(s.desc,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.5)),
      ),
      // visualizer
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withOpacity(0.25)),
            ),
            child: s.vizBuilder(context),
          ),
        ),
      ),
      // prev / next
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text(widget.settings.isVietnamese ? 'Trước' : 'Prev'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          if (_step < steps.length - 1)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _step++),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(widget.settings.isVietnamese ? 'Tiếp theo' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _StepData {
  final String title, desc;
  final Widget Function(BuildContext) vizBuilder;
  const _StepData({required this.title, required this.desc, required this.vizBuilder});
}

// ═══════════════════════════════════════════════════════
//  FP-GROWTH STEPS
// ═══════════════════════════════════════════════════════

List<_StepData> _fpGrowthSteps(bool vi) => [
  _StepData(
    title: vi ? 'Bước 1 — Dữ liệu giao dịch gốc' : 'Step 1 — Raw transactions',
    desc: vi
        ? 'Mỗi giao dịch là một giỏ hàng. Đặt mức Support tối thiểu = 2 (xuất hiện ≥ 2 lần).'
        : 'Each transaction is a basket. We set minimum support = 2 (appears ≥ 2 times).',
    vizBuilder: (_) => const _FpStep1(),
  ),
  _StepData(
    title: vi ? 'Bước 2 — Đếm & lọc item thường xuyên' : 'Step 2 — Count & filter frequent items',
    desc: vi
        ? 'Đếm tần suất từng item, loại bỏ item < min_support. Sắp xếp giảm dần theo tần suất.'
        : 'Count each item, drop those below min_support. Sort descending by frequency.',
    vizBuilder: (_) => const _FpStep2(),
  ),
  _StepData(
    title: vi ? 'Bước 3 — Xây dựng FP-Tree' : 'Step 3 — Build the FP-Tree',
    desc: vi
        ? 'Chèn từng giao dịch đã sắp xếp vào cây. Các tiền tố chung được chia sẻ, số đếm cộng dồn.'
        : 'Insert each sorted transaction into the tree. Shared prefixes are merged, counts accumulated.',
    vizBuilder: (_) => const _FpStep3(),
  ),
  _StepData(
    title: vi ? 'Bước 4 — Khai thác luật kết hợp' : 'Step 4 — Mine association rules',
    desc: vi
        ? 'Duyệt cây từ lá lên gốc, tính Support & Confidence cho từng tập phổ biến tìm được.'
        : 'Traverse bottom-up, compute Support & Confidence for each frequent itemset found.',
    vizBuilder: (_) => const _FpStep4(),
  ),
];

// --- FP viz widgets ---

class _FpStep1 extends StatelessWidget {
  const _FpStep1();
  @override
  Widget build(BuildContext context) {
    final txns = [
      ['Sữa', 'Bánh mì', 'Trứng', 'Bơ'],
      ['Sữa', 'Trứng'],
      ['Bánh mì', 'Trứng', 'Bơ'],
      ['Sữa', 'Bánh mì', 'Trứng'],
      ['Bánh mì', 'Bơ'],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...txns.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: Text('T${e.key + 1}',
                style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Wrap(spacing: 6, children: e.value.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Text(item, style: const TextStyle(fontSize: 11, color: Colors.white)),
          )).toList()),
        ]),
      )),
      const Divider(color: Colors.white10, height: 20),
      Text('Min Support = 2  →  item cần xuất hiện ≥ 2 lần',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }
}

class _FpStep2 extends StatelessWidget {
  const _FpStep2();
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Bánh mì', 4, true),
      ('Trứng',   4, true),
      ('Sữa',     3, true),
      ('Bơ',      3, true),
      ('Phô mai', 1, false),
    ];
    return Column(children: [
      // bar chart
      ...items.map((it) {
        final pct = it.$2 / 5;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(
              width: 72,
              child: Text(it.$1,
                  style: TextStyle(
                      fontSize: 12,
                      color: it.$3 ? Colors.white : Colors.grey.shade600,
                      fontWeight: it.$3 ? FontWeight.w500 : FontWeight.normal)),
            ),
            Expanded(
              child: Stack(children: [
                Container(height: 20, decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                )),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: it.$3 ? AppTheme.primaryColor.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 24, child: Text('${it.$2}',
                style: TextStyle(
                    fontSize: 12,
                    color: it.$3 ? AppTheme.primaryColor : Colors.grey.shade600))),
            Icon(
              it.$3 ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: it.$3 ? Colors.greenAccent : Colors.redAccent.withOpacity(0.6),
            ),
          ]),
        );
      }),
      const Divider(color: Colors.white10, height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statChip('Frequent', '4', Colors.greenAccent),
        _statChip('Dropped', '1', Colors.redAccent),
        _statChip('Order', 'Bánh > Trứng > Sữa > Bơ', Colors.amber),
      ]),
    ]);
  }

  Widget _statChip(String label, String val, Color c) {
    return Column(children: [
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]);
  }
}

class _FpStep3 extends StatelessWidget {
  const _FpStep3();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 200,
        child: CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _FpTreePainter(),
        ),
      ),
      const Divider(color: Colors.white10, height: 20),
      Wrap(spacing: 12, runSpacing: 8, children: [
        _legend('Null (root)', Colors.grey),
        _legend('Bánh mì :4', const Color(0xFF3B82F6)),
        _legend('Trứng :4', const Color(0xFF8B5CF6)),
        _legend('Sữa :3', const Color(0xFF10B981)),
        _legend('Bơ :3', const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 8),
      Text('Các tiền tố chung được gộp — cây chỉ cần 2 lần quét DB',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  Widget _legend(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(t, style: const TextStyle(fontSize: 10, color: Colors.white70)),
  ]);
}

class _FpTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    void drawNode(Offset o, String label, Color c, double r) {
      canvas.drawCircle(o, r, Paint()..color = c.withOpacity(0.25));
      canvas.drawCircle(o, r, Paint()..color = c..strokeWidth = 1.5..style = PaintingStyle.stroke);
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    void drawEdge(Offset a, Offset b) {
      canvas.drawLine(a, b, Paint()..color = Colors.white.withOpacity(0.15)..strokeWidth = 1);
    }

    // positions
    final root   = Offset(cx, 20);
    final banhMi = Offset(cx - 80, 70);  // Bánh mì:4
    final trung1 = Offset(cx - 120, 130); // Trứng:3 (child of Bánh mì)
    final sua1   = Offset(cx - 155, 180); // Sữa:2
    final bo1    = Offset(cx - 85, 180);  // Bơ:2
    final sua2   = Offset(cx - 45, 130);  // Sữa:1 (direct child of Bánh mì)
    final trung2 = Offset(cx + 60, 70);  // Trứng:1 (root child)
    final sua3   = Offset(cx + 100, 130); // Sữa:1
    final bo2    = Offset(cx + 120, 70);  // Bơ (separate)

    // edges
    drawEdge(root,   banhMi);
    drawEdge(banhMi, trung1);
    drawEdge(trung1, sua1);
    drawEdge(trung1, bo1);
    drawEdge(banhMi, sua2);
    drawEdge(root,   trung2);
    drawEdge(trung2, sua3);
    drawEdge(root,   bo2);

    // nodes
    drawNode(root,   'null',   Colors.grey,                    12);
    drawNode(banhMi, 'B:4',    const Color(0xFF3B82F6),        16);
    drawNode(trung1, 'T:3',    const Color(0xFF8B5CF6),        14);
    drawNode(sua1,   'S:2',    const Color(0xFF10B981),        12);
    drawNode(bo1,    'Bơ:2',   const Color(0xFFF59E0B),        12);
    drawNode(sua2,   'S:1',    const Color(0xFF10B981),        10);
    drawNode(trung2, 'T:1',    const Color(0xFF8B5CF6),        10);
    drawNode(sua3,   'S:1',    const Color(0xFF10B981),        10);
    drawNode(bo2,    'Bơ:1',   const Color(0xFFF59E0B),        10);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _FpStep4 extends StatelessWidget {
  const _FpStep4();

  static const _rules = [
    ('Bánh mì → Trứng',   '80%', '100%', '1.25'),
    ('Trứng → Bánh mì',   '80%', '100%', '1.25'),
    ('Trứng, Sữa → Bánh mì', '40%', '100%', '1.25'),
    ('Bơ → Bánh mì',      '60%',  '75%', '0.94'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(),
      const SizedBox(height: 10),
      ..._rules.map((r) => _ruleRow(r.$1, r.$2, r.$3, r.$4)),
      const Divider(color: Colors.white10, height: 20),
      Wrap(spacing: 16, children: [
        _kpi('Conf > 75%', '3 rules', Colors.greenAccent),
        _kpi('Lift > 1.0',  '3 rules', const Color(0xFF3B82F6)),
        _kpi('Top Rule', 'Bánh → Trứng', Colors.amber),
      ]),
    ]);
  }

  Widget _header() => Row(children: [
    for (final h in ['Rule', 'Support', 'Confidence', 'Lift'])
      Expanded(child: Text(h,
          style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600))),
  ]);

  Widget _ruleRow(String rule, String sup, String conf, String lift) {
    final confVal = double.parse(conf.replaceAll('%', '')) / 100;
    final isGood  = double.parse(lift) >= 1.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isGood ? Colors.green.withOpacity(0.07) : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isGood ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rule, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Support', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            Text(sup, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Confidence', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            Row(children: [
              Expanded(child: LinearProgressIndicator(
                value: confVal,
                backgroundColor: Colors.white.withOpacity(0.08),
                color: Colors.greenAccent,
                minHeight: 3,
              )),
              const SizedBox(width: 6),
              Text(conf, style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
            ]),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isGood ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Lift $lift',
                style: TextStyle(fontSize: 10, color: isGood ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }

  Widget _kpi(String label, String val, Color c) => Column(children: [
    Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
  ]);
}

// ═══════════════════════════════════════════════════════
//  K-MEANS STEPS
// ═══════════════════════════════════════════════════════

List<_StepData> _kmeansSteps(bool vi) => [
  _StepData(
    title: vi ? 'Bước 1 — Dữ liệu khách hàng (RFM scatter)' : 'Step 1 — Customer data (RFM scatter)',
    desc: vi
        ? 'Mỗi điểm = một khách hàng, vị trí dựa trên Frequency (trục X) và Monetary (trục Y).'
        : 'Each dot = one customer, position based on Frequency (x-axis) and Monetary (y-axis).',
    vizBuilder: (_) => const _KMeansScatter(step: 0),
  ),
  _StepData(
    title: vi ? 'Bước 2 — Khởi tạo K=3 tâm cụm ngẫu nhiên' : 'Step 2 — Initialise K=3 random centroids',
    desc: vi
        ? 'Chọn ngẫu nhiên 3 điểm làm tâm ban đầu. Chất lượng khởi tạo ảnh hưởng tốc độ hội tụ.'
        : 'Pick 3 random points as initial centroids. Initialisation quality affects convergence speed.',
    vizBuilder: (_) => const _KMeansScatter(step: 1),
  ),
  _StepData(
    title: vi ? 'Bước 3 — Gán điểm vào tâm gần nhất' : 'Step 3 — Assign points to nearest centroid',
    desc: vi
        ? 'Khoảng cách Euclidean: d = √((x₂-x₁)² + (y₂-y₁)²). Mỗi điểm nhận màu của tâm gần nhất.'
        : 'Euclidean distance: d = √((x₂-x₁)² + (y₂-y₁)²). Each point gets the nearest centroid\'s color.',
    vizBuilder: (_) => const _KMeansScatter(step: 2),
  ),
  _StepData(
    title: vi ? 'Bước 4 — Tính lại tâm cụm mới' : 'Step 4 — Recompute centroids',
    desc: vi
        ? 'Tâm mới = trung bình cộng toàn bộ điểm trong cụm. Lặp lại bước 3-4 đến khi tâm không đổi.'
        : 'New centroid = mean of all points in the cluster. Repeat steps 3-4 until centroids stop moving.',
    vizBuilder: (_) => const _KMeansScatter(step: 3),
  ),
  _StepData(
    title: vi ? 'Bước 5 — Kết quả: 3 phân khúc khách hàng' : 'Step 5 — Result: 3 customer segments',
    desc: vi
        ? 'VIP (Monetary cao), Growth (tần suất tăng), Dormant (ít mua). Dùng để cá nhân hoá marketing.'
        : 'VIP (high monetary), Growth (rising frequency), Dormant (infrequent). Used for personalised marketing.',
    vizBuilder: (_) => const _KMeansFinal(),
  ),
];

// K-Means data
final _kPoints = [
  // cluster A — VIP — top right
  (0.75, 0.82), (0.80, 0.90), (0.70, 0.75), (0.85, 0.88), (0.78, 0.70),
  // cluster B — Growth — mid
  (0.45, 0.50), (0.50, 0.55), (0.42, 0.60), (0.55, 0.48), (0.48, 0.65),
  // cluster C — Dormant — bottom left
  (0.15, 0.20), (0.20, 0.15), (0.12, 0.30), (0.25, 0.18), (0.18, 0.25),
];

const _centroids0 = [(0.50, 0.50), (0.60, 0.60), (0.40, 0.40)]; // initial random
const _centroids1 = [(0.78, 0.81), (0.48, 0.56), (0.18, 0.22)]; // final

int _nearestStep3(double x, double y) {
  final dists = _centroids0.map((c) => math.sqrt(math.pow(x - c.$1, 2) + math.pow(y - c.$2, 2))).toList();
  return dists.indexOf(dists.reduce(math.min));
}

int _nearestFinal(double x, double y) {
  final dists = _centroids1.map((c) => math.sqrt(math.pow(x - c.$1, 2) + math.pow(y - c.$2, 2))).toList();
  return dists.indexOf(dists.reduce(math.min));
}

class _KMeansScatter extends StatelessWidget {
  final int step;
  const _KMeansScatter({required this.step});

  static const _clusterColors = [
    Color(0xFF10B981), // VIP green
    Color(0xFF3B82F6), // Growth blue
    Color(0xFFF59E0B), // Dormant amber
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 220,
        child: CustomPaint(
          size: const Size(double.infinity, 220),
          painter: _ScatterPainter(step: step, clusterColors: _clusterColors),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _axLabel('Frequency →', false),
        const SizedBox(width: 20),
        _axLabel('↑ Monetary', true),
      ]),
      if (step >= 1) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < 3; i++) ...[
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: _clusterColors[i], shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5))),
              const SizedBox(width: 4),
              Text(['VIP', 'Growth', 'Dormant'][i],
                  style: TextStyle(fontSize: 10, color: _clusterColors[i])),
            ]),
            if (i < 2) const SizedBox(width: 16),
          ],
        ]),
      ],
    ]);
  }

  Widget _axLabel(String t, bool vertical) => Text(t,
      style: TextStyle(fontSize: 10, color: Colors.grey.shade600));
}

class _ScatterPainter extends CustomPainter {
  final int step;
  final List<Color> clusterColors;
  const _ScatterPainter({required this.step, required this.clusterColors});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 30.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    Offset toCanvas(double x, double y) => Offset(pad + x * w, pad + (1 - y) * h);

    // axes
    final axisPaint = Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5;
    canvas.drawLine(Offset(pad, pad), Offset(pad, pad + h), axisPaint);
    canvas.drawLine(Offset(pad, pad + h), Offset(pad + w, pad + h), axisPaint);

    // grid
    for (int i = 1; i < 5; i++) {
      canvas.drawLine(Offset(pad, pad + h * i / 5), Offset(pad + w, pad + h * i / 5),
          Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5);
      canvas.drawLine(Offset(pad + w * i / 5, pad), Offset(pad + w * i / 5, pad + h),
          Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5);
    }

    // points
    for (int i = 0; i < _kPoints.length; i++) {
      final p = _kPoints[i];
      Color c;
      if (step == 0 || step == 1) {
        c = Colors.white.withOpacity(0.5);
      } else if (step == 2) {
        c = clusterColors[_nearestStep3(p.$1, p.$2)].withOpacity(0.85);
      } else {
        c = clusterColors[_nearestFinal(p.$1, p.$2)].withOpacity(0.85);
      }
      canvas.drawCircle(toCanvas(p.$1, p.$2), 5, Paint()..color = c);
    }

    // centroids
    if (step >= 1) {
      final centroids = step >= 3 ? _centroids1 : _centroids0;
      for (int i = 0; i < centroids.length; i++) {
        final o = toCanvas(centroids[i].$1, centroids[i].$2);
        // cross marker
        final cp = Paint()
          ..color = clusterColors[i]
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(o.translate(-8, 0), o.translate(8, 0), cp);
        canvas.drawLine(o.translate(0, -8), o.translate(0, 8), cp);
        canvas.drawCircle(o, 8, Paint()..color = clusterColors[i].withOpacity(0.15));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter o) => o.step != step;
}

class _KMeansFinal extends StatelessWidget {
  const _KMeansFinal();
  @override
  Widget build(BuildContext context) {
    final segments = [
      ('VIP Champions',   '5 khách',  'Monetary cao, mua thường xuyên',    const Color(0xFF10B981), 0.85),
      ('Growth Potential','5 khách',  'Tần suất tăng, tiềm năng lớn',      const Color(0xFF3B82F6), 0.60),
      ('Dormant / Churn', '5 khách',  'Ít mua, cần chiến dịch tái kích hoạt', const Color(0xFFF59E0B), 0.30),
    ];
    return Column(children: [
      ...segments.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s.$4.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: s.$4.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: s.$4.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.people_rounded, color: s.$4, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: s.$4)),
            Text('${s.$2}  ·  ${s.$3}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(s.$5 * 100).toInt()}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: s.$4)),
            Text('avg spend', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ]),
        ]),
      )),
      const Divider(color: Colors.white10, height: 8),
      Text('Silhouette Score = 0.71  (good separation)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════
//  PROPHET STEPS
// ═══════════════════════════════════════════════════════

List<_StepData> _prophetSteps(bool vi) => [
  _StepData(
    title: vi ? 'Bước 1 — Thành phần xu hướng (Trend)' : 'Step 1 — Trend component',
    desc: vi
        ? 'Prophet phát hiện điểm thay đổi xu hướng (changepoints) tự động. Đường nét đứt = xu hướng tuyến tính từng đoạn.'
        : 'Prophet auto-detects changepoints. Dashed segments show piecewise linear trend.',
    vizBuilder: (_) => const _ProphetViz(type: 'trend'),
  ),
  _StepData(
    title: vi ? 'Bước 2 — Tính mùa vụ hàng tuần' : 'Step 2 — Weekly seasonality',
    desc: vi
        ? 'Chuỗi Fourier mô hoá chu kỳ tuần. Cuối tuần (T7, CN) thường có đỉnh doanh thu.'
        : 'Fourier series models weekly cycles. Weekends (Sat, Sun) typically show revenue peaks.',
    vizBuilder: (_) => const _ProphetViz(type: 'weekly'),
  ),
  _StepData(
    title: vi ? 'Bước 3 — Tính mùa vụ hàng năm' : 'Step 3 — Yearly seasonality',
    desc: vi
        ? 'Bắt sóng các đợt tăng doanh thu theo năm: Tết, hè, Black Friday...'
        : 'Captures annual revenue spikes: Tết, summer peak, Black Friday...',
    vizBuilder: (_) => const _ProphetViz(type: 'yearly'),
  ),
  _StepData(
    title: vi ? 'Bước 4 — Dự báo với khoảng tin cậy' : 'Step 4 — Forecast with confidence bands',
    desc: vi
        ? 'Tổng hợp Trend + Seasonality + Holidays = dự báo kèm dải tin cậy 80%. Màu đậm = dự báo chính, vùng mờ = uncertainty.'
        : 'Trend + Seasonality + Holidays = forecast with 80% confidence band. Dark line = median, shaded = uncertainty.',
    vizBuilder: (_) => const _ProphetViz(type: 'forecast'),
  ),
];

class _ProphetViz extends StatelessWidget {
  final String type;
  const _ProphetViz({required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 160,
        width: double.infinity,
        child: CustomPaint(painter: _ProphetPainter(type)),
      ),
      const SizedBox(height: 12),
      _buildLegend(),
    ]);
  }

  Widget _buildLegend() {
    switch (type) {
      case 'trend':
        return _row([
          _chip('Actual', const Color(0xFF3B82F6)),
          _chip('Trend', const Color(0xFF8B5CF6)),
          _chip('Changepoint', const Color(0xFFEF4444)),
        ]);
      case 'weekly':
        return _row([
          _chip('Weekday', const Color(0xFF6B7280)),
          _chip('Weekend peak', const Color(0xFF10B981)),
        ]);
      case 'yearly':
        return _row([
          _chip('Low season', const Color(0xFF6B7280)),
          _chip('High season (Tết, BF)', const Color(0xFFF59E0B)),
        ]);
      default: // forecast
        return _row([
          _chip('Historical', const Color(0xFF3B82F6)),
          _chip('Forecast', const Color(0xFF10B981)),
          _chip('80% CI band', const Color(0xFF10B981), opacity: 0.3),
        ]);
    }
  }

  Widget _row(List<Widget> children) =>
      Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 6, children: children);

  Widget _chip(String label, Color c, {double opacity = 1.0}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 3, color: c.withOpacity(opacity)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
    ],
  );
}

class _ProphetPainter extends CustomPainter {
  final String type;
  const _ProphetPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    const pad = 24.0;
    final w = W - pad * 2;
    final h = H - pad * 2;

    Offset pt(double x, double y) => Offset(pad + x * w, pad + (1 - y) * h);

    // axis
    canvas.drawLine(Offset(pad, pad), Offset(pad, pad + h),
        Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5);
    canvas.drawLine(Offset(pad, pad + h), Offset(pad + w, pad + h),
        Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5);

    final n = 60;

    if (type == 'trend') {
      // noisy actual
      final actualPath = Path();
      for (int i = 0; i <= n; i++) {
        final x = i / n;
        final noise = (math.sin(i * 2.3) * 0.05 + math.sin(i * 5.7) * 0.03);
        final y = 0.1 + x * 0.5 + (x > 0.55 ? (x - 0.55) * 0.8 : 0) + noise;
        final o = pt(x, y.clamp(0.0, 1.0));
        i == 0 ? actualPath.moveTo(o.dx, o.dy) : actualPath.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(actualPath, Paint()
        ..color = const Color(0xFF3B82F6).withOpacity(0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke);

      // trend line (piecewise)
      canvas.drawLine(pt(0, 0.12), pt(0.55, 0.38),
          Paint()..color = const Color(0xFF8B5CF6)..strokeWidth = 2
            ..style = PaintingStyle.stroke);
      canvas.drawLine(pt(0.55, 0.38), pt(1, 0.92),
          Paint()..color = const Color(0xFF8B5CF6)..strokeWidth = 2
            ..style = PaintingStyle.stroke);

      // changepoint
      canvas.drawLine(pt(0.55, 0), pt(0.55, 1),
          Paint()..color = const Color(0xFFEF4444).withOpacity(0.6)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
      final tp = TextPainter(
        text: const TextSpan(text: 'CP', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pt(0.55, 1.0).translate(3, 0));
    }

    if (type == 'weekly') {
      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      final vals = [0.40, 0.38, 0.42, 0.45, 0.55, 0.80, 0.75];
      for (int i = 0; i < days.length; i++) {
        final x = (i + 0.5) / days.length;
        final barH = vals[i];
        final isWeekend = i >= 5;
        final o = pt(x, 0);
        final barRect = Rect.fromLTWH(
          o.dx - w / days.length * 0.3,
          pt(x, barH).dy,
          w / days.length * 0.6,
          h * barH,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
          Paint()..color = (isWeekend ? const Color(0xFF10B981) : const Color(0xFF6B7280)).withOpacity(0.7),
        );
        final tp2 = TextPainter(
          text: TextSpan(text: days[i], style: TextStyle(
              color: isWeekend ? const Color(0xFF10B981) : Colors.grey.shade600, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp2.paint(canvas, Offset(o.dx - tp2.width / 2, pad + h + 4));
      }
    }

    if (type == 'yearly') {
      final basePath = Path();
      for (int i = 0; i <= n; i++) {
        final x = i / n;
        final monthlyWave = math.sin(x * math.pi * 2) * 0.12;
        // spikes: Tết (Feb ~0.12), Summer (0.45), Black Friday (0.88)
        double spike = 0;
        if ((x - 0.12).abs() < 0.05) spike = 0.35 * (1 - (x - 0.12).abs() / 0.05);
        if ((x - 0.45).abs() < 0.06) spike = 0.20 * (1 - (x - 0.45).abs() / 0.06);
        if ((x - 0.88).abs() < 0.04) spike = 0.28 * (1 - (x - 0.88).abs() / 0.04);
        final y = 0.35 + monthlyWave + spike;
        final o = pt(x, y.clamp(0.0, 1.0));
        i == 0 ? basePath.moveTo(o.dx, o.dy) : basePath.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(basePath, Paint()
        ..color = const Color(0xFFF59E0B).withOpacity(0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
      // axis labels
      for (final pair in [('Tết', 0.12), ('Hè', 0.45), ('BF', 0.88)]) {
        final tp = TextPainter(
          text: TextSpan(text: pair.$1, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pt(pair.$2, 1.05).translate(-tp.width / 2, 0));
      }
    }

    if (type == 'forecast') {
      // historical (blue)
      final hist = Path();
      for (int i = 0; i <= 38; i++) {
        final x = i / n;
        final y = 0.2 + x * 0.4 + math.sin(i * 1.5) * 0.08;
        final o = pt(x, y.clamp(0.0, 1.0));
        i == 0 ? hist.moveTo(o.dx, o.dy) : hist.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(hist, Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke);

      // divider
      canvas.drawLine(pt(38 / n, 0), pt(38 / n, 1),
          Paint()..color = Colors.white.withOpacity(0.2)..strokeWidth = 1
            ..style = PaintingStyle.stroke);

      // confidence band (filled)
      final upper = Path(), lower = Path();
      for (int i = 38; i <= n; i++) {
        final x = i / n;
        final base = 0.2 + x * 0.4;
        final spread = 0.04 + (i - 38) / n * 0.15;
        final uO = pt(x, (base + spread).clamp(0.0, 1.0));
        final lO = pt(x, (base - spread).clamp(0.0, 1.0));
        i == 38 ? upper.moveTo(uO.dx, uO.dy) : upper.lineTo(uO.dx, uO.dy);
        i == 38 ? lower.moveTo(lO.dx, lO.dy) : lower.lineTo(lO.dx, lO.dy);
      }
      final band = Path()..addPath(upper, Offset.zero);
      for (int i = n; i >= 38; i--) {
        final x = i / n;
        final base = 0.2 + x * 0.4;
        final spread = 0.04 + (i - 38) / n * 0.15;
        band.lineTo(pt(x, (base - spread).clamp(0.0, 1.0)).dx,
            pt(x, (base - spread).clamp(0.0, 1.0)).dy);
      }
      band.close();
      canvas.drawPath(band, Paint()..color = const Color(0xFF10B981).withOpacity(0.15));

      // forecast median
      final fore = Path();
      for (int i = 38; i <= n; i++) {
        final x = i / n;
        final y = 0.2 + x * 0.4;
        final o = pt(x, y.clamp(0.0, 1.0));
        i == 38 ? fore.moveTo(o.dx, o.dy) : fore.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(fore, Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);

      // label
      final tp = TextPainter(
        text: const TextSpan(text: 'Forecast →', style: TextStyle(color: Color(0xFF10B981), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pt(40 / n, 1.05).translate(0, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _ProphetPainter o) => o.type != type;
}

// ═══════════════════════════════════════════════════════
//  RFM STEPS
// ═══════════════════════════════════════════════════════

List<_StepData> _rfmSteps(bool vi) => [
  _StepData(
    title: vi ? 'Bước 1 — Recency: Gần đây nhất' : 'Step 1 — Recency: most recent purchase',
    desc: vi
        ? 'R = số ngày từ lần mua cuối đến hôm nay. R nhỏ = khách đang active. Xếp hạng 1-5 (5 = tốt nhất).'
        : 'R = days since last purchase. Lower R = more active customer. Ranked 1-5 (5 = best).',
    vizBuilder: (_) => const _RfmDimViz(dim: 'R'),
  ),
  _StepData(
    title: vi ? 'Bước 2 — Frequency: Tần suất mua' : 'Step 2 — Frequency: purchase count',
    desc: vi
        ? 'F = tổng số đơn hàng trong kỳ phân tích. F cao = khách trung thành. Xếp hạng 1-5.'
        : 'F = total orders in the analysis period. High F = loyal customer. Ranked 1-5.',
    vizBuilder: (_) => const _RfmDimViz(dim: 'F'),
  ),
  _StepData(
    title: vi ? 'Bước 3 — Monetary: Tổng chi tiêu' : 'Step 3 — Monetary: total spend',
    desc: vi
        ? 'M = tổng giá trị đã chi tiêu. M cao = khách VIP quan trọng nhất. Xếp hạng 1-5.'
        : 'M = total revenue from customer. High M = most valuable VIP. Ranked 1-5.',
    vizBuilder: (_) => const _RfmDimViz(dim: 'M'),
  ),
  _StepData(
    title: vi ? 'Bước 4 — Gộp điểm & phân khúc' : 'Step 4 — Combine scores & segment',
    desc: vi
        ? 'RFM Score = R + F + M (tổng 3-15). Khách hàng được nhóm vào phân khúc chiến lược: Champion, Loyal, At Risk, Lost.'
        : 'RFM Score = R + F + M (total 3-15). Customers grouped into strategic segments: Champion, Loyal, At Risk, Lost.',
    vizBuilder: (_) => const _RfmSegmentViz(),
  ),
];

class _RfmDimViz extends StatelessWidget {
  final String dim; // 'R', 'F', 'M'
  const _RfmDimViz({required this.dim});

  @override
  Widget build(BuildContext context) {
    final config = _dimConfig(dim);
    final customers = _customerData();

    return Column(children: [
      // score explanation bar
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: config.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: config.color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: config.color.withOpacity(0.15), shape: BoxShape.circle),
              child: Center(child: Text(dim,
                  style: TextStyle(color: config.color, fontSize: 20, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(config.title, style: TextStyle(color: config.color, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(config.subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.4)),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      // score scale
      Row(children: List.generate(5, (i) {
        final score = i + 1;
        final active = score == config.exampleScore;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: active ? 52 : 40,
            decoration: BoxDecoration(
              color: active ? config.color : config.color.withOpacity(0.1 + i * 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? config.color : config.color.withOpacity(0.2)),
            ),
            child: Center(child: Text('$score',
                style: TextStyle(color: active ? Colors.white : config.color.withOpacity(0.7),
                    fontSize: active ? 16 : 13, fontWeight: FontWeight.bold))),
          ),
        ));
      })),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(config.lowLabel, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            Text('Score ${config.exampleScore}/5', style: TextStyle(fontSize: 10, color: config.color)),
            Text(config.highLabel, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // sample customers
      ...customers.map((cust) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          _avatar(cust['name']!, config.color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cust['name']!, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
            Text(cust['value_$dim']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          _scorePill(int.parse(cust['score_$dim']!), config.color),
        ]),
      )),
    ]);
  }

  _DimConfig _dimConfig(String d) {
    switch (d) {
      case 'R': return _DimConfig(
        title: 'Recency', subtitle: 'Số ngày kể từ lần mua cuối\n(thấp = tốt)',
        color: const Color(0xFF3B82F6), exampleScore: 5,
        lowLabel: 'Lâu rồi (1)', highLabel: 'Vừa mua (5)',
      );
      case 'F': return _DimConfig(
        title: 'Frequency', subtitle: 'Tổng số lần giao dịch\n(cao = tốt)',
        color: const Color(0xFF8B5CF6), exampleScore: 4,
        lowLabel: '1 lần (1)', highLabel: '20+ lần (5)',
      );
      default: return _DimConfig(
        title: 'Monetary', subtitle: 'Tổng chi tiêu tích lũy\n(cao = quan trọng)',
        color: const Color(0xFF10B981), exampleScore: 5,
        lowLabel: '<100k (1)', highLabel: '>5M (5)',
      );
    }
  }

  List<Map<String, String>> _customerData() => [
    {
      'name': 'Nguyễn Văn A',
      'value_R': '3 ngày trước', 'score_R': '5',
      'value_F': '15 đơn hàng',  'score_F': '4',
      'value_M': '6.200.000đ',   'score_M': '5',
    },
    {
      'name': 'Trần Thị B',
      'value_R': '45 ngày trước', 'score_R': '2',
      'value_F': '3 đơn hàng',   'score_F': '2',
      'value_M': '320.000đ',      'score_M': '1',
    },
    {
      'name': 'Lê Minh C',
      'value_R': '12 ngày trước', 'score_R': '4',
      'value_F': '8 đơn hàng',   'score_F': '3',
      'value_M': '1.800.000đ',    'score_M': '3',
    },
  ];

  Widget _avatar(String name, Color c) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(color: c.withOpacity(0.2), shape: BoxShape.circle),
    child: Center(child: Text(name[0],
        style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold))),
  );

  Widget _scorePill(int score, Color c) => Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      color: c.withOpacity(score >= 4 ? 0.25 : 0.08),
      shape: BoxShape.circle,
      border: Border.all(color: c.withOpacity(score >= 4 ? 0.7 : 0.2)),
    ),
    child: Center(child: Text('$score',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: score >= 4 ? c : c.withOpacity(0.5)))),
  );
}

class _DimConfig {
  final String title, subtitle, lowLabel, highLabel;
  final Color color;
  final int exampleScore;
  const _DimConfig({
    required this.title, required this.subtitle,
    required this.color, required this.exampleScore,
    required this.lowLabel, required this.highLabel,
  });
}

class _RfmSegmentViz extends StatelessWidget {
  const _RfmSegmentViz();

  static const _segments = [
    _Seg('Champions',      '12-15', 'Mua gần, thường xuyên, chi nhiều',        Color(0xFF10B981), Icons.emoji_events_rounded),
    _Seg('Loyal',          '9-11',  'Mua đều đặn, ít churn risk',              Color(0xFF3B82F6), Icons.favorite_rounded),
    _Seg('Potential',      '7-9',   'Mới nhưng tiềm năng, cần nurture',        Color(0xFF8B5CF6), Icons.trending_up_rounded),
    _Seg('At Risk',        '4-6',   'Từng tốt, đang giảm — cần reactivate',   Color(0xFFF59E0B), Icons.warning_amber_rounded),
    _Seg('Lost / Churned', '3-5',   'Lâu không mua — chiến dịch win-back',    Color(0xFFEF4444), Icons.sentiment_dissatisfied_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // RFM matrix header
      Row(children: [
        const SizedBox(width: 8),
        for (final h in ['Segment', 'Score', 'Hành động', ''])
          Expanded(child: Text(h,
              style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 8),
      ..._segments.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: s.color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: s.color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(s.icon, color: s.color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: TextStyle(fontSize: 12, color: s.color, fontWeight: FontWeight.bold)),
            Text(s.desc, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s.score, style: TextStyle(fontSize: 10, color: s.color, fontWeight: FontWeight.bold)),
          ),
        ]),
      )),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat('541,909', 'Total records'),
        _stat('5', 'Segments'),
        _stat('91%', 'Label accuracy'),
      ]),
    ]);
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    Text(l, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
  ]);
}

class _Seg {
  final String name, score, desc;
  final Color color;
  final IconData icon;
  const _Seg(this.name, this.score, this.desc, this.color, this.icon);
}

// ═══════════════════════════════════════════════════════
//  TAB 3: COMPARISON
// ═══════════════════════════════════════════════════════

class _ComparisonTab extends StatelessWidget {
  final SettingsProvider settings;
  const _ComparisonTab({required this.settings});

  @override
  Widget build(BuildContext context) {
    final vi = settings.isVietnamese;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _versus(vi),
        const SizedBox(height: 28),
        _fullComparisonTable(vi),
        const SizedBox(height: 28),
        _complexityCard(vi),
      ]),
    );
  }

  Widget _versus(bool vi) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _vsCard(
        'Apriori',
        vi ? 'Sinh ứng viên' : 'Candidate Generation',
        [
          vi ? '• Quét DB nhiều lần' : '• Multiple DB scans',
          vi ? '• Bộ nhớ cao (lưu ứng viên)' : '• High memory (stores candidates)',
          vi ? '• Chậm với dữ liệu lớn' : '• Slow at scale',
          vi ? '• Dễ hiểu, dễ implement' : '• Simple to understand & implement',
        ],
        Icons.hourglass_bottom_rounded,
        const Color(0xFFEF4444),
        isWinner: false,
      )),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
        child: Text('VS', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.15), fontStyle: FontStyle.italic)),
      ),
      Expanded(child: _vsCard(
        'FP-Growth',
        vi ? 'Cấu trúc cây' : 'Tree Structure',
        [
          vi ? '• Chỉ 2 lần quét DB' : '• Only 2 DB scans',
          vi ? '• Bộ nhớ thấp (cây nén)' : '• Low memory (compressed tree)',
          vi ? '• Rất nhanh, scalable' : '• Very fast, scalable',
          vi ? '• Phức tạp hơn về cấu trúc' : '• More complex data structure',
        ],
        Icons.bolt_rounded,
        const Color(0xFF10B981),
        isWinner: true,
      )),
    ]);
  }

  Widget _vsCard(String title, String subtitle, List<String> points, IconData icon, Color c, {required bool isWinner}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(isWinner ? 0.5 : 0.2), width: isWinner ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))),
        ]),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        ...points.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(p, style: TextStyle(fontSize: 11, color: Colors.grey.shade300, height: 1.4)),
        )),
        if (isWinner) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(settings.isVietnamese ? '✓ Được dùng' : '✓ Used in app',
                style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }

  Widget _fullComparisonTable(bool vi) {
    final headers = ['Tiêu chí', 'FP-Growth', 'K-Means', 'Prophet', 'RFM'];
    final rows = [
      [vi ? 'Mục tiêu' : 'Goal', vi ? 'Luật kết hợp' : 'Assoc. rules', vi ? 'Phân cụm' : 'Clustering', vi ? 'Dự báo' : 'Forecasting', vi ? 'Phân khúc' : 'Segmentation'],
      [vi ? 'Kiểu học' : 'ML type', vi ? 'Không giám sát' : 'Unsupervised', vi ? 'Không giám sát' : 'Unsupervised', vi ? 'Chuỗi thời gian' : 'Time-series', vi ? 'Quy tắc' : 'Rule-based'],
      [vi ? 'Đầu vào' : 'Input', vi ? 'Giỏ hàng' : 'Baskets', 'RFM vectors', vi ? 'Doanh thu theo ngày' : 'Daily revenue', vi ? 'Giao dịch' : 'Transactions'],
      [vi ? 'Đầu ra' : 'Output', vi ? 'Luật A→B' : 'Rules A→B', vi ? 'Nhóm' : 'Groups', vi ? 'Dự báo+CI' : 'Forecast+CI', vi ? 'Nhãn phân khúc' : 'Segment label'],
      ['Metric', 'Lift, Conf', 'Silhouette', 'RMSE, MAE', 'Score 1-5'],
    ];

    final colColors = [
      Colors.transparent,
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(vi ? 'So sánh toàn diện 4 thuật toán' : 'Full 4-algorithm comparison',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 12),
      Table(
        border: TableBorder.all(color: Colors.white.withOpacity(0.06)),
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.2),
          4: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04)),
            children: List.generate(headers.length, (i) => _tc(headers[i], colColors[i], isHeader: true)),
          ),
          ...rows.map((row) => TableRow(
            children: List.generate(row.length, (i) => _tc(row[i], colColors[i])),
          )),
        ],
      ),
    ]);
  }

  Widget _tc(String text, Color c, {bool isHeader = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: c == Colors.transparent
              ? (isHeader ? Colors.white : Colors.white70)
              : (isHeader ? c : c.withOpacity(0.8)),
        )),
  );

  Widget _complexityCard(bool vi) {
    final items = [
      ('FP-Growth', 'O(n)', vi ? 'Tuyến tính theo số giao dịch' : 'Linear in transactions', const Color(0xFF10B981)),
      ('K-Means',   'O(nki)', vi ? 'n=data, k=clusters, i=iter' : 'n=data, k=clusters, i=iter', const Color(0xFF3B82F6)),
      ('Prophet',   'O(n log n)', vi ? 'Ưu thế nhờ MCMC sampling' : 'Efficient via MCMC sampling', const Color(0xFF8B5CF6)),
      ('RFM',       'O(n)', vi ? 'Đơn giản nhất — chỉ tính điểm' : 'Simplest — just scoring', const Color(0xFFF59E0B)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(vi ? 'Độ phức tạp tính toán' : 'Computational complexity',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 12),
      ...items.map((it) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(width: 90, child: Text(it.$1,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: it.$4.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: it.$4.withOpacity(0.3)),
            ),
            child: Text(it.$2, style: TextStyle(fontSize: 11, color: it.$4, fontFamily: 'monospace')),
          ),
          Expanded(child: Text(it.$3, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
        ]),
      )),
    ]);
  }
}