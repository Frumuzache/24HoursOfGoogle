import 'package:flutter/material.dart';
import 'constants.dart';
import 'dashboard.dart';
import 'services/api_client.dart';
import 'services/auth_session.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _displayNameController = TextEditingController();
  final _disordersController = TextEditingController();
  final _calmingStrategiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _favoriteFoodsController = TextEditingController();
  final _hobbiesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _disordersController.dispose();
    _calmingStrategiesController.dispose();
    _medicationsController.dispose();
    _favoriteFoodsController.dispose();
    _hobbiesController.dispose();
    super.dispose();
  }

  void _submitProfile() async {
    if (_displayNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient().createProfile(
        displayName: _displayNameController.text,
        disorders: _disordersController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        calmingStrategies: _calmingStrategiesController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        medications: _medicationsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        favoriteFoods: _favoriteFoodsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        hobbies: _hobbiesController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

      final profileId = response['id'];
      if (profileId is! num) {
        throw Exception('Invalid profile id returned by backend');
      }

      final userId = await AuthSession.getUserId();
      if (userId != null) {
        await AuthSession.saveSession(
          userId: userId,
          email: '',
          displayName: _displayNameController.text,
          profileId: profileId.toInt(),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(profileId: profileId.toInt()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
                style: TextStyle(color: AppColors.midnightText.withValues(alpha: 0.7), fontSize: 16)),
              const SizedBox(height: 40),

              _buildInputCard("Your Name *", "e.g. Sarah", Icons.person, _displayNameController),
              const SizedBox(height: 20),
              _buildInputCard("Health Conditions", "e.g. Anxiety, PTSD (comma-separated)", Icons.psychology, _disordersController),
              const SizedBox(height: 20),
              _buildInputCard("What calms you?", "e.g. Lofi music, deep breaths (comma-separated)", Icons.self_improvement, _calmingStrategiesController),
              const SizedBox(height: 20),
              _buildInputCard("Medications", "e.g. Sertraline - 8:00 AM (comma-separated)", Icons.medication, _medicationsController),
              const SizedBox(height: 20),
              _buildInputCard("Favorite Foods", "e.g. Pizza, Sushi (comma-separated)", Icons.food_bank, _favoriteFoodsController),
              const SizedBox(height: 20),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightText,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text("Finish Setup", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(String title, String hint, IconData icon, TextEditingController controller) {
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
            controller: controller,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.midnightText.withValues(alpha: 0.3)),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}