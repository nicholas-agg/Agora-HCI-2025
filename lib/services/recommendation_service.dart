import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/study_place.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'favorites_manager.dart';

final logger = Logger();

/// Generates personalized place recommendations based on user's location
/// and uses Google's Gemini API to rank results
class RecommendationService {
  /// Get recommendations: 
  /// 1. Get user's current location
  /// 2. Fetch nearby places from Google Maps API
  /// 3. Filter out user's favorites
  /// 4. Use Gemini API to rank the best results
  Future<List<StudyPlace>> getRecommendations({int limit = 10, List<String> types = const ['cafe', 'library', 'coworking']}) async {
    try {
      // 1. Get user's current location
      final location = await _getCurrentLocation();
      if (location == null) {
        logger.w('No location available for recommendations');
        return [];
      }

      // 2. Get user's favorites (to exclude them)
      final favorites = await _getUserFavorites();
      final favoriteIds = {for (final fav in favorites) if (fav.placeId != null) fav.placeId!};

      // 3. Fetch nearby places from Google Maps API
      final Set<String> seenPlaceIds = {...favoriteIds};
      final List<StudyPlace> candidates = [];

      for (final type in types) {
        final results = await _searchNearbyPlacesGoogle(
          location,
          type,
          excludePlaceIds: seenPlaceIds,
          maxResults: limit * 2, // Get more to have variety for ranking
        );
        for (final place in results) {
          if (place.placeId != null && !seenPlaceIds.contains(place.placeId!)) {
            candidates.add(place);
            seenPlaceIds.add(place.placeId!);
          }
        }
      }

      if (candidates.isEmpty) {
        logger.w('No candidate places found nearby');
        return [];
      }

      // 4. Use Gemini API to rank the candidates
      final ranked = await _rankWithGemini(candidates, limit: limit);
      return ranked;
    } catch (e) {
      logger.e('Error getting recommendations: $e');
      return [];
    }
  }

  /// Get user's current location with permission handling
  Future<LatLng?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logger.w('Location permissions are denied');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        logger.w('Location permissions are permanently denied');
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      logger.e('Error getting current location: $e');
      return null;
    }
  }

  /// Get user's favorite places to exclude from recommendations
  Future<List<StudyPlace>> _getUserFavorites() async {
    try {
      final favManager = FavoritesManager();
      await favManager.initialize();
      return favManager.favorites;
    } catch (e) {
      logger.w('Could not load favorites: $e');
      return [];
    }
  }

  /// Rank candidate places using Google's Gemini API (free tier)
  Future<List<StudyPlace>> _rankWithGemini(List<StudyPlace> candidates, {int limit = 10}) async {
    if (candidates.isEmpty) return [];

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        logger.w('GEMINI_API_KEY not found. Returning unranked results.');
        return candidates.take(limit).toList();
      }

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      // Minimize tokens: only send essential data
      final placesList = candidates
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value.name} (${e.value.type}, ${e.value.rating ?? 0}★)')
          .join('\n');

      // Ultra-concise prompt to minimize tokens
      final prompt = 'Rank top $limit study places:\n$placesList\nReply: numbers only, comma-separated (e.g. 2,5,1)';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      String responseText = response.text ?? '';
      responseText = responseText.trim();

      if (responseText.isEmpty) {
        logger.w('Gemini returned empty response');
        return candidates.take(limit).toList();
      }

      // Parse the comma-separated rank numbers
      final ranks = responseText
          .split(',')
          .map((s) => s.trim())
          .whereType<String>()
          .map((s) {
            try {
              return int.parse(s) - 1; // Convert to 0-indexed
            } catch (e) {
              return null;
            }
          })
          .whereType<int>()
          .where((idx) => idx >= 0 && idx < candidates.length)
          .toList();

      if (ranks.isEmpty) {
        logger.w('Could not parse Gemini rankings');
        return candidates.take(limit).toList();
      }

      // Build ranked list
      final ranked = <StudyPlace>[];
      for (final idx in ranks) {
        if (!ranked.contains(candidates[idx])) {
          ranked.add(candidates[idx]);
        }
        if (ranked.length >= limit) break;
      }

      // Add remaining candidates if needed
      for (final place in candidates) {
        if (!ranked.contains(place)) {
          ranked.add(place);
        }
        if (ranked.length >= limit) break;
      }

      logger.i('✅ Ranked ${ranked.length} places using Gemini API');
      return ranked;
    } catch (e) {
      // Check if it's a quota error
      if (e.toString().contains('quota') || e.toString().contains('Quota')) {
        logger.w('⚠️ Gemini quota exceeded. Returning unranked results.');
      } else {
        logger.e('Error ranking with Gemini: $e');
      }
      // Fallback to unranked
      return candidates.take(limit).toList();
    }
  }

  /// Search Google Maps API for places near a location
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
}
