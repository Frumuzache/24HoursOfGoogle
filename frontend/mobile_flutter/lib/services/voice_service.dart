import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum VoiceInteractionState {
  idle,
  listening,
  processing,
  speaking,
}

class VoiceService {
  VoiceService({
    SpeechToText? speechToText,
    FlutterTts? flutterTts,
  })  : _speechToText = speechToText ?? SpeechToText(),
        _flutterTts = flutterTts ?? FlutterTts();

  final SpeechToText _speechToText;
  final FlutterTts _flutterTts;

  final ValueNotifier<VoiceInteractionState> state =
      ValueNotifier(VoiceInteractionState.idle);

  bool _isInitialized = false;
  bool _isStoppingListening = false;
  String _latestTranscript = '';
  String _lastNonEmptyTranscript = '';
  bool _hasProcessedCurrentSession = false;

  Future<String> Function(String textInput)? _fetchAiResponse;
  void Function(String transcript)? _onUserTranscript;
  void Function(String aiResponse)? _onAiResponse;
  void Function(String errorMessage)? _onError;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setLanguage('en-US');

    _flutterTts.setStartHandler(() {
      state.value = VoiceInteractionState.speaking;
    });

    _flutterTts.setCompletionHandler(() {
      if (state.value == VoiceInteractionState.speaking) {
        state.value = VoiceInteractionState.idle;
      }
    });

    _flutterTts.setCancelHandler(() {
      if (state.value == VoiceInteractionState.speaking) {
        state.value = VoiceInteractionState.idle;
      }
    });

    _flutterTts.setErrorHandler((_) {
      state.value = VoiceInteractionState.idle;
      _emitError('Could not play voice response. Please try again.');
    });

    _isInitialized = true;
  }

  Future<void> handleMicTap({
    required Future<String> Function(String textInput) fetchAiResponse,
    required void Function(String transcript) onUserTranscript,
    required void Function(String aiResponse) onAiResponse,
    required void Function(String errorMessage) onError,
  }) async {
    _fetchAiResponse = fetchAiResponse;
    _onUserTranscript = onUserTranscript;
    _onAiResponse = onAiResponse;
    _onError = onError;

    await initialize();

    if (state.value == VoiceInteractionState.speaking) {
      await stopSpeaking();
      return;
    }

    if (state.value == VoiceInteractionState.listening) {
      await stopListeningAndProcess();
      return;
    }

    if (state.value == VoiceInteractionState.processing) {
      _emitError('Processing your previous voice message. Please wait.');
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    final hasMicPermission = await _ensureMicrophonePermission();
    if (!hasMicPermission) {
      state.value = VoiceInteractionState.idle;
      return;
    }

    final available = await _speechToText.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
      debugLogging: false,
    );

    if (!available) {
      _emitError('Speech recognition is unavailable on this device.');
      state.value = VoiceInteractionState.idle;
      return;
    }

    _latestTranscript = '';
    _lastNonEmptyTranscript = '';
    _hasProcessedCurrentSession = false;
    state.value = VoiceInteractionState.listening;

    await _speechToText.listen(
      onResult: _handleSpeechResult,
      listenFor: const Duration(minutes: 3),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    _latestTranscript = transcript;

    if (transcript.isNotEmpty) {
      _lastNonEmptyTranscript = transcript;
    }

    if (result.finalResult &&
        state.value == VoiceInteractionState.listening &&
        !_hasProcessedCurrentSession) {
      _processFinalTranscript();
    }
  }

  void _handleSpeechStatus(String status) {
    if (status == 'notListening' &&
        state.value == VoiceInteractionState.listening &&
        !_isStoppingListening) {
      _processFinalTranscript(waitForLateResult: true);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (state.value == VoiceInteractionState.listening) {
      state.value = VoiceInteractionState.idle;
      _emitError('Could not capture voice input. Please try again.');
    }
  }

  Future<void> stopListeningAndProcess() async {
    if (_speechToText.isListening) {
      _isStoppingListening = true;
      await _speechToText.stop();
      _isStoppingListening = false;
    }

    await _processFinalTranscript(waitForLateResult: true);
  }

  Future<void> _processFinalTranscript({bool waitForLateResult = false}) async {
    if (_hasProcessedCurrentSession) {
      return;
    }

    _hasProcessedCurrentSession = true;

    if (waitForLateResult && _latestTranscript.trim().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final transcript = (_latestTranscript.trim().isNotEmpty
            ? _latestTranscript
            : _lastNonEmptyTranscript)
        .trim();

    if (transcript.isEmpty) {
      state.value = VoiceInteractionState.idle;
      _emitError('I could not hear anything clearly. Please try again.');
      return;
    }

    _onUserTranscript?.call(transcript);

    final fetchAiResponse = _fetchAiResponse;
    if (fetchAiResponse == null) {
      state.value = VoiceInteractionState.idle;
      return;
    }

    state.value = VoiceInteractionState.processing;

    try {
      final aiResponse = await fetchAiResponse(transcript);
      final cleanedResponse = aiResponse.trim();

      if (cleanedResponse.isEmpty) {
        state.value = VoiceInteractionState.idle;
        _emitError('AI returned an empty response. Please try again.');
        return;
      }

      _onAiResponse?.call(cleanedResponse);
      await _speak(cleanedResponse);
    } catch (e) {
      state.value = VoiceInteractionState.idle;
      _emitError('AI request failed: $e');
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    final result = await _flutterTts.speak(text);

    if (result != 1) {
      state.value = VoiceInteractionState.idle;
      _emitError('Failed to start voice playback.');
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    state.value = VoiceInteractionState.idle;
  }

  Future<bool> _ensureMicrophonePermission() async {
    final currentStatus = await Permission.microphone.status;
    if (currentStatus.isGranted) {
      return true;
    }

    final requestedStatus = await Permission.microphone.request();
    if (requestedStatus.isGranted) {
      return true;
    }

    if (requestedStatus.isPermanentlyDenied) {
      _emitError(
        'Microphone permission is permanently denied. Enable it in Settings to use voice input.',
      );
      return false;
    }

    _emitError('Microphone permission is required to use voice input.');
    return false;
  }

  void _emitError(String message) {
    _onError?.call(message);
  }

  Future<void> dispose() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    await _flutterTts.stop();
    state.dispose();
    _isInitialized = false;
  }
}
