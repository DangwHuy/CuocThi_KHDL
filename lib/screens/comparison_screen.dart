import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 1000;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(context, settings),
                  const SizedBox(height: 24),
                  _buildSideCards(context, settings),
                  const SizedBox(height: 40),
                  _buildTechSpecs(context, settings),
                  const SizedBox(height: 40),
                  _buildApplications(context, settings, isMobile: true),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(context, settings),
                        const SizedBox(height: 40),
                        _buildTechSpecs(context, settings),
                        const SizedBox(height: 40),
                        _buildApplications(context, settings, isMobile: false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 3,
                    child: _buildSideCards(context, settings),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, SettingsProvider settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            AppTheme.backgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              settings.isVietnamese ? 'DEEP DIVE ANALYSIS' : 'DEEP DIVE ANALYSIS',
              style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            settings.isVietnamese ? 'So sánh: FP-Growth vs Apriori' : 'Comparison: FP-Growth vs Apriori',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 42, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            settings.isVietnamese
                ? 'Phân tích hiệu suất kỹ thuật giữa hai thuật toán khai phá luật kết hợp phổ biến nhất trong khoa học dữ liệu hiện đại.'
                : 'Technical performance analysis between the two most popular association rule mining algorithms in modern data science.',
            style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSideCards(BuildContext context, SettingsProvider settings) {
    return Column(
      children: [
        _buildStatCard(
          context: context,
          title: 'FP-GROWTH EFFICIENCY',
          value: '98.2%',
          subtitle: settings.isVietnamese ? 'Tối ưu hóa cấu trúc cây FP-Tree cho tập dữ liệu lớn.' : 'Optimized FP-Tree structure for large datasets.',
          icon: Icons.bolt_rounded,
          iconColor: Colors.purpleAccent,
        ),
        const SizedBox(height: 24),
        _buildStatCard(
          context: context,
          title: 'APRIORI RELIABILITY',
          value: 'Legacy',
          subtitle: settings.isVietnamese ? 'Phù hợp cho các tập dữ liệu nhỏ với quy trình minh bạch.' : 'Suitable for small datasets with transparent processes.',
          icon: Icons.shield_outlined,
          iconColor: Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTechSpecs(BuildContext context, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(
              settings.isVietnamese ? 'Thông số kỹ thuật' : 'Technical Specifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              _buildSpecHeader(settings),
              const Divider(height: 1, color: Colors.white10),
              _buildSpecRow(
                feature: settings.isVietnamese ? 'Tạo ứng viên (Candidate Generation)' : 'Candidate Generation',
                sub: 'PROCESS METHOD',
                fpValue: 'No',
                apValue: 'Yes',
                isFpGood: true,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSpecRow(
                feature: settings.isVietnamese ? 'Quét dữ liệu (Data Scans)' : 'Data Scans',
                sub: 'DB ITERATIONS',
                fpValue: '2 Scans',
                apValue: 'Multiple',
                isFpGood: true,
                isBadge: true,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSpecProgressRow(
                feature: settings.isVietnamese ? 'Tốc độ (Speed)' : 'Speed',
                sub: 'EXECUTION TIME',
                fpLabel: 'Fast',
                apLabel: 'Slow',
                fpValue: 0.9,
                apValue: 0.3,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSpecRowText(
                feature: settings.isVietnamese ? 'Bộ nhớ (Memory Usage)' : 'Memory Usage',
                sub: 'RAM CONSUMPTION',
                fpValue: 'High (Tree based)',
                apValue: 'Low (Candidate based)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecHeader(SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              settings.isVietnamese ? 'ĐẶC ĐIỂM (FEATURE)' : 'FEATURE',
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Text(
              'FP-GROWTH',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Text(
              'APRIORI',
              style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({required String feature, required String sub, required String fpValue, required String apValue, bool isFpGood = true, bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: isBadge
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(fpValue, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontFamily: 'monospace')),
                    ),
                  )
                : Row(
                    children: [
                      Icon(isFpGood ? Icons.cancel_outlined : Icons.check_circle_outline, color: isFpGood ? Colors.redAccent : Colors.greenAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(fpValue, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
          ),
          Expanded(
            flex: 1,
            child: isBadge
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                      child: Text(apValue, style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace')),
                    ),
                  )
                : Row(
                    children: [
                      Icon(!isFpGood ? Icons.cancel_outlined : Icons.check_circle_outline, color: !isFpGood ? Colors.redAccent : Colors.greenAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(apValue, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecProgressRow({required String feature, required String sub, required String fpLabel, required String apLabel, required double fpValue, required double apValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fpValue, backgroundColor: Colors.white12, color: AppTheme.primaryColor, minHeight: 6))),
                const SizedBox(width: 12),
                Text(fpLabel, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 24), // spacing
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: apValue, backgroundColor: Colors.white12, color: Colors.greenAccent, minHeight: 6))),
                const SizedBox(width: 12),
                Text(apLabel, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRowText({required String feature, required String sub, required String fpValue, required String apValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(fpValue, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Expanded(
            flex: 1,
            child: Text(apValue, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildApplications(BuildContext context, SettingsProvider settings, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Text(
              settings.isVietnamese ? 'Ứng dụng thực tế (Applications)' : 'Real-world Applications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (isMobile)
          Column(
            children: [
              _buildAppCard(context, Icons.shopping_cart_outlined, 'Market Basket Analysis', settings.isVietnamese ? 'Phân tích hành vi mua sắm để tối ưu hóa vị trí sản phẩm và chiến dịch khuyến mãi chéo.' : 'Analyze shopping behavior to optimize product placement and cross-selling campaigns.', 'RETAIL INDUSTRY', AppTheme.primaryColor),
              const SizedBox(height: 16),
              _buildAppCard(context, Icons.health_and_safety_outlined, 'Health Care', settings.isVietnamese ? 'Sử dụng trong chẩn đoán và phát hiện triệu chứng kết hợp để dự đoán bệnh lý sớm.' : 'Used in diagnosis and detecting combined symptoms for early disease prediction.', 'MEDICAL TECH', Colors.greenAccent),
              const SizedBox(height: 16),
              _buildAppCard(context, Icons.biotech_outlined, 'Bioinformatics', settings.isVietnamese ? 'Khai thác chuỗi gen và tìm kiếm các tổ hợp protein liên quan trong nghiên cứu sinh học.' : 'Mining gene sequences and finding related protein combinations in biological research.', 'LIFE SCIENCES', Colors.orangeAccent),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildAppCard(context, Icons.shopping_cart_outlined, 'Market Basket Analysis', settings.isVietnamese ? 'Phân tích hành vi mua sắm để tối ưu hóa vị trí sản phẩm và chiến dịch khuyến mãi chéo.' : 'Analyze shopping behavior to optimize product placement and cross-selling campaigns.', 'RETAIL INDUSTRY', AppTheme.primaryColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildAppCard(context, Icons.health_and_safety_outlined, 'Health Care', settings.isVietnamese ? 'Sử dụng trong chẩn đoán và phát hiện triệu chứng kết hợp để dự đoán bệnh lý sớm.' : 'Used in diagnosis and detecting combined symptoms for early disease prediction.', 'MEDICAL TECH', Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildAppCard(context, Icons.biotech_outlined, 'Bioinformatics', settings.isVietnamese ? 'Khai thác chuỗi gen và tìm kiếm các tổ hợp protein liên quan trong nghiên cứu sinh học.' : 'Mining gene sequences and finding related protein combinations in biological research.', 'LIFE SCIENCES', Colors.orangeAccent)),
            ],
          ),
      ],
    );
  }

  Widget _buildAppCard(BuildContext context, IconData icon, String title, String desc, String tag, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
