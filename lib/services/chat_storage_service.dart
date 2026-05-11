import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../models/chart_config.dart';

class ChatStorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? 'guest_user';
  
  Stream<User?> authStateChanges() => _auth.authStateChanges();

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
        'imageUrl': message.imageUrl,
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

      final messages = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          return ChatMessage(
            id: doc.id,
            content: data['content'] ?? '',
            role: _parseRole(data['role']),
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            chartConfig: data['chartConfig'] != null ? _mapToChartConfig(data['chartConfig']) : null,
            imageUrl: data['imageUrl'],
            status: _parseStatus(data['status']),
          );
        } catch (e) {
          print('Error parsing message ${doc.id}: $e');
          return null;
        }
      }).where((m) => m != null).cast<ChatMessage>().toList();

      print('Loaded ${messages.length} messages for user: $_userId');
      return messages;
    } catch (e) {
      print('Error loading chat history from Firestore: $e');
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
    return ChartConfig.fromMap(json);
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
