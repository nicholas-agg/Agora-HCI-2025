import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/study_place.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

final logger = Logger();

/// Generates personalized place recommendations based on user preferences
class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get recommendations: for each place the user has favorited or reviewed, find 10 nearby places (same category) via Google Maps API.
  Future<List<StudyPlace>> getRecommendations(String userId, {int limit = 10}) async {
    try {
      // 1. Get user's favorited places
      final favSnapshot = await _firestore.collection('users').doc(userId).collection('favorites').get();
      final favorites = favSnapshot.docs.map((doc) {
        final data = doc.data();
        return StudyPlace(
          data['placeName'] ?? '',
          LatLng((data['latitude'] as num?)?.toDouble() ?? 0.0, (data['longitude'] as num?)?.toDouble() ?? 0.0),
          data['placeType'] ?? 'unknown',
          photoReference: data['photoReference'] as String?,
          placeId: data['placeId'] as String?,
          rating: (data['rating'] as num?)?.toDouble(),
          userRatingsTotal: data['userRatingsTotal'] as int?,
        );
      }).toList();

      // 2. Get user's reviewed places
      final reviewSnapshot = await _firestore.collection('reviews').where('userId', isEqualTo: userId).get();
      final reviewed = reviewSnapshot.docs.map((doc) {
        final data = doc.data();
        return StudyPlace(
          data['placeName'] ?? '',
          LatLng((data['latitude'] as num?)?.toDouble() ?? 0.0, (data['longitude'] as num?)?.toDouble() ?? 0.0),
          data['type'] ?? 'unknown',
          photoReference: data['photoReference'] as String?,
          placeId: data['placeId'] as String?,
          rating: (data['rating'] as num?)?.toDouble(),
          userRatingsTotal: data['userRatingsTotal'] as int?,
        );
      }).toList();

      // Combine and deduplicate by placeId
      final Map<String, StudyPlace> userPlaces = {};
      for (final p in [...favorites, ...reviewed]) {
        if (p.placeId != null && p.placeId!.isNotEmpty) {
          userPlaces[p.placeId!] = p;
        }
      }
      if (userPlaces.isEmpty) return [];

      // 3. For each user place, find 10 nearby places in the same category via Google Maps API
      final Set<String> seenPlaceIds = {...userPlaces.keys};
      final List<StudyPlace> recommendations = [];
      for (final place in userPlaces.values) {
        final results = await _searchNearbyPlacesGoogle(
          place.location,
          place.type,
          excludePlaceIds: seenPlaceIds,
          maxResults: 10,
        );
        for (final rec in results) {
          if (seenPlaceIds.length >= limit) break;
          if (rec.placeId != null && !seenPlaceIds.contains(rec.placeId!)) {
            recommendations.add(rec);
            seenPlaceIds.add(rec.placeId!);
          }
        }
        if (recommendations.length >= limit) break;
      }
      return recommendations.take(limit).toList();
    } catch (e) {
      logger.e('Error getting recommendations: $e');
      return [];
    }
  }

  /// Search Google Maps API for places near a location, filtered by type/category
  Future<List<StudyPlace>> _searchNearbyPlacesGoogle(LatLng location, String type, {Set<String>? excludePlaceIds, int maxResults = 10}) async {
    try {
      // Map type to Google Places API type/keyword
      String apiType = 'cafe';
      String keyword = '';
      final t = type.toLowerCase();
      if (t.contains('coworking')) {
        apiType = '';
        keyword = 'coworking';
      } else if (t.contains('library')) {
        apiType = 'library';
      } else if (t.contains('cafe')) {
        apiType = 'cafe';
      }
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        logger.e('Google Maps API key not found in .env');
        return [];
      }
      final lat = location.latitude;
      final lng = location.longitude;
      final radius = 1500;
      String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radius';
      if (apiType.isNotEmpty) url += '&type=$apiType';
      if (keyword.isNotEmpty) url += '&keyword=$keyword';
      url += '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      if (data['status'] != 'OK') return [];
      final exclude = excludePlaceIds ?? {};
      final List<StudyPlace> found = [];
      for (final result in data['results']) {
        final placeId = result['place_id'] as String?;
        if (placeId == null || exclude.contains(placeId)) continue;
        final name = result['name'] as String? ?? '';
        final lat = (result['geometry']['location']['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (result['geometry']['location']['lng'] as num?)?.toDouble() ?? 0.0;
        String recType = type;
        if (result['types'] != null && result['types'] is List) {
          final types = (result['types'] as List).cast<String>();
          if (types.contains('library')) {
            recType = 'Library';
            } else if (types.any((t) => t.contains('coworking'))) {
            recType = 'Coworking';
            } else if (types.contains('cafe')) {
            recType = 'Cafe';
            }
        }
        String? photoRef;
        if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
          photoRef = result['photos'][0]['photo_reference'] as String?;
        }
        final rating = (result['rating'] as num?)?.toDouble();
        final userRatingsTotal = result['user_ratings_total'] as int?;
        found.add(StudyPlace(
          name,
          LatLng(lat, lng),
          recType,
          photoReference: photoRef,
          placeId: placeId,
          rating: rating,
          userRatingsTotal: userRatingsTotal,
        ));
        if (found.length >= maxResults) break;
      }
      return found;
    } catch (e) {
      logger.e('Error searching Google Places: $e');
      return [];
    }
  }

  // Removed unused _calculatePlaceScore

  /// Get all study places from the database
  /// Note: In a real app, you'd want to implement pagination or caching
  Future<List<StudyPlace>> _getAllPlaces() async {
    try {
      // This assumes you store places in Firestore
      // If you only use Google Places API, you'll need a different approach
      final placesSnapshot = await _firestore.collection('places').limit(50).get();
      
      return placesSnapshot.docs.map((doc) {
        final data = doc.data();
        return StudyPlace(
          data['name'] ?? '',
          LatLng(
            (data['latitude'] as num?)?.toDouble() ?? 0.0,
            (data['longitude'] as num?)?.toDouble() ?? 0.0,
          ),
          data['type'] ?? 'unknown',
          placeId: doc.id,
          rating: (data['rating'] as num?)?.toDouble(),
          userRatingsTotal: data['userRatingsTotal'] as int?,
          photoReference: data['photoReference'] as String?,
        );
      }).toList();
    } catch (e) {
      logger.e('Error getting all places: $e');
      // Return empty list if there's an error or no places in Firestore
      return [];
    }
  }

  /// Get similar places to a given place
  Future<List<StudyPlace>> getSimilarPlaces(StudyPlace place, {int limit = 5}) async {
    try {
      // Get all places
      final allPlaces = await _getAllPlaces();
      
      if (allPlaces.isEmpty) return [];
      
      // Remove the current place
      allPlaces.removeWhere((p) => p.placeId == place.placeId);
      
      // Score based on similarity
      final scoredPlaces = <MapEntry<StudyPlace, double>>[];
      
      for (var p in allPlaces) {
        double score = 0.0;
        
        // Same type = high score
        if (p.type == place.type) {
          score += 20;
        }
        
        // Similar rating
        if (p.rating != null && place.rating != null) {
          final diff = (p.rating! - place.rating!).abs();
          score += (5 - diff).clamp(0, 5);
        }
        
        scoredPlaces.add(MapEntry(p, score));
      }
      
      // Sort by score
      scoredPlaces.sort((a, b) => b.value.compareTo(a.value));
      
      return scoredPlaces.take(limit).map((e) => e.key).toList();
    } catch (e) {
      logger.e('Error getting similar places: $e');
      return [];
    }
  }
}
