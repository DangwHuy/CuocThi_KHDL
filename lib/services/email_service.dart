import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  // Thay thế URL dưới đây bằng URL Google Apps Script của bạn
  static const String _googleAppsScriptUrl = 'YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE';

  static Future<void> sendNegativeFeedbackAlert({
    required String reviewText,
    required double score,
    required List<String> keywords,
  }) async {
    if (_googleAppsScriptUrl == 'YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE') {
      debugPrint('⚠️ CHÚ Ý: Tính năng gửi Email bị tắt do chưa nhập URL Google Apps Script');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(_googleAppsScriptUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'reviewText': reviewText,
          'score': score,
          'keywords': keywords.join(', '),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        debugPrint('Đã gửi yêu cầu Email thành công qua Google Apps Script!');
      } else {
        debugPrint('Lỗi HTTP khi gửi Email: \${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi API gửi Email: $e');
    }
  }
}
