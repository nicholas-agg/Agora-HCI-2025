import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/study_place.dart';
import 'menu_page.dart';
import 'profile_page.dart';
import 'place_details_page.dart';
import '../services/favorites_manager.dart';
import '../services/database_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';

import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../services/theme_manager.dart';

class MyHomePage extends StatefulWidget {
  final VoidCallback onLogout;
  final String username;
  const MyHomePage({super.key, required this.onLogout, required this.username});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double? _agoraAvgRating;
  int? _agoraReviewCount;
  bool _agoraReviewsLoading = false;
  // Fetch Agora reviews for the selected place
  Future<void> _fetchAgoraReviewStats(String placeId) async {
    setState(() {
      _agoraReviewsLoading = true;
      _agoraAvgRating = null;
      _agoraReviewCount = null;
    });
    try {
      final db = DatabaseService();
      final avg = await db.getPlaceAverageRating(placeId);
      // Use FirebaseFirestore.instance directly for public access
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('placeId', isEqualTo: placeId)
          .get();
      setState(() {
        _agoraAvgRating = avg;
        _agoraReviewCount = snapshot.docs.length;
        _agoraReviewsLoading = false;
      });
    } catch (e) {
      setState(() {
        _agoraAvgRating = null;
        _agoraReviewCount = null;
        _agoraReviewsLoading = false;
      });
    }
  }

    // Removed unused _darkMapStyle
  LatLng _currentCenter = const LatLng(37.9838, 23.7275); // Default to Athens
  final double _currentZoom = 13;
  List<StudyPlace> _places = [];
  StudyPlace? _selectedPlace;
  bool _loading = true;
  String? _error;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  final _favoritesManager = FavoritesManager();

  // Custom marker icons for each category
  BitmapDescriptor? _cafeIcon;
  BitmapDescriptor? _libraryIcon;
  BitmapDescriptor? _coworkingIcon;
  BitmapDescriptor? _otherIcon;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<StudyPlace> _searchResults = [];

