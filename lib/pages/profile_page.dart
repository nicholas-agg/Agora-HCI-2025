import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/points_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/favorites_manager.dart';
import 'privacy_page.dart';
import 'help_support_page.dart';
import 'favorites_page.dart';
import 'my_reviews_page.dart';
import 'edit_profile_page.dart';
import 'leaderboard_page.dart';
import 'recently_visited_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onBackToHome;
  const ProfilePage({super.key, this.onSignOut, this.onBackToHome});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final PointsService _pointsService = PointsService();
  final FavoritesManager _favoritesManager = FavoritesManager();
  int _favoriteCount = 0;
  int _reviewCount = 0;
  int _userPoints = 0;
  int? _userRank;
  int _recentCount = 0;
  String? _profilePicturePath;
  bool _loading = true;
  late VoidCallback _favoritesListener;

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
    _loadProfilePictureLocal();
    // Do not call _syncAndLoadUserStats here; will be called in didChangeDependencies
  }

  Future<void> _loadProfilePictureLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('profile_picture_path');
      if (path != null && await File(path).exists()) {
        if (mounted) {
          setState(() {
            _profilePicturePath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile picture path: $e');
    }
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
      final userPoints = await _pointsService.getUserPoints(user.uid);
      final userRank = await _pointsService.getUserRank(user.uid);
      
      final recentCount = await _databaseService.getUserCheckInCount(user.uid);
      if (mounted) {
        setState(() {
          _favoriteCount = favoriteCount;
          _reviewCount = reviewCount;
          _userPoints = userPoints;
          _userRank = userRank;
          _recentCount = recentCount;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
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
                  backgroundImage: _profilePicturePath != null
                    ? FileImage(File(_profilePicturePath!))
                    : null,
                  child: _profilePicturePath == null
                    ? Icon(Icons.person, size: 40, color: colorScheme.primary)
                    : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName ?? 'User',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _getAchievementIcon(),
                            size: 20,
                            color: _getAchievementColor(),
                          ),
                        ],
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
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(),
                      ),
                    );
                    // Reload profile data when returning from edit page
                    _syncAndLoadUserStats();
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
                // Points and Achievement Card
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Agora Points',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: _userPoints),
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.easeOutExpo,
                                  builder: (context, value, child) {
                                    return Text(
                                      '$value',
                                      style: TextStyle(
                                        fontSize: 48,
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -1,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  Icon(
                                    _getAchievementIcon(),
                                    size: 64,
                                    color: _getAchievementColor(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pointsService.getAchievementLevel(_userPoints),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress to next level
                        (() {
                          final points = _userPoints;
                          String nextLevel = '';
                          double progress = 0.0;
                          int pointsNeeded = 0;

                          if (points < 100) {
                            nextLevel = 'Bronze';
                            progress = points / 100;
                            pointsNeeded = 100 - points;
                          } else if (points < 500) {
                            nextLevel = 'Silver';
                            progress = (points - 100) / 400;
                            pointsNeeded = 500 - points;
                          } else if (points < 1000) {
                            nextLevel = 'Gold';
                            progress = (points - 500) / 500;
                            pointsNeeded = 1000 - points;
                          } else if (points < 5000) {
                            nextLevel = 'Legend';
                            progress = (points - 1000) / 4000;
                            pointsNeeded = 5000 - points;
                          } else {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progress to $nextLevel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onPrimaryContainer.withAlpha(200),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$pointsNeeded more pts',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onPrimaryContainer.withAlpha(200),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 12,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: colorScheme.onPrimaryContainer.withAlpha(40),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: progress),
                                    duration: const Duration(seconds: 1),
                                    curve: Curves.easeInOutCubic,
                                    builder: (context, value, child) {
                                      return FractionallySizedBox(
                                        widthFactor: value.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                colorScheme.onPrimaryContainer.withAlpha(150),
                                                colorScheme.onPrimaryContainer,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.onPrimaryContainer.withAlpha(100),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        })(),
                        const SizedBox(height: 12),
                        Divider(color: colorScheme.onPrimaryContainer.withAlpha(80)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Global Rank: ${_userRank ?? 'Unranked'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const LeaderboardPage(),
                                  ),
                                );
                              },
                              child: const Text('View Leaderboard →'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
                    subtitle: _loading
                        ? const Text('Loading...')
                        : Text('$_recentCount visit${_recentCount == 1 ? '' : 's'}'),
                    trailing: !_loading && _recentCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_recentCount',
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
                          builder: (context) => const RecentlyVisitedPage(),
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
  IconData _getAchievementIcon() {
    final achievement = _pointsService.getAchievementLevel(_userPoints);
    switch (achievement) {
      case 'Legend':
        return Icons.emoji_events;
      case 'Gold':
        return Icons.workspace_premium;
      case 'Silver':
        return Icons.military_tech;
      case 'Bronze':
        return Icons.stars;
      default:
        return Icons.person;
    }
  }

  Color _getAchievementColor() {
    final achievement = _pointsService.getAchievementLevel(_userPoints);
    switch (achievement) {
      case 'Legend':
        return Colors.purple;
      case 'Gold':
        return Colors.amber;
      case 'Silver':
        return Colors.grey[400]!;
      case 'Bronze':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }}
