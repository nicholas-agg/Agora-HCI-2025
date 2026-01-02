import 'dart:developer' as developer;
import '../models/study_place.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

// Favorites manager with cloud sync and local fallback
class FavoritesManager extends ChangeNotifier {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  final List<StudyPlace> _favorites = [];
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;
  
  static const String _favoritesKey = 'user_favorites';

  List<StudyPlace> get favorites => List.unmodifiable(_favorites);

  // Initialize and load favorites from cloud or local storage
  Future<void> initialize() async {
    if (_initialized) return;
    final user = _auth.currentUser;
    if (user != null) {
      // User is logged in, sync from cloud
      await _syncFromCloud(user.uid);
    } else {
      // User not logged in, load from local storage
      await _loadFavorites();
    }
    _initialized = true;
    notifyListeners();
  }

  // Sync favorites from cloud database
  Future<void> _syncFromCloud(String userId) async {
    try {
      // Listen to real-time updates from cloud
      _databaseService.getUserFavorites(userId).listen(
        (cloudFavorites) {
          _favorites.clear();
          _favorites.addAll(cloudFavorites);
          // Also save to local storage as backup
          _saveFavorites();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Error syncing favorites from cloud: $error');
          // If permission denied or network error, fall back to local storage
          if (error.toString().contains('permission-denied') || 
              error.toString().contains('PERMISSION_DENIED')) {
            debugPrint('Permission denied - using local storage only');
            _loadFavorites();
            notifyListeners();
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up cloud sync: $e');
      // Fall back to local storage
      await _loadFavorites();
      notifyListeners();
    }
  }

  // Load favorites from local storage
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
      notifyListeners();
    } catch (e) {
      developer.log('Error loading favorites: $e');
    }
  }

  // Save favorites to local storage
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> favoritesList = 
          _favorites.map((place) => _studyPlaceToJson(place)).toList();
      await prefs.setString(_favoritesKey, json.encode(favoritesList));
      notifyListeners();
    } catch (e) {
      developer.log('Error saving favorites: $e');
    }
  }

  // Check if a place is in favorites
  bool isFavorite(StudyPlace place) {
    return _favorites.any((p) => p.placeId == place.placeId);
  }

  // Add a favorite (sync to cloud if user is logged in)
  Future<void> addFavorite(StudyPlace place) async {
    if (isFavorite(place)) return;
    final user = _auth.currentUser;
    try {
      if (user != null) {
        // Add to cloud database
        await _databaseService.addFavorite(user.uid, place);
        // Cloud listener will automatically update local list
      } else {
        // Add to local storage only
        _favorites.add(place);
        await _saveFavorites();
        notifyListeners();
      }
    } catch (e) {
      developer.log('Error adding favorite: $e');
      // Fallback to local storage
      if (!isFavorite(place)) {
        _favorites.add(place);
        await _saveFavorites();
        notifyListeners();
      }
    }
  }

  // Remove a favorite (sync to cloud if user is logged in)
  Future<void> removeFavorite(StudyPlace place) async {
    final user = _auth.currentUser;
    try {
      if (user != null && place.placeId != null) {
        // Remove from cloud database
        await _databaseService.removeFavorite(user.uid, place.placeId!);
        // Cloud listener will automatically update local list
      } else {
        // Remove from local storage only
        _favorites.removeWhere((p) => p.placeId == place.placeId);
        await _saveFavorites();
        notifyListeners();
      }
    } catch (e) {
      developer.log('Error removing favorite: $e');
      // Fallback to local storage
      _favorites.removeWhere((p) => p.placeId == place.placeId);
      await _saveFavorites();
      notifyListeners();
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(StudyPlace place) async {
    if (isFavorite(place)) {
      await removeFavorite(place);
    } else {
      await addFavorite(place);
    }
  }

  // Migrate local favorites to cloud when user logs in
  Future<void> migrateToCloud(String userId) async {
    try {
      for (var place in _favorites) {
        await _databaseService.addFavorite(userId, place);
      }
      // After migration, start syncing from cloud
      await _syncFromCloud(userId);
      notifyListeners();
    } catch (e) {
      developer.log('Error migrating favorites to cloud: $e');
    }
  }

  // Clear all favorites (for logout)
  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
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
