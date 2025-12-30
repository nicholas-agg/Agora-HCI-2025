import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/study_place.dart';
import 'menu_page.dart';
import 'profile_page.dart';
import '../services/favorites_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MyHomePage extends StatefulWidget {
  final VoidCallback onLogout;
  final String username;
  const MyHomePage({super.key, required this.onLogout, required this.username});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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

  void _fitMapToPlaces() {
    if (_places.isEmpty || _mapController == null) return;
    LatLngBounds bounds = _createBounds(_places.map((p) => p.location).toList());
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  LatLngBounds _createBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (var p in points) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLng == null || p.longitude < minLng) minLng = p.longitude;
      if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
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

  void _onCameraMove(CameraPosition position) {
    // Only update _currentCenter without setState to avoid excessive rebuilds
    _currentCenter = position.target;
    // If you want to update zoom, do it here without setState
    // _currentZoom = position.zoom;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          // 1. Full Screen Map
          Positioned.fill(
            child: GoogleMap(
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
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: _onCameraMove,
              onTap: (_) {
                setState(() {
                  _selectedPlace = null;
                });
              },
              padding: const EdgeInsets.only(top: 160, bottom: 100), // Adjust for overlays
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
                    Color.fromRGBO(255, 255, 255, 0.9),
                    Color.fromRGBO(255, 255, 255, 0.0),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF1D1B20)),
                    onPressed: () => _openMenu(context),
                  ),
                  const Text(
                    'Agora',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w400,
                      fontSize: 22,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ProfilePage(onSignOut: widget.onLogout)),
                      );
                    },
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFEADDFF),
                      child: Icon(Icons.person, size: 20, color: Color(0xFF4F378A)),
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
                  color: const Color(0xFFECE6F0),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isSearching
                    ? Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF49454F)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: _performSearch,
                              decoration: const InputDecoration(
                                hintText: 'Search for a place to study',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Color.fromRGBO(73, 69, 79, 0.8),
                                  fontSize: 16,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF1D1B20),
                                fontSize: 16,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xFF49454F)),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? Colors.red : const Color(0xFF49454F),
                            ),
                            onPressed: _isListening ? _stopListening : _startListening,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF49454F)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search for a place to study',
                              style: TextStyle(
                                color: Color.fromRGBO(73, 69, 79, 0.8),
                                fontSize: 16,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          const Icon(Icons.mic, color: Color(0xFF49454F)),
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
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _centerOnCurrentLocation,
              child: const Icon(Icons.my_location, color: Color(0xFF6750A4)),
            ),
          ),

          // 5. "Search this area" Button (fit all places)
          Positioned(
            top: MediaQuery.of(context).padding.top + 136,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _fitMapToPlaces();
                  _fetchPlacesAt(_currentCenter, _currentZoom);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFCAC4D0), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 16, color: Color(0xFF6750A4)),
                      const SizedBox(width: 6),
                      const Text(
                        'Search this area',
                        style: TextStyle(
                          color: Color(0xFF6750A4),
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
                      side: const BorderSide(color: Color(0xFFD9D9D9), width: 1),
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
                                    color: const Color(0xFFECE6F0),
                                    child: const Icon(Icons.image_not_supported, size: 40),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 160,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFECE6F0),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Center(child: Icon(Icons.place, color: Color(0xFF6750A4), size: 50)),
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
                                      await _favoritesManager.toggleFavorite(_selectedPlace!);
                                      if (!mounted) return;
                                      setState(() {});
                                      final isFavorite = _favoritesManager.isFavorite(_selectedPlace!);
                                      ScaffoldMessenger.of(context).showSnackBar(
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
                                        color: Color.fromRGBO(255, 255, 255, 0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _favoritesManager.isFavorite(_selectedPlace!)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                        size: 18,
                                        color: _favoritesManager.isFavorite(_selectedPlace!)
                                          ? Colors.red
                                          : Colors.black,
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
                                        color: Color.fromRGBO(255, 255, 255, 0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 18, color: Colors.black),
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF1E1E1E),
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Color(0xFF1D1B20)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_selectedPlace!.rating ?? "N/A"}(${_selectedPlace!.userRatingsTotal ?? 0} Reviews)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E1E1E),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Checked in to ${_selectedPlace!.name}')),
                                  );
                                },
                                child: const Text(
                                  'Check - in',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                    fontFamily: 'Roboto',
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.2),
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
                        color: const Color(0xFF6750A4),
                      ),
                      title: Text(
                        place.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        place.type,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedPlace = place;
                          _isSearching = false;
                          _searchController.clear();
                        });
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(place.location),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

          // 8. Loading Indicator
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6750A4)),
            ),
          if (_error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Material(
                color: Color.fromRGBO(255, 0, 0, 0.7),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
