import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks user preferences and interactions for personalized recommendations
class PreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Track when a user views a place
  Future<void> trackPlaceView({
    required String userId,
    required String placeId,
    required String placeName,
    required String placeType,
  }) async {
    try {
      final prefs = _firestore.collection('users').doc(userId).collection('preferences');
      
      // Update view count
      await prefs.doc('viewedPlaces').set({
        placeId: {
          'name': placeName,
          'type': placeType,
          'viewCount': FieldValue.increment(1),
          'lastViewed': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // Update type preferences
      await prefs.doc('placeTypes').set({
        placeType: {
          'viewCount': FieldValue.increment(1),
          'lastViewed': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      // Silent fail for analytics
      print('Failed to track place view: $e');
    }
  }

  /// Track user's attribute preferences based on reviews they submit
  Future<void> trackReviewPreferences({
    required String userId,
    int? wifiQuality,
    int? outletAvailability,
    int? comfortLevel,
    int? aestheticRating,
    double? noiseLevel,
  }) async {
    try {
      final prefs = _firestore.collection('users').doc(userId).collection('preferences');
      final data = <String, dynamic>{};

      if (wifiQuality != null && wifiQuality > 0) {
        data['preferredWifiQuality'] = wifiQuality;
      }
      if (outletAvailability != null && outletAvailability > 0) {
        data['preferredOutletAvailability'] = outletAvailability;
      }
      if (comfortLevel != null && comfortLevel > 0) {
        data['preferredComfort'] = comfortLevel;
      }
      if (aestheticRating != null && aestheticRating > 0) {
        data['preferredAesthetic'] = aestheticRating;
      }
      if (noiseLevel != null) {
        data['preferredNoiseLevel'] = noiseLevel;
      }

      if (data.isNotEmpty) {
        await prefs.doc('attributes').set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('Failed to track review preferences: $e');
    }
  }

  /// Track when user favorites a place
  Future<void> trackFavorite({
    required String userId,
    required String placeId,
    required String placeName,
    required String placeType,
    required bool isFavorited,
  }) async {
    try {
      final prefs = _firestore.collection('users').doc(userId).collection('preferences');
      
      if (isFavorited) {
        await prefs.doc('favorites').set({
          placeId: {
            'name': placeName,
            'type': placeType,
            'favoritedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));

        // Track favorite type
        await prefs.doc('favoritePlaceTypes').set({
          placeType: FieldValue.increment(1),
        }, SetOptions(merge: true));
      } else {
        // Remove from favorites
        await prefs.doc('favorites').update({
          placeId: FieldValue.delete(),
        });

        await prefs.doc('favoritePlaceTypes').update({
          placeType: FieldValue.increment(-1),
        });
      }
    } catch (e) {
      print('Failed to track favorite: $e');
    }
  }

  /// Get user preferences for recommendations
  Future<Map<String, dynamic>> getUserPreferences(String userId) async {
    try {
      final prefs = _firestore.collection('users').doc(userId).collection('preferences');
      
      final attributes = await prefs.doc('attributes').get();
      final placeTypes = await prefs.doc('placeTypes').get();
      final favoritePlaceTypes = await prefs.doc('favoritePlaceTypes').get();
      
      return {
        'attributes': attributes.data() ?? {},
        'viewedTypes': placeTypes.data() ?? {},
        'favoriteTypes': favoritePlaceTypes.data() ?? {},
      };
    } catch (e) {
      print('Failed to get user preferences: $e');
      return {};
    }
  }

  /// Get most viewed places for a user
  Future<List<Map<String, dynamic>>> getMostViewedPlaces(String userId, {int limit = 10}) async {
    try {
      final prefs = _firestore.collection('users').doc(userId).collection('preferences');
      final viewedPlaces = await prefs.doc('viewedPlaces').get();
      
      if (!viewedPlaces.exists) return [];
      
      final data = viewedPlaces.data() as Map<String, dynamic>;
      final places = <Map<String, dynamic>>[];
      
      data.forEach((placeId, placeData) {
        places.add({
          'placeId': placeId,
          ...placeData as Map<String, dynamic>,
        });
      });
      
      // Sort by view count
      places.sort((a, b) => (b['viewCount'] as int).compareTo(a['viewCount'] as int));
      
      return places.take(limit).toList();
    } catch (e) {
      print('Failed to get most viewed places: $e');
      return [];
    }
  }

  /// Get user's preferred place types based on views and favorites
  Future<List<String>> getPreferredPlaceTypes(String userId) async {
    try {
      final prefs = await getUserPreferences(userId);
      final viewedTypes = prefs['viewedTypes'] as Map<String, dynamic>;
      final favoriteTypes = prefs['favoriteTypes'] as Map<String, dynamic>;
      
      // Combine and weight the types
      final typeScores = <String, double>{};
      
      viewedTypes.forEach((type, data) {
        final viewCount = (data as Map<String, dynamic>)['viewCount'] as int;
        typeScores[type] = (typeScores[type] ?? 0) + viewCount.toDouble();
      });
      
      favoriteTypes.forEach((type, count) {
        // Weight favorites 3x more than views
        typeScores[type] = (typeScores[type] ?? 0) + (count as int).toDouble() * 3;
      });
      
      // Sort by score
      final sortedTypes = typeScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedTypes.map((e) => e.key).toList();
    } catch (e) {
      print('Failed to get preferred place types: $e');
      return [];
    }
  }
}
