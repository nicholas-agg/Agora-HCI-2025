import 'package:flutter/material.dart';
import 'privacy_page.dart';
import 'help_support_page.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback? onSignOut;
  const ProfilePage({super.key, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF49454F)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Profile', style: TextStyle(color: Color(0xFF1D1B20), fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFEADDFF),
                  child: const Icon(Icons.person, size: 40, color: Color(0xFF4F378A)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Demo User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF1D1B20))),
                      SizedBox(height: 4),
                      Text('demo@agora.com', style: TextStyle(fontSize: 15, color: Color(0xFF49454F))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF6750A4)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Edit Profile'),
                        content: const Text('Profile editing is not available in demo.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.person_outline, color: Color(0xFF6750A4)),
                    title: const Text('Account Info', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Demo User\ndemo@agora.com'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Account Info'),
                          content: const Text('Name: Demo User\nEmail: demo@agora.com'),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                        ),
                      );
                    },
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark, color: Color(0xFF6750A4)),
                    title: const Text('Favourites', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('No favourites in demo'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Favourites'),
                          content: const Text('No favourites for demo user.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                        ),
                      );
                    },
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Color(0xFF6750A4)),
                    title: const Text('Recently Visited', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('No history in demo'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Recently Visited'),
                          content: const Text('No history for demo user.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                        ),
                      );
                    },
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: Color(0xFF6750A4)),
                    title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Notifications are off in demo'),
                    onTap: () {},
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF6750A4)),
                    title: const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Security and privacy settings'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const PrivacyPage()),
                      );
                    },
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.reviews_outlined, color: Color(0xFF6750A4)),
                    title: const Text('Reviews', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('No reviews in demo'),
                    onTap: () {},
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.help_outline, color: Color(0xFF6750A4)),
                    title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Get help and contact us'),
                    trailing: const Icon(Icons.more_vert, color: Color(0xFF49454F)),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HelpSupportPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                    title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                    onTap: () {
                      if (onSignOut != null) {
                        // Pop all routes and call onSignOut to trigger login page
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        onSignOut!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF3F4F6),
        child: Icon(icon, color: iconColor ?? const Color(0xFF49454F)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? const Color(0xFF111827),
          fontSize: 18,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15))
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
    );
  }
}
