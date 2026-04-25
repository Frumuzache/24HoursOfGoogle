import 'package:flutter/material.dart';

import '../services/voice_service.dart';

class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final VoiceInteractionState state;
  final VoidCallback onPressed;

  Color _backgroundColor(BuildContext context) {
    switch (state) {
      case VoiceInteractionState.idle:
        return const Color(0xFF3268FA);
      case VoiceInteractionState.listening:
        return Colors.redAccent;
      case VoiceInteractionState.processing:
        return Colors.orange;
      case VoiceInteractionState.speaking:
        return Colors.green;
    }
  }

  Widget _icon() {
    switch (state) {
      case VoiceInteractionState.idle:
        return const Icon(Icons.mic, color: Colors.white);
      case VoiceInteractionState.listening:
        return const Icon(Icons.hearing, color: Colors.white);
      case VoiceInteractionState.processing:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case VoiceInteractionState.speaking:
        return const Icon(Icons.volume_up, color: Colors.white);
    }
  }

  String _tooltip() {
    switch (state) {
      case VoiceInteractionState.idle:
        return 'Start voice input';
      case VoiceInteractionState.listening:
        return 'Tap to stop listening';
      case VoiceInteractionState.processing:
        return 'Processing with AI';
      case VoiceInteractionState.speaking:
        return 'Tap to interrupt voice playback';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip(),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _backgroundColor(context),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(child: _icon()),
        ),
      ),
    );
  }
}
