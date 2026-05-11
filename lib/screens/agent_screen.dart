import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

class _AgentScreenState extends State<AgentScreen>
    with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final ChatStorageService _storageService = ChatStorageService();
  bool _isTyping = false;
  final List<String> _thinkingLogs = [];
  XFile? _selectedImage;
  bool _inputFocused = false;

  ChartConfig? _currentChart;
  final List<ChartConfig> _chartHistory = [];
  final FocusNode _focusNode = FocusNode();

  // Shimmer / pulse animation for typing dots
  late AnimationController _dotController;
  late AnimationController _headerGlowController;
  late Animation<double> _headerGlowAnimation;
  
  // Auth listener to handle session restoration on Web
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to auth changes to reload history when session is restored
    _authSubscription = _storageService.authStateChanges().listen((user) {
      _loadHistoryFromFirestore();
    });

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _headerGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _headerGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerGlowController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(() {
      setState(() => _inputFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _dotController.dispose();
    _headerGlowController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryFromFirestore() async {
    final history = await _storageService.loadChatHistory();
    if (mounted) {
      setState(() {
        _messages.clear();
        _chartHistory.clear();
        _currentChart = null;

        if (history.isEmpty) {
          _addSystemMessage();
        } else {
          _messages.addAll(history);
          for (var msg in history.reversed) {
            if (msg.chartConfig != null) {
              _currentChart = msg.chartConfig;
              break;
            }
          }
          _chartHistory.addAll(
              history.where((m) => m.chartConfig != null).map((m) => m.chartConfig!));
        }
      });
      _scrollToBottom();
    }
  }

  void _addSystemMessage() {
    final msg = ChatMessage(
      id: DateTime.now().toString(),
      content:
      'Xin chào! Tôi là trợ lý phân tích dữ liệu chuyên sâu (Data Analyst). Tôi đã sẵn sàng phân tích, dự báo (what-if) và tự động tạo báo cáo từ dữ liệu của bạn.',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      quickReplySuggestions: [
        'Dự báo doanh thu 3 tháng tới nếu tăng 15%?',
        'Tạo báo cáo hiệu quả kinh doanh 2015',
        'Top 5 sản phẩm bán chạy nhất?',
        'Nguyên nhân sụt giảm giao dịch tháng 12?'
      ],
    );
    if (mounted) setState(() => _messages.add(msg));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;
    _controller.clear();
    _scrollToBottom();

    try {
      String? base64Image;
      String? imageUrl;

      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final bytes = await _selectedImage!.readAsBytes();
        await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await storageRef.getDownloadURL();
        base64Image = base64Encode(bytes);
      }

      final userMsg = ChatMessage(
        id: DateTime.now().toString(),
        content: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        localImagePath: _selectedImage?.path,
      );

      setState(() {
        _messages.add(userMsg);
        _isTyping = true;
        _thinkingLogs.clear();
        _selectedImage = null;
      });
      _scrollToBottom();
      _storageService.saveMessage(userMsg);

      final dataContext = await AIContextService.buildContext(
        text,
        (log) {
          if (mounted) {
            setState(() => _thinkingLogs.add(log));
            _scrollToBottom();
          }
        },
      );
      
      final response = await _geminiService.sendMessage(
        userMessage: text,
        dataContext: dataContext,
        base64Image: base64Image,
        onProgress: (log) {
          if (mounted) {
            setState(() => _thinkingLogs.add(log));
            _scrollToBottom();
          }
        },
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
          _storageService.saveMessage(assistantMsg);
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = image);
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SelectionArea(
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _buildChatColumn(context, settings, isMobile),
            ),
            if (!isMobile) ...[
              Container(
                width: 1,
                color: Colors.white.withOpacity(0.06),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ChartPanel(
                    key: ValueKey(_chartHistory.length),
                    currentChart: _currentChart,
                    history: _chartHistory,
                    onSelect: (config) => setState(() => _currentChart = config),
                    onDrillDown: _handleDrillDown,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatColumn(
      BuildContext context, SettingsProvider settings, bool isMobile) {
    return Column(
      children: [
        _buildHeader(context, settings, isMobile),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(settings)
              : ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
                16, 20, 16, _isTyping ? 8 : 20),
            itemCount: _messages.length,
            itemBuilder: (context, index) =>
                _buildMessageBubble(_messages[index], isMobile),
          ),
        ),
        if (_isTyping) _buildTypingIndicator(),
        _buildInputArea(context, settings),
      ],
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context, SettingsProvider settings, bool isMobile) {
    return AnimatedBuilder(
      animation: _headerGlowAnimation,
      builder: (context, child) {
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, isMobile ? 52 : 28, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withOpacity(0.75),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor
                        .withOpacity(0.05 + _headerGlowAnimation.value * 0.04),
                    AppTheme.cardColor.withOpacity(0.0),
                    AppTheme.secondaryColor
                        .withOpacity(0.03 + _headerGlowAnimation.value * 0.03),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Row(
        children: [
          // Logo badge with gradient + glow
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.isVietnamese
                      ? 'Trợ lý AI Phân tích'
                      : 'AI Analysis Agent',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // Animated green dot
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.accentColor.withOpacity(0.6),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      settings.isVietnamese
                          ? 'Trực tuyến • Sẵn sàng hỗ trợ'
                          : 'Online • Ready to assist',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentColor.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Report button — glass pill
          _buildHeaderAction(
            icon: Icons.description_rounded,
            label: 'Báo cáo',
            onTap: () {
              _controller.text =
              "Tạo báo cáo hiệu quả kinh doanh chi tiết năm 2015 kèm biểu đồ tổng hợp";
              _handleSend();
            },
          ),
          const SizedBox(width: 6),
          // Clear history button
          _buildIconAction(
            icon: Icons.delete_sweep_outlined,
            onTap: _clearHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconAction(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, size: 18, color: Colors.grey.shade500),
      ),
    );
  }

  // ─── EMPTY STATE ────────────────────────────────────────────
  Widget _buildEmptyState(SettingsProvider settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 32, color: AppTheme.primaryColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            settings.isVietnamese
                ? 'Bắt đầu cuộc hội thoại'
                : 'Start a conversation',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            settings.isVietnamese
                ? 'Đặt câu hỏi về dữ liệu của bạn'
                : 'Ask anything about your data',
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGE BUBBLE ──────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage message, bool isMobile) {
    final isUser = message.role == MessageRole.user;
    final isError = message.status == MessageStatus.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _buildAvatar(Icons.auto_awesome_rounded, isUser: false),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Bubble
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      child: BackdropFilter(
                        filter: isUser
                            ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                            : ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            gradient: isUser
                                ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor,
                                Color(0xFF4F46E5),
                              ],
                            )
                                : null,
                            color: isUser
                                ? null
                                : isError
                                ? Colors.red.withOpacity(0.12)
                                : AppTheme.cardColor.withOpacity(0.9),
                            border: isUser
                                ? null
                                : Border.all(
                              color: isError
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                            boxShadow: isUser
                                ? [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                                : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _buildFormattedText(
                            message.content,
                            TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : isError
                                  ? Colors.red.shade300
                                  : Colors.white.withOpacity(0.92),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Image attachment
                    if (message.localImagePath != null ||
                        message.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildChatImage(message),
                      ),
                    ],

                    // Compact chart (mobile)
                    if (isMobile && message.chartConfig != null) ...[
                      const SizedBox(height: 12),
                      _buildCompactChart(message.chartConfig!),
                    ],

                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
                      child: Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.22),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 10),
                _buildAvatar(Icons.person_rounded, isUser: true),
              ],
            ],
          ),

          // Quick replies
          if (message.quickReplySuggestions != null &&
              message.quickReplySuggestions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.quickReplySuggestions!
                    .map((s) => _buildQuickReply(s))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactChart(ChartConfig config) {
    return GestureDetector(
      onTap: () => _showExpandedChart(config),
      child: Container(
        width: double.infinity,
        height: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(18),
          border:
          Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            DynamicChartWidget(
              config: config,
              compact: true,
              onDrillDown: _handleDrillDown,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.fullscreen_rounded,
                        size: 14, color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AVATAR ──────────────────────────────────────────────────
  Widget _buildAvatar(IconData icon, {required bool isUser}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser
            ? LinearGradient(
          colors: [
            Colors.blue.shade400.withOpacity(0.3),
            Colors.blue.shade700.withOpacity(0.15),
          ],
        )
            : LinearGradient(
          colors: [
            AppTheme.secondaryColor.withOpacity(0.25),
            AppTheme.primaryColor.withOpacity(0.15),
          ],
        ),
        border: Border.all(
          color: isUser
              ? Colors.blue.withOpacity(0.2)
              : AppTheme.secondaryColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        size: 17,
        color: isUser ? Colors.blue.shade300 : AppTheme.secondaryColor,
      ),
    );
  }

  // ─── QUICK REPLY ─────────────────────────────────────────────
  Widget _buildQuickReply(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _handleSend();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border:
          Border.all(color: AppTheme.primaryColor.withOpacity(0.28), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded,
                size: 13, color: AppTheme.primaryColor.withOpacity(0.7)),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(Icons.auto_awesome_rounded, isUser: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withOpacity(0.85),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AI Agent đang suy nghĩ...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor.withOpacity(0.9),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildBouncingDots(),
                            ],
                          ),
                          if (_thinkingLogs.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                children: _thinkingLogs.asMap().entries.map((entry) {
                                  final isLast = entry.key == _thinkingLogs.length - 1;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: isLast ? 0 : 10,
                                    ),
                                    child: Row(
                                      children: [
                                        // Animated icon
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: isLast 
                                            ? AnimatedBuilder(
                                                animation: _dotController,
                                                builder: (context, child) {
                                                  return Transform.rotate(
                                                    angle: _dotController.value * 2 * 3.14159,
                                                    child: Icon(
                                                      Icons.sync_rounded,
                                                      size: 14,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.check_circle_rounded,
                                                size: 14,
                                                color: AppTheme.accentColor.withOpacity(0.8),
                                              ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: isLast 
                                            ? AnimatedBuilder(
                                                animation: _dotController,
                                                builder: (context, child) {
                                                  return Opacity(
                                                    opacity: 0.7 + (0.3 * (1 - (_dotController.value - 0.5).abs() * 2)),
                                                    child: Text(
                                                      entry.value,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 0.1,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Text(
                                                entry.value,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white.withOpacity(0.45),
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _dotController,
          builder: (context, child) {
            final delay = i * 0.18;
            final t = (_dotController.value - delay).clamp(0.0, 1.0);
            final bounce = (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -3 * bounce),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.4 + bounce * 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ─── INPUT AREA ──────────────────────────────────────────────
  Widget _buildInputArea(BuildContext context, SettingsProvider settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image preview
        if (_selectedImage != null) _buildImagePreview(),

        // Input row
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.fromLTRB(
                  14, 12, 14, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withOpacity(0.82),
                border: Border(
                  top: BorderSide(
                    color: _inputFocused
                        ? AppTheme.primaryColor.withOpacity(0.25)
                        : Colors.white.withOpacity(0.06),
                    width: _inputFocused ? 1.5 : 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image picker icon
                  _buildInputIconButton(
                    icon: Icons.image_rounded,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                    onTap: _pickImage,
                  ),
                  const SizedBox(width: 8),

                  // Text field
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(
                        color: _inputFocused
                            ? AppTheme.backgroundColor.withOpacity(0.9)
                            : AppTheme.backgroundColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: _inputFocused
                              ? AppTheme.primaryColor.withOpacity(0.45)
                              : Colors.white.withOpacity(0.1),
                          width: _inputFocused ? 1.5 : 1,
                        ),
                        boxShadow: _inputFocused
                            ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                            : null,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: settings.isVietnamese
                              ? 'Hỏi trợ lý về dữ liệu...'
                              : 'Ask about your data...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.28),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send button
                  GestureDetector(
                    onTap: _handleSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isTyping
                            ? LinearGradient(
                          colors: [
                            Colors.grey.shade700,
                            Colors.grey.shade800
                          ],
                        )
                            : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        boxShadow: _isTyping
                            ? []
                            : [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isTyping
                            ? Icons.hourglass_empty_rounded
                            : Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputIconButton(
      {required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      color: AppTheme.cardColor.withOpacity(0.6),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: kIsWeb
                ? Image.network(_selectedImage!.path,
                height: 72, width: 72, fit: BoxFit.cover)
                : Image.file(File(_selectedImage!.path),
                height: 72, width: 72, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ảnh đã chọn',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedImage = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ─── IMAGE IN CHAT ───────────────────────────────────────────
  Widget _buildChatImage(ChatMessage message) {
    if (message.localImagePath != null) {
      if (kIsWeb) {
        return Image.network(message.localImagePath!,
            width: 220, height: 160, fit: BoxFit.cover);
      } else {
        return Image.file(File(message.localImagePath!),
            width: 220, height: 160, fit: BoxFit.cover);
      }
    }
    return Image.network(
      message.imageUrl!,
      width: 220,
      height: 160,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 220,
          height: 160,
          color: Colors.white.withOpacity(0.04),
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                  progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded,
                color: Colors.red.withOpacity(0.5), size: 28),
            const SizedBox(height: 6),
            Text('Không tải được ảnh',
                style: TextStyle(
                    color: Colors.red.withOpacity(0.5), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─── FORMATTED TEXT ──────────────────────────────────────────
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
        style: baseStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.accentColor,
        ),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return SelectableText.rich(TextSpan(style: baseStyle, children: spans));
  }

  // ─── EXPANDED CHART SHEET ────────────────────────────────────
  void _showExpandedChart(ChartConfig config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withOpacity(0.95),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ChartPanel(
                      currentChart: config,
                      history: [config],
                      onSelect: (c) {},
                      onDrillDown: (label) {
                        Navigator.pop(context);
                        _handleDrillDown(label);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UTILS ───────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}