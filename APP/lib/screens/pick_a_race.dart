import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'pick_a_session.dart'; 
import 'api_config.dart';

class RacePickerScreen extends StatefulWidget {
  final int selectedYear; 
  // NOWOŚĆ: Definiujemy miejsce na ID kierowcy
  final String? scannedDriverId;

  // NOWOŚĆ: Dodajemy parametr do konstruktora
  const RacePickerScreen({
    super.key, 
    required this.selectedYear, 
    this.scannedDriverId,
  });

  @override
  State<RacePickerScreen> createState() => _RacePickerScreenState();
}

class _RacePickerScreenState extends State<RacePickerScreen> {
  String? selectedRaceId; 
  List<dynamic> races = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRacesFromApi();
  }

  Future<void> _fetchRacesFromApi() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/races?year=${widget.selectedYear}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          races = json.decode(response.body);
          isLoading = false;
        });
      } else {
        print('Błąd API: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Błąd połączenia: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedRaceId != null
          ? ElevatedButton(
              onPressed: () {
                final selectedRace = races.firstWhere((race) => race['id'].toString() == selectedRaceId);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionPickerScreen(
                      selectedYear: widget.selectedYear,
                      raceName: selectedRace['name'], 
                      availableSessions: List<String>.from(selectedRace['sessions'] ?? []), 
                      // NOWOŚĆ: Podajemy ID kierowcy dalej do ekranu sesji!
                      scannedDriverId: widget.scannedDriverId,
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

              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : ListView.builder(
                        itemCount: races.length,
                        itemBuilder: (context, index) {
                          final race = races[index];
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
                                height: 160, 
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
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SvgPicture.asset(
                                          'assets/tracks/${race['image_slug']}.svg', 
                                          colorFilter: const ColorFilter.mode(
                                            Colors.white, 
                                            BlendMode.srcIn,
                                          ),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
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