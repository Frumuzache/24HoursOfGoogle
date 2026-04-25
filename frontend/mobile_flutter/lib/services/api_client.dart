import 'dart:convert';
import 'dart:io';

class ApiClient {
  static const String baseUrl = 'http://172.20.10.3:8080/api/v1';

  Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> payload,
    int expectedStatus,
    String operation,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != expectedStatus) {
        throw Exception('Failed to $operation: ${response.statusCode}');
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error trying to $operation: $e');
    } finally {
      client.close(force: true);
    }
  }
  
  // Create user profile
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
  
  // Send health check-in
  Future<Map<String, dynamic>> sendCheckIn({
    required String profileId,
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