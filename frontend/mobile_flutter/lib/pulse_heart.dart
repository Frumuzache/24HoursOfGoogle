import 'package:flutter/material.dart';
import 'constants.dart';

class PulseHeart extends StatefulWidget {
  final int bpm;
  const PulseHeart({super.key, required this.bpm});

  @override
  State<PulseHeart> createState() => _PulseHeartState();
}

class _PulseHeartState extends State<PulseHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // The duration determines the pulse speed
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logic: Change color if BPM is over 100
    Color heartColor = widget.bpm > 100 
        ? AppColors.softAwareness 
        : AppColors.sageGrounding;

    return ScaleTransition(
      scale: _animation,
      child: Icon(
        Icons.favorite,
        color: heartColor,
        size: 100,
      ),
    );
  }
}