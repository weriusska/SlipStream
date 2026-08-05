import 'package:flutter/material.dart';
import 'pick_a_race.dart';

class YearPickerScreen extends StatefulWidget {
  const YearPickerScreen({super.key});

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
      backgroundColor: const Color(0xFF1E1E1E), // Dostosuj odcień tła do swoich potrzeb
      
      // ===== PRZYCISK "NEXT" NA DOLE =====
      // Pojawia się na środku ekranu, tylko jeśli wybrano jakiś rok
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedYear != null
          ? ElevatedButton(
              onPressed: () {
                // Tutaj dodasz nawigację do następnego ekranu
                Navigator.push(
                  context,
                   MaterialPageRoute(
                    builder: (context) => RacePickerScreen(selectedYear: selectedYear!),
                ),
              );

              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9D9D9), // Jasnoszary z Twojego projektu
                foregroundColor: Colors.black, // Kolor tekstu
                padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 1.5, // Delikatne rozstrzelenie liter wg zdjęcia
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null, // Jeśli selectedYear to null, przycisk w ogóle się nie renderuje

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // Zmiana na center, aby dopasować się do układu ze zdjęcia
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [
              
              // ===== GÓRNY PASEK (STRZAŁKA + LOGO) =====
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
                      Navigator.pop(context); // Cofa do poprzedniego ekranu
                    },
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 24, // Możesz zmienić tę wartość, jeśli logo będzie za małe/za duże
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // ===== NAGŁÓWEK "PICK A YEAR" =====
              const Text(
                'PICK A YEAR',
                style: TextStyle(
                  color: Colors.white, // Zmieniłem na biały, tak jak na nowym zdjęciu
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              
              // Cienki biały pasek z obrazka
              Container(
                height: 2,
                width: 250, // Szerokość paska, możesz dopasować
                color: Colors.white,
              ),
              
              const SizedBox(height: 40),

              // ===== SIATKA Z LATAMI =====
              Expanded(
                child: GridView.builder(
                  // Pamiętaj o ustawieniu paddingu, jeśli chcesz zachować 2 kolumny i mniejsze kwadraty
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
                      borderRadius: BorderRadius.circular(20), // Zaokrąglenia ze zdjęcia
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          // Wzorując się na zdjęciu - puste w środku, tylko ramka
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
                              // Tu polecam podpiąć font podobny do tego ze zdjęcia (np. jakiś techniczny/kwadratowy)
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
              // Zostawiamy trochę miejsca na dole, żeby kafelki nie chowały się pod przyciskiem NEXT
              const SizedBox(height: 60), 
            ],
          ),
        ),
      ),
    );
  }
}