import 'package:cloud_firestore/cloud_firestore.dart';

class PointsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Point values for different actions
  static const int POINTS_SUBMIT_REVIEW = 10;
  static const int POINTS_UPLOAD_PHOTO = 5;
  static const int POINTS_NOISE_MEASUREMENT = 15;
  static const int POINTS_DETAILED_REVIEW = 20; // All attributes filled

  // Award points to a user
  Future<void> awardPoints(String userId, int points, String reason) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        
        if (!snapshot.exists) {
          // Initialize user if doesn't exist
          transaction.set(userDoc, {
            'points': points,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final currentPoints = snapshot.data()?['points'] as int? ?? 0;
          transaction.update(userDoc, {
            'points': currentPoints + points,
          });
        }
      });

      // Log the point transaction
      await _firestore.collection('users').doc(userId).collection('pointsHistory').add({
        'points': points,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail - points are not critical
      print('Error awarding points: $e');
    }
  }

  // Get user's current points
  Future<int> getUserPoints(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return 0;
      return doc.data()?['points'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Get top users by points (for leaderboard)
  Future<List<Map<String, dynamic>>> getTopUsers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('points', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'displayName': data['displayName'] as String? ?? 'Anonymous',
          'points': data['points'] as int? ?? 0,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get user's rank
  Future<int> getUserRank(String userId) async {
    try {
      final userPoints = await getUserPoints(userId);
      final snapshot = await _firestore
          .collection('users')
          .where('points', isGreaterThan: userPoints)
          .get();
      
      return snapshot.docs.length + 1; // Rank is 1-based
    } catch (e) {
      return 0;
    }
  }

  // Calculate weighted rating based on user points
  double calculateWeightedRating(int rating, int userPoints) {
    // Users with more points have slightly more weight
    // Formula: rating * (1 + min(userPoints/1000, 0.5))
    // Max 50% boost for very active users
    final boost = (userPoints / 1000).clamp(0.0, 0.5);
    return rating * (1 + boost);
  }

  // Get achievement level based on points
  String getAchievementLevel(int points) {
    if (points >= 5000) return 'Legend';
    if (points >= 1000) return 'Gold';
    if (points >= 500) return 'Silver';
    if (points >= 100) return 'Bronze';
    return 'Novice';
  }

  // Award points for review submission
  Future<void> awardPointsForReview({
    required String userId,
    required bool hasPhotos,
    required bool hasNoiseMeasurement,
    required bool hasAllAttributes,
  }) async {
    int totalPoints = POINTS_SUBMIT_REVIEW;
    String reason = 'Submitted review';

    if (hasPhotos) {
      totalPoints += POINTS_UPLOAD_PHOTO;
      reason += ' with photos';
    }

    if (hasNoiseMeasurement) {
      totalPoints += POINTS_NOISE_MEASUREMENT;
      reason += ' and noise measurement';
    }

    if (hasAllAttributes) {
      totalPoints += POINTS_DETAILED_REVIEW;
      reason += ' (detailed)';
    }

    await awardPoints(userId, totalPoints, reason);
  }
}
