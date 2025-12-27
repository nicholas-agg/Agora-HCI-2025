import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
    LatLng _currentCenter = const LatLng(37.9838, 23.7275); // Default to Athens
    double _currentZoom = 13;
  List<_StudyPlace> _places = [];
  bool _loading = true;
  String? _error;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchPlacesAt(_currentCenter, _currentZoom);
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentCenter = position.target;
      _currentZoom = position.zoom;
    });
  }

  void _onSearchThisArea() {
    _fetchPlacesAt(_currentCenter, _currentZoom);
  }

  Future<void> _fetchPlacesAt(LatLng center, double zoom) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    final location = '${center.latitude},${center.longitude}';
    // Adjust radius based on zoom (approximate)
    final radius = (40000 / (zoom * zoom)).clamp(500, 5000).toInt();
    final types = [
      {'type': 'cafe'},
      {'type': 'library'},
      {'type': 'coworking_space', 'keyword': 'coworking'}
    ];
    List<_StudyPlace> allPlaces = [];
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
              allPlaces.add(_StudyPlace(name, LatLng(lat, lng), type));
            }
          }
        } else {
          setState(() {
            _error = 'Failed to fetch places (${t['type']})';
          });
        }
      }
      setState(() {
        _places = allPlaces;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  void _openMenu(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MenuPage()),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double mapHeight = MediaQuery.of(context).size.height * 0.45;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1D1B20)),
          onPressed: () => _openMenu(context),
          tooltip: 'Menu',
        ),
        title: const Text(
          'Agora',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 22,
            color: Color(0xFF1D1B20),
            letterSpacing: 0,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF49454F)),
            onPressed: () => _openProfile(context),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: mapHeight,
                width: double.infinity,
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
                            infoWindow: InfoWindow(title: place.name, snippet: place.type),
                            icon: place.type == 'Cafe'
                                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                                : place.type == 'Library'
                                    ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                                    : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                          ))
                      .toSet(),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: _onCameraMove,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Study Places near you',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : ListView.builder(
                            itemCount: _places.length,
                            itemBuilder: (context, index) {
                              final place = _places[index];
                              return ListTile(
                                leading: Icon(
                                  place.type == 'Cafe'
                                      ? Icons.local_cafe
                                      : place.type == 'Library'
                                          ? Icons.local_library
                                          : Icons.business_center,
                                ),
                                title: Text(place.name),
                                subtitle: Text(place.type),
                                onTap: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLng(place.location),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
          // Floating search button
          Positioned(
            top: mapHeight - 30,
            left: MediaQuery.of(context).size.width / 2 - 80,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _loading ? null : _onSearchThisArea,
              icon: const Icon(Icons.search),
              label: const Text('Search this area'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyPlace {
  final String name;
  final LatLng location;
  final String type;
  _StudyPlace(this.name, this.location, this.type);
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
      ),
      body: const Center(
        child: Text('Menu Page'),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: const Center(
        child: Text('Profile Page'),
      ),
    );
  }
}

