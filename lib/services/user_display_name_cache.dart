import 'package:cloud_firestore/cloud_firestore.dart';

/// Caches userId -> displayName lookups for efficient review display.
class UserDisplayNameCache {
  static final UserDisplayNameCache _instance = UserDisplayNameCache._internal();
  factory UserDisplayNameCache() => _instance;
  UserDisplayNameCache._internal();

  final Map<String, String> _cache = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns displayName for userId, fetching from Firestore if not cached.
  Future<String> getDisplayName(String userId) async {
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final name = (doc.data()?['displayName'] as String?) ?? 'Anonymous';
      _cache[userId] = name;
      return name;
    } catch (_) {
      return 'Anonymous';
    }
  }

  /// Optionally preload a set of userIds (for batch review lists)
  Future<void> preloadUserIds(Iterable<String> userIds) async {
    final missing = userIds.where((id) => !_cache.containsKey(id)).toSet();
    if (missing.isEmpty) return;
    final futures = missing.map((id) async {
      try {
        final doc = await _firestore.collection('users').doc(id).get();
        final name = (doc.data()?['displayName'] as String?) ?? 'Anonymous';
        _cache[id] = name;
      } catch (_) {
        _cache[id] = 'Anonymous';
      }
    });
    await Future.wait(futures);
  }

  void clear() => _cache.clear();
}