//provides immediate reassurance and real-time data.

import 'package:flutter/material.dart';
import './constants.dart';
import './pulse_heart.dart';
import './services/api_client.dart';

class DashboardScreen extends StatelessWidget {
  final int profileId;

  const DashboardScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
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
                child: // Inside the Heart Rate Card in dashboard.dart
                  Column(
                    children: [
                      // Pulse animation replaced the static icon
                      PulseHeart(bpm: 72), 
                      const SizedBox(height: 16),
                      Text("72", style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: AppColors.midnightText)),
                      Text("BPM", style: TextStyle(letterSpacing: 2, color: AppColors.forestQuiet)),
                    ],
                  ),
              ),
              
              Spacer(),
              
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Check-in saved')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
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