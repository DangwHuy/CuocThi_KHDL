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
    defaultValue: '' // WARNING: Xóa chuỗi này trước khi push lên GitHub!
  );
  static const String _model = 'gemini-2.0-flash';
  
  String get _endpoint =>
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_model:generateContent?key=$_apiKey';

  final List<Map<String, dynamic>> _history = [];

  Future<GeminiResponse> sendMessage({
    required String userMessage,
    required String dataContext,
    String? base64Image,
  }) async {
    final systemPrompt = '''
Bạn là AI analyst chuyên nghiệp cho hệ thống phân tích bán lẻ và giao dịch
Dưới đây là dữ liệu thực tế từ hệ thống của cửa hàng:

$dataContext

NHIỆM VỤ:
- Trả lời các câu hỏi về xu hướng bán hàng, phân khúc khách hàng, dự báo và bất thường.
- Nếu người dùng gửi hình ảnh, hãy phân tích hình ảnh đó (đặc biệt là các biểu đồ) và đối chiếu với dữ liệu hệ thống.
- Luôn sử dụng số liệu cụ thể từ context đã cung cấp.
- Trả lời bằng ngôn ngữ người dùng đang sử dụng (Tiếng Việt hoặc Tiếng Anh).

=== QUAN TRỌNG: FORMAT RESPONSE ===
Mỗi response PHẢI có 2 phần, phân tách bằng "---CHART---":

Phần 1 (TRƯỚC ---CHART---): Text trả lời bình thường. Ngắn gọn, có số liệu, có gợi ý hành động.

Phần 2 (SAU ---CHART---): JSON cấu hình chart.
Sử dụng format chuẩn: {"type": "bar", "title": "...", "data": [{"label": "A", "value": 10}], "xAxisLabel": "X", "yAxisLabel": "Y"}
''';

    final List<Map<String, dynamic>> currentParts = [
      {'text': userMessage}
    ];

    if (base64Image != null) {
      currentParts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Image,
        }
      });
    }

    _history.add({
      'role': 'user',
      'parts': currentParts
    });

    final body = {
      'system_instruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 4096,
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

  Future<GeminiResponse> analyzeImage({
    required String base64Image,
    required String userPrompt,
    required String dataContext,
  }) async {
    final systemPrompt = '''
Bạn là AI analyst chuyên nghiệp. 
NHIỆM VỤ:
1. Nhìn vào hình ảnh biểu đồ được cung cấp.
2. Trích xuất dữ liệu từ hình ảnh đó (label, value).
3. Đối chiếu với dữ liệu ngữ cảnh hệ thống:
$dataContext

=== QUAN TRỌNG: FORMAT RESPONSE ===
Mỗi response PHẢI có 2 phần, phân tách chính xác bằng chuỗi "---CHART---":
Phần 1: Nhận xét chi tiết về hình ảnh và dữ liệu trích xuất được.
Phần 2: JSON cấu hình biểu đồ.

BẮT BUỘC sử dụng các format JSON sau đây (không được tự ý thay đổi cấu trúc):

BAR CHART:
{"type": "bar", "title": "Tiêu đề", "data": [{"label": "A", "value": 10}], "xAxisLabel": "X", "yAxisLabel": "Y"}

LINE CHART:
{"type": "line", "title": "Tiêu đề", "data": [{"label": "Jan", "value": 100}], "xAxisLabel": "X", "yAxisLabel": "Y"}

PIE CHART:
{"type": "pie", "title": "Tiêu đề", "data": [{"label": "A", "value": 30}]}
''';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': "$systemPrompt\n\nCâu hỏi: $userPrompt"},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 2048,
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
        final fullText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        
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

        return GeminiResponse(text: textResponse, chartConfig: chartConfig);
      } else {
        throw 'Gemini Image Error (${response.statusCode}): ${response.body}';
      }
    } catch (e) {
      print('Gemini Image Analysis Error: $e');
      rethrow;
    }
  }
}
