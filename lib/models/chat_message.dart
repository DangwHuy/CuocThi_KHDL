import 'chart_config.dart';

enum MessageRole { user, assistant, system }
enum MessageStatus { sending, done, error }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final MessageStatus status;
  final DateTime timestamp;
  final List<String>? quickReplySuggestions;
  final ChartConfig? chartConfig;
  final String? imageUrl;
  final String? localImagePath;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    this.status = MessageStatus.done,
    required this.timestamp,
    this.quickReplySuggestions,
    this.chartConfig,
    this.imageUrl,
    this.localImagePath,
  });
}
