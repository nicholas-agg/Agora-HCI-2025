import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy', style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy & Security', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            Text('Agora is committed to protecting your privacy. We only collect data necessary to provide and improve our services. Your data is never shared with third parties without your consent.', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text('For more information, contact us at nikgrava-agora@yahoo.gr.', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
