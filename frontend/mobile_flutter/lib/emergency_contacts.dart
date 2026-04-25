import 'package:flutter/material.dart';
import 'constants.dart';

class ContactManagerScreen extends StatelessWidget {
  const ContactManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMist,
      appBar: AppBar(
        title: Text("Emergency Contacts", style: TextStyle(color: AppColors.midnightText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.midnightText),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 80, color: AppColors.deepSerenity),
            SizedBox(height: 20),
            Text("No emergency contacts yet", style: TextStyle(color: AppColors.midnightText, fontSize: 18)),
            SizedBox(height: 10),
            Text("Add contacts to notify in case of emergency", style: TextStyle(color: AppColors.midnightText.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}