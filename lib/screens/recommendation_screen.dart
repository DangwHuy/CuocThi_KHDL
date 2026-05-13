import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _single = {};
  Map<String, dynamic> _multi = {};
  bool _isLoading = true;

  // Search state
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchFocused = false;
  final FocusNode _searchFocus = FocusNode();

  // Selected item
  String? _selectedItem;

  // Basket simulator
  final List<String> _basket = [];
  bool _showBasket = false;

  // ROI Tracking state
  int _totalRecsShown = 0;
  int _recsAccepted = 0;
  int _recsSkipped = 0;
  final List<Map<String, dynamic>> _acceptedHistory = [];
  double _baselineRevenue = 0;
  double _aiRevenue = 0;

  // Tab: 0 = single item, 1 = basket sim, 2 = ROI analytics
  late TabController _tabCtrl;

  // Popular quick-pick items
  static const List<String> _popularItems = [
    'whole milk', 'other vegetables', 'rolls/buns',
    'soda', 'yogurt', 'sausage', 'bottled water', 'tropical fruit',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _initMockTrackingData();
    _searchFocus.addListener(() => setState(() => _searchFocused = _searchFocus.hasFocus));
    _loadRecommendations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/recommendations_enriched.json');
      final data = json.decode(jsonStr);
      setState(() {
        _single = Map<String, dynamic>.from(data['single'] ?? {});
        _multi  = Map<String, dynamic>.from(data['multi']  ?? {});
        _isLoading = false;
      });
    } catch (e) {
      // Fallback: try old format
      try {
        final jsonStr = await rootBundle.loadString('assets/data/recommendations.json');
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        // Convert old format to new
        final converted = <String, dynamic>{};
        data.forEach((k, v) {
          final list = (v as List).map((r) => {
            'recommend': r['recommend'],
            'confidence': r['confidence'],
            'lift': 1.0,
            'support': 0.01,
            'antecedents': [k],
          }).toList();
          converted[k] = list;
        });
        setState(() { _single = converted; _isLoading = false; });
      } catch (_) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initMockTrackingData() {
    final rng = Random(42);
    _totalRecsShown = 156;
    _recsAccepted = 105;
    _recsSkipped = 51;
    _baselineRevenue = 24500.0;
    _aiRevenue = 31800.0;

    // Simulated accepted history
    final mockItems = [
      'whole milk', 'yogurt', 'rolls/buns', 'soda', 'bottled water',
      'tropical fruit', 'sausage', 'other vegetables', 'pastry', 'root vegetables',
    ];
    for (int i = 0; i < 12; i++) {
      final src = mockItems[rng.nextInt(mockItems.length)];
      String dest = mockItems[rng.nextInt(mockItems.length)];
      while (dest == src) dest = mockItems[rng.nextInt(mockItems.length)];
      _acceptedHistory.add({
        'source': src,
        'recommended': dest,
        'lift': 1.0 + rng.nextDouble() * 1.2,
        'confidence': 0.15 + rng.nextDouble() * 0.55,
        'accepted': rng.nextBool() || rng.nextBool(), // ~75% accepted
        'timestamp': DateTime.now().subtract(Duration(hours: rng.nextInt(72))),
        'revenue': DataService.getMockPrice(dest),
      });
    }
    _acceptedHistory.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
  }

  void _trackAcceptRec(String source, Map<String, dynamic> rec) {
    setState(() {
      _recsAccepted++;
      _totalRecsShown++;
      final price = DataService.getMockPrice(rec['recommend'] as String);
      _aiRevenue += price;
      _acceptedHistory.insert(0, {
        'source': source,
        'recommended': rec['recommend'],
        'lift': (rec['lift'] as num).toDouble(),
        'confidence': (rec['confidence'] as num).toDouble(),
        'accepted': true,
        'timestamp': DateTime.now(),
        'revenue': price,
      });
    });
  }

  // ── Helpers ───────────────────────────────────────────────────
  List<String> get _allItems => _single.keys.toList()..sort();

  List<String> get _filteredItems {
    if (_searchQuery.isEmpty) return _allItems;
    final q = _searchQuery.toLowerCase();
    return _allItems.where((item) =>
    item.toLowerCase().contains(q) ||
        DataService.translateItem(item).toLowerCase().contains(q)).toList();
  }

  List<Map<String, dynamic>> get _currentRecs {
    if (_selectedItem == null) return [];
    final raw = _single[_selectedItem];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw);
  }

  List<Map<String, dynamic>> get _basketRecs {
    if (_basket.isEmpty) return [];
    // Try multi-item key first
    final key = _basket.toList()..sort();
    final multiKey = key.join('|');
    if (_multi.containsKey(multiKey)) {
      return List<Map<String, dynamic>>.from(_multi[multiKey]);
    }
    // Aggregate single-item recs, de-duplicate, exclude basket items
    final Map<String, Map<String, dynamic>> agg = {};
    for (final item in _basket) {
      final recs = _single[item] as List? ?? [];
      for (final r in recs) {
        final rec = r as Map<String, dynamic>;
        final name = rec['recommend'] as String;
        if (_basket.contains(name)) continue;

        if (!agg.containsKey(name)) {
          agg[name] = Map<String, dynamic>.from(rec);
          agg[name]!['reasons'] = <String>[item];
        } else {
          final existingReasons = agg[name]!['reasons'] as List<String>;
          if (!existingReasons.contains(item)) existingReasons.add(item);

          if ((rec['lift'] as num) > (agg[name]!['lift'] as num)) {
            agg[name]!['lift'] = rec['lift'];
            agg[name]!['confidence'] = rec['confidence'];
            agg[name]!['support'] = rec['support'];
          }
        }
      }
    }
    final result = agg.values.toList()
      ..sort((a, b) => (b['lift'] as num).compareTo(a['lift'] as num));
    return result.take(8).toList();
  }

  String _liftLabel(double lift, bool isVi) {
    if (lift >= 1.5) return isVi ? 'Liên hệ rất mạnh' : 'Very strong';
    if (lift >= 1.2) return isVi ? 'Liên hệ mạnh' : 'Strong';
    if (lift >= 1.0) return isVi ? 'Có liên hệ' : 'Related';
    return isVi ? 'Yếu' : 'Weak';
  }

  Color _liftColor(double lift) {
    if (lift >= 1.5) return const Color(0xFF1D9E75);
    if (lift >= 1.2) return const Color(0xFF378ADD);
    if (lift >= 1.0) return const Color(0xFFD4A017);
    return const Color(0xFF5F5E5A);
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildHeader(context, settings, isMobile),
          _buildTabBar(context, settings),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSingleTab(context, settings, isMobile),
                _buildBasketTab(context, settings, isMobile),
                _buildROITab(context, settings, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, SettingsProvider settings, bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 52 : 28, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.isVietnamese ? 'AI Gợi ý Bán chéo' : 'AI Cross-sell Recommendations',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    settings.isVietnamese
                        ? 'Dựa trên FP-Growth • ${_single.length} sản phẩm'
                        : 'Powered by FP-Growth • ${_single.length} products',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────
  Widget _buildTabBar(BuildContext context, SettingsProvider settings) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: isMobile,
        tabAlignment: isMobile ? TabAlignment.center : TabAlignment.fill,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: isMobile ? 12 : 13),
        labelPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 12) : null,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_rounded, size: 16),
                const SizedBox(width: 6),
                Text(settings.isVietnamese ? 'Theo sản phẩm' : 'By product'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_basket_rounded, size: 16),
                const SizedBox(width: 6),
                Text(settings.isVietnamese ? 'Giỏ hàng AI' : 'Basket AI'),
                if (_basket.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_basket.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.analytics_rounded, size: 16),
                const SizedBox(width: 6),
                Text(settings.isVietnamese ? 'Đo hiệu quả' : 'ROI'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SINGLE ITEM TAB ───────────────────────────────────────────
  Widget _buildSingleTab(BuildContext context, SettingsProvider settings, bool isMobile) {
    return CustomScrollView(
      slivers: [
        // Search box
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _searchFocused
                          ? AppTheme.primaryColor.withOpacity(0.6)
                          : Colors.white.withOpacity(0.07),
                      width: _searchFocused ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: settings.isVietnamese
                          ? 'Tìm sản phẩm... (vd: sữa, bánh mì)'
                          : 'Search product... (e.g. milk, bread)',
                      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: _searchFocused ? AppTheme.primaryColor : Colors.grey.shade600),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 18),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                // Search results dropdown
                if (_searchFocused && _searchQuery.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2333),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: _filteredItems.take(8).map((item) {
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.inventory_2_outlined,
                                color: AppTheme.primaryColor, size: 14),
                          ),
                          title: Text(
                            settings.isVietnamese ? DataService.translateItem(item) : item,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          subtitle: Text(item,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          onTap: () {
                            setState(() {
                              _selectedItem = item;
                              _searchQuery = '';
                              _searchCtrl.clear();
                              _searchFocus.unfocus();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 14),

                // Quick picks
                if (_searchQuery.isEmpty) ...[
                  Text(
                    settings.isVietnamese ? 'Phổ biến nhất' : 'Most popular',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500, letterSpacing: 0.05),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _popularItems
                        .where((item) => _single.containsKey(item))
                        .map((item) {
                      final isSelected = _selectedItem == item;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedItem = item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            settings.isVietnamese ? DataService.translateItem(item) : item,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Selected item header
        if (_selectedItem != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.primaryColor.withOpacity(0.08)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.35)),
                    ),
                    child: Row(children: [
                      Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor, size: 14),
                      const SizedBox(width: 7),
                      Text(
                        settings.isVietnamese
                            ? DataService.translateItem(_selectedItem!)
                            : _selectedItem!,
                        style: TextStyle(color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    settings.isVietnamese
                        ? '${_currentRecs.length} gợi ý'
                        : '${_currentRecs.length} suggestions',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedItem = null),
                    child: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 18),
                  ),
                ],
              ),
            ),
          ),

        // Recommendation list
        if (_selectedItem != null && _currentRecs.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildRecCard(_currentRecs[i], i, settings),
                childCount: _currentRecs.length,
              ),
            ),
          ),

        if (_selectedItem == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(children: [
                  Icon(Icons.touch_app_rounded, size: 40, color: Colors.grey.shade700),
                  const SizedBox(height: 12),
                  Text(
                    settings.isVietnamese
                        ? 'Chọn sản phẩm để xem gợi ý'
                        : 'Select a product to see recommendations',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ]),
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── RECOMMENDATION CARD ────────────────────────────────────────
  Widget _buildRecCard(Map<String, dynamic> rec, int rank, SettingsProvider settings) {
    final confidence = (rec['confidence'] as num).toDouble();
    final lift = (rec['lift'] as num).toDouble();
    final support = (rec['support'] as num).toDouble();
    final name = rec['recommend'] as String;
    final liftColor = _liftColor(lift);

    final reasons = rec['reasons'] as List<String>?;
    final antecedents = rec['antecedents'] as List<dynamic>?;
    final isMulti = antecedents != null && antecedents.length > 1;
    final displayReasons = reasons ?? (antecedents?.map((e) => e.toString()).toList() ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: rank + name + lift badge + quick add button
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('${rank + 1}',
                      style: TextStyle(color: AppTheme.primaryColor,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.isVietnamese ? DataService.translateItem(name) : name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DataService.formatPrice(DataService.getMockPrice(name), settings.isVietnamese),
                      style: TextStyle(fontSize: 12, color: Colors.greenAccent.shade400, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: liftColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: liftColor.withOpacity(0.4)),
                ),
                child: Text(
                  'Lift ${lift.toStringAsFixed(2)}×',
                  style: TextStyle(color: liftColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (!_basket.contains(name) && _basket.length < 6) {
                    setState(() => _basket.add(name));
                    _trackAcceptRec(_selectedItem ?? 'basket', rec);
                    _tabCtrl.animateTo(1); // Switch to Basket Tab
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded, 
                      color: AppTheme.primaryColor, size: 16),
                ),
              ),
            ],
          ),
          
          // Explainable AI text
          if (displayReasons.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.amber.shade300),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    settings.isVietnamese
                        ? 'Gợi ý vì bạn đã chọn: ${displayReasons.map((e) => DataService.translateItem(e)).join(', ')}'
                        : 'Recommended because you selected: ${displayReasons.join(', ')}',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade200, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 14),

          // Confidence bar
          _buildMetricBar(
            label: settings.isVietnamese ? 'Độ tin cậy' : 'Confidence',
            value: confidence,
            maxValue: 1.0,
            displayText: '${(confidence * 100).toStringAsFixed(1)}%',
            color: const Color(0xFF534AB7),
            tooltip: settings.isVietnamese
                ? 'Xác suất mua kèm khi đã mua sản phẩm gốc'
                : 'Probability of buying this when buying the source item',
          ),
          const SizedBox(height: 8),

          // Lift bar
          _buildMetricBar(
            label: 'Lift',
            value: (lift - 1.0).clamp(0.0, 2.0),
            maxValue: 2.0,
            displayText: '${lift.toStringAsFixed(2)}× ${_liftLabel(lift, settings.isVietnamese)}',
            color: liftColor,
            tooltip: settings.isVietnamese
                ? 'Lift > 1: mối liên hệ thực sự, không phải ngẫu nhiên'
                : 'Lift > 1: real association, not random co-occurrence',
          ),
          const SizedBox(height: 8),

          // Support bar
          _buildMetricBar(
            label: 'Support',
            value: support,
            maxValue: 0.05,
            displayText: '${(support * 100).toStringAsFixed(2)}%',
            color: const Color(0xFF1D9E75),
            tooltip: settings.isVietnamese
                ? 'Tần suất xuất hiện cùng nhau trong toàn bộ dataset'
                : 'Frequency of co-occurrence across all transactions',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar({
    required String label,
    required double value,
    required double maxValue,
    required String displayText,
    required Color color,
    required String tooltip,
  }) {
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(displayText,
              style: TextStyle(fontSize: 11, color: color,
                  fontFamily: 'monospace', fontWeight: FontWeight.w500),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // ── BASKET SIMULATOR TAB ──────────────────────────────────────
  Widget _buildBasketTab(BuildContext context, SettingsProvider settings, bool isMobile) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.primaryColor.withOpacity(0.7), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.isVietnamese
                              ? 'Thêm sản phẩm vào giỏ → AI gợi ý dựa trên toàn bộ giỏ hàng'
                              : 'Add products to basket → AI recommends based on combined basket',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Basket display
                if (_basket.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settings.isVietnamese ? 'Giỏ hàng hiện tại' : 'Current basket',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${settings.isVietnamese ? "Tổng:" : "Total:"} ${DataService.formatPrice(_basket.fold(0.0, (sum, item) => sum + DataService.getMockPrice(item)), settings.isVietnamese)}',
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        ..._basket.map((item) => _buildBasketChip(item, settings)),
                        // Clear all
                        GestureDetector(
                          onTap: () => setState(() => _basket.clear()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                settings.isVietnamese ? 'Xóa hết' : 'Clear',
                                style: const TextStyle(color: Colors.red, fontSize: 11),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Add product search
                Text(
                  settings.isVietnamese ? 'Thêm sản phẩm vào giỏ' : 'Add product to basket',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _popularItems.map((item) {
                    final inBasket = _basket.contains(item);
                    return GestureDetector(
                      onTap: () {
                        if (!inBasket && _basket.length < 6) {
                          setState(() => _basket.add(item));
                        } else if (inBasket) {
                          setState(() => _basket.remove(item));
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: inBasket
                              ? const Color(0xFF1D9E75).withOpacity(0.15)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: inBasket
                                ? const Color(0xFF1D9E75).withOpacity(0.5)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (inBasket) ...[
                              const Icon(Icons.check_rounded,
                                  color: Color(0xFF1D9E75), size: 12),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              settings.isVietnamese
                                  ? DataService.translateItem(item)
                                  : item,
                              style: TextStyle(
                                fontSize: 12,
                                color: inBasket
                                    ? const Color(0xFF1D9E75)
                                    : Colors.grey.shade400,
                                fontWeight: inBasket ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Basket recommendations
        if (_basket.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFD4A017)),
                const SizedBox(width: 8),
                Text(
                  settings.isVietnamese
                      ? 'Gợi ý dựa trên giỏ hàng'
                      : 'Recommendations for your basket',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_basketRecs.length}',
                      style: const TextStyle(color: Color(0xFFD4A017), fontSize: 11)),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildRecCard(_basketRecs[i], i, settings),
                childCount: _basketRecs.length,
              ),
            ),
          ),
        ],

        if (_basket.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Column(children: [
                  Icon(Icons.shopping_basket_outlined, size: 44, color: Colors.grey.shade700),
                  const SizedBox(height: 12),
                  Text(
                    settings.isVietnamese
                        ? 'Chọn ít nhất 1 sản phẩm để bắt đầu'
                        : 'Add at least 1 product to start',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ]),
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildBasketChip(String item, SettingsProvider settings) {
    return GestureDetector(
      onTap: () => setState(() => _basket.remove(item)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1D9E75).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            settings.isVietnamese ? DataService.translateItem(item) : item,
            style: const TextStyle(color: Color(0xFF1D9E75), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.close_rounded, color: Color(0xFF1D9E75), size: 13),
        ]),
      ),
    );
  }

  // ── ROI ANALYTICS TAB ─────────────────────────────────────────
  Widget _buildROITab(BuildContext context, SettingsProvider settings, bool isMobile) {
    final ctr = _totalRecsShown > 0 ? _recsAccepted / _totalRecsShown : 0.0;
    final conversionLift = _baselineRevenue > 0
        ? ((_aiRevenue - _baselineRevenue) / _baselineRevenue * 100)
        : 0.0;
    final avgLift = _acceptedHistory.isNotEmpty
        ? _acceptedHistory.fold<double>(0, (s, e) => s + (e['lift'] as double)) / _acceptedHistory.length
        : 0.0;

    return CustomScrollView(
      slivers: [
        // ── Section: KPI Overview Cards ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_rounded, color: AppTheme.primaryColor.withOpacity(0.7), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      settings.isVietnamese
                          ? 'Đo lường hiệu quả hệ thống AI Gợi ý (FP-Growth) dựa trên hành vi người dùng.'
                          : 'Measure AI Recommendation (FP-Growth) effectiveness based on user behavior.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── KPI Cards Row ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isMobile ? 1.3 : 1.6,
            ),
            delegate: SliverChildListDelegate([
              _buildKPICard(
                icon: Icons.ads_click_rounded,
                label: settings.isVietnamese ? 'Tỉ lệ chấp nhận' : 'Acceptance Rate',
                value: '${(ctr * 100).toStringAsFixed(1)}%',
                color: const Color(0xFF378ADD),
                subtitle: '$_recsAccepted / $_totalRecsShown',
              ),
              _buildKPICard(
                icon: Icons.trending_up_rounded,
                label: settings.isVietnamese ? 'Tăng trưởng DT' : 'Revenue Lift',
                value: '+${conversionLift.toStringAsFixed(1)}%',
                color: const Color(0xFF1D9E75),
                subtitle: settings.isVietnamese ? 'so với không có AI' : 'vs no AI',
              ),
              _buildKPICard(
                icon: Icons.auto_awesome_rounded,
                label: settings.isVietnamese ? 'Lift trung bình' : 'Avg Lift',
                value: '${avgLift.toStringAsFixed(2)}×',
                color: const Color(0xFFD4A017),
                subtitle: settings.isVietnamese ? 'các gợi ý được chọn' : 'accepted recs',
              ),
              _buildKPICard(
                icon: Icons.remove_shopping_cart_outlined,
                label: settings.isVietnamese ? 'Bỏ qua' : 'Skipped',
                value: '$_recsSkipped',
                color: const Color(0xFFD85A30),
                subtitle: '${(_recsSkipped / max(1, _totalRecsShown) * 100).toStringAsFixed(0)}%',
              ),
            ]),
          ),
        ),

        // ── Conversion Lift Comparison ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _buildROISection(
              title: settings.isVietnamese ? 'So sánh Doanh thu' : 'Revenue Comparison',
              icon: Icons.compare_arrows_rounded,
              child: Column(
                children: [
                  _buildRevenueBar(
                    label: settings.isVietnamese ? 'Không có AI' : 'Without AI',
                    value: _baselineRevenue,
                    maxValue: _aiRevenue * 1.1,
                    color: Colors.grey.shade600,
                    settings: settings,
                  ),
                  const SizedBox(height: 12),
                  _buildRevenueBar(
                    label: settings.isVietnamese ? 'Có AI Gợi ý' : 'With AI Recs',
                    value: _aiRevenue,
                    maxValue: _aiRevenue * 1.1,
                    color: const Color(0xFF1D9E75),
                    settings: settings,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Color(0xFF1D9E75), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          settings.isVietnamese
                              ? 'AI giúp tăng +${DataService.formatPrice(_aiRevenue - _baselineRevenue, settings.isVietnamese)} (+${conversionLift.toStringAsFixed(1)}%)'
                              : 'AI boosts +${DataService.formatPrice(_aiRevenue - _baselineRevenue, settings.isVietnamese)} (+${conversionLift.toStringAsFixed(1)}%)',
                          style: const TextStyle(color: Color(0xFF1D9E75), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── A/B Test Simulator ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildROISection(
              title: settings.isVietnamese ? 'Mô phỏng A/B Test' : 'A/B Test Simulator',
              icon: Icons.science_outlined,
              child: Column(
                children: [
                  _buildABRow(
                    label: settings.isVietnamese ? 'Chiến thuật A: Ưu tiên Lift cao' : 'Strategy A: High Lift',
                    value: 0.62,
                    color: const Color(0xFF378ADD),
                    detail: settings.isVietnamese ? '62% chuyển đổi • Lift ≥ 1.5' : '62% conv. • Lift ≥ 1.5',
                  ),
                  const SizedBox(height: 12),
                  _buildABRow(
                    label: settings.isVietnamese ? 'Chiến thuật B: Ưu tiên Support cao' : 'Strategy B: High Support',
                    value: 0.38,
                    color: const Color(0xFFD4A017),
                    detail: settings.isVietnamese ? '38% chuyển đổi • Support ≥ 2%' : '38% conv. • Support ≥ 2%',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF378ADD).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF378ADD).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFF378ADD), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            settings.isVietnamese
                                ? 'Kết luận: Ưu tiên Lift cao hiệu quả hơn 63% — Lift phản ánh sự liên hệ thực sự giữa sản phẩm.'
                                : 'Conclusion: High Lift strategy outperforms by 63% — Lift reflects true product association.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Top Performing Recs ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildROISection(
              title: settings.isVietnamese ? 'Gợi ý hiệu quả nhất' : 'Top Performing Recs',
              icon: Icons.emoji_events_outlined,
              child: Column(
                children: _acceptedHistory
                    .where((e) => e['accepted'] == true)
                    .take(5)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) => _buildTopRecRow(entry.key, entry.value, settings))
                    .toList(),
              ),
            ),
          ),
        ),

        // ── Recent Activity Log ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildROISection(
              title: settings.isVietnamese ? 'Hoạt động gần đây' : 'Recent Activity',
              icon: Icons.history_rounded,
              child: Column(
                children: _acceptedHistory.take(6).map((e) {
                  final accepted = e['accepted'] as bool;
                  final src = e['source'] as String;
                  final dest = e['recommended'] as String;
                  final ts = e['timestamp'] as DateTime;
                  final diff = DateTime.now().difference(ts);
                  String timeAgo;
                  if (diff.inMinutes < 60) {
                    timeAgo = '${diff.inMinutes}m';
                  } else if (diff.inHours < 24) {
                    timeAgo = '${diff.inHours}h';
                  } else {
                    timeAgo = '${diff.inDays}d';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: accepted
                                ? const Color(0xFF1D9E75).withOpacity(0.12)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            accepted ? Icons.check_rounded : Icons.close_rounded,
                            size: 13,
                            color: accepted ? const Color(0xFF1D9E75) : Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                              children: [
                                TextSpan(
                                  text: settings.isVietnamese ? DataService.translateItem(src) : src,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                                TextSpan(text: ' → '),
                                TextSpan(
                                  text: settings.isVietnamese ? DataService.translateItem(dest) : dest,
                                  style: TextStyle(
                                    color: accepted ? const Color(0xFF1D9E75) : Colors.red.shade300,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── ROI Helper Widgets ─────────────────────────────────────────
  Widget _buildKPICard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildROISection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRevenueBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required SettingsProvider settings,
  }) {
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            Text(DataService.formatPrice(value, settings.isVietnamese),
                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildABRow({
    required String label,
    required double value,
    required Color color,
    required String detail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)],
                      ),
                      child: Center(
                        child: Text(
                          '${(value * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: Text(detail,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopRecRow(int rank, Map<String, dynamic> rec, SettingsProvider settings) {
    final src = rec['source'] as String;
    final dest = rec['recommended'] as String;
    final lift = rec['lift'] as double;
    final revenue = rec['revenue'] as double;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFD4A017).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('${rank + 1}',
                  style: const TextStyle(color: Color(0xFFD4A017), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.isVietnamese
                      ? '${DataService.translateItem(src)} → ${DataService.translateItem(dest)}'
                      : '$src → $dest',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Lift ${lift.toStringAsFixed(2)}× • +${DataService.formatPrice(revenue, settings.isVietnamese)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1D9E75), size: 14),
          ),
        ],
      ),
    );
  }
}