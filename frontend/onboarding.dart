import 'package:flutter/material.dart';
import './constants.dart';
import 'dashboard.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text("Create your", style: TextStyle(color: AppColors.midnightText, fontSize: 18)),
              Text("Safety Profile", style: TextStyle(color: AppColors.midnightText, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("This helps the AI know how to support you during a panic attack.", 
                style: TextStyle(color: AppColors.midnightText.withOpacity(0.7), fontSize: 16)),
              const SizedBox(height: 40),

              _buildInputCard("Health Condition", "e.g. Anxiety, PTSD", Icons.psychology),
              const SizedBox(height: 20),
              _buildInputCard("What calms you?", "e.g. Lofi music, deep breaths", Icons.self_improvement),
              const SizedBox(height: 20),
              _buildInputCard("Medications", "e.g. Sertraline - 8:00 AM", Icons.medication),
              
              const SizedBox(height: 50),
              
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightText,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Finish Setup", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(String title, String hint, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBlue, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.deepSerenity),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: AppColors.midnightText, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.midnightText.withOpacity(0.3)),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}