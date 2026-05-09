import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../models/chart_config.dart';

class ChatStorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? 'guest_user';

  // Lưu một tin nhắn mới
  Future<void> saveMessage(ChatMessage message) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('ai_chats')
          .doc(message.id)
          .set({
        'content': message.content,
        'role': message.role.toString(),
        'timestamp': message.timestamp,
        'chartConfig': message.chartConfig != null ? _chartConfigToMap(message.chartConfig!) : null,
        'status': message.status.toString(),
      });
    } catch (e) {
      print('Error saving message to Firestore: $e');
    }
  }

  // Tải lịch sử chat
  Future<List<ChatMessage>> loadChatHistory() async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('ai_chats')
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          content: data['content'],
          role: _parseRole(data['role']),
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          chartConfig: data['chartConfig'] != null ? _mapToChartConfig(data['chartConfig']) : null,
          status: _parseStatus(data['status']),
        );
      }).toList();
    } catch (e) {
      print('Error loading chat history: $e');
      return [];
    }
  }

  // Xóa lịch sử chat
  Future<void> clearHistory() async {
    final snapshots = await _db
        .collection('users')
        .doc(_userId)
        .collection('ai_chats')
        .get();
    
    if (snapshots.docs.isEmpty) return;
    
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Map<String, dynamic> _chartConfigToMap(ChartConfig config) {
    return {
      'type': config.type,
      'title': config.title,
      'xAxisLabel': config.xAxisLabel,
      'yAxisLabel': config.yAxisLabel,
      'data': config.data.map((p) => {
        'label': p.label,
        'value': p.value,
        'values': p.values,
        'color': p.color,
      }).toList(),
      'colors': config.colors,
      'color': config.color,
      'series': config.series,
    };
  }

  // Chuyển đổi từ Map sang ChartConfig (thay vì dùng tryParse string)
  ChartConfig _mapToChartConfig(Map<String, dynamic> json) {
    return ChartConfig(
      type: json['type'] ?? 'bar',
      title: json['title'] ?? '',
      data: (json['data'] as List?)
              ?.map((e) => ChartDataPoint.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      xAxisLabel: json['xAxisLabel'],
      yAxisLabel: json['yAxisLabel'],
      color: json['color'],
      series: (json['series'] as List?)?.map((e) => e.toString()).toList(),
      colors: (json['colors'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  MessageRole _parseRole(String? roleStr) {
    if (roleStr == 'MessageRole.assistant') return MessageRole.assistant;
    if (roleStr == 'MessageRole.system') return MessageRole.system;
    return MessageRole.user;
  }

  MessageStatus _parseStatus(String? statusStr) {
    if (statusStr == 'MessageStatus.error') return MessageStatus.error;
    if (statusStr == 'MessageStatus.sending') return MessageStatus.sending;
    return MessageStatus.done; // Thay cho 'sent' và mặc định không null
  }
}
