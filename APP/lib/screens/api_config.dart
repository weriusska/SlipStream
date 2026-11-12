import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
  // Domyślny adres dla Twojego fizycznego telefonu (Wi-Fi)
  static String baseUrl = 'https://sulphate-elusive-seltzer.ngrok-free.dev';

  static Future<void> init() async {
    try {
      // Sprawdzamy tylko, jeśli jesteśmy na Androidzie
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        
        // Jeśli urządzenie NIE JEST fizyczne (czyli to emulator na laptopie)
        if (!androidInfo.isPhysicalDevice) {
          baseUrl = 'http://10.0.2.2:5000'; 
          print('Uruchomiono na emulatorze. Adres API: $baseUrl');
        } else {
          print('Uruchomiono na telefonie. Adres API: $baseUrl');
        }
      }
    } catch (e) {
      print('Błąd podczas konfiguracji API: $e');
    }
  }
}