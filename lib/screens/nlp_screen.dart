import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:csv/csv.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/telegram_service.dart';
import '../services/gemini_service.dart';

class NLPScreen extends StatefulWidget {
  const NLPScreen({super.key});

  @override
  State<NLPScreen> createState() => _NLPScreenState();
}

class _NLPScreenState extends State<NLPScreen> {
  // URL được ẩn đi, chỉ thay đổi qua Dialog Settings
  String _apiUrl = 'https://dania-ariose-out.ngrok-free.dev';
  final TextEditingController _reviewController = TextEditingController();
  bool _isAnalyzing = false;
  String _selectedFilter = 'All'; // Bộ lọc hiện tại: All, Positive, Neutral, Negative
  StreamSubscription<QuerySnapshot>? _subscription;

  List<Map<String, dynamic>> _reviews = [];

  String _selectedTimeFilter = 'All'; // Thêm biến lưu time filter

  void _subscribeToReviews() {
    _subscription?.cancel();
    Query query = FirebaseFirestore.instance.collection('ai_reviews').orderBy('date', descending: true);
    
    if (_selectedTimeFilter != 'All') {
      DateTime now = DateTime.now();
      DateTime startDate;
      if (_selectedTimeFilter == 'Today') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (_selectedTimeFilter == '7Days') {
        startDate = now.subtract(const Duration(days: 7));
      } else {
        startDate = now.subtract(const Duration(days: 30));
      }
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }

    _subscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _reviews = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'text_vi': data['text_vi'] ?? '',
            'text_en': data['text_en'] ?? '',
            'sentiment': data['sentiment'] ?? 'Neutral',
            'score': (data['score'] ?? 0.0).toDouble(),
            'keywords': List<String>.from(data['keywords'] ?? []),
            'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'status': data['status'] ?? 'pending',
            'department': data['department'] ?? '',
            'ai_reply_text': data['ai_reply_text'] ?? '',
          };
        }).toList();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _subscribeToReviews();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  // ---- DYNAMIC METRICS GETTERS ----
  int get _totalReviews => _reviews.length;
  int get _positiveReviews => _reviews.where((r) => r['sentiment'] == 'Positive').length;
  int get _negativeReviews => _reviews.where((r) => r['sentiment'] == 'Negative').length;
  String get _satisfactionRate {
    if (_totalReviews == 0) return "0%";
    return "${((_positiveReviews / _totalReviews) * 100).toStringAsFixed(0)}%";
  }

  // Danh sách đã lọc để hiển thị
  List<Map<String, dynamic>> get _filteredReviews {
    if (_selectedFilter == 'All') return _reviews;
    return _reviews.where((r) => r['sentiment'] == _selectedFilter).toList();
  }

  void _exportReport() {
    final reviews = _filteredReviews;
    if (reviews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có dữ liệu để xuất!')));
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(["Thời gian", "Nội dung", "Cảm xúc", "Độ tự tin", "Từ khóa", "Trạng thái", "Bộ phận"]);

    for (var r in reviews) {
      rows.add([
        DateFormat('dd/MM/yyyy HH:mm').format(r['date']),
        r['text_vi'],
        r['sentiment'],
        '${(r['score'] * 100).toInt()}%',
        (r['keywords'] as List).join(', '),
        r['status'],
        r['department']
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode('\uFEFF$csvData'); // Thêm BOM để Excel hiển thị đúng Tiếng Việt UTF-8

    if (kIsWeb) {
      // ignore: avoid_web_libraries_in_flutter
      final blob = html.Blob([bytes]);
      // ignore: avoid_web_libraries_in_flutter
      final url = html.Url.createObjectUrlFromBlob(blob);
      // ignore: avoid_web_libraries_in_flutter
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'NLP_Report_\${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      // ignore: avoid_web_libraries_in_flutter
      html.Url.revokeObjectUrl(url);
    }
  }

  // Hàm mở Dialog cấu hình URL (Dành cho Developer/Admin)
  void _showSettingsDialog() {
    TextEditingController urlCtrl = TextEditingController(text: _apiUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2333),
        title: const Text('Cấu hình API AI', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Ngrok URL',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              setState(() => _apiUrl = urlCtrl.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật URL API!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeReview() async {
    final text = _reviewController.text.trim();
    if (text.isEmpty) return;

    if (_apiUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng cấu hình URL API trong Cài đặt (Icon Bánh răng)')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true'
        },
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Bắn dữ liệu thẳng lên Firestore
        await FirebaseFirestore.instance.collection('ai_reviews').add({
          'text_vi': data['text'],
          'text_en': data['text'],
          'sentiment': data['sentiment'],
          'score': data['score'],
          'keywords': List<String>.from(data['keywords']),
          'date': FieldValue.serverTimestamp(),
        });

        // TỰ ĐỘNG GỬI TELEGRAM NẾU TIÊU CỰC
        if (data['sentiment'] == 'Negative') {
          TelegramService.sendAlert(
            reviewText: data['text'],
            score: (data['score'] ?? 0.0).toDouble(),
            keywords: List<String>.from(data['keywords'] ?? []),
          );
        }

        setState(() {
          _reviewController.clear();
          _selectedFilter = 'All'; // Reset filter để thấy bài mới
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API Error: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi chi tiết: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _uploadCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isAnalyzing = true);

        // Sử dụng URL có tham số skip-warning để lách qua lỗi Preflight/CORS của Ngrok
        final cleanApiUrl = _apiUrl.endsWith('/') ? _apiUrl.substring(0, _apiUrl.length - 1) : _apiUrl;
        final uploadUri = Uri.parse('$cleanApiUrl/analyze-batch-file').replace(
          queryParameters: {'ngrok-skip-browser-warning': '1'}
        );
        
        var request = http.MultipartRequest('POST', uploadUri);
        
        // Vẫn gửi kèm Header cho chắc chắn
        request.headers.addAll({
          'ngrok-skip-browser-warning': '1',
          'Accept': 'application/json',
        });

        for (var file in result.files) {
          if (file.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'files', 
              file.bytes!, 
              filename: file.name
            ));
          } else if (file.path != null) {
            request.files.add(await http.MultipartFile.fromPath('files', file.path!));
          }
        }

        debugPrint('--- Đang gửi file tới: ${request.url} ---');
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          var finalResult = json.decode(response.body);
          if (finalResult['data'] != null) {
            int totalSaved = 0;
            for (var fileData in finalResult['data']) {
              if (fileData['results'] != null) {
                for (var reviewResult in fileData['results']) {
                  await FirebaseFirestore.instance.collection('ai_reviews').add({
                    'text_vi': reviewResult['text'],
                    'text_en': reviewResult['text'],
                    'sentiment': reviewResult['sentiment'],
                    'score': reviewResult['score'],
                    'keywords': List<String>.from(reviewResult['keywords'] ?? []),
                    'keywords_vi': reviewResult['keywords'],
                    'keywords_en': reviewResult['keywords'],
                    'date': FieldValue.serverTimestamp(),
                  });
                  totalSaved++;

                  // TỰ ĐỘNG GỬI TELEGRAM NẾU TIÊU CỰC
                  if (reviewResult['sentiment'] == 'Negative') {
                    TelegramService.sendAlert(
                      reviewText: reviewResult['text'],
                      score: (reviewResult['score'] ?? 0.0).toDouble(),
                      keywords: List<String>.from(reviewResult['keywords'] ?? []),
                    );
                  }
                }
              }
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Thành công! Đã lưu $totalSaved đánh giá.'), backgroundColor: Colors.green),
              );
            }
          }
        } else {
          debugPrint('Lỗi Server: ${response.body}');
          throw 'Server trả về lỗi: ${response.statusCode}';
        }
      }
    } catch (e) {
      debugPrint('Lỗi hệ thống: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString().split('\n')[0]}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _createTicket(Map<String, dynamic> review) async {
    String tempDept = 'Kỹ thuật';
    List<String> departments = ['Kỹ thuật', 'Giao hàng', 'CSKH'];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2333),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.assignment_ind_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  const Text('Tạo Ticket Xử Lý', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chọn bộ phận tiếp nhận:', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  ...departments.map((dept) => RadioListTile<String>(
                    title: Text(dept, style: const TextStyle(color: Colors.white)),
                    value: dept,
                    groupValue: tempDept,
                    activeColor: Colors.orangeAccent,
                    onChanged: (val) {
                      setState(() => tempDept = val!);
                    },
                  )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx, tempDept),
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: const Text('Chuyển Tiếp', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );

    if (result != null) {
      try {
        await FirebaseFirestore.instance.collection('ai_reviews').doc(review['id']).update({
          'status': 'processing',
          'department': result,
          'ticket_updated_at': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển Ticket cho bộ phận: $result'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('Lỗi cập nhật ticket: $e');
      }
    }
  }

  Future<void> _generateAutoReply(Map<String, dynamic> review, bool isVietnamese) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    try {
      final gemini = GeminiService();
      final prompt = isVietnamese 
          ? 'Đóng vai là nhân viên CSKH của cửa hàng. Viết một phản hồi lịch sự, chân thành cho đánh giá sau: "${review['text_vi']}". Đánh giá này là ${review['sentiment']}. Nếu tiêu cực, hãy xin lỗi, hứa khắc phục và đề xuất đền bù (như voucher). Nếu tích cực, hãy cảm ơn. Dưới 50 từ.'
          : 'Act as Customer Service. Write a polite reply to this review: "${review['text_en']}". Sentiment is ${review['sentiment']}. Apologize and offer compensation if negative, say thanks if positive. Keep it under 50 words.';
      
      final response = await gemini.sendMessage(
        userMessage: prompt,
        dataContext: 'Keywords: ${review['keywords'].join(', ')}',
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2333),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(isVietnamese ? 'AI Đề xuất Phản hồi' : 'AI Suggested Reply', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(response.text, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isVietnamese ? 'Hủy' : 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection('ai_reviews').doc(review['id']).update({
                    'status': 'replied',
                    'ai_reply_text': response.text,
                    'replied_at': FieldValue.serverTimestamp(),
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isVietnamese ? 'Đã duyệt và lưu phản hồi!' : 'Reply Approved & Sent!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  debugPrint('Lỗi cập nhật reply: $e');
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              label: Text(isVietnamese ? 'Duyệt & Gửi' : 'Approve & Send', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi sinh phản hồi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ---- PIE CHART: Sentiment Distribution ----
  List<PieChartSectionData> _getSentimentSections() {
    int total = _totalReviews;
    if (total == 0) return [];
    
    return [
      PieChartSectionData(
        color: Colors.greenAccent.shade400,
        value: _positiveReviews.toDouble(),
        title: '${((_positiveReviews / total) * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.redAccent.shade400,
        value: _negativeReviews.toDouble(),
        title: '${((_negativeReviews / total) * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.orangeAccent.shade400,
        value: (total - _positiveReviews - _negativeReviews).toDouble(),
        title: '${(((total - _positiveReviews - _negativeReviews) / total) * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  // ---- ROOT CAUSE ANALYSIS: Top Negative Keywords ----
  List<MapEntry<String, int>> _getTopNegativeKeywords() {
    Map<String, int> keywordCounts = {};
    for (var review in _reviews) {
      if (review['sentiment'] == 'Negative') {
        List<String> keywords = (review['keywords'] as List).map((e) => e.toString().toLowerCase()).toList();
        for (var kw in keywords) {
          if (kw.trim().isNotEmpty) {
            keywordCounts[kw] = (keywordCounts[kw] ?? 0) + 1;
          }
        }
      }
    }
    var sorted = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(15).toList();
  }

  Widget _buildDashboard(BuildContext context, SettingsProvider settings, bool isMobile) {
    if (_reviews.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isMobile 
              ? Column(
                  children: [
                    _buildSentimentPieChart(settings),
                    const SizedBox(height: 14),
                    _buildRootCauseAnalysis(settings),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildSentimentPieChart(settings)),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: _buildRootCauseAnalysis(settings)),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentPieChart(SettingsProvider settings) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                settings.isVietnamese ? 'Phân bổ Cảm xúc (Tỉ lệ)' : 'Sentiment Distribution',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: _getSentimentSections(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegend(Colors.greenAccent.shade400, settings.isVietnamese ? 'Tích cực' : 'Positive'),
                      const SizedBox(height: 10),
                      _buildLegend(Colors.orangeAccent.shade400, settings.isVietnamese ? 'Trung tính' : 'Neutral'),
                      const SizedBox(height: 10),
                      _buildLegend(Colors.redAccent.shade400, settings.isVietnamese ? 'Tiêu cực' : 'Negative'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ],
    );
  }

  Widget _buildRootCauseAnalysis(SettingsProvider settings) {
    final topKeywords = _getTopNegativeKeywords();
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded, size: 18, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                settings.isVietnamese ? 'Phân tích Căn nguyên (Word Cloud)' : 'Root Cause Analysis',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topKeywords.isEmpty)
             Expanded(
               child: Center(
                 child: Text(
                   settings.isVietnamese ? 'Chưa có phản hồi tiêu cực' : 'No negative data',
                   style: TextStyle(color: Colors.grey.shade600),
                 ),
               ),
             )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topKeywords.map((kw) {
                    double weight = kw.value / (topKeywords.first.value);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1 + (weight * 0.3)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            kw.key,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: weight > 0.6 ? FontWeight.bold : FontWeight.w500,
                              fontSize: 11 + (weight * 3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                            child: Text(kw.value.toString(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, settings, isMobile),
          _buildMetricsCards(context, settings, isMobile),
          _buildDashboard(context, settings, isMobile),
          _buildLiveInput(context, settings),
          _buildFilterTabs(context, settings),
          _buildReviewsList(context, settings),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, bool isMobile) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, isMobile ? 52 : 28, 20, 16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent.shade400, Colors.deepPurple.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                ]
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.isVietnamese ? 'Phân tích Cảm xúc (AI)' : 'Sentiment Analysis (AI)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                  Text(
                    settings.isVietnamese
                        ? 'Tự động trích xuất và phân loại phản hồi khách hàng'
                        : 'Automatically extract and classify customer feedback',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            // Nút Settings ẩn dành cho Admin
            IconButton(
              icon: Icon(Icons.settings_suggest_rounded, color: Colors.grey.shade500),
              onPressed: _showSettingsDialog,
              tooltip: 'Cấu hình API',
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards(BuildContext context, SettingsProvider settings, bool isMobile) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: isMobile ? 1.4 : 1.8,
        ),
        delegate: SliverChildListDelegate([
          _buildMetricCard(
            title: settings.isVietnamese ? 'Mức độ Hài lòng' : 'Satisfaction Rate',
            value: _satisfactionRate, // Hiển thị số liệu động
            icon: Icons.sentiment_satisfied_alt_rounded,
            color: Colors.greenAccent.shade400,
          ),
          _buildMetricCard(
            title: settings.isVietnamese ? 'Tổng đánh giá' : 'Total Reviews',
            value: _totalReviews.toString(), // Hiển thị số liệu động
            icon: Icons.forum_rounded,
            color: Colors.blueAccent.shade400,
          ),
          _buildMetricCard(
            title: settings.isVietnamese ? 'Phản hồi Tiêu cực' : 'Negative Feedback',
            value: _negativeReviews.toString(), // Hiển thị số liệu động
            icon: Icons.warning_rounded,
            color: Colors.redAccent.shade400,
          ),
          _buildMetricCard(
            title: settings.isVietnamese ? 'Độ chính xác (F1)' : 'Accuracy (F1-Score)',
            value: '0.91', // Số này thường cố định theo Model
            icon: Icons.fact_check_rounded,
            color: Colors.purpleAccent.shade400,
          ),
        ]),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveInput(BuildContext context, SettingsProvider settings) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.blueAccent.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _reviewController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: settings.isVietnamese ? 'Nhập phản hồi của khách hàng để AI phân tích...' : 'Enter customer feedback for AI analysis...',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _analyzeReview(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.upload_file_rounded, color: Colors.blueAccent),
              onPressed: _isAnalyzing ? null : _uploadCSV,
              tooltip: settings.isVietnamese ? 'Tải lên CSV' : 'Upload CSV',
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isAnalyzing ? null : _analyzeReview,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.lightBlueAccent]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isAnalyzing 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(settings.isVietnamese ? 'Gửi AI' : 'Analyze', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, SettingsProvider settings) {
    List<String> filters = ['All', 'Positive', 'Neutral', 'Negative'];
    Map<String, String> viNames = {'All': 'Tất cả', 'Positive': 'Tích cực', 'Neutral': 'Trung tính', 'Negative': 'Tiêu cực'};
    
    return SliverToBoxAdapter(
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  String filter = filters[index];
                  bool isSelected = _selectedFilter == filter;
                  Color getFilterColor() {
                    if (filter == 'Positive') return Colors.greenAccent;
                    if (filter == 'Negative') return Colors.redAccent;
                    if (filter == 'Neutral') return Colors.orangeAccent;
                    return Colors.blueAccent;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(settings.isVietnamese ? viNames[filter]! : filter),
                      selected: isSelected,
                      selectedColor: getFilterColor().withOpacity(0.2),
                      backgroundColor: const Color(0xFF1E2333),
                      labelStyle: TextStyle(
                        color: isSelected ? getFilterColor() : Colors.grey.shade400,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(color: isSelected ? getFilterColor().withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // Time Filter Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2333),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTimeFilter,
                  dropdownColor: const Color(0xFF1E2333),
                  icon: const Icon(Icons.filter_list_rounded, color: Colors.blueAccent, size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(settings.isVietnamese ? 'Tất cả' : 'All Time')),
                    DropdownMenuItem(value: 'Today', child: Text(settings.isVietnamese ? 'Hôm nay' : 'Today')),
                    DropdownMenuItem(value: '7Days', child: Text(settings.isVietnamese ? '7 ngày qua' : 'Last 7 Days')),
                    DropdownMenuItem(value: '30Days', child: Text(settings.isVietnamese ? '30 ngày qua' : 'Last 30 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedTimeFilter = val);
                      _subscribeToReviews(); // Reload data with new time filter
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Nút Xuất Báo Cáo
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.greenAccent, Colors.teal]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                ),
                onPressed: _exportReport,
                icon: const Icon(Icons.download_rounded, size: 18, color: Colors.black87),
                label: Text(settings.isVietnamese ? 'Xuất CSV' : 'Export', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList(BuildContext context, SettingsProvider settings) {
    final reviews = _filteredReviews;
    
    if (reviews.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade700),
                const SizedBox(height: 16),
                Text(
                  settings.isVietnamese ? 'Không có đánh giá nào phù hợp.' : 'No reviews match this filter.',
                  style: TextStyle(color: Colors.grey.shade500),
                )
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final review = reviews[index];
          final isPositive = review['sentiment'] == 'Positive';
          final isNegative = review['sentiment'] == 'Negative';
          
          Color statusColor = Colors.orangeAccent.shade400;
          IconData icon = Icons.sentiment_neutral_rounded;
          String sentimentVi = 'Trung tính';
          
          if (isPositive) {
            statusColor = Colors.greenAccent.shade400;
            icon = Icons.sentiment_very_satisfied_rounded;
            sentimentVi = 'Tích cực';
          } else if (isNegative) {
            statusColor = Colors.redAccent.shade400;
            icon = Icons.sentiment_very_dissatisfied_rounded;
            sentimentVi = 'Tiêu cực';
          }

          // Format thời gian
          String timeAgo = DateFormat('dd/MM HH:mm').format(review['date']);

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2333),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor.withOpacity(0.2), statusColor.withOpacity(0.05)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Icon(icon, color: statusColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  settings.isVietnamese ? sentimentVi.toUpperCase() : review['sentiment'].toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                              Text(timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            settings.isVietnamese ? review['text_vi'] : review['text_en'],
                            style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          
                          // Hiển thị Keywords hiện đại
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Icon(Icons.label_important_outline_rounded, size: 16, color: Colors.grey.shade500),
                              ...(review['keywords'] as List).map((kw) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Text(kw, style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Thanh Progress Confidence Score
                          Row(
                            children: [
                              Text(settings.isVietnamese ? 'Độ tự tin (AI):' : 'AI Confidence:', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: review['score'],
                                    backgroundColor: Colors.white.withOpacity(0.05),
                                    color: statusColor,
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${(review['score'] * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          // Khung hiển thị Phản hồi AI
                          if (review['ai_reply_text'].toString().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.reply_all_rounded, size: 16, color: Colors.blueAccent),
                                      const SizedBox(width: 6),
                                      Text(settings.isVietnamese ? 'Đã phản hồi tự động (AI):' : 'Auto Replied (AI):', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(review['ai_reply_text'], style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (review['status'] == 'processing')
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        settings.isVietnamese ? 'Đã chuyển cho: ${review['department']}' : 'Forwarded to: ${review['department']}',
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              if (review['status'] == 'replied')
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.mark_email_read_rounded, color: Colors.blueAccent, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        settings.isVietnamese ? 'Đã xử lý xong' : 'Resolved',
                                        style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isNegative && review['status'] == 'pending')
                                TextButton.icon(
                                  onPressed: () => _createTicket(review),
                                  icon: const Icon(Icons.assignment_late_rounded, size: 16, color: Colors.orangeAccent),
                                  label: Text(settings.isVietnamese ? 'Tạo Ticket Xử Lý' : 'Create Ticket', style: const TextStyle(color: Colors.orangeAccent)),
                                ),
                              const SizedBox(width: 8),
                              if (review['status'] != 'replied')
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: statusColor.withOpacity(0.15),
                                    foregroundColor: statusColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _generateAutoReply(review, settings.isVietnamese),
                                  icon: const Icon(Icons.smart_toy_rounded, size: 16),
                                  label: Text(settings.isVietnamese ? 'AI Phản hồi' : 'AI Reply'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        childCount: reviews.length,
      ),
    );
  }
}