import 'package:flutter/material.dart';
import 'pick_a_race.dart'; // Upewnij się, że ścieżka jest poprawna

class YearPickerScreen extends StatefulWidget {
  // NOWOŚĆ: Definiujemy miejsce na ID kierowcy
  final String? scannedDriverId;

  // NOWOŚĆ: Dodajemy parametr do konstruktora
  const YearPickerScreen({super.key, this.scannedDriverId});

  @override
  State<YearPickerScreen> createState() => _YearPickerScreenState();
}

class _YearPickerScreenState extends State<YearPickerScreen> {
  int? selectedYear;

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final int itemCount = currentYear - 2018 + 1;
    final List<int> years = List.generate(itemCount, (index) => currentYear - index);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), 
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedYear != null
          ? ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                   MaterialPageRoute(
                    builder: (context) => RacePickerScreen(
                      selectedYear: selectedYear!,
                      // NOWOŚĆ: Podajemy ID kierowcy dalej do ekranu wyścigów!
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
                    icon: const Icon(
                      Icons.arrow_back, 
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                    },
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 24, 
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              const Text(
                'PICK A YEAR',
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
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.0, 
                  ),
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final year = years[index];
                    final bool isSelected = selectedYear == year;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (selectedYear == year) {
                            selectedYear = null;
                          } else {
                            selectedYear = year;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20), 
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white70,
                            width: isSelected ? 3 : 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            year.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
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