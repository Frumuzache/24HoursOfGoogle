import 'package:flutter/material.dart';
import '../constants.dart';

class ChatAiScreen extends StatefulWidget {
  const ChatAiScreen({super.key});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final TextEditingController _controller = TextEditingController();
  
  // Mock list of messages to show how it looks
  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hello! I noticed your heart rate was a bit high. How are you feeling?",
      "isAi": true
    },
  ];

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    setState(() {
      // 1. Add User Message
      _messages.add({"text": _controller.text, "isAi": false});
      
      // 2. Mock AI Response (Your "Prompt" logic)
      String userText = _controller.text.toLowerCase();
      String aiResponse = "I'm listening. Tell me more about that.";

      if (userText.contains("anxious") || userText.contains("panic")) {
        aiResponse = "I'm here with you. Let's try to name 3 things you can see right now to ground yourself.";
      } else if (userText.contains("medication") || userText.contains("pills")) {
        aiResponse = "Checking your profile... Remember, your doctor suggested taking your meds with water. Have you done that today?";
      }

      _messages.add({"text": aiResponse, "isAi": true});
      _controller.clear();
    });
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
              decoration: InputDecoration(
                hintText: "Type how you feel...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.bgMist,
              ),
            ),
          ),
          SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppColors.midnightText,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}