import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DriverPickerScreen extends StatefulWidget {
  final int selectedYear;
  final String raceName;
  final String sessionType;

  const DriverPickerScreen({
    super.key,
    required this.selectedYear,
    required this.raceName,
    required this.sessionType,
  });

  @override
  State<DriverPickerScreen> createState() => _DriverPickerScreenState();
}

class _DriverPickerScreenState extends State<DriverPickerScreen> {
  // Przechowujemy ID wybranego kierowcy (np. jego skrót lub numer)
  String? selectedDriverNumber; 
  
  // To będzie nasza pogrupowana lista: { "RED BULL RACING": [kierowca1, kierowca2], "FERRARI": [...] }
  Map<String, List<dynamic>> driversByTeam = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDriversFromApi();
  }

  // Funkcja konwertująca nazwę sesji z naszej aplikacji na skrót wymagany przez fastf1
  String _mapSessionTypeForApi(String session) {
    final lower = session.toLowerCase();
    if (lower.contains('qualifying') || lower.contains('shootout') || lower.contains('qualifications')) return 'Q';
    if (lower.contains('fp1') || lower.contains('practice 1')) return 'FP1';
    if (lower.contains('fp2') || lower.contains('practice 2')) return 'FP2';
    if (lower.contains('fp3') || lower.contains('practice 3')) return 'FP3';
    if (lower.contains('sprint')) return 'S';
    if (lower.contains('race')) return 'R';
    return session; // domyślnie wysyła to, co przyszło
  }

  Future<void> _fetchDriversFromApi() async {
    try {
      final fastF1SessionCode = _mapSessionTypeForApi(widget.sessionType);
      // Kodowanie URL, aby obsłużyć spacje w nazwach torów (np. "Marina Bay")
      final encodedLocation = Uri.encodeComponent(widget.raceName);
      final url = Uri.parse('http://10.2.0.164:5000/api/drivers?year=${widget.selectedYear}&location=$encodedLocation&session_type=$fastF1SessionCode');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        
        // Zabezpieczenie przed odwołanymi sesjami (kiedy Python zwróci error z try-except)
        if (decodedResponse is Map && decodedResponse.containsKey('error')) {
          setState(() {
            errorMessage = 'Sesja została odwołana lub brak danych (Błąd: ${decodedResponse['error']}).';
            isLoading = false;
          });
          return;
        }

        final List<dynamic> rawDrivers = decodedResponse;
        
        // GRUPOWANIE KIEROWCÓW WEDŁUG ZESPOŁÓW
        Map<String, List<dynamic>> grouped = {};
        for (var driver in rawDrivers) {
          // Używamy replaceAll, żeby usunąć ewentualne zbędne dopiski z nazwy
          String teamName = (driver['team_name'] ?? 'UNKNOWN').toString().toUpperCase();
          if (!grouped.containsKey(teamName)) {
            grouped[teamName] = [];
          }
          grouped[teamName]!.add(driver);
        }

        setState(() {
          driversByTeam = grouped;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Błąd serwera: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Błąd połączenia: sprawdź czy serwer działa.';
        isLoading = false;
      });
    }
  }

  // Funkcja zamieniająca kolor "#3671C6" na obiekt Color we Flutterze
  Color _parseHexColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Dodajemy pełne krycie (FF = 100% opacity)
    }
    try {
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.grey; // Kolor awaryjny
    }
  }

  Widget _buildDriverButton(dynamic driver) {
    final driverNumber = driver['driver_number'].toString();
    final abbreviation = driver['abbreviation'].toString();
    final bool isSelected = selectedDriverNumber == driverNumber;
    final Color teamColor = _parseHexColor(driver['team_color']);

    return InkWell(
      onTap: () {
        setState(() {
          selectedDriverNumber = isSelected ? null : driverNumber;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100, // Stała szerokość kwadratu (dopasuj wg uznania)
        height: 100,
        decoration: BoxDecoration(
          color: teamColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: teamColor.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              driverNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900, // Extra pogrubienie jak na zdjęciu
              ),
            ),
            const SizedBox(height: 4),
            Text(
              abbreviation,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedDriverNumber != null
          ? ElevatedButton(
              onPressed: () {
                print('Wybrano kierowcę z numerem: $selectedDriverNumber');
                // Nawigacja dalej
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
                style: TextStyle(fontSize: 20, letterSpacing: 1.5, fontWeight: FontWeight.w500),
              ),
            )
          : null,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ===== GÓRNY PASEK I NAGŁÓWEK =====
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
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
                    'PICK A DRIVER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 2, width: 250, color: Colors.white),
                ],
              ),
            ),

            // ===== LISTA ZESPOŁÓW I KIEROWCÓW =====
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100), // Miejsce na przycisk NEXT
                          itemCount: driversByTeam.keys.length,
                          itemBuilder: (context, index) {
                            String teamName = driversByTeam.keys.elementAt(index);
                            List<dynamic> drivers = driversByTeam[teamName]!;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Column(
                                children: [
                                  // NAZWA ZESPOŁU
                                  Text(
                                    teamName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // KAFELKI KIEROWCÓW W TYM ZESPOLE
                                  // Używamy widgetu Wrap, który naturalnie wyśrodkuje kafle i przełamie linię
                                  Wrap(
                                    spacing: 24, // Odstęp poziomy między kafelkami
                                    runSpacing: 16, // Odstęp pionowy (gdyby było > 2 kierowców)
                                    alignment: WrapAlignment.center,
                                    children: drivers.map((d) => _buildDriverButton(d)).toList(),
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