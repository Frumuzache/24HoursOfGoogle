import 'package:flutter/material.dart';
import 'onboarding.dart'; // Fișierul tău original
import 'login.dart'; // Noul import

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
      // Schimbăm doar aici ca să pornească direct cu Login-ul
      home: const LoginScreen(), 
    );
  }
}