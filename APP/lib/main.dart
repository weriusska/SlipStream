import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'screens/welcome.dart'; 
import 'screens/pick_a_race.dart'; // Tu pamiętaj o poprawnej ścieżce, którą ustaliliśmy
import 'screens/api_config.dart'; // Pamiętaj o dodaniu tego importu!

void main() async {
  // Upewniamy się, że silnik Fluttera jest gotowy na operacje asynchroniczne
  WidgetsFlutterBinding.ensureInitialized();
  
  // Odpalamy nasz "wykrywacz" urządzenia
  await ApiConfig.init(); 

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Ten sam klucz do nawigacji
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  
  // NOWOŚĆ: Zmienna przechowująca ID kierowcy odczytane z karty. 
  // Jeśli użytkownik otworzy apkę bez karty, po prostu będzie to "null".
  String? nfcDriverId;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'slipstream') {
      
      // Nasz nowy link: slipstream://driver/1
      if (uri.host == 'driver' && uri.pathSegments.isNotEmpty) {
        
        setState(() {
          // Zapisujemy odczytany identyfikator (w naszym przykładzie to "1")
          nfcDriverId = uri.pathSegments.first;
        });
        
        // Zamiast "wyskakiwać" z nowym ekranem, tylko powiadamiamy użytkownika
        print("Zeskanowano kartę kierowcy: $nfcDriverId");
        
        // Opcjonalnie: Jeśli aplikacja była "zamknięta", i tak musimy wrzucić go na WelcomeScreen, 
        // ale teraz WelcomeScreen ma dostęp do zmiennej nfcDriverId!
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SlipSTREAM',
      theme: ThemeData.dark(),
      
      // Tutaj jest klucz! Przekazujemy zeskanowane ID do pierwszego ekranu
      home: WelcomeScreen(scannedDriverId: nfcDriverId),  
      
      debugShowCheckedModeBanner: false,
    );
  }
}