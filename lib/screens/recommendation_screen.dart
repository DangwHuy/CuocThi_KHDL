import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  Map<String, dynamic> _recommendations = {};
  String? _selectedItem;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/recommendations.json');
      setState(() {
        _recommendations = json.decode(jsonStr);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading recommendations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final items = _recommendations.keys.toList();

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: isMobile ? 60 : 120,
                  floating: false,
                  pinned: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: isMobile ? IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ) : null,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      settings.isVietnamese ? 'AI Gợi ý' : 'AI Recommendation',
                      style: TextStyle(
                        fontSize: isMobile ? 19 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    centerTitle: isMobile,
                    titlePadding: EdgeInsets.only(
                      left: isMobile ? 0 : 24, 
                      bottom: isMobile ? 14 : 16
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.isVietnamese 
                              ? 'Dựa trên mô hình FP-Growth, AI phân tích hành vi mua sắm để gợi ý sản phẩm mua kèm.'
                              : 'Based on FP-Growth model, AI analyzes shopping behavior to recommend complementary products.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: settings.isVietnamese ? 'Chọn sản phẩm khách hàng đang mua' : 'Select a product customer is buying',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          value: _selectedItem,
                          items: items.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(settings.isVietnamese ? DataService.translateItem(item) : item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedItem = value;
                            });
                          },
                        ),
                        const SizedBox(height: 32),
                        if (_selectedItem != null) ...[
                          Text(
                            settings.isVietnamese ? 'Sản phẩm nên gợi ý mua kèm:' : 'Recommended complementary products:',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_selectedItem != null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final recommendation = _recommendations[_selectedItem][index];
                          final itemName = recommendation['recommend'];
                          final confidence = recommendation['confidence'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Theme.of(context).cardColor,
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                child: Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                              ),
                              title: Text(
                                settings.isVietnamese ? DataService.translateItem(itemName) : itemName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                settings.isVietnamese 
                                  ? 'Độ tin cậy: ${(confidence * 100).toStringAsFixed(1)}%' 
                                  : 'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ),
                          );
                        },
                        childCount: _recommendations[_selectedItem].length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
    );
  }
}
