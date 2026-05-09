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

  static ChartConfig? tryParse(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return ChartConfig(
        type: json['type'] ?? 'bar',
        title: json['title'] ?? '',
        data: (json['data'] as List?)
                ?.map((e) => ChartDataPoint.fromJson(e))
                .toList() ??
            [],
        xAxisLabel: json['xAxisLabel'],
        yAxisLabel: json['yAxisLabel'],
        color: json['color'],
        series: (json['series'] as List?)?.map((e) => e.toString()).toList(),
        colors: (json['colors'] as List?)?.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      print('ChartConfig parse error: $e');
      return null;
    }
  }
}
