import 'dart:math';
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

class _DynamicChartWidgetState extends State<DynamicChartWidget> {
  int? _touchedIndex;

  static const List<Color> _pieColors = [
    Color(0xFF534AB7), Color(0xFF1D9E75), Color(0xFFD4A017),
    Color(0xFF185FA5), Color(0xFFD85A30), Color(0xFF8E44AD),
    Color(0xFF16A085), Color(0xFFE67E22),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(widget.config.title + widget.config.type),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildChart(context),
        ),
        if (!widget.compact && widget.config.type != 'pie') _buildAxisLabels(),
        if (!widget.compact && _touchedIndex != null && _touchedIndex! < widget.config.data.length)
          _buildDrillDownPanel(),
      ],
    );
  }

  Widget _buildAxisLabels() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.config.xAxisLabel != null)
            Text(
              widget.config.xAxisLabel!,
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic),
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

  // --- BAR CHART ---
  Color _barColor(int index, int total, double value, double maxValue) {
    if (value == maxValue) return const Color(0xFFFFD700);
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;
    final colors = const [
      Color(0xFF7F77DD),
      Color(0xFF5E8FD4),
      Color(0xFF4AAFC6),
      Color(0xFF3DC9A0),
      Color(0xFF6DD67A),
    ];
    final colorIndex = ((1 - ratio) * (colors.length - 1)).round();
    return colors[colorIndex.clamp(0, colors.length - 1)];
  }

  Widget _buildBarChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();
    
    final maxValue = widget.config.data.map((e) => e.value).reduce(max);
    final totalValue = widget.config.data.map((e) => e.value).fold(0.0, (a, b) => a + b);
    final double maxY = maxValue * 1.25;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1F2E),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = widget.config.data[groupIndex];
              final pct = totalValue == 0 ? 0.0 : (item.value / totalValue * 100);
              return BarTooltipItem(
                '${item.label}\n',
                TextStyle(color: Colors.grey.shade400, fontSize: 11),
                children: [
                  TextSpan(
                    text: item.value.toInt().toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},'
                    ),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  TextSpan(
                    text: '  (${pct.toStringAsFixed(1)}%)',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              );
            },
          ),
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (!widget.compact && event.isInterestedForInteractions && barTouchResponse != null && barTouchResponse.spot != null) {
              setState(() { _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex; });
            } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
              // keep it open until tapped elsewhere maybe? Or just keep it.
              // setState(() { _touchedIndex = null; });
            }
          },
        ),
        titlesData: _buildTitlesData(isBar: true, maxValue: maxValue),
        gridData: _buildGridData(),
        borderData: FlBorderData(show: false),
        barGroups: widget.config.data.asMap().entries.map((e) {
          final isMax = e.value.value == maxValue;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: widget.compact ? AppTheme.primaryColor : _barColor(e.key, widget.config.data.length, e.value.value, maxValue),
                width: isMax && !widget.compact ? 22 : (widget.compact ? 12 : 16),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- LINE CHART ---
  Widget _buildLineChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();
    final color = _parseColor(widget.config.color ?? '#6366F1');
    final maxValue = widget.config.data.map((e) => e.value).reduce(max);
    final minValue = widget.config.data.map((e) => e.value).reduce(min);
    final avgValue = widget.config.data.map((e) => e.value).fold(0.0, (a, b) => a + b) / widget.config.data.length;

    return LineChart(
      LineChartData(
        gridData: _buildGridData(),
        titlesData: _buildTitlesData(),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: widget.compact ? [] : [
            HorizontalLine(
              y: avgValue,
              color: Colors.white.withOpacity(0.15),
              strokeWidth: 1,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                labelResolver: (line) => 'TB: ${avgValue.toInt()}',
              ),
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1F2E),
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                '${widget.config.data[spot.x.toInt()].label}\n',
                TextStyle(color: Colors.grey.shade400, fontSize: 11),
                children: [
                  TextSpan(
                    text: spot.y.toInt().toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((i) => TouchedSpotIndicatorData(
              FlLine(color: Colors.white.withOpacity(0.2), strokeWidth: 1, dashArray: [4, 4]),
              FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 6, color: color, strokeWidth: 2, strokeColor: Colors.white,
              )),
            )).toList();
          },
          touchCallback: (FlTouchEvent event, lineTouchResponse) {
            if (!widget.compact && event.isInterestedForInteractions && lineTouchResponse != null && lineTouchResponse.lineBarSpots != null) {
              setState(() { _touchedIndex = lineTouchResponse.lineBarSpots!.first.spotIndex; });
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: widget.config.data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: !widget.compact,
              checkToShowDot: (spot, barData) => spot.y == maxValue || spot.y == minValue,
              getDotPainter: (spot, _, __, ___) {
                final isMax = spot.y == maxValue;
                return FlDotCirclePainter(
                  radius: 5,
                  color: isMax ? const Color(0xFFFFD700) : const Color(0xFFD85A30),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.08), color.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PIE CHART ---
  Widget _buildPieChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();
    final totalValue = widget.config.data.map((e) => e.value).fold(0.0, (a, b) => a + b);

    final pieWidget = Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: widget.compact ? 30 : 52,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                if (!widget.compact && event.isInterestedForInteractions && pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                  setState(() {
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                } else if (event is FlTapUpEvent) {
                   setState(() { _touchedIndex = null; });
                }
              },
            ),
            sections: widget.config.data.asMap().entries.map((e) {
              final isTouched = e.key == _touchedIndex;
              final color = _pieColors[e.key % _pieColors.length];
              return PieChartSectionData(
                color: color,
                value: e.value.value,
                title: widget.compact ? '' : '${(e.value.value/totalValue*100).toStringAsFixed(0)}%',
                radius: widget.compact ? 30 : (isTouched ? 55 : 45),
                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
          ),
        ),
        if (!widget.compact)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              totalValue.toInt().toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text('tổng', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
      ],
    );

    if (widget.compact) return pieWidget;

    return Column(
      children: [
        Expanded(child: pieWidget),
        const SizedBox(height: 16),
        // Legend
        SizedBox(
          height: 100,
          child: ListView.builder(
            itemCount: widget.config.data.length,
            itemBuilder: (context, i) {
              final item = widget.config.data[i];
              final color = _pieColors[i % _pieColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(item.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 40, height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: totalValue == 0 ? 0 : item.value / totalValue,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 35,
                    child: Text('${totalValue == 0 ? 0 : (item.value/totalValue*100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 10, color: color, fontFamily: 'monospace')),
                  ),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrillDownPanel() {
    final item = widget.config.data[_touchedIndex!];
    final color = _pieColors[_touchedIndex! % _pieColors.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Giá trị: ${item.value.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (widget.onDrillDown != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.search_rounded, size: 14),
              label: const Text('Phân tích', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.2),
                foregroundColor: color,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(80, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onDrillDown!(item.label),
            ),
        ],
      ),
    );
  }

  // --- GROUPED BAR ---
  Widget _buildGroupedBarChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();
    final List<Color> palette = (widget.config.colors ?? ['#378ADD', '#1D9E75']).map((c) => _parseColor(c)).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: _buildTitlesData(isBar: true),
        gridData: _buildGridData(),
        borderData: FlBorderData(show: false),
        barGroups: widget.config.data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barsSpace: 4,
            barRods: (e.value.values ?? []).asMap().entries.map((v) {
              return BarChartRodData(
                toY: v.value,
                color: palette[v.key % palette.length],
                width: widget.compact ? 6 : 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  // --- COMBO CHART (Stack) ---
  Widget _buildComboChart(BuildContext context) {
    if (widget.config.data.isEmpty) return _buildFallback();
    final barColor = _parseColor(widget.config.colors?[0] ?? '#6366F1');
    final lineColor = _parseColor(widget.config.colors?.length == 2 ? widget.config.colors![1] : '#10B981');

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
                    color: barColor.withOpacity(0.3),
                    width: widget.compact ? 12 : 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
                spots: widget.config.data.asMap().entries.where((e) => e.value.values != null && e.value.values!.isNotEmpty).map((e) => FlSpot(e.key.toDouble(), e.value.values![0])).toList(),
                isCurved: true,
                color: lineColor,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- UTILS ---
  FlTitlesData _buildTitlesData({bool isBar = false, double maxValue = 0}) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: widget.config.data.length > 6 ? 52 : 30,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= widget.config.data.length) return const SizedBox();
            if (widget.config.data.length > 12 && index % (widget.config.data.length ~/ 6) != 0) return const SizedBox();

            final label = widget.config.data[index].label;
            final shouldRotate = widget.config.data.length > 6 && !widget.compact;
            
            Widget text = Text(
              label.length > 8 ? '${label.substring(0, 7)}…' : label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.right,
            );

            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: shouldRotate ? Transform.rotate(angle: -0.6, child: text) : text,
            );
          },
        ),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: isBar && !widget.compact,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= widget.config.data.length) return const SizedBox();
            if (widget.config.data[index].value != maxValue || maxValue == 0) return const SizedBox();
            
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
              ),
              child: const Text('▲ MAX', style: TextStyle(fontSize: 8, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: !widget.compact,
          reservedSize: 35,
          getTitlesWidget: (value, meta) {
            if (value == meta.max) return const SizedBox();
            return Text(
              value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toInt().toString(),
              style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.3)),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(
        color: Colors.white.withOpacity(0.05),
        strokeWidth: 1,
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Widget _buildFallback() {
    return const Center(child: Icon(Icons.show_chart, color: Colors.grey, size: 40));
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Text(
        'Chart Error',
        style: TextStyle(color: Colors.red.withOpacity(0.5), fontSize: 10),
      ),
    );
  }
}
