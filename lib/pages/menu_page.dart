import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/theme_manager.dart';
import '../services/auth_service.dart';

class MenuPage extends StatefulWidget {
  final VoidCallback? onSignOut;
  const MenuPage({super.key, this.onSignOut});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          // Theme Toggle
          Consumer<ThemeManager>(
            builder: (context, themeManager, _) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SwitchListTile(
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  subtitle: const Text('Toggle between light and dark theme'),
                  value: themeManager.themeMode == ThemeMode.dark,
                  onChanged: (val) {
                    // Immediate haptic feedback for instant user response
                    HapticFeedback.lightImpact();
                    // Theme change happens asynchronously
                    Future.microtask(() {
                      themeManager.setTheme(val ? ThemeMode.dark : ThemeMode.light);
                    });
                  },
                  secondary: Icon(
                    themeManager.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    color: const Color(0xFF6750A4),
                  ),
                ),
              );
            },
          ),

          // General Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              'General',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // App Info
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6750A4).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF6750A4)),
              ),
              title: const Text(
                'App Info',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Version, updates & support'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('App Info'),
                    content: const Text('Agora v1.0.0\n\nA study space finder app.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Language
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6750A4).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.language, color: Color(0xFF6750A4)),
              ),
              title: const Text(
                'Language',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('English (US)'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Language'),
                    content: const Text('Language selection is not available in demo.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Accessibility
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6750A4).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.accessibility, color: Color(0xFF6750A4)),
              ),
              title: const Text(
                'Accessibility',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Display & interaction settings'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Accessibility'),
                    content: const Text('Accessibility settings are not available in demo.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Account Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            margin: const EdgeInsets.only(top: 16),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Logout
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF49454F).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Color(0xFF49454F)),
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Sign out of your account'),
              onTap: () {
                if (widget.onSignOut != null) {
                  // Pop back to main navigation first, then logout
                  Navigator.of(context).pop();
                  widget.onSignOut!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ),

          // Delete Account
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFFDC2626),
                ),
              ),
              subtitle: const Text(
                'Permanently remove your account',
                style: TextStyle(color: Color(0xFFF87171)),
              ),
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final authService = AuthService();
    _emailController.clear();
    final rootContext = context;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To permanently delete your account, please enter your email address below.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final currentUser = authService.currentUser;
              final enteredEmail = _emailController.text.trim();
              
              if (enteredEmail.isEmpty) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }
              
              if (currentUser?.email?.toLowerCase() != enteredEmail.toLowerCase()) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('Email does not match')),
                );
                return;
              }
              
              // Check if demo user
              if (enteredEmail.toLowerCase() == 'demo@agora.com') {
                Navigator.pop(dialogContext);
                
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion is not available for the demo user.'),
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }
              
              try {
                Navigator.pop(dialogContext);
                
                // Show loading dialog
                showDialog(
                  context: rootContext,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                // Delete account
                await authService.deleteAccount();
                
                // Guard context usage across async gap with BuildContext
                if (!rootContext.mounted) return;

                // Close loading dialog
                Navigator.pop(rootContext);
                
                // Sign out callback
                if (widget.onSignOut != null) {
                  Navigator.of(rootContext).pop();
                  widget.onSignOut!();
                }
              } catch (e) {
                // Guard context usage across async gap with BuildContext
                if (!rootContext.mounted) return;

                // Close loading dialog if still showing
                if (Navigator.canPop(rootContext)) {
                  Navigator.pop(rootContext);
                }
                
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
