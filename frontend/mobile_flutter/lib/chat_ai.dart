import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'services/api_client.dart';
import 'services/voice_service.dart';
import 'services/location_service.dart';
import 'widgets/voice_mic_button.dart';

class ChatAiScreen extends StatefulWidget {
  final int profileId;

  const ChatAiScreen({super.key, required this.profileId});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  final VoiceService _voiceService = VoiceService();
  final LocationService _locationService = LocationService();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;
  String _lastNearbySafePlaces = '';
  String _lastRequestedPlaceType = 'park';
  VoiceInteractionState _voiceState = VoiceInteractionState.idle;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _addWelcomeMessage();
    _voiceService.initialize();
    _voiceService.state.addListener(_handleVoiceStateChanged);
  }

  @override
  void dispose() {
    _voiceService.state.removeListener(_handleVoiceStateChanged);
    _voiceService.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleVoiceStateChanged() {
    if (!mounted) return;
    setState(() {
      _voiceState = _voiceService.state.value;
    });
  }

  void _addWelcomeMessage() {
    _messages.add({
      "text": "Hello! I'm your safety assistant. How are you feeling right now?",
      "isAi": true
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _apiClient.getProfile(widget.profileId);
      if (mounted) {
        setState(() {
          _profileData = profile;
        });
      }
    } catch (e) {
      print('Failed to load profile: $e');
    }
  }

  String _formatList(List<dynamic> list) {
    if (list.isEmpty) return "None specified";
    return list.map((e) => e.toString()).join(", ");
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  bool _isLocationFollowUpIntent(String message) {
    final lower = message.toLowerCase();
    const followUpPatterns = [
      'take me',
      'go there',
      'directions',
      'where is it',
      'i want to go',
      'closest',
      'nearest',
      'there',
    ];
    return followUpPatterns.any(lower.contains);
  }

  Future<String> _resolveNearbySafePlace(String userMessage) async {
    final detectedPlaceType = _locationService.detectPlaceType(userMessage);
    final followUpIntent = _isLocationFollowUpIntent(userMessage);

    String? targetType = detectedPlaceType;
    if (targetType != null) {
      _lastRequestedPlaceType = targetType;
    } else if (followUpIntent) {
      targetType = _lastRequestedPlaceType;
    }

    if (targetType == null) {
      return _lastNearbySafePlaces;
    }

    final place = await _locationService.getClosestPlace(targetType);
    if (place == null) {
      final searchLink = await _locationService.findNearbyPlace(targetType) ??
          _locationService.generateGoogleMapsSearchLinkWithoutLocation(
            placeType: targetType,
          );
      _lastNearbySafePlaces =
          'Nearby ${targetType[0].toUpperCase()}${targetType.substring(1)}|Near your location|nearby|$searchLink';
      return _lastNearbySafePlaces;
    }

    final position = await _locationService.getCurrentLocation();
    final directionsUrl = _locationService.generateGoogleMapsDirectionsLink(
      destLatitude: place.latitude,
      destLongitude: place.longitude,
      originLatitude: position?.latitude,
      originLongitude: position?.longitude,
    );
    final distance = _locationService.formatDistance(place.distance);
    _lastNearbySafePlaces = '${place.name}|${place.address}|$distance|$directionsUrl';
    return _lastNearbySafePlaces;
  }

  Future<String> _fetchAiResponse(String userMessage) async {
    final nearbySafePlaces = await _resolveNearbySafePlace(userMessage);
    
    final history = <Map<String, String>>[];
    for (final msg in _messages) {
      if (msg["isAi"] == true) {
        history.add({"role": "assistant", "content": msg["text"]});
      } else {
        history.add({"role": "user", "content": msg["text"]});
      }
    }

    return _apiClient.chatWithAi(
      message: userMessage,
      userName: _profileData?['display_name'] ?? '',
      userConditions: _formatList(_profileData?['disorders'] ?? []),
      heartRate: '72',
      calmingMethods: _formatList(_profileData?['calming_strategies'] ?? []),
      hobbies: _formatList(_profileData?['hobbies'] ?? []),
      nearbySafePlaces: nearbySafePlaces,
      conversationHistory: history,
    );
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;
    if (_voiceState == VoiceInteractionState.listening ||
        _voiceState == VoiceInteractionState.processing) {
      _showMessage('Finish voice flow first, then send a text message.');
      return;
    }

    final userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.add({"text": userMessage, "isAi": false});
      _isLoading = true;
    });

    try {
      final aiResponse = await _fetchAiResponse(userMessage);

      if (mounted) {
        setState(() {
          _messages.add({"text": aiResponse, "isAi": true});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "text": "I'm here with you. Can you tell me what's happening?",
            "isAi": true
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVoiceMicPressed() async {
    await _voiceService.handleMicTap(
      fetchAiResponse: _fetchAiResponse,
      onUserTranscript: (transcript) {
        if (!mounted) return;
        setState(() {
          _messages.add({"text": transcript, "isAi": false});
        });
      },
      onAiResponse: (aiResponse) {
        if (!mounted) return;
        setState(() {
          _messages.add({"text": aiResponse, "isAi": true});
        });
      },
      onError: (errorMessage) {
        if (!mounted) return;
        _showMessage(errorMessage);

        // Ensure the user still sees an assistant reply in the thread
        // when the voice->AI pipeline fails.
        setState(() {
          _messages.add({
            "text": "I'm here with you. I couldn't reach the AI just now. Please try again.",
            "isAi": true,
          });
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
      appBar: AppBar(
        title: Text("AI Assistant", style: TextStyle(color: AppColors.midnightText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.midnightText),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.midnightText),
            onPressed: () {
              setState(() {
                _messages.clear();
                _lastNearbySafePlaces = '';
                _lastRequestedPlaceType = 'park';
                _addWelcomeMessage();
              });
            },
            tooltip: "Clear conversation",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg["text"], msg["isAi"]);
              },
            ),
          ),
          if (_isLoading || _voiceState == VoiceInteractionState.processing)
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepSerenity),
                  ),
                  SizedBox(width: 10),
                  Text("Thinking...", style: TextStyle(color: AppColors.midnightText)),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isAi) {
    final urlPattern = RegExp(r'https?://[^\s]+');
    final matches = urlPattern.allMatches(text);
    
    if (matches.isEmpty || !isAi) {
      return Align(
        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isAi ? AppColors.surfaceBlue : AppColors.deepSerenity,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: isAi ? Radius.zero : Radius.circular(20),
              bottomRight: isAi ? Radius.circular(20) : Radius.zero,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(color: isAi ? AppColors.midnightText : Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0)!,
        style: TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isAi ? AppColors.surfaceBlue : AppColors.deepSerenity,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isAi ? Radius.zero : Radius.circular(20),
            bottomRight: isAi ? Radius.circular(20) : Radius.zero,
          ),
        ),
        child: GestureDetector(
          onTap: () async {
            final url = urlPattern.firstMatch(text)?.group(0);
            if (url != null) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: isAi ? AppColors.midnightText : Colors.white,
                fontSize: 16,
              ),
              children: spans,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading && _voiceState != VoiceInteractionState.listening,
              decoration: InputDecoration(
                hintText: "Type how you feel...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.bgMist,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 10),
          VoiceMicButton(
            state: _voiceState,
            onPressed: _handleVoiceMicPressed,
          ),
          SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppColors.midnightText,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}