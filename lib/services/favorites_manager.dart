import '../models/study_place.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Favorites manager with persistent local storage
class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  final List<StudyPlace> _favorites = [];
  bool _initialized = false;
  
  static const String _favoritesKey = 'user_favorites';

  List<StudyPlace> get favorites => List.unmodifiable(_favorites);

  // Initialize and load favorites from local storage
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFavorites();
    _initialized = true;
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? favoritesJson = prefs.getString(_favoritesKey);
      
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = json.decode(favoritesJson);
        _favorites.clear();
        for (var item in favoritesList) {
          _favorites.add(_studyPlaceFromJson(item));
        }
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> favoritesList = 
          _favorites.map((place) => _studyPlaceToJson(place)).toList();
      await prefs.setString(_favoritesKey, json.encode(favoritesList));
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  bool isFavorite(StudyPlace place) {
    return _favorites.any((p) => p.placeId == place.placeId);
  }

  Future<void> addFavorite(StudyPlace place) async {
    if (!isFavorite(place)) {
      _favorites.add(place);
      await _saveFavorites();
    }
  }

  Future<void> removeFavorite(StudyPlace place) async {
    _favorites.removeWhere((p) => p.placeId == place.placeId);
    await _saveFavorites();
  }

  Future<void> toggleFavorite(StudyPlace place) async {
    if (isFavorite(place)) {
      await removeFavorite(place);
    } else {
      await addFavorite(place);
    }
  }

  // Helper methods to convert StudyPlace to/from JSON
  Map<String, dynamic> _studyPlaceToJson(StudyPlace place) {
    return {
      'name': place.name,
      'latitude': place.location.latitude,
      'longitude': place.location.longitude,
      'type': place.type,
      'photoReference': place.photoReference,
      'placeId': place.placeId,
      'rating': place.rating,
      'userRatingsTotal': place.userRatingsTotal,
    };
  }

  StudyPlace _studyPlaceFromJson(Map<String, dynamic> json) {
    return StudyPlace(
      json['name'] as String,
      LatLng(json['latitude'] as double, json['longitude'] as double),
      json['type'] as String,
      photoReference: json['photoReference'] as String?,
      placeId: json['placeId'] as String?,
      rating: json['rating'] as double?,
      userRatingsTotal: json['userRatingsTotal'] as int?,
    );
  }
}
