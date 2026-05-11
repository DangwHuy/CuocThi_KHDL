import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

// ─────────────────────────────────────────────
//  EFFECT 1 — Particle Flow Painter
// ─────────────────────────────────────────────
class _ParticleFlowPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<Map<String, dynamic>> steps;
  final int expandedIndex;
  final int simulatingStep;

  _ParticleFlowPainter({
    required this.particles,
    required this.steps,
    required this.expandedIndex,
    required this.simulatingStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeCount = steps.length;
    final nodeW = 58.0;
    final nodeH = 30.0;
    final gap = (size.width - nodeCount * nodeW) / (nodeCount + 1);

    for (int i = 0; i < nodeCount; i++) {
      final step = steps[i];
      final colors = step['colors'] as List<Color>;
      final x = gap + i * (nodeW + gap);
      final cy = size.height / 2;
      final isActive = expandedIndex == i || simulatingStep == i;

      // connector line
      if (i < nodeCount - 1) {
        final nextColors = steps[i + 1]['colors'] as List<Color>;
        final x2 = gap + (i + 1) * (nodeW + gap);
        final paint = Paint()
          ..shader = LinearGradient(colors: [
            colors[0].withOpacity(0.4),
            nextColors[0].withOpacity(0.4),
          ]).createShader(Rect.fromLTWH(x + nodeW, cy - 1, x2 - x - nodeW, 2))
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(x + nodeW, cy), Offset(x2, cy), paint);
      }

      // node box
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy - nodeH / 2, nodeW, nodeH),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = colors[0].withOpacity(isActive ? 0.25 : 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = isActive ? colors[0] : colors[0].withOpacity(0.45)
          ..strokeWidth = isActive ? 1.5 : 1.0
          ..style = PaintingStyle.stroke,
      );

      // glow behind active node
      if (isActive) {
        canvas.drawRRect(
          rrect.inflate(4),
          Paint()
            ..color = colors[0].withOpacity(0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..style = PaintingStyle.fill,
        );
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? colors[0] : colors[0].withOpacity(0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x + nodeW / 2 - textPainter.width / 2, cy - textPainter.height / 2),
      );
    }

    // draw particles
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleFlowPainter old) => true;
}

class _Particle {
  double x;
  final double fromX, toX, y;
  final Color color;
  final double speed;
  final double radius;
  double alpha;
  double t = 0;

  _Particle({
    required this.fromX,
    required this.toX,
    required double baseY,
    required this.color,
  })  : x = fromX,
        y = baseY + (math.Random().nextDouble() - 0.5) * 5,
        speed = 1.0 + math.Random().nextDouble() * 2.0,
        radius = 1.2 + math.Random().nextDouble() * 1.5,
        alpha = 0.5 + math.Random().nextDouble() * 0.5;

  void update(double dtFraction) {
    t += dtFraction * speed;
    x = fromX + (toX - fromX) * t;
    // fade in/out
    final mid = (t - 0.5).abs();
    alpha = (1.0 - mid * 1.8).clamp(0.0, 1.0);
  }

  bool get done => t >= 1.0;
}

// ─────────────────────────────────────────────
//  EFFECT 3 — Typewriter log entry
// ─────────────────────────────────────────────
enum _LogLevel { info, ok, warn, done }

class _LogLine {
  final String timestamp;
  final _LogLevel level;
  final String fullText;
  String visibleText;
  bool typing;

  _LogLine({
    required this.timestamp,
    required this.level,
    required this.fullText,
  })  : visibleText = '',
        typing = true;

