class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final int points; // Gamification points

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.points = 0,
  });

  // Create AppUser from JSON
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      points: json['points'] as int? ?? 0,
    );
  }

  // Convert AppUser to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'points': points,
    };
  }

  // Create AppUser from Firestore document
  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      createdAt: (data['createdAt'] as dynamic).toDate(),
      points: data['points'] as int? ?? 0,
    );
  }

  // Convert AppUser to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt,
      'points': points,
    };
  }
}
