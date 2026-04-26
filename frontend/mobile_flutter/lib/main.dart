import 'package:flutter/material.dart';
import 'login.dart';
import 'onboarding.dart';
import 'dashboard.dart';
import 'services/auth_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final isLoggedIn = await AuthSession.isLoggedIn();
  final profileId = await AuthSession.getProfileId();
  final hasProfile = profileId != null && profileId > 0;
  
  runApp(MyApp(startScreen: isLoggedIn 
    ? (hasProfile ? DashboardScreen(profileId: profileId) : const OnboardingScreen()) 
    : const LoginScreen()));
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safety Net',
      home: startScreen,
    );
  }
}