  Color get color {
    switch (level) {
      case _LogLevel.ok:   return const Color(0xFF68D391);
      case _LogLevel.warn: return const Color(0xFFF6AD55);
      case _LogLevel.done: return const Color(0xFFB794F4);
      default:             return const Color(0xFF90CDF4);
    }
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});
  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen>
    with TickerProviderStateMixin {
  // core controllers
  late AnimationController _pulseCtrl;
  late AnimationController _flowCtrl;
  late AnimationController _simCtrl;

  // particle system
  final List<_Particle> _particles = [];
  final math.Random _rnd = math.Random();
  late Ticker _particleTicker;
  double _lastTickTime = 0;

  // state
  int _expandedIndex = -1;
  int _activePhase = 0;
  bool _isSimulating = false;
  int _simulatingStep = -1;

  // EFFECT 3 – typewriter
  final List<_LogLine> _logLines = [];
  final ScrollController _logScrollCtrl = ScrollController();
  Timer? _twTimer;
  int _twCharIdx = 0;

  // EFFECT 4 – 3D tilt per card
  final Map<int, Offset> _tiltOffsets = {};

  final List<Map<String, dynamic>> _steps = [
    {
      'title_vi': '1. Thu thập Dữ liệu', 'title_en': '1. Data Collection',
      'desc_vi': 'Thu thập dữ liệu bán lẻ từ nhiều nguồn khác nhau',
      'desc_en': 'Collect retail data from various sources',
      'icon': Icons.cloud_download_rounded,
      'colors': [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      'progress': 1.0, 'tech': ['Hadoop', 'Data Lake', 'CSV/API'],
      'route': '/explorer',
      'details_vi': [
        'Dữ liệu giao dịch bán hàng (Transaction Data)',
        'Dữ liệu sản phẩm và danh mục (Product Catalog)',
        'Dữ liệu khách hàng (Customer Demographics)',
        'Dữ liệu thời gian (Timestamps, Seasons)',
      ],
      'details_en': [
        'Sales transaction data', 'Product and category catalog',
        'Customer demographics', 'Temporal data (Timestamps, Seasons)',
      ],
      'metrics': {'Records': '541,909', 'Sources': '3', 'Period': '12 months'},
      'logPrefix': 'Loading 541,909 records from Data Lake',
      'logLevel': _LogLevel.info,
    },
    {
      'title_vi': '2. Xử lý Dữ liệu', 'title_en': '2. Data Processing',
      'desc_vi': 'Làm sạch, xử lý missing values và chuẩn hóa dữ liệu',
      'desc_en': 'Clean, handle missing values, standardize data',
      'icon': Icons.auto_fix_high_rounded,
      'colors': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      'progress': 1.0, 'tech': ['Pandas', 'NumPy', 'Spark'],
      'details_vi': [
        'Loại bỏ dữ liệu trùng lặp & ngoại lai (Outliers)',
        'Xử lý giá trị thiếu bằng Imputation',
        'Feature Engineering: RFM, Time-based features',
        'Chuẩn hóa dữ liệu (StandardScaler, MinMax)',
      ],
      'details_en': [
        'Remove duplicates & outliers', 'Handle missing values with Imputation',
        'Feature Engineering: RFM, Time-based features',
        'Data normalization (StandardScaler, MinMax)',
      ],
      'metrics': {'Cleaned': '98.7%', 'Features': '24', 'Outliers': '1,203'},
      'logPrefix': 'Imputation complete · 24 features engineered',
      'logLevel': _LogLevel.ok,
    },
    {
      'title_vi': '3. Mô hình & AI', 'title_en': '3. Modeling & AI',
      'desc_vi': 'Xây dựng mô hình ML: Forecast, Clustering, Association Rules',
      'desc_en': 'Build ML models: Forecast, Clustering, Association Rules',
      'icon': Icons.psychology_rounded,
      'colors': [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      'progress': 0.85, 'tech': ['Scikit-Learn', 'TensorFlow', 'Prophet'],
      'route': '/forecast',
      'details_vi': [
        'Time-Series Forecasting (ARIMA/Prophet)',
        'Customer Segmentation (K-Means Clustering)',
        'Association Rules (FP-Growth / Apriori)',
        'RFM Analysis & Scoring',
      ],
      'details_en': [
        'Time-Series Forecasting (ARIMA/Prophet)',
        'Customer Segmentation (K-Means Clustering)',
        'Association Rules (FP-Growth / Apriori)',
        'RFM Analysis & Scoring',
      ],
      'metrics': {'Models': '5', 'Best R²': '0.94', 'Training': '~2min'},
      'logPrefix': 'Training Prophet + K-Means + FP-Growth... Best R²=0.942',
      'logLevel': _LogLevel.info,
    },
    {
      'title_vi': '4. Đánh giá', 'title_en': '4. Evaluation',
      'desc_vi': 'Đánh giá mô hình bằng các chỉ số: RMSE, Silhouette, Lift',
      'desc_en': 'Evaluate models: RMSE, Silhouette Score, Lift',
      'icon': Icons.verified_rounded,
      'colors': [const Color(0xFFEF4444), const Color(0xFFDC2626)],
      'progress': 0.9, 'tech': ['Jupyter', 'MLflow', 'Cross-Val'],
      'details_vi': [
        'Cross-Validation (K-Fold = 5)', 'RMSE & MAE cho Forecasting',
        'Silhouette Score cho Clustering',
        'Support, Confidence, Lift cho Association',
      ],
      'details_en': [
        'Cross-Validation (K-Fold = 5)', 'RMSE & MAE for Forecasting',
        'Silhouette Score for Clustering',
        'Support, Confidence, Lift for Association',
      ],
      'metrics': {'RMSE': '0.032', 'Silhouette': '0.71', 'Lift': '>1.5'},
      'logPrefix': 'Cross-val K=5 passed · RMSE=0.032, Silhouette=0.71',
      'logLevel': _LogLevel.ok,
    },
    {
      'title_vi': '5. Trực quan hóa', 'title_en': '5. Visualization',
      'desc_vi': 'Biểu đồ tương tác, Dashboard thời gian thực',
      'desc_en': 'Interactive charts, Real-time Dashboard',
      'icon': Icons.insights_rounded,
      'colors': [const Color(0xFF10B981), const Color(0xFF059669)],
      'progress': 0.95, 'tech': ['Flutter', 'FL Chart', 'Firebase'],
      'route': '/dashboard',
      'details_vi': [
        'Dashboard tổng quan KPIs',
        'Biểu đồ tương tác (Line, Bar, Pie, Radar)',
        'Bản đồ phân bố khách hàng',
        'Real-time monitoring & alerts',
      ],
      'details_en': [
        'KPI overview dashboard', 'Interactive charts (Line, Bar, Pie, Radar)',
        'Customer distribution maps', 'Real-time monitoring & alerts',
      ],
      'metrics': {'Charts': '12+', 'FPS': '60', 'Platform': 'Cross'},
      'logPrefix': 'Dashboard rendered at 60fps · 12 charts active',
      'logLevel': _LogLevel.ok,
    },
    {
      'title_vi': '6. Business Insight', 'title_en': '6. Business Insight',
      'desc_vi': 'Đề xuất chiến lược bán chéo, giá, nhập hàng thông minh',
      'desc_en': 'Cross-sell, pricing, and restock strategies',
      'icon': Icons.rocket_launch_rounded,
      'colors': [const Color(0xFFF59E0B), const Color(0xFFEAB308)],
      'progress': 0.8, 'tech': ['AI Agent', 'Gemini', 'KPIs'],
      'route': '/agent',
      'details_vi': [
        'Đề xuất bán chéo sản phẩm (Cross-selling)',
        'Tối ưu chiến lược giá (Dynamic Pricing)',
        'Dự báo nhu cầu nhập hàng (Demand Planning)',
        'Phân loại khách hàng VIP & chiến lược CRM',
      ],
      'details_en': [
        'Product cross-selling recommendations',
        'Dynamic pricing optimization',
        'Demand planning & restocking',
        'VIP customer classification & CRM strategy',
      ],
      'metrics': {'ROI': '+23%', 'Accuracy': '91%', 'Actions': '15+'},
      'logPrefix': '✦ Pipeline complete · ROI projection: +23%',
      'logLevel': _LogLevel.done,
    },
  ];

  // ── lifecycle ───────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    _flowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();

    _simCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12));

    _simCtrl.addListener(_onSimProgress);
    _simCtrl.addStatusListener(_onSimStatus);

    // particle ticker
    _particleTicker = createTicker(_onParticleTick)..start();
  }

  void _onParticleTick(Duration elapsed) {
    if (!mounted) return;
    final t = elapsed.inMilliseconds.toDouble();
    final dt = (t - _lastTickTime) / 1000.0;
    _lastTickTime = t;

    // spawn new particles along visible connectors
    if (_rnd.nextDouble() < 0.35) {
      final nodeCount = _steps.length;
      final seg = _rnd.nextInt(nodeCount - 1);
      // rough x positions based on parent layout width — updated in build
      final segFromX = _segFromX(seg);
      final segToX = _segFromX(seg + 1);
      if (segFromX != null && segToX != null) {
        final colors = _steps[seg + 1]['colors'] as List<Color>;
        _particles.add(_Particle(
          fromX: segFromX,
          toX: segToX,
          baseY: 36.0,
          color: colors[0],
        ));
      }
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt * 0.35);
      if (_particles[i].done) _particles.removeAt(i);
    }

    // cap particle count
    while (_particles.length > 80) {
      _particles.removeAt(0);
    }

    if (mounted) setState(() {});
  }

  // approximate x positions of nodes (will be refined with LayoutBuilder in build)
  double? _canvasWidth;

  double? _segFromX(int idx) {
    if (_canvasWidth == null) return null;
    final nodeCount = _steps.length;
    final nodeW = 58.0;
    final gap = (_canvasWidth! - nodeCount * nodeW) / (nodeCount + 1);
    if (idx >= nodeCount) return null;
    return gap + idx * (nodeW + gap) + nodeW;
  }

  void _onSimProgress() {
    final newStep = (_simCtrl.value * _steps.length).floor().clamp(0, _steps.length - 1);
    if (newStep != _simulatingStep) {
      setState(() {
        _simulatingStep = newStep;
        _expandedIndex = newStep;
      });
      _typewriterLogStep(newStep);
    }
  }

  void _onSimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _isSimulating = false;
        _simulatingStep = -1;
      });
    }
  }

  // ── EFFECT 3: typewriter ────────────────────
  String _nowTs() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2,'0')}:'
        '${now.minute.toString().padLeft(2,'0')}:'
        '${now.second.toString().padLeft(2,'0')}';
  }

  void _typewriterLogStep(int stepIdx) {
    final step = _steps[stepIdx];
    final text = step['logPrefix'] as String;
    final level = step['logLevel'] as _LogLevel;
    final line = _LogLine(timestamp: _nowTs(), level: level, fullText: text);
    setState(() => _logLines.add(line));

    _twTimer?.cancel();
    _twCharIdx = 0;
    _typeNextChar(line);
  }

  void _typeNextChar(_LogLine line) {
    if (_twCharIdx >= line.fullText.length) {
      line.typing = false;
      _scrollConsole();
      return;
    }
    _twTimer = Timer(
      Duration(milliseconds: 18 + _rnd.nextInt(22)),
          () {
        if (!mounted) return;
        setState(() {
          line.visibleText = line.fullText.substring(0, _twCharIdx + 1);
          _twCharIdx++;
        });
        _typeNextChar(line);
      },
    );
  }

  void _scrollConsole() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startSimulation() {
    setState(() {
      _isSimulating = true;
      _logLines.clear();
      _simulatingStep = -1;
    });
    _simCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _flowCtrl.dispose();
    _simCtrl.dispose();
    _particleTicker.dispose();
    _twTimer?.cancel();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildBgGrid(),
          CustomScrollView(
            slivers: [
              _buildHeader(context, settings, isMobile),
              _buildPhaseSelector(settings),
              _buildParticleFlow(),        // EFFECT 1
              if (_isSimulating || _logLines.isNotEmpty)
                _buildTypewriterConsole(settings), // EFFECT 3
              _buildTimeline(context, settings, isMobile),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSimulating ? null : _startSimulation,
        backgroundColor: _isSimulating ? Colors.grey : AppTheme.primaryColor,
        icon: _isSimulating
            ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_isSimulating
            ? (settings.isVietnamese ? 'Đang chạy...' : 'Running...')
            : (settings.isVietnamese ? 'Chạy mô phỏng' : 'Run Simulation')),
      ),
    );
  }

  // ── background grid ─────────────────────────
  Widget _buildBgGrid() => Positioned.fill(
    child: Opacity(
      opacity: 0.3,
      child: CustomPaint(
        painter: _GridPainter(AppTheme.primaryColor.withOpacity(0.1)),
      ),
    ),
  );

  // ── header ──────────────────────────────────
  Widget _buildHeader(BuildContext context, SettingsProvider settings, bool isMobile) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, isMobile ? 52 : 28, 20, 8),
        child: Row(children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: AppTheme.primaryColor
                      .withOpacity(0.3 + _pulseCtrl.value * 0.25),
                  blurRadius: 12 + _pulseCtrl.value * 8,
                  spreadRadius: 1,
                )],
              ),
              child: const Icon(Icons.schema_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.isVietnamese ? 'Quy trình Data Science' : 'Data Science Pipeline',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                settings.isVietnamese ? 'Nhấn vào từng bước để xem chi tiết' : 'Tap each step for details',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          )),
        ]),
      ),
    );
  }

  // ── phase selector ──────────────────────────
  Widget _buildPhaseSelector(SettingsProvider settings) {
    final phases = settings.isVietnamese
        ? ['Tất cả', 'Chuẩn bị', 'Mô hình', 'Triển khai']
        : ['All', 'Preparation', 'Modeling', 'Deployment'];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: phases.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = _activePhase == i;
              return GestureDetector(
                onTap: () => setState(() => _activePhase = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor])
                        : null,
                    color: selected ? null : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? Colors.transparent : Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(phases[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? Colors.white : Colors.grey.shade400,
                      )),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EFFECT 1 — Particle Flow Canvas
  // ─────────────────────────────────────────────
  Widget _buildParticleFlow() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: LayoutBuilder(builder: (_, constraints) {
            _canvasWidth = constraints.maxWidth;
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: _ParticleFlowPainter(
                  particles: _particles,
                  steps: _steps,
                  expandedIndex: _expandedIndex,
                  simulatingStep: _simulatingStep,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EFFECT 3 — Typewriter Console
  // ─────────────────────────────────────────────
  Widget _buildTypewriterConsole(SettingsProvider settings) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        padding: const EdgeInsets.all(12),
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF080B14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.12),
              blurRadius: 16,
              spreadRadius: 0,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.terminal, color: AppTheme.primaryColor, size: 13),
              const SizedBox(width: 7),
              const Text('PIPELINE CONSOLE',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const Spacer(),
              _buildPulseDot(Colors.greenAccent),
            ]),
            const Divider(color: Colors.white12, height: 10),
            Expanded(
              child: ListView.builder(
                controller: _logScrollCtrl,
                itemCount: _logLines.length,
                itemBuilder: (_, i) {
                  final line = _logLines[i];
                  return RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11, height: 1.5),
                      children: [
                        TextSpan(
                            text: '[${line.timestamp}] ',
                            style: const TextStyle(color: Color(0xFF718096))),
                        TextSpan(
                            text: line.visibleText,
                            style: TextStyle(color: line.color)),
                        if (line.typing)
                          WidgetSpan(
                            child: AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, __) => Opacity(
                                opacity: (_pulseCtrl.value > 0.5) ? 1.0 : 0.0,
                                child: const Text('▋',
                                    style: TextStyle(
                                        color: Color(0xFF68D391),
                                        fontSize: 11,
                                        height: 1.5)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseDot(Color color) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5 + _pulseCtrl.value * 0.5),
              blurRadius: 4 + _pulseCtrl.value * 6,
            )
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EFFECT 2 + 4 — Timeline cards (neon + tilt)
  // ─────────────────────────────────────────────
  bool _isStepVisible(int index) {
    if (_activePhase == 0) return true;
    if (_activePhase == 1) return index <= 1;
    if (_activePhase == 2) return index >= 2 && index <= 3;
    return index >= 4;
  }

  Widget _buildTimeline(
      BuildContext context, SettingsProvider settings, bool isMobile) {
    final visible = [
      for (int i = 0; i < _steps.length; i++)
        if (_isStepVisible(i)) i
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, vIdx) {
            final idx = visible[vIdx];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 350 + vIdx * 90),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                    offset: Offset(0, 24 * (1 - v)), child: child),
              ),
              child: _buildTimelineItem(context, settings, idx,
                  isLast: vIdx == visible.length - 1),
            );
          },
          childCount: visible.length,
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
      BuildContext context,
      SettingsProvider settings,
      int index, {
        required bool isLast,
      }) {
    final step = _steps[index];
    final colors = step['colors'] as List<Color>;
    final isExpanded = _expandedIndex == index;
    final isSimulating = _simulatingStep == index;
    final tilt = _tiltOffsets[index] ?? Offset.zero;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // timeline spine
          Column(children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  shape: BoxShape.circle,
                  border: isSimulating
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withOpacity(
                          (isExpanded || isSimulating)
                              ? 0.55 + _pulseCtrl.value * 0.35
                              : 0.25),
                      blurRadius: (isExpanded || isSimulating)
                          ? 18 + _pulseCtrl.value * 8
                          : 8,
                      spreadRadius: (isExpanded || isSimulating) ? 2 : 0,
                    ),
                  ],
                ),
                child: Icon(step['icon'] as IconData,
                    color: Colors.white, size: 20),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2.5,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isSimulating ? Colors.white : colors[0],
                        colors[1].withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              ),
          ]),

          const SizedBox(width: 14),

          // ── EFFECT 2 + 4: neon card with 3D tilt ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: MouseRegion(
                onHover: (e) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  // approximate card position
                  setState(() => _tiltOffsets[index] = e.localPosition);
                },
                onExit: (_) => setState(() => _tiltOffsets[index] = Offset.zero),
                child: GestureDetector(
                  onTap: () => setState(
                          () => _expandedIndex = isExpanded ? -1 : index),
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, child) {
                      // EFFECT 4 – 3D tilt via Transform
                      final dx = tilt == Offset.zero ? 0.0 : (tilt.dx - 160) / 160;
                      final dy = tilt == Offset.zero ? 0.0 : (tilt.dy - 80) / 80;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(dx * 0.07)
                          ..rotateX(-dy * 0.05),
                        child: child,
                      );
                    },
                    child: _buildNeonCard(
                        context, settings, step, index, colors,
                        isExpanded, isSimulating),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EFFECT 2 — Neon card body
  // ─────────────────────────────────────────────
  Widget _buildNeonCard(
      BuildContext context,
      SettingsProvider settings,
      Map<String, dynamic> step,
      int index,
      List<Color> colors,
      bool isExpanded,
      bool isSimulating,
      ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isExpanded
            ? LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [colors[0].withOpacity(0.18), const Color(0xFF1E2333)])
            : null,
        color: isExpanded ? null : const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(16),
        // EFFECT 2 – neon glow border
        border: Border.all(
          color: (isExpanded || isSimulating)
              ? colors[0]
              : Colors.white.withOpacity(0.06),
          width: (isExpanded || isSimulating) ? 1.5 : 1,
        ),
        boxShadow: (isExpanded || isSimulating)
            ? [
          BoxShadow(
            color: colors[0].withOpacity(0.35),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: colors[0].withOpacity(0.12),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                settings.isVietnamese
                    ? step['title_vi'] as String
                    : step['title_en'] as String,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: (isExpanded || isSimulating) ? colors[0] : Colors.white,
                ),
              ),
            ),
            // EFFECT 2 – liquid progress circle
            _buildLiquidProgress(step['progress'] as double, colors[0]),
          ]),
          const SizedBox(height: 6),
          Text(
            settings.isVietnamese
                ? step['desc_vi'] as String
                : step['desc_en'] as String,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6, runSpacing: 4,
              children: (step['tech'] as List<String>).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors[0].withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors[0].withOpacity(0.25)),
                ),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 10,
                        color: colors[0],
                        fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? _buildExpandedContent(
                context, step, settings, colors, index)
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EFFECT 2 — Liquid Progress Widget
  // ─────────────────────────────────────────────
  Widget _buildLiquidProgress(double progress, Color color) {
    return SizedBox(
      width: 40, height: 40,
      child: Stack(alignment: Alignment.center, children: [
        // shimmer track
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (_, v, __) => CircularProgressIndicator(
            value: v,
            strokeWidth: 3.5,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        // glow overlay
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15 + _pulseCtrl.value * 0.15),
                  blurRadius: 8 + _pulseCtrl.value * 6,
                )
              ],
            ),
          ),
        ),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }

  // ── expanded details ────────────────────────
  Widget _buildExpandedContent(
      BuildContext context,
      Map<String, dynamic> step,
      SettingsProvider settings,
      List<Color> colors,
      int index,
      ) {
    final details = settings.isVietnamese
        ? step['details_vi'] as List<String>
        : step['details_en'] as List<String>;
    final metrics = step['metrics'] as Map<String, String>;
    final route = step['route'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [colors[0].withOpacity(0.4), Colors.transparent]),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          settings.isVietnamese ? 'Chi tiết:' : 'Details:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors[0]),
        ),
        const SizedBox(height: 8),
        ...details.asMap().entries.map((e) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + e.key * 70),
          builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(14 * (1 - v), 0), child: child)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  decoration:
                  BoxDecoration(color: colors[0], shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(e.value,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade300,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 14),
        Text(
          settings.isVietnamese ? 'Chỉ số:' : 'Metrics:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors[0]),
        ),
        const SizedBox(height: 8),
        Row(
          children: metrics.entries.map((e) => Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: colors[0].withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors[0].withOpacity(0.2)),
              ),
              child: Column(children: [
                Text(e.value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors[0])),
                const SizedBox(height: 2),
                Text(e.key,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
              ]),
            ),
          )).toList(),
        ),
        if (route != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, route),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors[0].withOpacity(0.2),
                foregroundColor: colors[0],
                elevation: 0,
                side: BorderSide(color: colors[0].withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.launch_rounded, size: 16),
              label: Text(
                settings.isVietnamese
                    ? 'Khám phá Module này'
                    : 'Explore this Module',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Background grid
// ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}