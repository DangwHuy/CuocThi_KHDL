import 'dart:convert';
import 'package:flutter/services.dart';

class AIContextService {
  static Future<String> buildContext([String? query]) async {
    final context = StringBuffer();
    
    context.writeln('=== KHDL DS SYSTEM: FULL DATA CONTEXT ===');

    await _appendEDAData(context);
    await _appendCategoryData(context);
    await _appendRFMData(context);
    await _appendSeasonalityData(context);
    await _appendAnomalyData(context);

    return context.toString();
  }

  static Future<void> _appendEDAData(StringBuffer sb) async {
    try {
      final eda = json.decode(await rootBundle.loadString('assets/data/eda_results.json'));
      sb.writeln('\n--- SALES & PRODUCTS ---');
      final allItems = (eda['all_items'] as Map).entries.map((e) => '${e.key}:${e.value}').join('|');
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
}
