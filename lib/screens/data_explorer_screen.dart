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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.isVietnamese ? 'Kho Dữ Liệu Sản Phẩm' : 'Product Data Explorer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  settings.isVietnamese 
                    ? 'Thống kê chi tiết doanh số của toàn bộ 167 mặt hàng trong tập dữ liệu.'
                    : 'Detailed sales statistics for all 167 items in the dataset.',
                  style: const TextStyle(color: Colors.grey),
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
                          DropdownMenuItem(value: 'desc', child: Text(settings.isVietnamese ? 'Bán chạy' : 'Top Sales')),
                          DropdownMenuItem(value: 'asc', child: Text(settings.isVietnamese ? 'Bán ít' : 'Low Sales')),
                          DropdownMenuItem(value: 'alpha', child: Text(settings.isVietnamese ? 'Tên A-Z' : 'Name A-Z')),
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
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final entry = _filteredItems[index];
                final progress = entry.value / maxSales;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                            '${entry.value} ${settings.isVietnamese ? 'đã bán' : 'sold'}',
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: AppTheme.primaryColor,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
