import 'package:flutter/material.dart';
import 'pick_a_driver.dart';
import 'hero_screen.dart';

class SessionPickerScreen extends StatefulWidget {
  final int selectedYear;
  final String raceName;
  final List<String> availableSessions; 
  // NOWOŚĆ: Miejsce na ID kierowcy z NFC
  final String? scannedDriverId;

  const SessionPickerScreen({
    super.key,
    required this.selectedYear,
    required this.raceName,
    required this.availableSessions,
    // NOWOŚĆ: Odbieramy ID w konstruktorze
    this.scannedDriverId,
  });

  @override
  State<SessionPickerScreen> createState() => _SessionPickerScreenState();
}

class _SessionPickerScreenState extends State<SessionPickerScreen> {
  String? selectedSession;

  Color _getSessionColor(String sessionName) {
    final lower = sessionName.toLowerCase();
    if (lower.contains('qualifying') || lower.contains('shootout')) {
      return const Color(0xFF3B0078); 
    } else if (lower.contains('practice 1') || lower.contains('practice 2') || lower.contains('practice 3')) {
      return const Color(0xFF00229E); 
    } else if (lower.contains('sprint')) {
      return const Color(0xFF4C6BFF); 
    } else if (lower.contains('race')) {
      return const Color(0xFF008A20); 
    }
    return const Color(0xFF2A2A2A); 
  }

  Widget _buildSessionButton(String title) {
    final bool isSelected = selectedSession == title;
    final Color bgColor = _getSessionColor(title);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedSession = isSelected ? null : title;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: isSelected ? 3 : 0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: bgColor.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedSession != null
          ? ElevatedButton(
              onPressed: () {
                print('Wybrano: $selectedSession, Wyścig: ${widget.raceName}');
                
                // ===== NOWA LOGIKA POMIJANIA EKRANU =====
                if (widget.scannedDriverId != null) {
                  // 1. Użytkownik ma kartę NFC! 
                  // Pomijamy ekran kierowców i idziemy prosto do HeroScreen.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HeroScreen(
                        selectedYear: widget.selectedYear,
                        raceName: widget.raceName,
                        sessionType: selectedSession!,
                        driverId: widget.scannedDriverId!,
                      ),
                    ),
                  );
                } else {
                  // 2. Użytkownik nie ma karty (klika manualnie).
                  // Idziemy normalnie do ekranu wyboru kierowcy.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverPickerScreen(
                        selectedYear: widget.selectedYear,
                        raceName: widget.raceName,
                        sessionType: selectedSession!, 
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Image.asset('assets/images/logo.png', height: 24),
                ],
              ),
              const SizedBox(height: 30),
              
              const Text(
                'PICK A SESSION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 2, width: 250, color: Colors.white),
              const SizedBox(height: 40), 

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.availableSessions.length,
                  itemBuilder: (context, index) {
                    final sessionName = widget.availableSessions[index];
                    return _buildSessionButton(sessionName);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}