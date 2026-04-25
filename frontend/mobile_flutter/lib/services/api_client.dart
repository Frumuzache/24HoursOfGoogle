import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  static const String baseUrl = 'http://localhost:3000/api/v1';
  
  // Create user profile
  Future<Map<String, dynamic>> createProfile({
    required String displayName,
    List<String> disorders = const [],
    List<String> calmingStrategies = const [],
    List<String> medications = const [],
    List<String> favoriteFoods = const [],
    List<String> hobbies = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'displayName': displayName,
          'disorders': disorders,
          'calmingStrategies': calmingStrategies,
          'medications': medications,
          'favoriteFoods': favoriteFoods,
          'hobbies': hobbies,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 201) {
        throw Exception('Failed to create profile: ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error creating profile: $e');
    }
  }
  
  // Send health check-in
  Future<Map<String, dynamic>> sendCheckIn({
    required String profileId,
    required int heartRate,
    required int moodScore,
    int anxietyLevel = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-ins'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'profileId': profileId,
          'heartRate': heartRate,
          'moodScore': moodScore,
          'anxietyLevel': anxietyLevel,
          'panicAttack': false,
          'hasTakenMedication': false,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 201) {
        throw Exception('Failed to send check-in: ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error sending check-in: $e');
    }
  }
}