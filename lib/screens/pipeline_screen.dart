import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  bool _showTechStack = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, settings, isMobile),
          
          // Toggle button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    settings.isVietnamese ? 'Hiển thị Công nghệ (Tech Stack)' : 'Show Tech Stack',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _showTechStack,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _showTechStack = v),
                  ),
                ],
              ),
            ),
          ),

          _buildPipelineTimeline(context, settings, isMobile),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, bool isMobile) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, isMobile ? 52 : 28, 20, 16),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.schema_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.isVietnamese ? 'Quy trình Data Science' : 'Data Science Pipeline',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  settings.isVietnamese
                      ? 'Kiến trúc hệ thống và luồng dữ liệu chuẩn'
                      : 'Standard system architecture and data flow',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineTimeline(BuildContext context, SettingsProvider settings, bool isMobile) {
    final steps = [
      {
        'title': '1. Data Collection',
        'desc_vi': 'Thu thập dữ liệu bán lẻ từ nhiều nguồn',
        'desc_en': 'Collect retail data from various sources',
        'icon': Icons.source_rounded,
        'color': Colors.blue,
        'tech': 'Hadoop / Data Lake',
      },
      {
        'title': '2. Data Processing',
        'desc_vi': 'Làm sạch, xử lý missing values, chuẩn hóa',
        'desc_en': 'Clean, handle missing values, standardize',
        'icon': Icons.cleaning_services_rounded,
        'color': Colors.orange,
        'tech': 'Apache Spark / Pandas',
      },
      {
        'title': '3. Modeling & AI',
        'desc_vi': 'Xây dựng mô hình Forecast, Clustering, FP-Growth',
        'desc_en': 'Build Forecast, Clustering, FP-Growth models',
        'icon': Icons.model_training_rounded,
        'color': Colors.purple,
        'tech': 'Scikit-Learn / TensorFlow',
      },
      {
        'title': '4. Evaluation',
        'desc_vi': 'Đánh giá mô hình (RMSE, Silhouette Score, Lift)',
        'desc_en': 'Model evaluation (RMSE, Silhouette Score, Lift)',
        'icon': Icons.fact_check_rounded,
        'color': Colors.redAccent,
        'tech': 'Jupyter / PyTest',
      },
      {
        'title': '5. Visualization',
        'desc_vi': 'Trực quan hóa dữ liệu qua biểu đồ tương tác',
        'desc_en': 'Visualize data through interactive charts',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.green,
        'tech': 'Flutter / FL Chart',
      },
      {
        'title': '6. Business Insight',
        'desc_vi': 'Đưa ra đề xuất bán chéo, chiến lược giá, nhập hàng',
        'desc_en': 'Provide cross-sell, pricing, and restock strategies',
        'icon': Icons.lightbulb_rounded,
        'color': Colors.amber,
        'tech': 'Actionable KPIs',
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            final color = step['color'] as Color;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline line & dot
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Icon(step['icon'] as IconData, color: color, size: 18),
                      ),
                      if (!isLast)
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (context, child) {
                              return Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      color,
                                      (steps[index + 1]['color'] as Color).withOpacity(0.5),
                                    ],
                                    stops: [
                                      _animCtrl.value - 0.2,
                                      _animCtrl.value + 0.2,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Card content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2333),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              step['title'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              settings.isVietnamese ? step['desc_vi'] as String : step['desc_en'] as String,
                              style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
                            ),
                            
                            // Tech stack badge
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              child: _showTechStack
                                  ? Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: color.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.terminal_rounded, size: 12, color: Colors.grey.shade400),
                                          const SizedBox(width: 6),
                                          Text(
                                            step['tech'] as String,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade300, fontFamily: 'monospace'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: steps.length,
        ),
      ),
    );
  }
}
