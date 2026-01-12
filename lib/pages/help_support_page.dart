import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support', style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text('Help & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 12),
          Text('Find quick answers, troubleshoot common issues, and reach us when you need more help.', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _InfoSection(
            title: 'Common questions',
            color: colorScheme,
            items: const [
              'Cannot sign in: confirm your email/password or try a password reset from the sign-in screen.',
              'Map or places not loading: check your internet connection and allow location access for nearby results.',
              'Favorites missing after reinstall: sign in with the same account to sync favorites from the cloud.',
              'Reviews not posting: ensure you are online and signed in; we block duplicates and obvious spam.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Troubleshooting steps',
            color: colorScheme,
            items: const [
              'Restart the app after granting permissions (Location/Storage) so changes take effect.',
              'Update Agora to the latest version for map keys and bug fixes.',
              'Toggle Airplane mode off and verify Wi-Fi or cellular data is active.',
              'If maps stay blank, ensure Google Play Services (Android) or Location Services (iOS) are enabled.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'How to',
            color: colorScheme,
            items: const [
              'Add a favorite: open a place and tap the heart. Favorites sync to your account and cache for offline viewing.',
              'Report an issue with a place: open the place, choose "Report" (if available), or email us with the place name.',
              'Change theme: go to Profile > Theme to switch light/dark; preference is saved on device.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Contact us',
            color: colorScheme,
            items: const [
              'Email: support@agora.app',
              'Include screenshots and the email you use to sign in so we can help faster.',
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.color, required this.items});

  final String title;
  final ColorScheme color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color.onSurface)),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- ', style: TextStyle(fontSize: 16, color: color.primary)),
                Expanded(child: Text(item, style: TextStyle(fontSize: 16, color: color.onSurfaceVariant))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
