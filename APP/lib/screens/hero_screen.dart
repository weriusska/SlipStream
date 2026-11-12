import 'package:flutter/material.dart';
import 'api_config.dart';

class HeroScreen extends StatelessWidget {
  final int selectedYear;
  final String raceName;
  final String sessionType;
  final String driverId; // ID kierowcy, które dotarło aż tutaj!

  const HeroScreen({
    super.key,
    required this.selectedYear,
    required this.raceName,
    required this.sessionType,
    required this.driverId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'EKRAN DOCELOWY\nKierowca: $driverId\n$selectedYear $raceName ($sessionType)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.5),
        ),
      ),
    );
  }
}