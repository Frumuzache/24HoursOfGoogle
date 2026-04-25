import 'dart:convert' as convert;
import 'dart:io';

class ApiClient {
  // Backend API (running in Docker)
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
  // AI Service (running in Docker)
  static const String aiUrl = 'http://10.0.2.2:8000';

  // Conversation history for AI chat
  final List<Map<String, String>> _chatHistory = [];

  List<Map<String, String>> get chatHistory => List.unmodifiable(_chatHistory);

  void clearHistory() {
    _chatHistory.clear();
  }

  Future<Map<String, dynamic>> _postJson(
    String uri,
    Map<String, dynamic> payload,
    int expectedStatus,
    String operation,
  ) async {
    print('🚀 [API] Trimit $operation la: $uri');

    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(uri)).timeout(const Duration(seconds: 60));
      request.headers.contentType = ContentType.json;
      request.write(convert.jsonEncode(payload));

      final response = await request.close().timeout(const Duration(seconds: 60));
      final body = await response.transform(convert.utf8.decoder).join();

      print('📥 [API] Răspuns server ($operation): ${response.statusCode}');
      client.close();

      if (response.statusCode != expectedStatus) {
        throw Exception('Status incorect: ${response.statusCode}. Body: $body');
      }

      return convert.jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      print('❌ [API] Eroare la $operation: $e');
      throw Exception('Eroare conexiune: $e');
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
      '$baseUrl/profiles',
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

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _postJson(
      '$baseUrl/auth/register',
      {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
      201,
      'register',
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _postJson(
      '$baseUrl/auth/login',
      {
        'email': email,
        'password': password,
      },
      200,
      'login',
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
      '$baseUrl/check-ins',
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

  // Chat cu AI Assistant - cu istoric
  Future<String> chatWithAi({
    required String message,
    String userName = '',
    String userConditions = '',
    String heartRate = '',
    String calmingMethods = '',
    String hobbies = '',
    String nearbySafePlaces = '',
    String templateName = 'default_prompt.txt',
    List<Map<String, String>>? conversationHistory,
  }) async {
    final response = await _postJson(
      '$aiUrl/infer',
      {
        'input': message,
        'template_name': templateName,
        'user_name': userName,
        'user_conditions': userConditions,
        'heart_rate': heartRate,
        'calming_methods': calmingMethods,
        'hobbies': hobbies,
        'nearby_safe_places': nearbySafePlaces,
        'conversation_history': conversationHistory ?? _chatHistory,
      },
      200,
      'chat with AI',
    );
    return response['output'] as String;
  }

  // Obține profil utilizator
  Future<Map<String, dynamic>> getProfile(int profileId) async {
    return _postJson(
      '$baseUrl/profiles/$profileId',
      {},
      200,
      'get profile',
    );
  }
}