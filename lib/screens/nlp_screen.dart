import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('ai_reviews')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
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
          };
        }).toList();
      });
    });
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
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              Text('${(review['score'] * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
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