  // Voice search
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadCustomMarkerIcons();
    _checkLocationPermission();
  }

  Future<void> _loadCustomMarkerIcons() async {
    // Helper to create a BitmapDescriptor from a Material icon
    Future<BitmapDescriptor> createIcon(IconData icon, Color color) async {
      // Medium pin for Google Maps scaling (logical: 80x98)
      const double scale = 3.0;
      final double width = 80 * scale, height = 98 * scale;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      // Draw shadow (bigger and more oval, like Google)
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(width / 2, height - 16 * scale),
          width: 32 * scale,
          height: 12 * scale,
        ),
        shadowPaint,
      );

      // Draw teardrop pin shape (circle + triangle, more Googley)
      final pinPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      // Main circle
      final circleRadius = 32 * scale;
      final circleCenter = Offset(width / 2, circleRadius + 8 * scale);
      canvas.drawCircle(circleCenter, circleRadius, pinPaint);

      // Teardrop triangle (longer, more pointed)
      final path = Path();
      path.moveTo(width / 2 - 18.5 * scale, circleCenter.dy + 12 * scale);
      path.lineTo(width / 2, height - 21 * scale);
      path.lineTo(width / 2 + 18.5 * scale, circleCenter.dy + 12 * scale);
      path.close();
      canvas.drawPath(path, pinPaint);

      // Draw icon in center (smaller)
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 40 * scale,
            fontFamily: icon.fontFamily,
            color: Colors.white,
            package: icon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          (width - iconPainter.width) / 2,
          circleCenter.dy - iconPainter.height / 2,
        ),
      );

      // Downscale to target size for sharpness
      final image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
      final targetWidth = 80, targetHeight = 98;
      final resized = await image.toByteData(format: ui.ImageByteFormat.png);
      final codec = await ui.instantiateImageCodec(resized!.buffer.asUint8List(), targetWidth: targetWidth, targetHeight: targetHeight);
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    }

    final cafeIcon = await createIcon(Icons.local_cafe, Colors.brown);
    final libraryIcon = await createIcon(Icons.menu_book, Colors.blue);
    final coworkingIcon = await createIcon(Icons.work, Colors.deepPurple);
    final otherIcon = await createIcon(Icons.location_on, Colors.grey);
    if (!mounted) return;
    setState(() {
      _cafeIcon = cafeIcon;
      _libraryIcon = libraryIcon;
      _coworkingIcon = coworkingIcon;
      _otherIcon = otherIcon;
    });
  }

  BitmapDescriptor _getMarkerIconForType(String type) {
    if (type.toLowerCase().contains('cafe') && _cafeIcon != null) return _cafeIcon!;
    if (type.toLowerCase().contains('library') && _libraryIcon != null) return _libraryIcon!;
    if (type.toLowerCase().contains('coworking') && _coworkingIcon != null) return _coworkingIcon!;
    if (_otherIcon != null) return _otherIcon!;
    // Fallback to default marker if icons not loaded yet
    return BitmapDescriptor.defaultMarker;
  }

  // Map styling is now handled via Google Cloud Map IDs
  // No need for manual style application


  // _updateMapStyle is no longer needed; style is set in onMapCreated

  // didChangeDependencies override removed

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _locationPermissionGranted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    });
    if (_locationPermissionGranted) {
      _centerOnCurrentLocation();
    } else {
      _fetchPlacesAt(_currentCenter, _currentZoom);
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentCenter));
      _fetchPlacesAt(_currentCenter, _currentZoom);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not get current location.';
      });
      _fetchPlacesAt(_currentCenter, _currentZoom);
    }
  }


  Future<void> _fetchPlacesAt(LatLng center, double zoom) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    final location = '${center.latitude},${center.longitude}';
    // Use a larger radius to cover more area
    final radius = 3000;
    final types = [
      {'type': 'cafe'},
      {'type': 'library'},
      {'type': 'coworking_space', 'keyword': 'coworking'}
    ];
    List<StudyPlace> allPlaces = [];
    try {
      for (var t in types) {
        String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$location&radius=$radius&type=${t['type']}&key=$apiKey';
        if (t['type'] == 'coworking_space') {
          url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$location&radius=$radius&keyword=coworking&key=$apiKey';
        }
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            for (var result in data['results']) {
              final name = result['name'];
              final lat = result['geometry']['location']['lat'];
              final lng = result['geometry']['location']['lng'];
              final type = t['type'] == 'coworking_space' ? 'Coworking' : (t['type'] as String).replaceFirst((t['type'] as String)[0], (t['type'] as String)[0].toUpperCase());
              
              String? photoRef;
              if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
                photoRef = result['photos'][0]['photo_reference'];
              }
              final placeId = result['place_id'];
              final rating = result['rating']?.toDouble();
              final userRatingsTotal = result['user_ratings_total']?.toInt();

              allPlaces.add(StudyPlace(
                name, 
                LatLng(lat, lng), 
                type,
                photoReference: photoRef,
                placeId: placeId,
                rating: rating,
                userRatingsTotal: userRatingsTotal,
              ));
            }
          }
        } else {
          if (!mounted) return;
          setState(() {
            _error = 'Failed to fetch places (${t['type']})';
          });
        }
      }
      // Prioritize: Coworking > Library > Cafe
      allPlaces.sort((a, b) {
        int rank(String type) {
          if (type.toLowerCase().contains('coworking')) return 0;
          if (type.toLowerCase().contains('library')) return 1;
          if (type.toLowerCase().contains('cafe')) return 2;
          return 3;
        }
        return rank(a.type).compareTo(rank(b.type));
      });
      if (!mounted) return;
      setState(() {
        _places = allPlaces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  void _openMenu(BuildContext context) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MenuPage(onSignOut: widget.onLogout),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    // 1. Search loaded pins first
    final localResults = _places.where((place) {
      return place.name.toLowerCase().contains(query.toLowerCase()) ||
             place.type.toLowerCase().contains(query.toLowerCase());
    }).toList();

    // 2. Search Google Places API for more results
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    final location = '${_currentCenter.latitude},${_currentCenter.longitude}';
    final radius = 3000;
    // Removed unused 'types' variable
    List<StudyPlace> apiResults = [];
    try {
      // Use Text Search for the query
      String url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&location=$location&radius=$radius&key=$apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          for (var result in data['results']) {
            // Only include relevant types
            final placeTypes = (result['types'] as List).cast<String>();
            if (!placeTypes.any((t) => t.contains('cafe') || t.contains('library') || t.contains('coworking'))) {
              continue;
            }
            final name = result['name'];
            final lat = result['geometry']['location']['lat'];
            final lng = result['geometry']['location']['lng'];
            String type = 'Other';
            if (placeTypes.contains('cafe')) {
              type = 'Cafe';
            } else if (placeTypes.contains('library')) {
              type = 'Library';
            } else if (placeTypes.any((t) => t.contains('coworking'))) {
              type = 'Coworking';
            }
            String? photoRef;
            if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
              photoRef = result['photos'][0]['photo_reference'];
            }
            final placeId = result['place_id'];
            final rating = result['rating']?.toDouble();
            final userRatingsTotal = result['user_ratings_total']?.toInt();
            // Avoid duplicates with loaded pins
            if (_places.any((p) => p.placeId == placeId)) continue;
            apiResults.add(StudyPlace(
              name,
              LatLng(lat, lng),
              type,
              photoReference: photoRef,
              placeId: placeId,
              rating: rating,
              userRatingsTotal: userRatingsTotal,
            ));
          }
        }
      }
    } catch (e) {
      // Ignore API errors for search
    }

    setState(() {
      _searchResults = [...localResults, ...apiResults];
    });
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          if (!mounted) return;
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: {error.errorMsg}')),
        );
      },
    );

    if (available) {
      if (!mounted) return;
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _voiceText = result.recognizedWords;
            _searchController.text = _voiceText;
            _performSearch(_voiceText);
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  String? _getPhotoUrl(String? photoReference) {
    if (photoReference == null) return null;
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey';
  }

  double _calculateRadius(LatLngBounds bounds) {
    const double earthRadius = 6371000; // meters
    double lat1 = bounds.northeast.latitude * (pi / 180.0);
    double lon1 = bounds.northeast.longitude * (pi / 180.0);
    double lat2 = bounds.southwest.latitude * (pi / 180.0);
    double lon2 = bounds.southwest.longitude * (pi / 180.0);
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = 
      (sin(dLat / 2) * sin(dLat / 2)) +
      cos(lat1) * cos(lat2) *
      (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    return distance / 2; // half diagonal as radius
  }

  Future<void> _fetchPlacesInBounds(LatLngBounds bounds, LatLng center) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    final location = '${center.latitude},${center.longitude}';
    final radius = _calculateRadius(bounds);
    final types = [
      {'type': 'cafe'},
      {'type': 'library'},
      {'type': 'coworking_space', 'keyword': 'coworking'}
    ];
    List<StudyPlace> allPlaces = [];
    try {
      for (var t in types) {
        String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$location&radius=${radius.round()}&type=${t['type']}&key=$apiKey';
        if (t['type'] == 'coworking_space') {
          url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$location&radius=${radius.round()}&keyword=coworking&key=$apiKey';
        }
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            for (var result in data['results']) {
              final name = result['name'];
              final lat = result['geometry']['location']['lat'];
              final lng = result['geometry']['location']['lng'];
              final type = t['type'] == 'coworking_space' ? 'Coworking' : (t['type'] as String).replaceFirst((t['type'] as String)[0], (t['type'] as String)[0].toUpperCase());
              String? photoRef;
              if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
                photoRef = result['photos'][0]['photo_reference'];
              }
              final placeId = result['place_id'];
              final rating = result['rating']?.toDouble();
              final userRatingsTotal = result['user_ratings_total']?.toInt();
              final place = StudyPlace(
                name,
                LatLng(lat, lng),
                type,
                photoReference: photoRef,
                placeId: placeId,
                rating: rating,
                userRatingsTotal: userRatingsTotal,
              );
              // Only add if inside visible bounds
              if (_isLatLngInBounds(LatLng(lat, lng), bounds)) {
                allPlaces.add(place);
              }
            }
          }
        } else {
          if (!mounted) return;
          setState(() {
            _error = 'Failed to fetch places (${t['type']})';
          });
        }
      }
      // Prioritize: Coworking > Library > Cafe
      allPlaces.sort((a, b) {
        int rank(String type) {
          if (type.toLowerCase().contains('coworking')) return 0;
          if (type.toLowerCase().contains('library')) return 1;
          if (type.toLowerCase().contains('cafe')) return 2;
          return 3;
        }
        return rank(a.type).compareTo(rank(b.type));
      });
      if (!mounted) return;
      setState(() {
        _places = allPlaces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  bool _isLatLngInBounds(LatLng point, LatLngBounds bounds) {
    final lat = point.latitude;
    final lng = point.longitude;
    return lat >= bounds.southwest.latitude && lat <= bounds.northeast.latitude &&
           lng >= bounds.southwest.longitude && lng <= bounds.northeast.longitude;
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Full Screen Map with smooth transition
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: GoogleMap(
                    key: ValueKey(isDarkMode), // Key ensures AnimatedSwitcher detects the change
                    cloudMapId: isDarkMode ? '2f87b85e986833829e30b116' : null,
                    initialCameraPosition: CameraPosition(
                      target: _currentCenter,
                      zoom: _currentZoom,
                    ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _places
                  .map((place) => Marker(
                        markerId: MarkerId(place.name),
                        position: place.location,
                        onTap: () {
                          setState(() {
                            _selectedPlace = place;
                          });
                          _fetchAgoraReviewStats(place.placeId ?? '');
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLng(place.location),
                          );
                        },
                        icon: _getMarkerIconForType(place.type),
                      ))
                  .toSet(),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: (_) {
                setState(() {
                  _selectedPlace = null;
                });
              },
                  ),
                );
              },
            ),
          ),

          // 2. Custom App Bar (Floating)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 8,
                left: 8,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.95),
                    colorScheme.surface.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: colorScheme.onSurface),
                    onPressed: () => _openMenu(context),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Consumer<ThemeManager>(
                        builder: (context, themeManager, _) {
                          return Image.asset(
                            themeManager.themeMode == ThemeMode.light
                                ? 'assets/icon/app_icon_black.png'
                                : 'assets/icon/app_icon_bw.png',
                            height: 32,
                            width: 32,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Agora',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          fontSize: 22,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ProfilePage(onSignOut: widget.onLogout)),
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.person, size: 20, color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Search Bar Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = true;
                });
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isSearching
                    ? Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.menu, color: colorScheme.onSurfaceVariant),
                            onPressed: () => _openMenu(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: _performSearch,
                              decoration: InputDecoration(
                                hintText: 'Search for a place to study',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                  fontSize: 16,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? Colors.red : colorScheme.onSurfaceVariant,
                            ),
                            onPressed: _isListening ? _stopListening : _startListening,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.menu, color: colorScheme.onSurfaceVariant),
                            onPressed: () => _openMenu(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Search for a place to study',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          Icon(Icons.mic, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
              ),
            ),
          ),

          // 4. Current Location Button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'currentLocation',
              backgroundColor: colorScheme.surface,
              elevation: 4,
              onPressed: _centerOnCurrentLocation,
              child: Icon(Icons.my_location, color: colorScheme.primary),
            ),
          ),

          // 5. "Search this area" Button (fit all places)
          Positioned(
            top: MediaQuery.of(context).padding.top + 136,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  if (_mapController != null) {
                    final bounds = await _mapController!.getVisibleRegion();
                    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
                    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
                    final center = LatLng(centerLat, centerLng);
                    setState(() {
                      _currentCenter = center;
                    });
                    await _fetchPlacesInBounds(bounds, center);
                  } else {
                    await _fetchPlacesAt(_currentCenter, _currentZoom);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Search this area',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 6. Place Card Overlay
          if (_selectedPlace != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailsPage(place: _selectedPlace!),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              if (_getPhotoUrl(_selectedPlace!.photoReference) != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.network(
                                    _getPhotoUrl(_selectedPlace!.photoReference)!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 160,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.image_not_supported, size: 40),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  ),
                                  child: Center(child: Icon(Icons.place, color: colorScheme.primary, size: 50)),
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Favorite button
                                    GestureDetector(
                                      onTap: () async {
                                        final rootContext = context;
                                        final wasFavorite = _favoritesManager.isFavorite(_selectedPlace!);
                                        await _favoritesManager.toggleFavorite(_selectedPlace!);
                                        if (!mounted) return;
                                        setState(() {});
                                        if (!rootContext.mounted) return;
                                        ScaffoldMessenger.of(rootContext).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              wasFavorite 
                                                ? '${_selectedPlace!.name} removed from favorites' 
                                                : '${_selectedPlace!.name} added to favorites'
                                            ),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface.withValues(alpha: 0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _favoritesManager.isFavorite(_selectedPlace!)
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                          size: 18,
                                          color: _favoritesManager.isFavorite(_selectedPlace!)
                                            ? Colors.red
                                            : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Close button
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedPlace = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface.withValues(alpha: 0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close, size: 18, color: colorScheme.onSurface),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedPlace!.type.toLowerCase().contains('cafe')
                                          ? Icons.local_cafe
                                          : _selectedPlace!.type.toLowerCase().contains('library')
                                              ? Icons.menu_book
                                              : _selectedPlace!.type.toLowerCase().contains('coworking')
                                                  ? Icons.work
                                                  : Icons.location_on,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedPlace!.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w400,
                                          color: colorScheme.onSurface,
                                          fontFamily: 'Inter',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Google reviews row
                                Row(
                                  children: [
                                    Icon(Icons.star, size: 16, color: colorScheme.onSurface),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_selectedPlace!.rating != null ? _selectedPlace!.rating!.toStringAsFixed(1) : "N/A"} (Google, ${_selectedPlace!.userRatingsTotal ?? 0} reviews)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                // Agora reviews row
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    if (_agoraReviewsLoading) {
                                      return Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Loading Agora reviews...', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                        ],
                                      );
                                    } else if (_agoraReviewCount == null || _agoraReviewCount == 0) {
                                      return Row(
                                        children: [
                                          Icon(Icons.star_border, size: 16, color: colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Text('No Agora reviews yet', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                        ],
                                      );
                                    } else {
                                      return Row(
                                        children: [
                                          Icon(Icons.star, size: 16, color: colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_agoraAvgRating != null ? _agoraAvgRating!.toStringAsFixed(1) : "N/A"} (Agora, $_agoraReviewCount review${_agoraReviewCount == 1 ? '' : 's'})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.primary,
                                    fontFamily: 'Roboto',
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 7. Search Results Overlay
          if (_isSearching && _searchResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 128,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    return FutureBuilder<double?>(
                      future: DatabaseService().getPlaceAverageRating(place.placeId ?? ''),
                      builder: (context, snapshot) {
                        final agoraRating = snapshot.data;
                        return ListTile(
                          leading: Icon(
                            place.type.toLowerCase().contains('cafe')
                                ? Icons.local_cafe
                                : place.type.toLowerCase().contains('library')
                                    ? Icons.menu_book
                                    : Icons.work,
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            place.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            place.type,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          trailing: agoraRating != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      agoraRating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text('—', style: TextStyle(color: Colors.grey)),
                          onTap: () {
                            // If not already a pin, add to pins and select
                            setState(() {
                              if (!_places.any((p) => p.placeId == place.placeId)) {
                                _places.add(place);
                                _selectedPlace = place;
                              } else {
                                _selectedPlace = _places.firstWhere((p) => p.placeId == place.placeId);
                              }
                              // Hide search overlay
                              _isSearching = false;
                              _searchResults = [];
                            });
                            // Center map on the place
                            _mapController?.animateCamera(CameraUpdate.newLatLng(place.location));
                            // Show popup card (handled by _selectedPlace)
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

          // 8. Loading Indicator
          if (_loading)
            Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          if (_error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Material(
                color: colorScheme.errorContainer.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
