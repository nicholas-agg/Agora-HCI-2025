
class Review {
  final String id;
  final String? userId; // May be null for legacy reviews
  final String? userName; // Only for legacy reviews
  final String placeId;
  final String placeName;
  final int rating;
  final String outlets;
  final String reviewText;
  final DateTime createdAt;
  final String? photoReference;

  // New detailed attributes
  final int? wifiQuality; // 1-5 rating
  final int? outletAvailability; // 1-5 rating
  final String? averagePrice; // e.g., "€5-10", "Free"
  final double? noiseLevel; // Measured in decibels
  final int? comfortLevel; // 1-5 rating
  final int? aestheticRating; // 1-5 rating
  final List<String>? userPhotos; // Base64 encoded images

  Review({
    required this.id,
    this.userId,
    this.userName,
    required this.placeId,
    required this.placeName,
    required this.rating,
    required this.outlets,
    required this.reviewText,
    required this.createdAt,
    this.photoReference,
    this.wifiQuality,
    this.outletAvailability,
    this.averagePrice,
    this.noiseLevel,
    this.comfortLevel,
    this.aestheticRating,
    this.userPhotos,
  });

  /// Returns the display name for this review (legacy or new)
  String? get displayName => userName;

  // Create Review from Firestore document (supports both schemas)
  factory Review.fromFirestore(Map<String, dynamic> data, String id) {
    final hasUserId = data.containsKey('userId') && data['userId'] != null;
    final hasUserName = data.containsKey('userName') && data['userName'] != null;
    return Review(
      id: id,
      userId: hasUserId ? data['userId'] as String : null,
      userName: hasUserName ? data['userName'] as String : null,
      placeId: data['placeId'] as String,
      placeName: data['placeName'] as String,
      rating: data['rating'] as int,
      outlets: data['outlets'] as String,
      reviewText: data['reviewText'] as String,
      createdAt: (data['createdAt'] as dynamic).toDate(),
      photoReference: data['photoReference'] as String?,
      wifiQuality: data['wifiQuality'] as int?,
      outletAvailability: data['outletAvailability'] as int?,
      averagePrice: data['averagePrice'] as String?,
      noiseLevel: data['noiseLevel'] as double?,
      comfortLevel: data['comfortLevel'] as int?,
      aestheticRating: data['aestheticRating'] as int?,
      userPhotos: data['userPhotos'] != null ? List<String>.from(data['userPhotos'] as List) : null,
    );
  }

  // Convert Review to Firestore document (always new schema)
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'placeId': placeId,
      'placeName': placeName,
      'rating': rating,
      'outlets': outlets,
      'reviewText': reviewText,
      'createdAt': createdAt,
      if (photoReference != null) 'photoReference': photoReference,
      if (wifiQuality != null) 'wifiQuality': wifiQuality,
      if (outletAvailability != null) 'outletAvailability': outletAvailability,
      if (averagePrice != null) 'averagePrice': averagePrice,
      if (noiseLevel != null) 'noiseLevel': noiseLevel,
      if (comfortLevel != null) 'comfortLevel': comfortLevel,
      if (aestheticRating != null) 'aestheticRating': aestheticRating,
      if (userPhotos != null && userPhotos!.isNotEmpty) 'userPhotos': userPhotos,
    };
  }

  // Create Review from JSON (supports both schemas)
  factory Review.fromJson(Map<String, dynamic> json) {
    final hasUserId = json.containsKey('userId') && json['userId'] != null;
    final hasUserName = json.containsKey('userName') && json['userName'] != null;
    return Review(
      id: json['id'] as String,
      userId: hasUserId ? json['userId'] as String : null,
      userName: hasUserName ? json['userName'] as String : null,
      placeId: json['placeId'] as String,
      placeName: json['placeName'] as String,
      rating: json['rating'] as int,
      outlets: json['outlets'] as String,
      reviewText: json['reviewText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      photoReference: json['photoReference'] as String?,
      wifiQuality: json['wifiQuality'] as int?,
      outletAvailability: json['outletAvailability'] as int?,
      averagePrice: json['averagePrice'] as String?,
      noiseLevel: json['noiseLevel'] as double?,
      comfortLevel: json['comfortLevel'] as int?,
      aestheticRating: json['aestheticRating'] as int?,
      userPhotos: json['userPhotos'] != null ? List<String>.from(json['userPhotos'] as List) : null,
    );
  }

  // Convert Review to JSON (always new schema)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'placeId': placeId,
      'placeName': placeName,
      'rating': rating,
      'outlets': outlets,
      'reviewText': reviewText,
      'createdAt': createdAt.toIso8601String(),
      if (photoReference != null) 'photoReference': photoReference,
      if (wifiQuality != null) 'wifiQuality': wifiQuality,
      if (outletAvailability != null) 'outletAvailability': outletAvailability,
      if (averagePrice != null) 'averagePrice': averagePrice,
      if (noiseLevel != null) 'noiseLevel': noiseLevel,
      if (comfortLevel != null) 'comfortLevel': comfortLevel,
      if (aestheticRating != null) 'aestheticRating': aestheticRating,
      if (userPhotos != null && userPhotos!.isNotEmpty) 'userPhotos': userPhotos,
    };
  }
}
