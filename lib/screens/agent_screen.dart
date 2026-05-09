import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/ai_context_service.dart';
import '../services/gemini_service.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dynamic_chart_widget.dart';
import '../widgets/chart_panel.dart';
import '../models/chart_config.dart';
import '../services/chat_storage_service.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final ChatStorageService _storageService = ChatStorageService();
  bool _isTyping = false;
  
  ChartConfig? _currentChart;
  final List<ChartConfig> _chartHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistoryFromFirestore();
  }

  Future<void> _loadHistoryFromFirestore() async {
    final history = await _storageService.loadChatHistory();
    if (mounted) {
      setState(() {
        if (history.isEmpty) {
          _addSystemMessage();
        } else {
          _messages.addAll(history);
          // Khôi phục biểu đồ mới nhất từ lịch sử
          for (var msg in history.reversed) {
            if (msg.chartConfig != null) {
              _currentChart = msg.chartConfig;
              break;
            }
          }
          // Khôi phục danh sách history biểu đồ
          _chartHistory.addAll(history
              .where((m) => m.chartConfig != null)
              .map((m) => m.chartConfig!));
        }
      });
      _scrollToBottom();
    }
  }

  void _addSystemMessage() {
    final msg = ChatMessage(
      id: DateTime.now().toString(),
      content: 'Xin chào! Tôi là trợ lý phân tích dữ liệu chuyên sâu (Data Analyst). Tôi đã sẵn sàng phân tích, dự báo (what-if) và tự động tạo báo cáo từ dữ liệu của bạn.',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      quickReplySuggestions: [
        'Dự báo doanh thu 3 tháng tới nếu tăng 15%?',
        'Tạo báo cáo hiệu quả kinh doanh 2015',
        'Top 5 sản phẩm bán chạy nhất?',
        'Nguyên nhân sụt giảm giao dịch tháng 12?'
      ],
    );
    if (mounted) {
      setState(() {
        _messages.add(msg);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    _controller.clear();
    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();
    _storageService.saveMessage(userMsg); // Lưu tin nhắn User vào Firestore

    try {
      final dataContext = await AIContextService.buildContext(text);
      final response = await _geminiService.sendMessage(
        userMessage: text,
        dataContext: dataContext,
      );

      if (mounted) {
        setState(() {
          final assistantMsg = ChatMessage(
            id: DateTime.now().toString(),
            content: response.text,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            chartConfig: response.chartConfig,
          );
          _messages.add(assistantMsg);
          _storageService.saveMessage(assistantMsg); // Lưu phản hồi AI vào Firestore
          
          if (response.chartConfig != null) {
            _currentChart = response.chartConfig;
            _chartHistory.add(response.chartConfig!);
          }
          
          _isTyping = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().toString(),
          content: 'Lỗi: $e',
          role: MessageRole.assistant,
          status: MessageStatus.error,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _clearHistory() {
    setState(() {
      _messages.clear();
      _chartHistory.clear();
      _currentChart = null;
      _addSystemMessage();
    });
    _storageService.clearHistory();
    _geminiService.clearHistory();
  }

  void _handleDrillDown(String label) {
    if (_isTyping) return;
    _controller.text = 'Phân tích nguyên nhân và chi tiết của "$label"';
    _handleSend();
  }


  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: _buildChatColumn(context, settings, isMobile),
          ),
          if (!isMobile) ...[
            const VerticalDivider(width: 1, color: Colors.white10),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ChartPanel(
                  currentChart: _currentChart,
                  history: _chartHistory,
                  onSelect: (config) {
                    setState(() {
                      _currentChart = config;
                    });
                  },
                  onDrillDown: _handleDrillDown,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatColumn(BuildContext context, SettingsProvider settings, bool isMobile) {
    return Column(
      children: [
        _buildHeader(context, settings, isMobile),
        Expanded(
          child: _messages.isEmpty 
            ? _buildEmptyState(settings)
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index], isMobile);
                },
              ),
        ),
        if (_isTyping) _buildTypingIndicator(),
        _buildInputArea(context, settings),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 34 : 28, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.isVietnamese ? 'Trợ lý AI Phân tích' : 'AI Analysis Agent',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  settings.isVietnamese ? 'Trực tuyến • Sẵn sàng hỗ trợ' : 'Online • Ready to assist',
                  style: TextStyle(fontSize: 12, color: AppTheme.accentColor.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.description_rounded, size: 16),
            label: const Text('Báo cáo', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              foregroundColor: AppTheme.primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _controller.text = "Tạo báo cáo hiệu quả kinh doanh chi tiết năm 2015 kèm biểu đồ tổng hợp";
              _handleSend();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
            onPressed: _clearHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(SettingsProvider settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            settings.isVietnamese ? 'Bắt đầu cuộc hội thoại' : 'Start a conversation',
            style: TextStyle(color: Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMobile) {
    final isUser = message.role == MessageRole.user;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _buildAvatar(Icons.auto_awesome_rounded),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.primaryColor : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                      ),
                      child: _buildFormattedText(
                        message.content,
                        TextStyle(
                          color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (isMobile && message.chartConfig != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 220, // Bổ sung chiều cao cố định để fix lỗi overflow
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.07)),
                        ),
                        child: DynamicChartWidget(
                          config: message.chartConfig!,
                          compact: true,
                          onDrillDown: _handleDrillDown,
                        ),
                      ),
                    ],

                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isUser) _buildAvatar(Icons.person_rounded),
            ],
          ),
          if (message.quickReplySuggestions != null && message.quickReplySuggestions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.quickReplySuggestions!.map((s) => _buildQuickReply(s)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: icon == Icons.person_rounded ? Colors.blue.withOpacity(0.1) : AppTheme.secondaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Icon(icon, size: 18, color: icon == Icons.person_rounded ? Colors.blue : AppTheme.secondaryColor),
    );
  }

  Widget _buildQuickReply(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _handleSend();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildAvatar(Icons.auto_awesome_rounded),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 30,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: settings.isVietnamese ? 'Hỏi trợ lý về dữ liệu...' : 'Ask about your data...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final Match match in exp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold, color: AppTheme.accentColor),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}
