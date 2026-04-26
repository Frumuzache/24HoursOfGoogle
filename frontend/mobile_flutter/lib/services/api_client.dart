import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

class ApiClient {
  // Backend API host. Defaults to network IP. Override with --dart-define=API_HOST=<ip> for local dev.
  static const String _apiHost = String.fromEnvironment('API_HOST', defaultValue: '10.200.22.248');
  // AI service host. Defaults to network IP for physical devices.
  // For localhost/emulator use: 127.0.0.1 or 10.0.2.2
  static const String _aiHost = String.fromEnvironment('AI_HOST', defaultValue: '10.200.22.248');
  // Optional full AI URL override (example: http://192.168.6.1:8000).
  static const String _aiUrlOverride = String.fromEnvironment('AI_URL', defaultValue: '');

  // Backend API (running in Docker)
  static String get baseUrl => 'http://$_apiHost:8080/api/v1';
  // AI Service (running in Docker)
  static String get aiUrl {
    if (_aiUrlOverride.isNotEmpty) return _aiUrlOverride;
    return 'http://$_aiHost:8000';
  }

  // Conversation history for AI chat
  final List<Map<String, String>> _chatHistory = [];

  List<Map<String, String>> get chatHistory => List.unmodifiable(_chatHistory);

  void clearHistory() {
    _chatHistory.clear();
  }

  Future<void> _delay(Duration duration) async {
    await Future<void>.delayed(duration);
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  Future<Map<String, dynamic>> _postJson(
    String uri,
    Map<String, dynamic> payload,
    int expectedStatus,
    String operation,
    {
    Duration timeout = const Duration(seconds: 60),
    int maxAttempts = 1,
    Duration retryDelay = const Duration(seconds: 2),
  }
  ) async {
    print('🚀 [API] Trimit $operation la: $uri');

    Exception? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse(uri)).timeout(timeout);
        request.headers.contentType = ContentType.json;
        request.write(convert.jsonEncode(payload));

        final response = await request.close().timeout(timeout);
        final body = await response.transform(convert.utf8.decoder).join();

        print('📥 [API] Răspuns server ($operation): ${response.statusCode}');

        if (response.statusCode == expectedStatus) {
          return convert.jsonDecode(body) as Map<String, dynamic>;
        }

        final statusError = Exception(
          'Status incorect: ${response.statusCode}. Body: $body',
        );
        final canRetry =
            attempt < maxAttempts && _isRetryableStatus(response.statusCode);
        if (!canRetry) {
          throw statusError;
        }

        print('⚠️ [API] Retry $attempt/$maxAttempts pentru $operation');
        await _delay(retryDelay);
      } on SocketException catch (e) {
        lastError = Exception('Eroare conexiune: $e');
        final canRetry = attempt < maxAttempts;
        if (!canRetry) {
          break;
        }
        print('⚠️ [API] Retry $attempt/$maxAttempts pentru $operation');
        await _delay(retryDelay);
      } on TimeoutException catch (e) {
        lastError = Exception('Timeout la $operation: $e');
        final canRetry = attempt < maxAttempts;
        if (!canRetry) {
          break;
        }
        print('⚠️ [API] Retry $attempt/$maxAttempts pentru $operation');
        await _delay(retryDelay);
      } catch (e) {
        print('❌ [API] Eroare la $operation: $e');
        throw Exception('Eroare conexiune: $e');
      } finally {
        client.close();
      }
    }

    print('❌ [API] Eroare la $operation: $lastError');
    throw lastError ?? Exception('Eroare conexiune necunoscută');
  }

  Future<Map<String, dynamic>> _getJson(
    String uri,
    int expectedStatus,
    String operation,
    {Duration timeout = const Duration(seconds: 60)}
  ) async {
    print('🚀 [API] Trimit $operation la: $uri');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(uri)).timeout(timeout);
      request.headers.contentType = ContentType.json;

      final response = await request.close().timeout(timeout);
      final body = await response.transform(convert.utf8.decoder).join();

      print('📥 [API] Răspuns server ($operation): ${response.statusCode}');

      if (response.statusCode != expectedStatus) {
        throw Exception('Status incorect: ${response.statusCode}. Body: $body');
      }

      return convert.jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      print('❌ [API] Eroare la $operation: $e');
      throw Exception('Eroare conexiune: $e');
    } finally {
      client.close();
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
      timeout: const Duration(seconds: 180),
      maxAttempts: 2,
      retryDelay: const Duration(seconds: 2),
    );
    return response['output'] as String;
  }

  // Obține profil utilizator
  Future<Map<String, dynamic>> getProfile(int profileId) async {
    return _getJson(
      '$baseUrl/profiles/$profileId',
      200,
      'get profile',
    );
  }

  Future<Map<String, dynamic>> updateEmergencyContact({
    required int profileId,
    required String name,
    required String phone,
  }) async {
    return _postJson(
      '$baseUrl/profiles/$profileId/emergency-contact',
      {
        'name': name,
        'phone': phone,
      },
      200,
      'update emergency contact',
    );
  }

  Future<Map<String, dynamic>> triggerSos({
    required int profileId,
    int? heartRate,
    String? locationLabel,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    final payload = {
      'profileId': profileId,
      if (heartRate != null) 'heartRate': heartRate,
      if (locationLabel != null && locationLabel.isNotEmpty) 'locationLabel': locationLabel,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final candidateUrls = <String>[
      '$baseUrl/sos',
      '$baseUrl/checkins/sos',
      '$baseUrl/check-ins/sos',
    ];

    Exception? last404Error;
    for (final url in candidateUrls) {
      try {
        return _postJson(
          url,
          payload,
          201,
          'trigger sos',
        );
      } catch (e) {
        final message = e.toString();
        if (message.contains('Status incorect: 404') || message.contains('Cannot POST')) {
          last404Error = e is Exception ? e : Exception(message);
          continue;
        }
        rethrow;
      }
    }

    throw last404Error ?? Exception('No SOS endpoint responded with 201');
  }
}