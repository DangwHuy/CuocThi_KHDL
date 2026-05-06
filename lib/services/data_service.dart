import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class DataService {
  static Future<List<List<dynamic>>> loadCSV() async {
    try {
      final rawData = await rootBundle.loadString('assets/data/Groceries_dataset.csv');
      List<List<dynamic>> listData = const CsvToListConverter().convert(rawData);
      return listData;
    } catch (e) {
      print('Error loading CSV: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> loadEDA() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/eda_results.json');
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading EDA: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> loadRFM() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/rfm_data.json');
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading RFM: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> loadSeasonality() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/seasonality_data.json');
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading Seasonality: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> loadClustering() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/clustering_data.json');
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading Clustering: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> loadCategory() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/category_data.json');
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading Category: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> loadAnomaly() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/anomaly_data.json');
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading Anomaly: $e');
      return {};
    }
  }

  static Map<String, int> analyzeTopItems(List<List<dynamic>> data) {
    if (data.isEmpty) return {};
    
    final items = data.skip(1).map((row) => row[2].toString()).toList();
    
    var counts = <String, int>{};
    for (var item in items) {
      final translatedItem = translateItem(item);
      counts[translatedItem] = (counts[translatedItem] ?? 0) + 1;
    }
    
    var sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    return Map.fromEntries(sortedEntries.take(10));
  }

  static String translateItem(String item) {
    const dictionary = {
      'whole milk': 'Sữa tươi',
      'other vegetables': 'Rau củ khác',
      'rolls/buns': 'Bánh mì cuộn',
      'soda': 'Nước ngọt',
      'yogurt': 'Sữa chua',
      'root vegetables': 'Củ quả',
      'tropical fruit': 'Trái cây nhiệt đới',
      'bottled water': 'Nước đóng chai',
      'sausage': 'Xúc xích',
      'pastry': 'Bánh ngọt',
      'citrus fruit': 'Trái cây có múi',
      'pip fruit': 'Trái cây có hạt',
      'shopping bags': 'Túi mua sắm',
      'canned beer': 'Bia lon',
      'bottled beer': 'Bia chai',
      'whipped/sour cream': 'Kem tươi/chua',
      'newspapers': 'Báo chí',
      'frankfurter': 'Xúc xích Đức',
      'brown bread': 'Bánh mì đen',
      'pork': 'Thịt lợn',
      'beef': 'Thịt bò',
      'curd': 'Sữa đông',
      'butter': 'Bơ',
      'domestic eggs': 'Trứng gà',
      'frozen vegetables': 'Rau củ đông lạnh',
      'fruit/vegetable juice': 'Nước ép trái cây',
      'specialty chocolate': 'Sô-cô-la đặc biệt',
      'flour': 'Bột mì',
      'beverages': 'Đồ uống',
      'napkins': 'Khăn giấy',
      'processed cheese': 'Phô mai chế biến',
      'hard cheese': 'Phô mai cứng',
      'soft cheese': 'Phô mai mềm',
      'sugar': 'Đường',
      'white bread': 'Bánh mì trắng',
      'chewing gum': 'Kẹo cao su',
      'sliced cheese': 'Phô mai thái lát',
      'candy': 'Kẹo',
      'packaged fruit/vegetables': 'Trái cây/Rau đóng gói',
      'seasonal products': 'Sản phẩm theo mùa',
      'dessert': 'Tráng miệng',
      'frozen meals': 'Bữa ăn đông lạnh',
      'herbs': 'Thảo mộc',
      'cat food': 'Thức ăn cho mèo',
      'oil': 'Dầu ăn',
      'coffee': 'Cà phê',
      'grapes': 'Nho',
      'chicken': 'Thịt gà',
      'onions': 'Hành tây',
      'butter milk': 'Sữa bơ',
      'meat': 'Thịt các loại',
      'berries': 'Quả mọng',
      'hamburger meat': 'Thịt băm hamburger',
      'red/blush wine': 'Rượu vang đỏ',
      'chocolate': 'Sô-cô-la',
      'margarine': 'Bơ thực vật'
    };
    
    return dictionary[item.toLowerCase()] ?? item;
  }

  static double getMockPrice(String item) {
    final predefined = {
      'whole milk': 1.5,
      'other vegetables': 2.0,
      'rolls/buns': 1.0,
      'soda': 1.2,
      'yogurt': 1.8,
      'bottled water': 0.8,
      'sausage': 3.5,
      'tropical fruit': 2.5,
      'root vegetables': 2.2,
      'beef': 5.0,
      'pork': 4.0,
      'chicken': 3.8,
    };
    if (predefined.containsKey(item.toLowerCase())) {
      return predefined[item.toLowerCase()]!;
    }
    // Generate a consistent pseudo-random price between $0.50 and $9.50
    final hash = item.hashCode.abs();
    final price = 0.5 + (hash % 90) / 10.0;
    return price;
  }

  static String formatPrice(double priceInUSD, bool isVi) {
    if (isVi) {
      final vnd = (priceInUSD * 25000).round();
      final str = vnd.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
      return '$str ₫';
    } else {
      return '\$${priceInUSD.toStringAsFixed(2)}';
    }
  }
}
