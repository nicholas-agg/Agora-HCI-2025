import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/study_place.dart';
import '../models/review.dart';
import '../models/check_in.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DatabaseService {
  // (No longer needed) Update all reviews for a user with a new userName
  // Future<void> updateUserNameInReviews(String userId, String newUserName) async {}
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to handle Firestore errors
  String _handleFirestoreError(dynamic e) {
    if (e.toString().contains('permission-denied')) {
      return 'Access denied. Please sign in again.';
    } else if (e.toString().contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (e.toString().contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  // ==================== FAVORITES ====================

  // Add a place to user's favorites
  Future<void> addFavorite(String userId, StudyPlace place) async {
    try {
      final favoriteData = {
        'placeId': place.placeId,
        'placeName': place.name,
        'placeType': place.type,
        'photoReference': place.photoReference,
        'rating': place.rating,
        'userRatingsTotal': place.userRatingsTotal,
        'latitude': place.location.latitude,
        'longitude': place.location.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(place.placeId)
          .set(favoriteData);
    } catch (e) {
      throw Exception(_handleFirestoreError(e));
    }
  }

  // Remove a place from user's favorites
  Future<void> removeFavorite(String userId, String placeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(placeId)
          .delete();
    } catch (e) {
      throw Exception(_handleFirestoreError(e));
    }
  }

  // Get all favorites for a user
  Stream<List<StudyPlace>> getUserFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return StudyPlace(
              data['placeName'] as String,
              LatLng(data['latitude'] as double, data['longitude'] as double),
              data['placeType'] as String,
              photoReference: data['photoReference'] as String?,
              placeId: data['placeId'] as String?,
              rating: data['rating'] as double?,
              userRatingsTotal: data['userRatingsTotal'] as int?,
            );
          }).toList();
        });
  }

  // Check if a place is in user's favorites
  Future<bool> isFavorite(String userId, String placeId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(placeId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get favorite count for a user
  Future<int> getFavoriteCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== REVIEWS ====================

  // Create a new review
  Future<void> createReview({
    required String userId,
    required String placeId,
    required String placeName,
    required int rating,
    required String outlets,
    required String reviewText,
    int? wifiQuality,
    int? outletAvailability,
    String? averagePrice,
    double? noiseLevel,
    int? comfortLevel,
    int? aestheticRating,
    List<String>? userPhotos,
  }) async {
    try {
      final review = {
        'userId': userId,
        'placeId': placeId,
        'placeName': placeName,
        'rating': rating,
        'outlets': outlets,
        'reviewText': reviewText,
        'createdAt': FieldValue.serverTimestamp(),
        if (wifiQuality != null) 'wifiQuality': wifiQuality,
        if (outletAvailability != null)
          'outletAvailability': outletAvailability,
        if (averagePrice != null) 'averagePrice': averagePrice,
        if (noiseLevel != null) 'noiseLevel': noiseLevel,
        if (comfortLevel != null) 'comfortLevel': comfortLevel,
        if (aestheticRating != null) 'aestheticRating': aestheticRating,
        if (userPhotos != null && userPhotos.isNotEmpty)
          'userPhotos': userPhotos,
      };

      await _firestore.collection('reviews').add(review);
    } catch (e) {
      throw Exception(_handleFirestoreError(e));
    }
  }

  // Get all reviews for a specific place
  Stream<List<Review>> getPlaceReviews(String placeId) {
    return _firestore
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Review.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  // Get all reviews by a specific user
  Stream<List<Review>> getUserReviews(String userId) {
    return _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs.map((doc) {
            return Review.fromFirestore(doc.data(), doc.id);
          }).toList();

          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  // Get review count for a user
  Future<int> getUserReviewCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Update a review
  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String outlets,
    required String reviewText,
    int? wifiQuality,
    int? outletAvailability,
    String? averagePrice,
    double? noiseLevel,
    int? comfortLevel,
    int? aestheticRating,
    List<String>? userPhotos,
  }) async {
    try {
      final updateData = {
        'rating': rating,
        'outlets': outlets,
        'reviewText': reviewText,
      };

      // Add optional fields only if provided
      if (wifiQuality != null) updateData['wifiQuality'] = wifiQuality;
      if (outletAvailability != null) {
        updateData['outletAvailability'] = outletAvailability;
      }
      if (averagePrice != null) updateData['averagePrice'] = averagePrice;
      if (noiseLevel != null) updateData['noiseLevel'] = noiseLevel;
      if (comfortLevel != null) updateData['comfortLevel'] = comfortLevel;
      if (aestheticRating != null) {
        updateData['aestheticRating'] = aestheticRating;
      }
      if (userPhotos != null) updateData['userPhotos'] = userPhotos;

      await _firestore.collection('reviews').doc(reviewId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update review: $e');
    }
  }

  // Delete a review
  Future<void> deleteReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  // ==================== CHECK-INS ====================

  Future<void> createCheckIn({
    required String userId,
    required String userName,
    required String placeId,
    required String placeName,
    required LatLng placeLocation,
    double? userLatitude,
    double? userLongitude,
    double? distanceMeters,
    double? noiseDb,
    String? photoUrl,
  }) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));
      final data = {
        'userId': userId,
        'userName': userName,
        'placeId': placeId,
        'placeName': placeName,
        'placeLatitude': placeLocation.latitude,
        'placeLongitude': placeLocation.longitude,
        'userLatitude': userLatitude,
        'userLongitude': userLongitude,
        'distanceMeters': distanceMeters,
        'noiseDb': noiseDb,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      };

      await _firestore.collection('checkins').add(data);
    } catch (e) {
      throw Exception(_handleFirestoreError(e));
    }
  }

  /// Returns the number of active (not expired) check-ins for a place
  Stream<int> getActiveCheckInCount(String placeId) {
    final now = Timestamp.fromDate(DateTime.now());
    return _firestore
        .collection('checkins')
        .where('placeId', isEqualTo: placeId)
        .where('expiresAt', isGreaterThan: now)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Returns the user's active check-in for a place, or null if none
  Future<CheckIn?> getUserActiveCheckIn({
    required String userId,
    required String placeId,
  }) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final query = await _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .where('placeId', isEqualTo: placeId)
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt', descending: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return CheckIn.fromDoc(query.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Returns the user's active check-in at ANY place, or null if none
  Future<CheckIn?> getUserActiveCheckInAnyPlace({
    required String userId,
  }) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final query = await _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt', descending: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return CheckIn.fromDoc(query.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream the user's active check-in (any place). Emits null if none.
  Stream<CheckIn?> userActiveCheckInStream({required String userId}) {
    final now = Timestamp.fromDate(DateTime.now());
    return _firestore
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return CheckIn.fromDoc(snapshot.docs.first);
          }
          return null;
        });
  }

  /// Cancel (delete) the user's active check-in. If placeId is provided, only cancel at that place.
  Future<void> cancelActiveCheckIn({
    required String userId,
    String? placeId,
  }) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      Query<Map<String, dynamic>> q = _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: now);
      if (placeId != null) {
        q = q.where('placeId', isEqualTo: placeId);
      }
      final res = await q.limit(1).get();
      if (res.docs.isNotEmpty) {
        await _firestore.collection('checkins').doc(res.docs.first.id).delete();
      }
    } catch (e) {
      throw Exception(_handleFirestoreError(e));
    }
  }

  /// Cancel an active check-in by its document ID
  Future<void> cancelCheckInById(String checkInId) async {
    try {
      await _firestore.collection('checkins').doc(checkInId).delete();
    } catch (e) {
      throw Exception(_handleFirestoreError(e));
    }
  }

  Future<bool> isCheckedIn({
    required String userId,
    required String placeId,
  }) async {
    try {
      final query = await _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .where('placeId', isEqualTo: placeId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Stream<List<CheckIn>> getRecentCheckIns({
    required String userId,
    int limit = 20,
  }) {
    return _firestore
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final checkIns = snapshot.docs
              .map((doc) => CheckIn.fromDoc(doc))
              .toList();
          checkIns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return checkIns;
        });
  }

  Future<int> getUserCheckInCount(String userId) async {
    try {
      final query = await _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .get();
      return query.size;
    } catch (_) {
      return 0;
    }
  }

  // Get average rating for a place from user reviews
  Future<double?> getPlaceAverageRating(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('placeId', isEqualTo: placeId)
          .get();

      if (snapshot.docs.isEmpty) return null;

      double totalWeightedRating = 0;
      double totalWeight = 0;

      for (var doc in snapshot.docs) {
        final rating = doc.data()['rating'] as int;
        final userId = doc.data()['userId'] as String;

        // Get user points for weighting
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userPoints = userDoc.data()?['points'] as int? ?? 0;

        // Calculate weight: 1.0 + (points/1000), capped at 1.5x
        final weight = (1.0 + (userPoints / 1000)).clamp(1.0, 1.5);

        totalWeightedRating += rating * weight;
        totalWeight += weight;
      }

      return totalWeight > 0 ? totalWeightedRating / totalWeight : null;
    } catch (e) {
      return null;
    }
  }

  // Get place attribute averages
  Future<Map<String, double?>> getPlaceAttributeAverages(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('placeId', isEqualTo: placeId)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'wifiQuality': null,
          'outletAvailability': null,
          'noiseLevel': null,
          'comfortLevel': null,
          'aestheticRating': null,
        };
      }

      double wifiSum = 0,
          outletSum = 0,
          noiseSum = 0,
          comfortSum = 0,
          aestheticSum = 0;
      int wifiCount = 0,
          outletCount = 0,
          noiseCount = 0,
          comfortCount = 0,
          aestheticCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data['wifiQuality'] != null) {
          wifiSum += (data['wifiQuality'] as int).toDouble();
          wifiCount++;
        }
        if (data['outletAvailability'] != null) {
          outletSum += (data['outletAvailability'] as int).toDouble();
          outletCount++;
        }
        if (data['noiseLevel'] != null) {
          noiseSum += data['noiseLevel'] as double;
          noiseCount++;
        }
        if (data['comfortLevel'] != null) {
          comfortSum += (data['comfortLevel'] as int).toDouble();
          comfortCount++;
        }
        if (data['aestheticRating'] != null) {
          aestheticSum += (data['aestheticRating'] as int).toDouble();
          aestheticCount++;
        }
      }

      return {
        'wifiQuality': wifiCount > 0 ? wifiSum / wifiCount : null,
        'outletAvailability': outletCount > 0 ? outletSum / outletCount : null,
        'noiseLevel': noiseCount > 0 ? noiseSum / noiseCount : null,
        'comfortLevel': comfortCount > 0 ? comfortSum / comfortCount : null,
        'aestheticRating': aestheticCount > 0
            ? aestheticSum / aestheticCount
            : null,
      };
    } catch (e) {
      return {
        'wifiQuality': null,
        'outletAvailability': null,
        'noiseLevel': null,
        'comfortLevel': null,
        'aestheticRating': null,
      };
    }
  }

  // Get all user photos for a place
  Future<List<String>> getPlacePhotos(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('placeId', isEqualTo: placeId)
          .get();

      List<String> allPhotos = [];
      for (var doc in snapshot.docs) {
        final photos = doc.data()['userPhotos'] as List?;
        if (photos != null) {
          allPhotos.addAll(photos.cast<String>());
        }
      }

      return allPhotos;
    } catch (e) {
      return [];
    }
  }
}
