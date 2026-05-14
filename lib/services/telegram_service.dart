import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TelegramService {
  // 1. Điền Bot Token lấy từ @BotFather
  static const String _botToken = '';
  
  // 2. Điền Chat ID của bạn (lấy từ @userinfobot)
  static const String _chatId = '';

  static Future<void> sendAlert({
    required String reviewText,
    required double score,
    required List<String> keywords,
  }) async {
    if (_botToken == 'YOUR_BOT_TOKEN_HERE' || _chatId == 'YOUR_CHAT_ID_HERE') {
      debugPrint('⚠️ CHÚ Ý: Tính năng gửi Telegram bị tắt do chưa cấu hình Token và Chat ID');
      return;
    }

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
    
    final message = '''
🚨 *CẢNH BÁO PHẢN HỒI TIÊU CỰC* 🚨

*Nội dung:* _"$reviewText"_
*Độ tự tin của AI:* ${(score * 100).toStringAsFixed(0)}%
*Từ khóa bắt được:* ${keywords.join(', ')}

👉 _Hệ thống tự động phát hiện trải nghiệm tồi tệ. Vui lòng mở Dashboard để xử lý!_
''';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _chatId,
          'text': message,
          'parse_mode': 'Markdown',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Đã gửi cảnh báo qua Telegram thành công!');
      } else {
        debugPrint('❌ Lỗi Telegram API: \${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi Telegram: $e');
    }
  }
}
