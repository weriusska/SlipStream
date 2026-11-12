import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'api_config.dart';

class HeroScreen extends StatefulWidget {
  final int selectedYear;
  final String raceName;
  final String sessionType;
  final String driverId;

  const HeroScreen({
    super.key,
    required this.selectedYear,
    required this.raceName,
    required this.sessionType,
    required this.driverId,
  });

  @override
  State<HeroScreen> createState() => _HeroScreenState();
}

class _HeroScreenState extends State<HeroScreen> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? telemetryData;

  // Stan dla trybu porównania (Head-to-Head)
  bool isCompareLoading = false;
  Map<String, dynamic>? compareData;
  String? comparedDriverAbbr;

  @override
  void initState() {
    super.initState();
    _fetchTelemetry();
  }

  Future<void> _fetchTelemetry() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loc = Uri.encodeComponent(widget.raceName);
      final sess = Uri.encodeComponent(widget.sessionType);
      final drv = Uri.encodeComponent(widget.driverId);

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/telemetry?year=${widget.selectedYear}&location=$loc&session_type=$sess&driver=$drv',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded.containsKey('error')) {
          setState(() {
            errorMessage = decoded['error'].toString();
            isLoading = false;
          });
        } else {
          setState(() {
            telemetryData = decoded;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Błąd serwera: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Błąd połączenia z serwerem: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchComparison(String secondDriver) async {
    setState(() {
      isCompareLoading = true;
      comparedDriverAbbr = secondDriver;
    });

    try {
      final loc = Uri.encodeComponent(widget.raceName);
      final sess = Uri.encodeComponent(widget.sessionType);
      final drv1 = Uri.encodeComponent(telemetryData?['abbreviation'] ?? widget.driverId);
      final drv2 = Uri.encodeComponent(secondDriver);

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/compare?year=${widget.selectedYear}&location=$loc&session_type=$sess&driver1=$drv1&driver2=$drv2',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && !decoded.containsKey('error')) {
          setState(() {
            compareData = decoded;
            isCompareLoading = false;
          });
          return;
        }
      }
      setState(() => isCompareLoading = false);
    } catch (e) {
      setState(() => isCompareLoading = false);
    }
  }

  Future<void> _openCompareModal() async {
    final loc = Uri.encodeComponent(widget.raceName);
    final sess = Uri.encodeComponent(widget.sessionType);
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/drivers?year=${widget.selectedYear}&location=$loc&session_type=$sess',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<http.Response>(
          future: http.get(url),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }
            final decoded = json.decode(snapshot.data!.body);
            if (decoded is! List) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text('Nie udało się pobrać listy kierowców', style: TextStyle(color: Colors.white)),
                ),
              );
            }

            final currentAbbr = telemetryData?['abbreviation'];
            final drivers = decoded.where((d) => d['abbreviation'] != currentAbbr).toList();

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELECT RIVAL (HEAD-TO-HEAD)',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: drivers.length,
                      itemBuilder: (context, idx) {
                        final drv = drivers[idx];
                        final c = _parseHexColor(drv['team_color'] ?? '#FFFFFF');
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c,
                            child: Text(
                              drv['driver_number'].toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            drv['full_name'].toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            drv['team_name'].toString(),
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: Text(
                            drv['abbreviation'].toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _fetchComparison(drv['abbreviation'].toString());
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _parseHexColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    try {
      return Color(int.parse(hexColor, radix: 16));
    } catch (_) {
      return const Color(0xFFD4AF37);
    }
  }

  Color _getCompoundColor(String compound) {
    switch (compound.toUpperCase()) {
      case 'SOFT':
        return Colors.redAccent;
      case 'MEDIUM':
        return Colors.amber;
      case 'HARD':
        return Colors.white;
      case 'INTERMEDIATE':
        return Colors.greenAccent;
      case 'WET':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = telemetryData != null
        ? _parseHexColor(telemetryData!['team_color'] ?? '#D4AF37')
        : const Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : errorMessage != null
                ? _buildErrorView()
                : Column(
                    children: [
                      _buildTopBar(teamColor),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeroHeader(teamColor),
                              const SizedBox(height: 24),
                              if (isCompareLoading)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                                )
                              else if (compareData != null)
                                _buildComparisonSection()
                              else if (telemetryData!['mode'] == 'RACE')
                                _buildRaceSection(teamColor)
                              else
                                _buildQualiTelemetrySection(teamColor),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('WRÓĆ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color teamColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '${widget.selectedYear} ${widget.raceName.toUpperCase()} • ${telemetryData?['session_type'] ?? widget.sessionType}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (compareData != null)
            TextButton.icon(
              onPressed: () => setState(() => compareData = null),
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
              label: const Text('EXIT VS', style: TextStyle(color: Colors.redAccent)),
            )
          else
            OutlinedButton.icon(
              onPressed: _openCompareModal,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: teamColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
              label: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(Color teamColor) {
    final fullName = telemetryData!['full_name'] ?? '';
    final number = telemetryData!['driver_number'] ?? '';
    final teamName = telemetryData!['team_name'] ?? '';
    final fastestLap = telemetryData!['fastest_lap_time'] ?? 'N/A';
    final pos = telemetryData!['position'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: teamColor.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName.toString().toUpperCase(),
                      style: TextStyle(
                        color: teamColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullName.toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#$number',
                style: TextStyle(
                  color: teamColor,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge('POSITION', pos > 0 ? 'P$pos' : 'N/A'),
              _buildStatBadge('FASTEST LAP', fastestLap.toString()),
              _buildStatBadge('LAP NO.', '${telemetryData!['fastest_lap_number'] ?? '-'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDOK 1: KWALIFIKACJE / TRENINGI (Speed, Throttle/Brake, Gears)
  // ===========================================================================
  Widget _buildQualiTelemetrySection(Color teamColor) {
    final List<dynamic> pts = telemetryData!['telemetry'] ?? [];
    if (pts.isEmpty) {
      return const Center(
        child: Text('Brak punktów telemetrycznych.', style: TextStyle(color: Colors.white70)),
      );
    }

    final speedSpots = pts.map((p) => FlSpot((p['d'] as num).toDouble(), (p['s'] as num).toDouble())).toList();
    final throttleSpots = pts.map((p) => FlSpot((p['d'] as num).toDouble(), (p['t'] as num).toDouble())).toList();
    final brakeSpots = pts.map((p) => FlSpot((p['d'] as num).toDouble(), (p['b'] as num).toDouble())).toList();
    final gearSpots = pts.map((p) => FlSpot((p['d'] as num).toDouble(), (p['g'] as num).toDouble())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChartCard(
          title: 'SPEED PROFILE (KM/H vs DISTANCE)',
          height: 240,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 360,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: _defaultTitlesData(leftInterval: 100),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: speedSpots,
                  isCurved: true,
                  color: teamColor,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: teamColor.withOpacity(0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'THROTTLE (GREEN) & BRAKE (RED) %',
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 105,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: _defaultTitlesData(leftInterval: 50),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: throttleSpots,
                  isCurved: false,
                  color: Colors.greenAccent,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: brakeSpots,
                  isCurved: false,
                  color: Colors.redAccent,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.redAccent.withOpacity(0.2)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'GEAR SHIFTS (1 - 8)',
          height: 150,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 9,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: _defaultTitlesData(leftInterval: 2),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: gearSpots,
                  isStepLineChart: true,
                  color: const Color(0xFFD4AF37),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDOK 2: WYŚCIG ('R') -> Ewolucja czasów okrążeń i opony
  // ===========================================================================
  Widget _buildRaceSection(Color teamColor) {
    final List<dynamic> laps = telemetryData!['laps'] ?? [];
    if (laps.isEmpty) {
      return const Center(
        child: Text('Brak zarejestrowanych okrążeń wyścigowych.', style: TextStyle(color: Colors.white70)),
      );
    }

    final spots = laps.map((l) => FlSpot((l['lap_number'] as num).toDouble(), (l['lap_time_s'] as num).toDouble())).toList();
    final times = laps.map((l) => (l['lap_time_s'] as num).toDouble()).toList();
    final minTime = (times.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxTime = (times.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChartCard(
          title: 'RACE PACE (LAP TIME IN SECONDS)',
          height: 260,
          child: LineChart(
            LineChartData(
              minY: minTime,
              maxY: maxTime,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: _defaultTitlesData(leftInterval: 5),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: teamColor,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final compound = laps[index]['compound']?.toString() ?? 'UNKNOWN';
                      return FlDotCirclePainter(
                        radius: 4,
                        color: _getCompoundColor(compound),
                        strokeWidth: 1.5,
                        strokeColor: Colors.black,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CompoundLegend(label: 'SOFT', color: Colors.redAccent),
            SizedBox(width: 16),
            _CompoundLegend(label: 'MEDIUM', color: Colors.amber),
            SizedBox(width: 16),
            _CompoundLegend(label: 'HARD', color: Colors.white),
            SizedBox(width: 16),
            _CompoundLegend(label: 'INTER/WET', color: Colors.greenAccent),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDOK 3: PORÓWNANIE 1 vs 1 (Head-to-Head + Time Delta)
  // ===========================================================================
  Widget _buildComparisonSection() {
    final d1 = compareData!['driver1'];
    final d2 = compareData!['driver2'];
    final List<dynamic> comp = compareData!['comparison'] ?? [];

    final Color c1 = _parseHexColor(d1['team_color'] ?? '#FFFFFF');
    Color c2 = _parseHexColor(d2['team_color'] ?? '#FFD700');
    // Jeśli obaj są z tego samego zespołu, dajemy drugiemu kierowcy złoty/biały kontrast
    if (c1.value == c2.value) {
      c2 = const Color(0xFFD4AF37);
    }

    final spots1 = comp.map((p) => FlSpot((p['d'] as num).toDouble(), (p['s1'] as num).toDouble())).toList();
    final spots2 = comp.map((p) => FlSpot((p['d'] as num).toDouble(), (p['s2'] as num).toDouble())).toList();
    final deltaSpots = comp.map((p) => FlSpot((p['d'] as num).toDouble(), (p['delta'] as num).toDouble())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(d1['abbreviation'], style: TextStyle(color: c1, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text(d1['lap_time'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
              const Text('VS', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold)),
              Column(
                children: [
                  Text(d2['abbreviation'], style: TextStyle(color: c2, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text(d2['lap_time'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'HEAD-TO-HEAD SPEED COMPARISON (KM/H)',
          height: 240,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 360,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: _defaultTitlesData(leftInterval: 100),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots1,
                  isCurved: true,
                  color: c1,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: spots2,
                  isCurved: true,
                  color: c2,
                  barWidth: 2.0,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'TIME DELTA (SECONDS) • >0 MEANS ${d1['abbreviation']} AHEAD',
          height: 190,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: _defaultTitlesData(leftInterval: 0.5),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: 0, color: Colors.white54, strokeWidth: 1, dashArray: [4, 4]),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: deltaSpots,
                  isCurved: true,
                  color: const Color(0xFFD4AF37),
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({required String title, required double height, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }

  FlTitlesData _defaultTitlesData({required double leftInterval}) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: leftInterval,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(leftInterval < 1 ? 1 : 0),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _CompoundLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _CompoundLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}