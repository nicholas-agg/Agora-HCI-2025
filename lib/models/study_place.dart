import 'package:google_maps_flutter/google_maps_flutter.dart';

class StudyPlace {
  final String name;
  final LatLng location;
  final String type;
  final String? photoReference;
  final String? placeId;
  final double? rating;
  final int? userRatingsTotal;

  StudyPlace(
    this.name, 
    this.location, 
    this.type, {
    this.photoReference, 
    this.placeId,
    this.rating,
    this.userRatingsTotal,
  });
}
