import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/check_in.dart';
import '../models/study_place.dart';
import '../services/database_service.dart';
import 'place_details_page.dart';

class RecentlyVisitedPage extends StatefulWidget {
  const RecentlyVisitedPage({super.key});

  @override
  State<RecentlyVisitedPage> createState() => _RecentlyVisitedPageState();
}

class _RecentlyVisitedPageState extends State<RecentlyVisitedPage> {
  final DatabaseService _databaseService = DatabaseService();

  Future<void> _openPlaceDetails(CheckIn checkIn) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing Google Maps API key.')),
      );
      return;
    }

    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=${checkIn.placeId}&fields=name,geometry,formatted_address,type,photos&key=$apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final name = result['name'] as String;
          final lat = result['geometry']['location']['lat'] as double;
          final lng = result['geometry']['location']['lng'] as double;
          String? photoRef;
          if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
            photoRef = result['photos'][0]['photo_reference'];
          }
          final place = StudyPlace(
            name,
            LatLng(lat, lng),
            'Study Place',
            photoReference: photoRef,
            placeId: checkIn.placeId,
          );
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlaceDetailsPage(place: place),
              ),
            );
          }
        } else {
          _showError('Failed to load place details.');
        }
      } else {
        _showError('Failed to load place details.');
      }
    } catch (e) {
      _showError('Failed to load place details: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '$weeks week${weeks == 1 ? '' : 's'} ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
    final years = (diff.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        title: const Text('Recently Visited', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view your history.'))
          : StreamBuilder<List<CheckIn>>(
              stream: _databaseService.getRecentCheckIns(userId: user.uid, limit: 30),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load history'));
                }
                final checkIns = snapshot.data ?? [];
                if (checkIns.isEmpty) {
                  return _buildEmptyState(colorScheme);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: checkIns.length,
                  itemBuilder: (context, index) {
                    final checkIn = checkIns[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.place, color: colorScheme.primary),
                        ),
                        title: Text(checkIn.placeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_timeAgo(checkIn.createdAt)),
                            if (checkIn.distanceMeters != null)
                              Text('${checkIn.distanceMeters!.toStringAsFixed(0)} m away when checked in',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        onTap: () => _openPlaceDetails(checkIn),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No visits yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text('Check in at a place to see it here.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
