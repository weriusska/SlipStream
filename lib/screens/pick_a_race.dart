import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'pick_a_session.dart';

class RacePickerScreen extends StatefulWidget {
  final int selectedYear; // Przyjmujemy rok z poprzedniego ekranu

  const RacePickerScreen({super.key, required this.selectedYear});

  @override
  State<RacePickerScreen> createState() => _RacePickerScreenState();
}

class _RacePickerScreenState extends State<RacePickerScreen> {
  String? selectedRaceId; // Przechowujemy ID wybranego wyścigu
  List<dynamic> races = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRacesFromApi();
  }

  // ===== FUNKCJA POBIERAJĄCA DANE Z PYTHONA =====
  Future<void> _fetchRacesFromApi() async {
    try {
      // Podmień na adres swojego API Pythona (dla emulatora Androida localhost to często 10.0.2.2)
      final url = Uri.parse('http://10.2.0.164:5000/api/races?year=${widget.selectedYear}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          races = json.decode(response.body);
          isLoading = false;
        });
      } else {
        // Obsługa błędu serwera
        print('Błąd API: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      // Obsługa braku połączenia
      print('Błąd połączenia: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      
      // ===== PRZYCISK "NEXT" NA DOLE =====
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedRaceId != null
          ? ElevatedButton(
              onPressed: () {
                print('Wybrano wyścig o ID: $selectedRaceId dla roku ${widget.selectedYear}');
                
                // ===== NOWOŚĆ: SZUKAMY PEŁNYCH DANYCH WYŚCIGU =====
                // Przeszukujemy listę "races", aby znaleźć ten wyścig, którego ID pasuje do wybranego.
                final selectedRace = races.firstWhere((race) => race['id'].toString() == selectedRaceId);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionPickerScreen(
                      selectedYear: widget.selectedYear,
                      // Używamy znalezionego obiektu selectedRace
                      raceName: selectedRace['name'], 
                      availableSessions: List<String>.from(selectedRace['sessions'] ?? []), 
                    ),
                  ),
                );
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
              
              // ===== GÓRNY PASEK (STRZAŁKA + LOGO) =====
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 24,
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // ===== NAGŁÓWEK "PICK A RACE" =====
              const Text(
                'PICK A RACE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                width: 250,
                color: Colors.white,
              ),
              const SizedBox(height: 40),

              // ===== LISTA WYŚCIGÓW LUB ŁADOWANIE =====
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : ListView.builder(
                        itemCount: races.length,
                        itemBuilder: (context, index) {
                          final race = races[index];
                          // Sprawdzamy wybrane ID
                          final bool isSelected = selectedRaceId == race['id'].toString();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedRaceId = isSelected ? null : race['id'].toString();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 160, // Wysokość kafelka wg zdjęcia
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white54,
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // ZDJĘCIE TORU (pobierane z assets)

                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SvgPicture.asset(
                                          'assets/tracks/${race['image_slug']}.svg', // Zwróć uwagę na .svg na końcu!
                                          // Dzięki temu pokolorujemy każdy tor na biało, niezależnie od tego jaki miał kolor oryginalnie
                                          colorFilter: const ColorFilter.mode(
                                            Colors.white, 
                                            BlendMode.srcIn,
                                          ),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    //NAZWA TORU
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Text(
                                        race['name'].toString().toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 60), 
            ],
          ),
        ),
      ),
    );
  }
}