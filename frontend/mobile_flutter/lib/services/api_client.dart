import 'dart:convert';
import 'dart:io';

class ApiClient {
  // Folosim 127.0.0.1 (localhost) pentru că vei rula comanda "adb reverse"
  static const String baseUrl = 'http://10.200.23.114:8080/api/v1';

  Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> payload,
    int expectedStatus,
    String operation,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final client = HttpClient();

    // Debug print ca să vezi în terminal exact unde pleacă datele
    print('🚀 [API] Trimit $operation la: $uri');

    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      print('📥 [API] Răspuns server ($operation): ${response.statusCode}');

      if (response.statusCode != expectedStatus) {
        throw Exception('Status incorect: ${response.statusCode}. Body: $body');
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      print('❌ [API] Eroare la $operation: $e');
      throw Exception('Eroare conexiune: $e');
    } finally {
      client.close(force: true);
    }
  }

  // Creare profil utilizator
  Future<Map<String, dynamic>> createProfile({
    required String displayName,
    List<String> disorders = const [],
    List<String> calmingStrategies = const [],
    List<String> medications = const [],
    List<String> favoriteFoods = const [],
    List<String> hobbies = const [],
  }) async {
    return _postJson(
      '/profiles',
      {
        'displayName': displayName,
        'disorders': disorders,
        'calmingStrategies': calmingStrategies,
        'medications': medications,
        'favoriteFoods': favoriteFoods,
        'hobbies': hobbies,
      },
      201,
      'create profile',
    );
  }

  // Trimitere Check-in (Mood/Heart Rate)
  Future<Map<String, dynamic>> sendCheckIn({
    required int profileId,
    required int heartRate,
    required int moodScore,
    int anxietyLevel = 5,
  }) async {
    return _postJson(
      '/check-ins',
      {
        'profileId': profileId,
        'heartRate': heartRate,
        'moodScore': moodScore,
        'anxietyLevel': anxietyLevel,
        'panicAttack': false,
        'hasTakenMedication': false,
      },
      201,
      'send check-in',
    );
  }
}