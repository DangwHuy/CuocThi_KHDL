import 'dart:convert';

class ChartDataPoint {
  final String label;
  final double value;
  final String? color;
  final List<double>? values; // for grouped_bar

  ChartDataPoint({
    required this.label,
    required this.value,
    this.color,
    this.values,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      color: json['color'],
      values: (json['values'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}

class ChartConfig {
  final String type; // "bar" | "line" | "pie" | "grouped_bar"
  final String title;
  final List<ChartDataPoint> data;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final String? color; // for line chart
  final List<String>? series; // for grouped_bar
  final List<String>? colors; // for grouped_bar

  ChartConfig({
    required this.type,
    required this.title,
    required this.data,
    this.xAxisLabel,
    this.yAxisLabel,
    this.color,
    this.series,
    this.colors,
  });

  factory ChartConfig.fromMap(Map<String, dynamic> json) {
    final typeRaw = (json['type'] ?? 'bar').toString().toLowerCase();
    final type = (typeRaw == 'groupedbar' || typeRaw == 'grouped_bar') 
        ? 'grouped_bar' 
        : typeRaw;
        
    final series = (json['series'] as List?)?.map((e) => e.toString()).toList();
    
    final data = (json['data'] as List?)?.map((item) {
      final map = item as Map<String, dynamic>;
      
      // Extract value
      double value = 0.0;
      if (map.containsKey('value')) {
        value = (map['value'] as num).toDouble();
      } else if (series != null && series.isNotEmpty && map.containsKey(series[0])) {
        value = (map[series[0]] as num?)?.toDouble() ?? 0.0;
      }

      // Extract grouped values
      List<double>? values;
      if (map['values'] != null) {
        values = (map['values'] as List).map((e) => (e as num).toDouble()).toList();
      } else if (series != null && series.isNotEmpty) {
        values = series.map((s) => (map[s] as num?)?.toDouble() ?? 0.0).toList();
      }

      return ChartDataPoint(
        label: map['label']?.toString() ?? '',
        value: value,
        color: map['color'],
        values: values,
      );
    }).toList() ?? [];

    return ChartConfig(
      type: type,
      title: json['title'] ?? '',
      data: data,
      xAxisLabel: json['xAxisLabel'],
      yAxisLabel: json['yAxisLabel'],
      color: json['color'],
      series: series,
      colors: (json['colors'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  static ChartConfig? tryParse(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      if (json is Map<String, dynamic>) {
        return ChartConfig.fromMap(json);
      }
      return null;
    } catch (e) {
      print('ChartConfig parse error: $e');
      return null;
    }
  }
}
