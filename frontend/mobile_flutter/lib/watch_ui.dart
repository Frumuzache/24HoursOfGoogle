import 'package:flutter/material.dart';
import 'vitals_service.dart';

class WatchScreen extends StatelessWidget {
  final int profileId;
  const WatchScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A1A1A),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 40),
              const Text("78", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
              const Text("BPM", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await VitalsService().sendVitals(profileId, 155);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Critical Alert sent from Watch!")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                child: const Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}