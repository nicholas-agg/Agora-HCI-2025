import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1D1B20),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Help & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('This is a demo help and support page. For any issues or questions, please contact us at demo@agora.com.', style: TextStyle(fontSize: 16)),
            SizedBox(height: 24),
            Text('We are here to help you with any problems you encounter while using the demo app.', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
