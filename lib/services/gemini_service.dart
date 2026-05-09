import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/chart_config.dart';

class GeminiResponse {
  final String text;
  final ChartConfig? chartConfig;

  GeminiResponse({required this.text, this.chartConfig});
}

class GeminiService {
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY', 
    defaultValue: 'AIzaSyB58IFoPoCTtVjHH2DMDXGuA00nzAqzCrk' // WARNING: Xóa chuỗi này trước khi push lên GitHub!
  );
  static const String _model = 'gemini-2.0-flash';
  
  String get _endpoint =>
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_model:generateContent?key=$_apiKey';

  final List<Map<String, dynamic>> _history = [];

  Future<GeminiResponse> sendMessage({
    required String userMessage,
    required String dataContext,
  }) async {
    final systemPrompt = '''
Bạn là AI analyst chuyên nghiệp cho hệ thống phân tích bán lẻ DaklakAgent.
Dưới đây là dữ liệu thực tế từ hệ thống của cửa hàng:

$dataContext

NHIỆM VỤ:
- Trả lời các câu hỏi về xu hướng bán hàng, phân khúc khách hàng, dự báo và bất thường.
- Luôn sử dụng số liệu cụ thể từ context đã cung cấp.
- Trả lời bằng ngôn ngữ người dùng đang sử dụng (Tiếng Việt hoặc Tiếng Anh).

=== QUAN TRỌNG: FORMAT RESPONSE ===
Mỗi response PHẢI có 2 phần, phân tách bằng "---CHART---":

Phần 1 (TRƯỚC ---CHART---): Text trả lời bình thường. Ngắn gọn, có số liệu, có gợi ý hành động.

Phần 2 (SAU ---CHART---): JSON cấu hình chart.
Nếu KHÔNG cần chart: để trống sau ---CHART---
Nếu CÓ chart, dùng đúng 1 trong các format sau:

BAR CHART:
{"type": "bar", "title": "Tiêu đề", "data": [{"label": "A", "value": 10, "color": "#534AB7"}], "xAxisLabel": "X", "yAxisLabel": "Y"}

LINE CHART:
{"type": "line", "title": "Tiêu đề", "data": [{"label": "Jan", "value": 100}], "xAxisLabel": "X", "yAxisLabel": "Y", "color": "#534AB7"}

PIE CHART:
{"type": "pie", "title": "Tiêu đề", "data": [{"label": "A", "value": 30, "color": "#534AB7"}]}

COMBO CHART (Bar + Line):
{"type": "combo", "title": "Tiêu đề", "xAxisLabel": "Tháng", "colors": ["#6366F1", "#10B981"], "data": [{"label": "Jan", "value": 100, "values": [120]}]}
(Chú ý: 'value' dành cho cột, 'values' (list) dành cho đường)

QUY TẮC CHỌN CHART:
- Top products / so sánh sản phẩm → bar chart
- Xu hướng 12 tháng / thời gian → line chart hoặc bar chart (PHẢI output đủ 12 tháng)
- RFM segments / phân bổ / tỷ lệ % → pie chart
- So sánh 2 năm (2014 vs 2015) → grouped_bar
- Dự báo (Forecast) / What-If / So sánh xu hướng → combo chart (Cột 'value' là thực tế, Đường 'values' là dự báo/mục tiêu)
- Báo cáo tổng quan (Report) → grouped_bar (Tổng hợp các chỉ số chính)

QUY TẮC TRÌNH BÀY TEXT (Đặc biệt cho Báo cáo):
- Sử dụng markdown cơ bản (như **in đậm** cho tiêu đề hoặc ý chính).
- Trình bày rõ ràng bằng gạch đầu dòng nếu là báo cáo.
- Luôn điền 'xAxisLabel' và 'yAxisLabel' cho chart.
''';

    _history.add({
      'role': 'user',
      'parts': [{'text': userMessage}]
    });

    final body = {
      'system_instruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 2048,
        'topP': 0.8,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] == null || data['candidates'].isEmpty) {
          throw 'AI không trả về kết quả (Candidate empty)';
        }
        final fullText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        
        // Split response
        final parts = fullText.split('---CHART---');
        final textResponse = parts[0].trim();
        final chartJson = parts.length > 1 ? parts[1].trim() : '';

        ChartConfig? chartConfig;
        if (chartJson.isNotEmpty) {
          try {
            final jsonStart = chartJson.indexOf('{');
            final jsonEnd = chartJson.lastIndexOf('}');
            if (jsonStart != -1 && jsonEnd != -1) {
              final cleanJson = chartJson.substring(jsonStart, jsonEnd + 1);
              chartConfig = ChartConfig.tryParse(cleanJson);
            }
          } catch (_) {}
        }

        _history.add({
          'role': 'model',
          'parts': [{'text': fullText}]
        });

        if (_history.length > 20) {
          _history.removeRange(0, 2);
        }

        return GeminiResponse(text: textResponse, chartConfig: chartConfig);
      } else {
        final errorData = jsonDecode(response.body);
        String message = errorData['error']?['message'] ?? 'Unknown Error';
        throw 'Gemini Error (${response.statusCode}): $message';
      }
    } catch (e) {
      print('Gemini Service Error: $e');
      rethrow;
    }
  }

  void clearHistory() {
    _history.clear();
  }
}
