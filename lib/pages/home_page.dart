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
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';
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
    _checkLocationPermission();
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

  void _performSearch(String query) {
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
      _searchResults = _places.where((place) {
        return place.name.toLowerCase().contains(query.toLowerCase()) ||
               place.type.toLowerCase().contains(query.toLowerCase());
      }).toList();
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
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLng(place.location),
                          );
                        },
                        icon: place.type == 'Cafe'
                            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                            : place.type == 'Library'
                                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
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
                          Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
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
                          Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
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
                                      await _favoritesManager.toggleFavorite(_selectedPlace!);
                                      if (!mounted) return;
                                      setState(() {});
                                      final isFavorite = _favoritesManager.isFavorite(_selectedPlace!);
                                      if (!rootContext.mounted) return;
                                      ScaffoldMessenger.of(rootContext).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isFavorite 
                                              ? '${_selectedPlace!.name} added to favorites' 
                                              : '${_selectedPlace!.name} removed from favorites'
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
                              Text(
                                _selectedPlace!.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: colorScheme.onSurface,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 16, color: colorScheme.onSurface),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_selectedPlace!.rating ?? "N/A"}(${_selectedPlace!.userRatingsTotal ?? 0} Reviews)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PlaceDetailsPage(place: _selectedPlace!),
                                    ),
                                  );
                                },
                                child: Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.primary,
                                    fontFamily: 'Roboto',
                                    decoration: TextDecoration.underline,
                                  ),
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
                      trailing: place.rating != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  place.rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlaceDetailsPage(place: place),
                          ),
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
