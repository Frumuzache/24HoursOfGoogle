import 'dart:convert';
import 'package:http/http.dart' as http;

class VitalsService {
  final String baseUrl = "http://10.200.23.114:8080/api/v1";

  Future<void> sendVitals(int profileId, int heartRate) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/vitals"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "profileId": profileId,
          "source": "watch",
          "heartRate": heartRate,
          "steps": 0, // Punem 0 default pentru test
        }),
      );

      if (response.statusCode == 201) {
        print("✅ Success: ${response.body}");
      } else {
        print("❌ Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Conexiune eșuată: $e");
    }
  }
}