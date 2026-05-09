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

class _ChartPanelState extends State<ChartPanel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentChart == null) {
      return _buildEmptyState(context);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(widget.currentChart!.title + widget.currentChart!.type + widget.history.indexOf(widget.currentChart!).toString()),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Color.fromARGB(
                255,
                Theme.of(context).cardColor.red,
                Theme.of(context).cardColor.green,
                (Theme.of(context).cardColor.blue + 8).clamp(0, 255),
              ),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHÂN TÍCH DỮ LIỆU',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.08, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        widget.currentChart!.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getIconForType(widget.currentChart!.type), size: 12, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        widget.currentChart!.type.toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Main Chart
            Expanded(
              child: DynamicChartWidget(
                config: widget.currentChart!, 
                compact: false,
                onDrillDown: widget.onDrillDown,
              ),
            ),
            
            // History
            if (widget.history.length > 1) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.05)),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.history.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final item = widget.history[i];
                    final isSelected = item == widget.currentChart;
                    return GestureDetector(
                      onTap: () => widget.onSelect?.call(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? LinearGradient(colors: [AppTheme.primaryColor.withOpacity(0.3), AppTheme.primaryColor.withOpacity(0.1)])
                              : null,
                          color: isSelected ? null : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIconForType(item.type),
                              size: 12,
                              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.title.length > 12 ? '${item.title.substring(0, 11)}…' : item.title,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'bar': return Icons.bar_chart_rounded;
      case 'line': return Icons.show_chart_rounded;
      case 'pie': return Icons.pie_chart_rounded;
      case 'grouped_bar': return Icons.stacked_bar_chart_rounded;
      default: return Icons.analytics_rounded;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Color.fromARGB(
              255,
              Theme.of(context).cardColor.red,
              Theme.of(context).cardColor.green,
              (Theme.of(context).cardColor.blue + 8).clamp(0, 255),
            ),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulseAnimation,
              child: Icon(Icons.area_chart_outlined, size: 44, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const Text(
              'Biểu đồ sẽ xuất hiện ở đây',
              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Hỏi AI về sản phẩm, xu hướng hoặc khách hàng',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
