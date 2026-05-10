import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/chart_config.dart';
import '../theme/app_theme.dart';
import 'dynamic_chart_widget.dart';

class ChartPanel extends StatefulWidget {
  final ChartConfig? currentChart;
  final List<ChartConfig> history;
  final Function(ChartConfig)? onSelect;
  final Function(String)? onDrillDown;

  const ChartPanel({
    super.key,
    this.currentChart,
    required this.history,
    this.onSelect,
    this.onDrillDown,
  });

  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late PageController _pageController;
  late ScrollController _historyScrollController;

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo PageController tại vị trí của biểu đồ hiện tại
    final initialPage = widget.currentChart != null 
        ? widget.history.indexOf(widget.currentChart!) 
        : 0;
    _pageController = PageController(initialPage: initialPage.clamp(0, widget.history.length));
    _historyScrollController = ScrollController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu biểu đồ hiện tại thay đổi từ bên ngoài (ví dụ click nút), hãy trượt PageView đến đó
    if (widget.currentChart != oldWidget.currentChart && widget.currentChart != null) {
      final index = widget.history.indexOf(widget.currentChart!);
      if (index != -1 && _pageController.hasClients) {
        if ((_pageController.page?.round() ?? -1) != index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentChart == null || widget.history.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.history.length,
            onPageChanged: (index) {
              if (index < widget.history.length) {
                widget.onSelect?.call(widget.history[index]);
              }
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final chart = widget.history[index];
              return _buildChartCard(context, chart);
            },
          ),
        ),
        if (widget.history.length > 1) ...[
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildHistoryList(),
        ],
      ],
    );
  }

  Widget _buildChartCard(BuildContext context, ChartConfig chart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      key: ValueKey(
        chart.title +
            chart.type +
            widget.history.indexOf(chart).toString(),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.cardColor.withOpacity(0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.09),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildHeader(chart),
                const SizedBox(height: 20),
                Expanded(
                  child: DynamicChartWidget(
                    config: chart,
                    compact: false,
                    onDrillDown: widget.onDrillDown,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ChartConfig chart) {
    return Row(
      children: [
        // Gradient icon badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHÂN TÍCH DỮ LIỆU',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                chart.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Chart type badge — glassmorphism pill
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIconForType(chart.type),
                    size: 12,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    chart.type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return SizedBox(
      height: 54, // Tăng nhẹ chiều cao để không bị thanh cuộn che mất
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: _historyScrollController,
          thumbVisibility: true,
          thickness: 3,
          radius: const Radius.circular(10),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0), // Tạo khoảng trống cho thanh cuộn
            child: ListView.separated(
              controller: _historyScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final item = widget.history[i];
                final isSelected = item == widget.currentChart;
                return GestureDetector(
                  onTap: () => widget.onSelect?.call(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.32),
                          AppTheme.primaryColor.withOpacity(0.12),
                        ],
                      )
                          : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.6)
                            : Colors.white.withOpacity(0.07),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            _getIconForType(item.type),
                            size: 12,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.title.length > 13
                              ? '${item.title.substring(0, 12)}…'
                              : item.title,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey.shade500,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            letterSpacing: isSelected ? 0.1 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'bar':
        return Icons.bar_chart_rounded;
      case 'line':
        return Icons.show_chart_rounded;
      case 'pie':
        return Icons.pie_chart_rounded;
      case 'grouped_bar':
        return Icons.stacked_bar_chart_rounded;
      case 'combo':
        return Icons.auto_graph_rounded;
      default:
        return Icons.analytics_rounded;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor.withOpacity(0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                AppTheme.cardColor.withOpacity(0.0),
                AppTheme.primaryColor.withOpacity(0.03),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Decorative background rings
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _EmptyStatePainter(
                        opacity: _pulseAnimation.value * 0.12,
                        rotate: _rotateAnimation.value,
                      ),
                    );
                  },
                ),
              ),
              // Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _pulseAnimation.value,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.18),
                                Colors.transparent,
                              ],
                            ),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.area_chart_outlined,
                            size: 32,
                            color: AppTheme.primaryColor.withOpacity(0.6),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Biểu đồ sẽ xuất hiện ở đây',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hỏi AI về sản phẩm, xu hướng hoặc khách hàng',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Decorative chips
                  Wrap(
                    spacing: 8,
                    children: ['Doanh thu', 'Xu hướng', 'Khách hàng']
                        .map((label) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Decorative concentric rings painter for empty state
class _EmptyStatePainter extends CustomPainter {
  final double opacity;
  final double rotate;

  _EmptyStatePainter({required this.opacity, required this.rotate});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final radii = [size.width * 0.28, size.width * 0.4, size.width * 0.52];
    for (int i = 0; i < radii.length; i++) {
      paint.color = AppTheme.primaryColor.withOpacity(opacity * (1 - i * 0.25));
      canvas.drawCircle(center, radii[i], paint);
    }

    // Subtle diagonal line pattern
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.4)
      ..strokeWidth = 0.5;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotate);
    canvas.translate(-center.dx, -center.dy);
    for (double x = -size.width; x < size.width * 2; x += 28) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmptyStatePainter old) =>
      old.opacity != opacity || old.rotate != rotate;
}