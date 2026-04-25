import 'package:flutter/material.dart';
import 'constants.dart';
import 'services/api_client.dart';

class ChatAiScreen extends StatefulWidget {
  final int profileId;

  const ChatAiScreen({super.key, required this.profileId});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add({"text": "Hello! I'm your safety assistant. How are you feeling right now?", "isAi": true});
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiClient().getProfile(widget.profileId);
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

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty || _isLoading) return;

    final userMessage = _controller.text;
    _controller.clear();

    setState(() {
      _messages.add({"text": userMessage, "isAi": false});
      _isLoading = true;
    });

    try {
      final aiResponse = await ApiClient().chatWithAi(
        message: userMessage,
        userName: _profileData?['display_name'] ?? '',
        userConditions: _formatList(_profileData?['disorders'] ?? []),
        heartRate: '72',
        calmingMethods: _formatList(_profileData?['calming_strategies'] ?? []),
        hobbies: _formatList(_profileData?['hobbies'] ?? []),
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
      appBar: AppBar(
        title: Text("AI Assistant", style: TextStyle(color: AppColors.midnightText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.midnightText),
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
          if (_isLoading)
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

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading,
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