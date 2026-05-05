import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

class DataExplorerScreen extends StatefulWidget {
  final Map<String, dynamic> allItems;
  const DataExplorerScreen({super.key, required this.allItems});

  @override
  State<DataExplorerScreen> createState() => _DataExplorerScreenState();
}

class _DataExplorerScreenState extends State<DataExplorerScreen> {
  late List<MapEntry<String, dynamic>> _filteredItems;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'desc'; // 'desc', 'asc', 'alpha'

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.allItems.entries.toList();
    _sortItems();
  }

  void _sortItems() {
    setState(() {
      if (_sortBy == 'desc') {
        _filteredItems.sort((a, b) => b.value.compareTo(a.value));
      } else if (_sortBy == 'asc') {
        _filteredItems.sort((a, b) => a.value.compareTo(b.value));
      } else {
        _filteredItems.sort((a, b) => a.key.compareTo(b.key));
      }
    });
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredItems = widget.allItems.entries
          .where((entry) => 
              entry.key.toLowerCase().contains(query.toLowerCase()) ||
              DataService.translateItem(entry.key).toLowerCase().contains(query.toLowerCase()))
          .toList();
      _sortItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final maxSales = widget.allItems.values.fold(0, (max, e) => e > max ? e : max);

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
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
                settings.isVietnamese ? 'Kho Dữ Liệu' : 'Data Explorer',
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
                      ? 'Thống kê chi tiết doanh số của toàn bộ 167 mặt hàng trong tập dữ liệu.'
                      : 'Detailed sales statistics for all 167 items in the dataset.',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterSearch,
                          decoration: InputDecoration(
                            hintText: settings.isVietnamese ? 'Tìm kiếm sản phẩm...' : 'Search items...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _sortBy,
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(value: 'desc', child: Text(settings.isVietnamese ? 'Nhiều nhất' : 'Highest')),
                            DropdownMenuItem(value: 'asc', child: Text(settings.isVietnamese ? 'Ít nhất' : 'Lowest')),
                            DropdownMenuItem(value: 'alpha', child: Text(settings.isVietnamese ? 'A-Z' : 'A-Z')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              _sortBy = val;
                              _sortItems();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = _filteredItems[index];
                  final sales = entry.value;
                  final percentage = sales / maxSales;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                settings.isVietnamese ? DataService.translateItem(entry.key) : entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Text(
                              '$sales ${settings.isVietnamese ? "GD" : "txns"}',
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.lerp(Colors.blue, AppTheme.primaryColor, percentage) ?? AppTheme.primaryColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _filteredItems.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}
