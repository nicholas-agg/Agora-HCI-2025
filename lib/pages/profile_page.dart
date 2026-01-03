import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/favorites_manager.dart';
import 'privacy_page.dart';
import 'help_support_page.dart';
import 'favorites_page.dart';
import 'my_reviews_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onSignOut;
  const ProfilePage({super.key, this.onSignOut});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final FavoritesManager _favoritesManager = FavoritesManager();
  int _favoriteCount = 0;
  int _reviewCount = 0;
  bool _loading = true;
  VoidCallback _favoritesListener = () {};

  @override
  void initState() {
    super.initState();
    _favoritesListener = () {
      if (mounted) {
        setState(() {
          _favoriteCount = _favoritesManager.favorites.length;
        });
      }
    };
    _favoritesManager.addListener(_favoritesListener);
    // Do not call _syncAndLoadUserStats here; will be called in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This is called every time the widget becomes visible in the navigation stack
    _syncAndLoadUserStats();
  }

  @override
  void dispose() {
    // Do not use context for ancestor lookups here!
    _favoritesManager.removeListener(_favoritesListener);
    super.dispose();
  }

  Future<void> _syncAndLoadUserStats() async {
    // Force sync favorites from Firebase first
    await _favoritesManager.forceSync();
    _favoriteCount = _favoritesManager.favorites.length;
    await _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final favoriteCount = await _databaseService.getFavoriteCount(user.uid);
      final reviewCount = await _databaseService.getUserReviewCount(user.uid);
      
      if (mounted) {
        setState(() {
          _favoriteCount = favoriteCount;
          _reviewCount = reviewCount;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = _authService.currentUser;
    
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text('No user logged in'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: (() {
          // Hide back button if in MainNavigation (bottom nav), show otherwise
          final mainNavState = context.findAncestorStateOfType<State<StatefulWidget>>();
          if (mainNavState != null && mainNavState.widget.runtimeType.toString() == 'MainNavigation') {
            return null;
          }
          return IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          );
        })(),
        title: Text('Profile', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.person, size: 40, color: colorScheme.primary),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'User',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(),
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
                    subtitle: Text('${user.displayName ?? "User"}\n${user.email ?? ""}'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Account Info'),
                          content: Text('Name: ${user.displayName ?? "User"}\nEmail: ${user.email ?? ""}'),
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
                    subtitle: _loading
                        ? const Text('Loading...')
                        : Text('$_favoriteCount favourite${_favoriteCount == 1 ? '' : 's'}'),
                    trailing: !_loading && _favoriteCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_favoriteCount',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FavoritesPage(),
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
                    subtitle: _loading
                        ? const Text('Loading...')
                        : Text('$_reviewCount review${_reviewCount == 1 ? '' : 's'}'),
                    trailing: !_loading && _reviewCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_reviewCount',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MyReviewsPage(),
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
                    leading: const Icon(Icons.help_outline, color: Color(0xFF6750A4)),
                    title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Get help and contact us'),
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
                    onTap: () async {
                      if (widget.onSignOut != null) {
                        await _authService.signOut();
                        widget.onSignOut!();
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
