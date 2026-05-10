import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/chart_config.dart';
import '../theme/app_theme.dart';

class DynamicChartWidget extends StatefulWidget {
  final ChartConfig config;
  final bool compact;
  final Function(String)? onDrillDown;

  const DynamicChartWidget({
    super.key,
    required this.config,
    this.compact = false,
    this.onDrillDown,
  });

  @override
  State<DynamicChartWidget> createState() => _DynamicChartWidgetState();
}

class _DynamicChartWidgetState extends State<DynamicChartWidget>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  // Premium pie palette — richer, more distinct hues
  static const List<Color> _pieColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryController.forward();
  }

  @override
  void didUpdateWidget(DynamicChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.title != widget.config.title ||
        oldWidget.config.type != widget.config.type) {
      _touchedIndex = null;
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryAnimation,
      child: Column(
        key: ValueKey(widget.config.title + widget.config.type),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildChart(context)),
          if (!widget.compact && widget.config.type != 'pie')
            _buildAxisLabel(),
          if (!widget.compact &&
              _touchedIndex != null &&
              _touchedIndex! >= 0 &&
              _touchedIndex! < widget.config.data.length)
            _buildDrillDownPanel(),
        ],
      ),
    );
  }

  Widget _buildAxisLabel() {
    if (widget.config.xAxisLabel == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 42),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.config.xAxisLabel!,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.35),
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    try {
      switch (widget.config.type) {
        case 'bar':
          return _buildBarChart(context);
        case 'line':
          return _buildLineChart(context);
        case 'pie':
          return _buildPieChart(context);
        case 'grouped_bar':
          return _buildGroupedBarChart(context);
        case 'combo':
          return _buildComboChart(context);
        default:
          return _buildFallback();
      }
    } catch (e) {
      return _buildErrorState(e.toString());
    }
  }

  // ─────────────────────────────────────────────
  // BAR CHART
  // ─────────────────────────────────────────────
  Color _barColor(double value, double maxValue) {
    if (value == maxValue) return const Color(0xFFFFD700);
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;
    const colors = [
      Color(0xFF7F77DD),
      Color(0xFF5E8FD4),
      Color(0xFF4AAFC6),
      Color(0xFF3DC9A0),
      Color(0xFF6DD67A),
    ];
    final idx = ((1 - ratio) * (colors.length - 1)).round();
    return colors[idx.clamp(0, colors.length - 1)];
  }

  Widget _buildBarChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();

    final maxValue = widget.config.data.map((e) => e.value).reduce(max);
    final totalValue =
    widget.config.data.map((e) => e.value).fold(0.0, (a, b) => a + b);
    final double maxY = maxValue * 1.28;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A2236),
            tooltipPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            tooltipMargin: 10,
            tooltipRoundedRadius: 14,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = widget.config.data[groupIndex];
              final pct =
              totalValue == 0 ? 0.0 : (item.value / totalValue * 100);
              return BarTooltipItem(
                '${item.label}\n',
                TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: _formatNumber(item.value),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3),
                  ),
                  TextSpan(
                    text: '  ${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              );
            },
          ),
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (!widget.compact &&
                (event is FlTapDownEvent || event is FlTapUpEvent) &&
                barTouchResponse?.spot != null) {
              setState(() {
                _touchedIndex =
                    barTouchResponse!.spot!.touchedBarGroupIndex;
              });
            }
          },
        ),
        titlesData: _buildTitlesData(isBar: true, maxValue: maxValue),
        gridData: _buildGridData(),
        borderData: FlBorderData(show: false),
        barGroups: widget.config.data.asMap().entries.map((e) {
          final isMax = e.value.value == maxValue;
          final color = widget.compact
              ? AppTheme.primaryColor
              : _barColor(e.value.value, maxValue);
          final isTouched = e.key == _touchedIndex;

          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                // Gradient rod fill
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isMax
                        ? const Color(0xFFFFD700)
                        : color.withOpacity(isTouched ? 1.0 : 0.95),
                    color.withOpacity(0.55),
                  ],
                ),
                width: isMax && !widget.compact
                    ? 22
                    : (widget.compact ? 12 : 16),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isMax ? 8 : 6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ],
            // Glow for max bar
            showingTooltipIndicators: [],
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LINE CHART
  // ─────────────────────────────────────────────
  Widget _buildLineChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();

    final color = _parseColor(widget.config.color ?? '#6366F1');
    final maxValue = widget.config.data.map((e) => e.value).reduce(max);
    final minValue = widget.config.data.map((e) => e.value).reduce(min);
    final avgValue = widget.config.data
        .map((e) => e.value)
        .fold(0.0, (a, b) => a + b) /
        widget.config.data.length;

    return LineChart(
      LineChartData(
        gridData: _buildGridData(),
        titlesData: _buildTitlesData(),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (widget.config.data.length - 1).toDouble(),
        extraLinesData: ExtraLinesData(
          horizontalLines: widget.compact
              ? []
              : [
            HorizontalLine(
              y: avgValue,
              color: Colors.white.withOpacity(0.18),
              strokeWidth: 1,
              dashArray: [6, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 10),
                labelResolver: (line) =>
                'TB: ${_formatNumber(avgValue)}',
              ),
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A2236),
            tooltipRoundedRadius: 14,
            tooltipPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            getTooltipItems: (spots) => spots.map((spot) {
              final idx = spot.x.toInt();
              final label = idx < widget.config.data.length
                  ? widget.config.data[idx].label
                  : '';
              return LineTooltipItem(
                '$label\n',
                TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: _formatNumber(spot.y),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3),
                  ),
                ],
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes
                .map((i) => TouchedSpotIndicatorData(
              FlLine(
                color: color.withOpacity(0.3),
                strokeWidth: 1.5,
                dashArray: [5, 4],
              ),
              FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) =>
                    FlDotCirclePainter(
                      radius: 7,
                      color: color,
                      strokeWidth: 2.5,
                      strokeColor: Colors.white,
                    ),
              ),
            ))
                .toList();
          },
          touchCallback: (FlTouchEvent event, lineTouchResponse) {
            if (!widget.compact &&
                (event is FlTapDownEvent || event is FlTapUpEvent) &&
                lineTouchResponse?.lineBarSpots != null) {
              setState(() {
                _touchedIndex =
                    lineTouchResponse!.lineBarSpots!.first.spotIndex;
              });
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: widget.config.data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.35, // Smooth Bézier
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            shadow: Shadow(
              color: color.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            dotData: FlDotData(
              show: !widget.compact,
              checkToShowDot: (spot, _) =>
              spot.y == maxValue || spot.y == minValue,
              getDotPainter: (spot, _, __, ___) {
                final isMax = spot.y == maxValue;
                final dotColor =
                isMax ? const Color(0xFFFFD700) : const Color(0xFFEF4444);
                return FlDotCirclePainter(
                  radius: isMax ? 6 : 5,
                  color: dotColor,
                  strokeWidth: 2.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.28),
                  color.withOpacity(0.1),
                  color.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PIE CHART
  // ─────────────────────────────────────────────
  Widget _buildPieChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();

    final totalValue =
    widget.config.data.map((e) => e.value).fold(0.0, (a, b) => a + b);

    final pieWidget = Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: widget.compact ? 2 : 3,
            centerSpaceRadius: widget.compact ? 28 : 54,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                if (!widget.compact &&
                    (event is FlTapDownEvent || event is FlTapUpEvent) &&
                    pieTouchResponse?.touchedSection != null) {
                  final index = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                  if (index >= 0) {
                    setState(() {
                      _touchedIndex = index;
                    });
                  }
                }
              },
            ),
            sections: widget.config.data.asMap().entries.map((e) {
              final isTouched = e.key == _touchedIndex;
              final color = _pieColors[e.key % _pieColors.length];
              final pct = totalValue == 0
                  ? 0.0
                  : e.value.value / totalValue * 100;

              return PieChartSectionData(
                color: color.withOpacity(isTouched ? 1.0 : 0.88),
                value: e.value.value,
                title: widget.compact
                    ? ''
                    : (isTouched
                    ? '${pct.toStringAsFixed(1)}%'
                    : (pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '')),
                radius: widget.compact
                    ? 30
                    : (isTouched ? 58 : 46),
                titleStyle: TextStyle(
                  fontSize: isTouched ? 12 : 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
                  ],
                ),
                borderSide: isTouched
                    ? BorderSide(color: color, width: 2)
                    : BorderSide.none,
              );
            }).toList(),
          ),
        ),
        // Center total label
        if (!widget.compact)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatNumber(totalValue),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'tổng',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
      ],
    );

    if (widget.compact) return pieWidget;

    return Column(
      children: [
        Expanded(child: pieWidget),
        const SizedBox(height: 14),
        _buildPieLegend(totalValue),
      ],
    );
  }

  Widget _buildPieLegend(double totalValue) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        itemCount: widget.config.data.length,
        itemBuilder: (context, i) {
          final item = widget.config.data[i];
          final color = _pieColors[i % _pieColors.length];
          final pct =
          totalValue == 0 ? 0.0 : item.value / totalValue;

          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                // Color dot with glow
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Progress bar
                SizedBox(
                  width: 48,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(pct * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // GROUPED BAR CHART
  // ─────────────────────────────────────────────
  Widget _buildGroupedBarChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();

    final List<Color> palette =
    (widget.config.colors ?? ['#6366F1', '#10B981'])
        .map((c) => _parseColor(c))
        .toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: _buildTitlesData(isBar: true),
        gridData: _buildGridData(),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A2236),
            tooltipRoundedRadius: 14,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = widget.config.data[groupIndex];
              final color = palette[rodIndex % palette.length];
              final seriesLabel = widget.config.series != null &&
                  rodIndex < widget.config.series!.length
                  ? widget.config.series![rodIndex]
                  : 'S${rodIndex + 1}';
              return BarTooltipItem(
                '$seriesLabel\n',
                TextStyle(color: Colors.grey.shade400, fontSize: 11),
                children: [
                  TextSpan(
                    text: _formatNumber(rod.toY),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: widget.config.data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barsSpace: 4,
            barRods: (e.value.values ?? []).asMap().entries.map((v) {
              final color = palette[v.key % palette.length];
              return BarChartRodData(
                toY: v.value,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withOpacity(0.5)],
                ),
                width: widget.compact ? 6 : 10,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // COMBO CHART
  // ─────────────────────────────────────────────
  Widget _buildComboChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();

    final barColor =
    _parseColor(widget.config.colors?[0] ?? '#6366F1');
    final lineColor = _parseColor(
        widget.config.colors?.length == 2
            ? widget.config.colors![1]
            : '#10B981');

    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            titlesData: _buildTitlesData(isBar: true),
            gridData: _buildGridData(),
            borderData: FlBorderData(show: false),
            barGroups: widget.config.data.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        barColor.withOpacity(0.45),
                        barColor.withOpacity(0.15),
                      ],
                    ),
                    width: widget.compact ? 12 : 20,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        LineChart(
          LineChartData(
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: widget.config.data
                    .asMap()
                    .entries
                    .where((e) =>
                e.value.values != null &&
                    e.value.values!.isNotEmpty)
                    .map((e) => FlSpot(
                    e.key.toDouble(), e.value.values![0]))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                shadow: Shadow(
                  color: lineColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: lineColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // DRILL-DOWN PANEL
  // ─────────────────────────────────────────────
  Widget _buildDrillDownPanel() {
    final item = widget.config.data[_touchedIndex!];
    final color = _pieColors[_touchedIndex! % _pieColors.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.12),
                  color.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.insights_rounded,
                      size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Giá trị: ${_formatNumber(item.value)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (widget.onDrillDown != null)
                  GestureDetector(
                    onTap: () => widget.onDrillDown!(item.label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.3),
                            color.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded,
                              size: 13, color: color),
                          const SizedBox(width: 5),
                          Text(
                            'Phân tích',
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  // ─────────────────────────────────────────────
  // SHARED CHART HELPERS
  // ─────────────────────────────────────────────
  FlTitlesData _buildTitlesData(
      {bool isBar = false, double maxValue = 0}) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: widget.config.data.length > 6 ? 52 : 30,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= widget.config.data.length) {
              return const SizedBox();
            }
            if (widget.config.data.length > 12 &&
                index % (widget.config.data.length ~/ 6) != 0) {
              return const SizedBox();
            }

            final label = widget.config.data[index].label;
            final shouldRotate =
                widget.config.data.length > 6 && !widget.compact;

            Widget text = Text(
              label.length > 8 ? '${label.substring(0, 7)}…' : label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            );

            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: shouldRotate
                  ? Transform.rotate(angle: -0.6, child: text)
                  : text,
            );
          },
        ),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: isBar && !widget.compact,
          reservedSize: 26,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= widget.config.data.length) {
              return const SizedBox();
            }
            if (widget.config.data[index].value != maxValue ||
                maxValue == 0) return const SizedBox();

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.18),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.5)),
              ),
              child: const Text(
                '▲ MAX',
                style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: !widget.compact,
          reservedSize: 38,
          getTitlesWidget: (value, meta) {
            if (value == meta.max) return const SizedBox();
            return Text(
              value >= 1000
                  ? '${(value / 1000).toStringAsFixed(1)}k'
                  : value.toInt().toString(),
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.28),
                  fontWeight: FontWeight.w500),
            );
          },
        ),
      ),
      rightTitles:
      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(
        color: Colors.white.withOpacity(0.045),
        strokeWidth: 1,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────
  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return value
          .toInt()
          .toString()
          .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return value.toInt().toString();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded,
              color: Colors.grey.shade700, size: 36),
          const SizedBox(height: 8),
          Text('Không có dữ liệu',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.withOpacity(0.4), size: 28),
          const SizedBox(height: 6),
          Text('Lỗi hiển thị',
              style: TextStyle(
                  color: Colors.red.withOpacity(0.4), fontSize: 11)),
        ],
      ),
    );
  }
}