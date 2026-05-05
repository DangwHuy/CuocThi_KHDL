import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isMobile ? 60 : 100,
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
                settings.isVietnamese ? 'Cài đặt' : 'Settings',
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
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle(settings.isVietnamese ? 'Giao diện' : 'Appearance', context),
                Card(
                  color: AppTheme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Icon(
                      settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(settings.isVietnamese ? 'Chế độ tối' : 'Dark Mode'),
                    trailing: Switch(
                      value: settings.isDarkMode,
                      onChanged: (_) => settings.toggleTheme(),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(settings.isVietnamese ? 'Ngôn ngữ' : 'Language', context),
                Card(
                  color: AppTheme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.language_rounded, color: AppTheme.secondaryColor),
                    title: Text(settings.isVietnamese ? 'Tiếng Việt' : 'Vietnamese'),
                    trailing: TextButton(
                      onPressed: () => settings.toggleLanguage(),
                      child: Text(
                        settings.isVietnamese ? 'Đổi sang English' : 'Switch to Vietnamese',
                        style: const TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Phiên bản 1.0.0\nCuộc thi Khoa học Dữ liệu 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
