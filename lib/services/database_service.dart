import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/study_place.dart';
import '../models/review.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DatabaseService {
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
          LatLng(
            data['latitude'] as double,
            data['longitude'] as double,
          ),
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
    required String userName,
    required String placeId,
    required String placeName,
    required int rating,
    required String outlets,
    required String reviewText,
  }) async {
    try {
      final review = {
        'userId': userId,
        'userName': userName,
        'placeId': placeId,
        'placeName': placeName,
        'rating': rating,
        'outlets': outlets,
        'reviewText': reviewText,
        'createdAt': FieldValue.serverTimestamp(),
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromFirestore(doc.data(), doc.id);
      }).toList();
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
  }) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'outlets': outlets,
        'reviewText': reviewText,
      });
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
      };

      await _firestore.collection('checkins').add(data);
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

  // Get average rating for a place from user reviews
  Future<double?> getPlaceAverageRating(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('placeId', isEqualTo: placeId)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final ratings = snapshot.docs.map((doc) => doc.data()['rating'] as int).toList();
      final sum = ratings.fold<int>(0, (prev, rating) => prev + rating);
      return sum / ratings.length;
    } catch (e) {
      return null;
    }
  }


}
