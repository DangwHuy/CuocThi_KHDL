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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.isVietnamese ? 'AI Gợi ý Bán chéo (Cross-selling)' : 'AI Cross-selling Recommendation',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.isVietnamese 
                        ? 'Dựa trên mô hình FP-Growth, AI phân tích hành vi mua sắm để gợi ý sản phẩm mua kèm.'
                        : 'Based on FP-Growth model, AI analyzes shopping behavior to recommend complementary products.',
                    style: TextStyle(color: Colors.grey[500]),
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
                    Expanded(
                      child: ListView.builder(
                        itemCount: _recommendations[_selectedItem].length,
                        itemBuilder: (context, index) {
                          final rec = _recommendations[_selectedItem][index];
                          final recItem = rec['recommend'];
                          final confidence = (rec['confidence'] * 100).toStringAsFixed(1);
                          final lift = rec['lift'].toStringAsFixed(2);
                          
                          return Card(
                            color: Theme.of(context).cardColor,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.secondaryColor,
                                child: Icon(Icons.star_rounded, color: Colors.white),
                              ),
                              title: Text(
                                settings.isVietnamese ? DataService.translateItem(recItem) : recItem,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                settings.isVietnamese 
                                  ? 'Độ tự tin: $confidence% | Chỉ số Lift: $lift'
                                  : 'Confidence: $confidence% | Lift: $lift',
                              ),
                              trailing: const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.primaryColor),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
