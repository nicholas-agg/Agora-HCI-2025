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
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text('Privacy & Security', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 12),
          Text('Agora uses Firebase, Google Maps, and local storage to help you discover study places. We collect only what is needed to run the app and keep your account safe.', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _InfoSection(
            title: 'What we collect',
            color: colorScheme,
            children: const [
              'Account details: email, display name, profile photo (if provided) to let you sign in and personalize your profile.',
              'Places activity: favorites, reviews, and ratings you choose to submit so you can revisit and share feedback.',
              'Location (approximate/precise, depending on your permission): to show nearby study places and map directions.',
              'Device and app diagnostics: basic event logs and performance data to keep the app reliable.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'How we use it',
            color: colorScheme,
            children: const [
              'Provide core features like sign-in, map search, favorites sync, and review posting.',
              'Secure your account and prevent abuse (for example, limiting spam reviews).',
              'Improve reliability through crash and performance signals.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Sharing and storage',
            color: colorScheme,
            children: const [
              'We do not sell your data. Access is limited to services needed to run the app (Firebase, Google Maps).',
              'Favorites and reviews you create are stored in Firestore and linked to your user ID.',
              'Some preferences (like theme and offline favorites) are stored locally on your device.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Your controls',
            color: colorScheme,
            children: const [
              'Location: you can turn location access on or off in your device settings at any time.',
              'Data you post: edit or delete your reviews and favorites from within the app.',
              'Account: delete your account by emailing support; your user data and associated content will be removed.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Data security',
            color: colorScheme,
            children: const [
              'All traffic uses HTTPS. Firebase enforces authenticated access rules for user-specific data.',
              'We apply least-privilege access to storage and review permissions regularly.',
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Contact',
            color: colorScheme,
            children: const [
              'Email: support@agora.app',
              'Include the email used to sign in so we can locate your account for data requests.',
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.color, required this.children});

  final String title;
  final ColorScheme color;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color.onSurface)),
        const SizedBox(height: 10),
        ...children.map(
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
