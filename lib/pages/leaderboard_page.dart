import 'package:flutter/material.dart';
import '../services/points_service.dart';
import '../services/auth_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final PointsService _pointsService = PointsService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _topUsers = [];
  int? _currentUserRank;
  int? _currentUserPoints;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _authService.currentUser;
      
      // Get top users
      final topUsers = await _pointsService.getTopUsers(limit: 50);
      
      int? rank;
      int? points;
      
      if (user != null) {
        // Get current user's rank and points
        rank = await _pointsService.getUserRank(user.uid);
        points = await _pointsService.getUserPoints(user.uid);
      }
      
      if (!mounted) return;
      
      setState(() {
        _topUsers = topUsers;
        _currentUserRank = rank;
        _currentUserPoints = points;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load leaderboard: $e')),
      );
    }
  }

  String _getAchievementBadge(int points) {
    return _pointsService.getAchievementLevel(points);
  }

  IconData _getBadgeIcon(String achievement) {
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

  Color _getBadgeColor(String achievement) {
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
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Current user stats card
                  if (currentUserId != null && _currentUserPoints != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getBadgeIcon(_getAchievementBadge(_currentUserPoints!)),
                            size: 48,
                            color: _getBadgeColor(_getAchievementBadge(_currentUserPoints!)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Rank: ${_currentUserRank ?? 'Unranked'}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_currentUserPoints points • ${_getAchievementBadge(_currentUserPoints!)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onPrimaryContainer.withAlpha(200),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Leaderboard header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Top Contributors',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('How Points Work'),
                                content: const SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Earn points by contributing:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      Text('• Submit a review: +10 points'),
                                      Text('• Add photos: +5 points'),
                                      Text('• Measure noise level: +15 points'),
                                      Text('• Fill all details: +20 points'),
                                      SizedBox(height: 16),
                                      Text('Achievement Levels:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      Text('• Novice: 0-99 points'),
                                      Text('• Bronze: 100-499 points'),
                                      Text('• Silver: 500-999 points'),
                                      Text('• Gold: 1000-4999 points'),
                                      Text('• Legend: 5000+ points'),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Got it!'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Leaderboard list
                  Expanded(
                    child: _topUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emoji_events, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No contributors yet',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Be the first to earn points!',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _topUsers.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final user = _topUsers[index];
                              final rank = index + 1;
                              final points = user['points'] as int;
                              final userName = (user['displayName'] as String?) ?? 'Anonymous';
                              final achievement = _getAchievementBadge(points);
                              final isCurrentUser = user['userId'] == currentUserId;

                              return Card(
                                elevation: isCurrentUser ? 4 : 1,
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isCurrentUser 
                                    ? colorScheme.primaryContainer.withAlpha(100)
                                    : colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isCurrentUser
                                      ? BorderSide(color: colorScheme.primary, width: 2)
                                      : BorderSide.none,
                                ),
                                child: ListTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Rank with special styling for top 3
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: rank <= 3
                                              ? (rank == 1
                                                  ? Colors.amber
                                                  : rank == 2
                                                      ? Colors.grey[400]
                                                      : Colors.brown)
                                              : colorScheme.surfaceContainerHighest,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$rank',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: rank <= 3 ? Colors.white : colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Achievement badge
                                      Icon(
                                        _getBadgeIcon(achievement),
                                        color: _getBadgeColor(achievement),
                                        size: 32,
                                      ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userName,
                                          style: TextStyle(
                                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: const Text('You', style: TextStyle(fontSize: 12)),
                                          backgroundColor: colorScheme.primary,
                                          labelStyle: TextStyle(color: colorScheme.onPrimary),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(achievement),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$points pts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
