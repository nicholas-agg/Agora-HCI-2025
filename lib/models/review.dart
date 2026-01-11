class Review {
  final String id;
  final String userId;
  final String userName;
  final String placeId;
  final String placeName;
  final int rating;
  final String outlets;
  final String reviewText;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.placeId,
    required this.placeName,
    required this.rating,
    required this.outlets,
    required this.reviewText,
    required this.createdAt,
  });

  // Create Review from Firestore document
  factory Review.fromFirestore(Map<String, dynamic> data, String id) {
    final created = data['createdAt'];
    final createdDate = created is DateTime
        ? created
        : created is dynamic && created?.toDate != null
            ? created.toDate() as DateTime
            : DateTime.now();

    return Review(
      id: id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'User',
      placeId: data['placeId'] as String? ?? '',
      placeName: data['placeName'] as String? ?? 'Unknown place',
      rating: data['rating'] as int? ?? 0,
      outlets: data['outlets'] as String? ?? '',
      reviewText: data['reviewText'] as String? ?? '',
      createdAt: createdDate,
    );
  }

  // Convert Review to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'placeId': placeId,
      'placeName': placeName,
      'rating': rating,
      'outlets': outlets,
      'reviewText': reviewText,
      'createdAt': createdAt,
    };
  }

  // Create Review from JSON
  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      placeId: json['placeId'] as String,
      placeName: json['placeName'] as String,
      rating: json['rating'] as int,
      outlets: json['outlets'] as String,
      reviewText: json['reviewText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Convert Review to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'placeId': placeId,
      'placeName': placeName,
      'rating': rating,
      'outlets': outlets,
      'reviewText': reviewText,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
