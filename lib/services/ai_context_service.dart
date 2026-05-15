import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIContextService {
  static Future<String> buildContext([String? query, Function(String)? onProgress]) async {
    final context = StringBuffer();
    
    onProgress?.call('Initializing data context analysis...');
    context.writeln('=== KHDL DS SYSTEM: FULL DATA CONTEXT ===');

    onProgress?.call('Loading system architecture and features...');
    context.writeln('''
--- SYSTEM FEATURES & NAVIGATION ---
Bạn đang là AI Agent (Trợ lý AI) tích hợp bên trong một Hệ thống Dashboard Phân tích Dữ liệu.
Hệ thống của chúng ta có các chức năng (màn hình) sau ở thanh menu (Sidebar):
1. Tổng quan: Xem chỉ số tổng quát.
2. AI Gợi ý: Gợi ý hành động kinh doanh tự động.
3. So sánh: So sánh hiệu quả các chiến dịch/sản phẩm.
4. Dữ liệu: Duyệt dữ liệu thô.
5. RFM: Phân khúc khách hàng theo mô hình RFM.
6. Mùa vụ: Phân tích xu hướng theo thời gian.
7. Phân cụm: Thuật toán gom cụm (K-Means/DBSCAN).
8. Danh mục: Phân tích các ngành hàng.
9. Bất thường: Phát hiện giao dịch/khách hàng bất thường (Anomaly Detection).
10. Dự báo: Dự báo doanh thu/xu hướng tương lai (ARIMA/Prophet).
11. Kiến trúc: Sơ đồ luồng dữ liệu của hệ thống.
12. Live: Dữ liệu thời gian thực.
13. NLP: Phân tích cảm xúc đánh giá khách hàng.
14. AI Agent: Chính là bạn - nơi người dùng đang chat.
15. Thuật toán: Thuyết minh các thuật toán KHDL đã dùng.

Lưu ý: Khi người dùng hỏi hệ thống có chức năng gì, hãy tự tin trả lời dựa trên danh sách này.
''');

    onProgress?.call('Loading sales and product trends...');
    await _appendEDAData(context);
    
    onProgress?.call('Analyzing category distributions...');
    await _appendCategoryData(context);
    
    onProgress?.call('Processing customer RFM segments...');
    await _appendRFMData(context);
    
    onProgress?.call('Evaluating seasonality patterns...');
    await _appendSeasonalityData(context);
    
    onProgress?.call('Detecting data anomalies...');
    await _appendAnomalyData(context);

    onProgress?.call('Fetching NLP Sentiment data from Firebase...');
    await _appendNLPData(context);

    onProgress?.call('Context construction complete.');
    return context.toString();
  }

  static Future<void> _appendEDAData(StringBuffer sb) async {
    try {
      final eda = json.decode(await rootBundle.loadString('assets/data/eda_results.json'));
      sb.writeln('\n--- SALES & PRODUCTS ---');
      
      final allItemsMap = eda['all_items'] as Map;
      sb.writeln('[Total_Unique_Products]: ${allItemsMap.length} mặt hàng');
      
      final allItems = allItemsMap.entries.map((e) => '${e.key}:${e.value}').join('|');
      sb.writeln('[All_Products_Inventory]: $allItems');
      
      final trends = eda['monthly_trend'] as Map;
      final tAll = trends.entries.map((e) => '${e.key}:${e.value}').join(',');
      sb.writeln('[Monthly_Sales_Trend_All]: $tAll');
      
      final baskets = eda['basket_sizes'] as Map;
      final bsz = baskets.entries.map((e) => 'Size${e.key}:${e.value}').join(',');
      sb.writeln('[Basket_Sizes]: $bsz');
    } catch (e) {
      sb.writeln('Error loading EDA data: $e');
    }
  }

  static Future<void> _appendCategoryData(StringBuffer sb) async {
    try {
      final cat = json.decode(await rootBundle.loadString('assets/data/category_data.json'));
      sb.writeln('\n--- CATEGORIES ---');
      final cats = (cat['categories'] as List).map((c) {
        final top3 = (c['top_3'] as List).map((t) => '${t['name']}(${t['pct_in_category']}%)').join(',');
        return '${c['name_en']}(${c['name_vi']}): Total=${c['total']}, Pct=${c['pct']}%, Top3=[$top3]';
      }).join(' | ');
      sb.writeln('[Category_Breakdown]: $cats');
    } catch (_) {}
  }

  static Future<void> _appendRFMData(StringBuffer sb) async {
    try {
      final rfm = json.decode(await rootBundle.loadString('assets/data/rfm_data.json'));
      sb.writeln('\n--- CUSTOMER SEGMENTS (RFM) ---');
      final segs = (rfm['segments'] as List).map((s) => '${s['name']}: ${s['count']} members (${s['pct']}%)').join(' | ');
      sb.writeln('[Segments]: $segs');
      if (rfm.containsKey('stats')) {
        final stats = rfm['stats'];
        sb.writeln('[RFM_Stats]: TotalCust=${stats['total_customers']}, VIPs=${stats['champions_count']}, Lost=${stats['lost_count']}');
      }
    } catch (_) {}
  }

  static Future<void> _appendSeasonalityData(StringBuffer sb) async {
    try {
      final sea = json.decode(await rootBundle.loadString('assets/data/seasonality_data.json'));
      sb.writeln('\n--- SEASONALITY & TIMING ---');
      if (sea.containsKey('stats')) {
        final stats = sea['stats'];
        sb.writeln('[Seasonality_Stats]: Peak_Month=${stats['peak_month']} (${stats['peak_count']} txns), YoY_Growth=${stats['yoy_growth']}%');
      }
      
      if (sea.containsKey('day_of_week')) {
        final dow = (sea['day_of_week'] as List).map((d) => '${d['name_en']}:${d['count']}').join(',');
        sb.writeln('[Weekly_Pattern]: $dow');
      }
    } catch (_) {}
  }

  static Future<void> _appendAnomalyData(StringBuffer sb) async {
    try {
      final ano = json.decode(await rootBundle.loadString('assets/data/anomaly_data.json'));
      sb.writeln('\n--- ANOMALIES & ALERTS ---');
      
      if (ano.containsKey('daily_anomalies')) {
        final list = (ano['daily_anomalies'] as List).map((a) => '${a['date']} (${a['type']}): Count=${a['count']}, ExpMax=${a['expected_max']}').join(' | ');
        sb.writeln('[Daily_Anomalies]: $list');
      }
      
      if (ano.containsKey('customer_anomalies')) {
        final custList = (ano['customer_anomalies'] as List).take(10).map((a) => 'Mem${a['member_id']}: ${a['reason_en']} (Txns=${a['total_transactions']}, AvgBskt=${a['avg_basket']})').join(' | ');
        sb.writeln('[Customer_Anomalies (Top 10)]: $custList');
      }
    } catch (_) {}
  }

  static Future<void> _appendNLPData(StringBuffer sb) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ai_reviews').get();
      if (snapshot.docs.isEmpty) return;

      int positive = 0;
      int negative = 0;
      int neutral = 0;
      Map<String, int> keywordCounts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final sentiment = data['sentiment'] as String?;
        if (sentiment == 'Positive') positive++;
        else if (sentiment == 'Negative') negative++;
        else if (sentiment == 'Neutral') neutral++;
        // Count anything else as neutral if needed, or just ignore

        if (data['keywords'] is List) {
          for (var kw in data['keywords']) {
            final keyword = kw.toString().toLowerCase().trim();
            if (keyword.isNotEmpty) {
              keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
            }
          }
        }
      }

      final topKeywords = keywordCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top10Keywords = topKeywords.take(10).map((e) => '${e.key}(${e.value})').join(', ');

      sb.writeln('\n--- CUSTOMER FEEDBACK & NLP SENTIMENT ---');
      sb.writeln('[Sentiment_Distribution]: Positive=$positive, Negative=$negative, Neutral=$neutral');
      sb.writeln('[Top_Keywords]: $top10Keywords');
      sb.writeln('[Total_Reviews]: ${snapshot.docs.length}');
      
      sb.writeln('''
BẮT BUỘC: Khi người dùng yêu cầu "vẽ biểu đồ" hoặc "trình bày biểu đồ" về dữ liệu NLP này, bạn PHẢI nối thêm phần cấu hình JSON ở cuối câu trả lời theo đúng định dạng sau:
---CHART---
{"type": "pie", "title": "Phân bổ Cảm xúc Khách hàng", "data": [{"label": "Tích cực", "value": $positive}, {"label": "Tiêu cực", "value": $negative}, {"label": "Trung tính", "value": $neutral}]}
''');
    } catch (e) {
      sb.writeln('Error loading NLP data from Firebase: $e');
    }
  }
}
