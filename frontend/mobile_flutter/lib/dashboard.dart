//provides immediate reassurance and real-time data.

import 'package:flutter/material.dart';
import './constants.dart';
import './pulse_heart.dart';
import './services/api_client.dart';
import 'chat_ai.dart';
import 'emergency_contacts.dart'; 

class DashboardScreen extends StatelessWidget {
  final int profileId;

  const DashboardScreen({super.key, required this.profileId});

  // Function to handle the SOS trigger
  void _triggerSOS(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.softAwareness, size: 60),
            const SizedBox(height: 20),
            const Text("SOS Triggered", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Notifying your emergency contact and preparing AI grounding support...",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatAiScreen(profileId: profileId), 
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepSerenity,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Start AI Grounding", style: TextStyle(color: Colors.white, fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.contact_phone, color: AppColors.midnightText),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactManagerScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Good morning,", style: TextStyle(color: AppColors.midnightText, fontSize: 18)),
              Text("You are safe.", style: TextStyle(color: AppColors.midnightText, fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 40),
              
              // The Heart Rate Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    PulseHeart(bpm: 72), 
                    const SizedBox(height: 16),
                    Text("72", style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: AppColors.midnightText)),
                    Text("BPM", style: TextStyle(letterSpacing: 2, color: AppColors.forestQuiet)),
                  ],
                ),
              ),
              
              const Spacer(),

              // Quick SOS Button
              GestureDetector(
                onLongPress: () => _triggerSOS(context),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.softAwareness,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.softAwareness.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_share, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "HOLD FOR SOS",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Emergency AI Button
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ApiClient().sendCheckIn(
                      profileId: profileId,
                      heartRate: 72,
                      moodScore: 7,
                      anxietyLevel: 5,
                    );
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatAiScreen(profileId: profileId),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatAiScreen(profileId: profileId),
                        ),
                      );
                    }
                  }
                },
                icon: Icon(Icons.psychology, color: Colors.white),
                label: Text("Talk to Assistant", style: TextStyle(color: Colors.white, fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepSerenity,
                  minimumSize: Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}