import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1D1B20),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Privacy & Security', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('This is a demo privacy page. Your data is not stored or shared. All features are for demonstration purposes only.', style: TextStyle(fontSize: 16)),
            SizedBox(height: 24),
            Text('For more information, contact us at demo@agora.com.', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
