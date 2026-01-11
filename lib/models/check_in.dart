import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CheckIn {
  CheckIn({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.placeName,
    required this.placeLocation,
    required this.createdAt,
    required this.expiresAt,
    this.userLatitude,
    this.userLongitude,
    this.distanceMeters,
    this.noiseDb,
    this.photoUrl,
  });

  final String id;
  final String userId;
  final String placeId;
  final String placeName;
  final LatLng placeLocation;
  final DateTime createdAt;
  final DateTime expiresAt;
  final double? userLatitude;
  final double? userLongitude;
  final double? distanceMeters;
  final double? noiseDb;
  final String? photoUrl;

  factory CheckIn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CheckIn(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      placeId: data['placeId'] as String? ?? '',
      placeName: data['placeName'] as String? ?? 'Unknown place',
      placeLocation: LatLng(
        (data['placeLatitude'] as num?)?.toDouble() ?? 0,
        (data['placeLongitude'] as num?)?.toDouble() ?? 0,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 1)),
      userLatitude: (data['userLatitude'] as num?)?.toDouble(),
      userLongitude: (data['userLongitude'] as num?)?.toDouble(),
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      noiseDb: (data['noiseDb'] as num?)?.toDouble(),
      photoUrl: data['photoUrl'] as String?,
    );
  }
}
