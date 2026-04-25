import 'package:flutter/material.dart';
import 'onboarding.dart'; // Importă fișierul tău

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safety Net',
      // Aici îi spui cu ce ecran să înceapă:
      home: const OnboardingScreen(), 
    );
  }
}