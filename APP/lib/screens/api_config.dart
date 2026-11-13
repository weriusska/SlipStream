import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
  // Domyślnie dla fizycznego telefonu (Ngrok)
  static String baseUrl = 'https://sulphate-elusive-seltzer.ngrok-free.dev';

  static Future<void> init() async {
    try {
      // 1. Jeśli uruchomiono w przeglądarce (Chrome / Edge) -> lokalny port 5000
      if (kIsWeb) {
        baseUrl = 'http://127.0.0.1:5000';
      } 
      // 2. Jeśli uruchomiono jako aplikację Windows / macOS / Linux -> lokalny port 5000
      else if (defaultTargetPlatform == TargetPlatform.windows ||
               defaultTargetPlatform == TargetPlatform.macOS ||
               defaultTargetPlatform == TargetPlatform.linux) {
        baseUrl = 'http://127.0.0.1:5000';
      } 
      // 3. Jeśli to Android -> sprawdzamy czy emulator (10.0.2.2) czy fizyczny telefon (Ngrok)
      else if (defaultTargetPlatform == TargetPlatform.android) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        if (!androidInfo.isPhysicalDevice) {
          baseUrl = 'http://10.0.2.2:5000';
        }
      }
    } catch (e) {
      debugPrint('Błąd wykrywania platformy: $e');
    }

    debugPrint('🚀 Połączono z API pod adresem: $baseUrl');
  }
}