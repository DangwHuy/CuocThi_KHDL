import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen> {
  Timer? _timer;
  final Random _random = Random();
  
  // Data for chart
  final List<FlSpot> _revenuePoints = [];
  double _timeX = 0;
  
  // Live events feed
  final List<Map<String, dynamic>> _liveEvents = [];
  
  // Metrics
  double _currentRevPerMin = 0;
  int _activeUsers = 120;
  int _anomaliesDetected = 0;

  final List<String> _sampleItems = [
    'whole milk', 'other vegetables', 'rolls/buns', 'soda', 'yogurt', 
    'bottled water', 'root vegetables', 'tropical fruit', 'sausage'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize chart with empty points
    for (int i = 0; i < 20; i++) {
      _revenuePoints.add(FlSpot(i.toDouble(), 0));
    }
    _timeX = 19;
    
    // Start live simulation
    _startLiveStream();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLiveStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 5500), (timer) {
      if (!mounted) return;
      
      setState(() {
        // 1. Update Chart Data
        _timeX += 1;
        
        // Base sine wave pattern + noise + occasional spikes
        double baseVal = 50 + sin(_timeX * 0.2) * 20;
        double noise = _random.nextDouble() * 20 - 10;
        double spike = _random.nextDouble() > 0.95 ? 80 : 0; // 5% chance of spike
        double newVal = (baseVal + noise + spike).clamp(0, 200).toDouble();
        
        _revenuePoints.add(FlSpot(_timeX, newVal));
        if (_revenuePoints.length > 20) {
          _revenuePoints.removeAt(0);
        }
        
        // 2. Update Metrics
        _currentRevPerMin = newVal * 40; // Simulated scaling
        _activeUsers = (_activeUsers + _random.nextInt(11) - 5).clamp(50, 500);
        if (spike > 0) _anomaliesDetected++;

        // 3. Add Live Event
        String item = _sampleItems[_random.nextInt(_sampleItems.length)];
        double price = DataService.getMockPrice(item);
        bool isAnomaly = spike > 0;
        
        _liveEvents.insert(0, {
          'time': DateTime.now(),
          'item': item,
          'price': price,
          'qty': _random.nextInt(3) + 1,
          'isAnomaly': isAnomaly,
        });
        
        if (_liveEvents.length > 50) {
          _liveEvents.removeLast();
        }
      });
    });
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
          _buildDataSourceInfo(context, settings),
          _buildMetricsCards(context, settings, isMobile),
          _buildLiveChart(context, settings),
          _buildLiveEvents(context, settings),
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade700],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stream_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      settings.isVietnamese ? 'Phân tích Thời gian thực' : 'Real-time Analytics',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    _buildLiveBadge(),
                  ],
                ),
                Text(
                  settings.isVietnamese
                      ? 'Dữ liệu streaming qua Apache Kafka / Spark'
                      : 'Live streaming via Apache Kafka / Spark',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDataSourceInfo(BuildContext context, SettingsProvider settings) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.isVietnamese ? 'Nguồn dữ liệu (Data Pipeline):' : 'Data Pipeline Source:',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.isVietnamese
                        ? 'Point of Sale (POS) → Apache Kafka → Apache Spark Streaming → FastAPI (WebSockets) → Flutter App'
                        : 'Point of Sale (POS) → Apache Kafka → Apache Spark Streaming → FastAPI (WebSockets) → Flutter App',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade300, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
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
          childAspectRatio: isMobile ? 1.4 : 2.0,
        ),
        delegate: SliverChildListDelegate([
          _buildMetricCard(
            title: settings.isVietnamese ? 'Tốc độ doanh thu (phút)' : 'Revenue Velocity (/min)',
            value: DataService.formatPrice(_currentRevPerMin, settings.isVietnamese),
            icon: Icons.speed_rounded,
            color: Colors.greenAccent.shade400,
          ),
          _buildMetricCard(
            title: settings.isVietnamese ? 'Người dùng đang Online' : 'Active Users Online',
            value: '$_activeUsers',
            icon: Icons.people_alt_rounded,
            color: Colors.blueAccent.shade400,
          ),
          _buildMetricCard(
            title: settings.isVietnamese ? 'Giao dịch / giây (TPS)' : 'Transactions/sec (TPS)',
            value: '0.67',
            icon: Icons.bolt_rounded,
            color: Colors.amber.shade400,
          ),
          _buildMetricCard(
            title: settings.isVietnamese ? 'Bất thường phát hiện' : 'Anomalies Detected',
            value: '$_anomaliesDetected',
            icon: Icons.warning_rounded,
            color: Colors.redAccent.shade400,
          ),
        ]),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade400), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChart(BuildContext context, SettingsProvider settings) {
    return SliverToBoxAdapter(
      child: Container(
        height: 250,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.isVietnamese ? 'LƯU LƯỢNG GIAO DỊCH STREAMING' : 'STREAMING TRANSACTION VOLUME',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 0.5),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 220,
                  minX: _revenuePoints.first.x,
                  maxX: _revenuePoints.last.x,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenuePoints,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.4),
                            AppTheme.primaryColor.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveEvents(BuildContext context, SettingsProvider settings) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  settings.isVietnamese ? 'KAFKA EVENT STREAM' : 'KAFKA EVENT STREAM',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 0.5),
                ),
                Icon(Icons.memory_rounded, size: 16, color: Colors.grey.shade500),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _liveEvents.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _liveEvents.length,
                      itemBuilder: (context, index) {
                        final event = _liveEvents[index];
                        final timeStr = '${event['time'].hour.toString().padLeft(2,'0')}:${event['time'].minute.toString().padLeft(2,'0')}:${event['time'].second.toString().padLeft(2,'0')}';
                        final itemName = settings.isVietnamese ? DataService.translateItem(event['item']) : event['item'];
                        final isAnomaly = event['isAnomaly'] as bool;
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isAnomaly ? Colors.redAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(6),
                            border: Border(left: BorderSide(color: isAnomaly ? Colors.redAccent : AppTheme.primaryColor, width: 3)),
                          ),
                          child: Row(
                            children: [
                              Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'User bought ${event['qty']}x $itemName',
                                  style: TextStyle(fontSize: 12, color: isAnomaly ? Colors.redAccent.shade100 : Colors.white),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DataService.formatPrice(event['price'] * event['qty'], settings.isVietnamese),
                                style: TextStyle(fontSize: 12, color: Colors.greenAccent.shade400, fontWeight: FontWeight.bold),
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
}
