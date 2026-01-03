import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/database_service.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  final DatabaseService _databaseService = DatabaseService();
  bool _loading = true;
  String? _error;
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final reviewStream = _databaseService.getUserReviews(user.uid);
      reviewStream.listen((userReviews) {
        setState(() {
          _reviews = userReviews;
          _loading = false;
        });
      }, onError: (e) {
        setState(() {
          _error = 'Failed to load reviews: $e';
          _loading = false;
        });
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reviews: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        title: const Text('My Reviews', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _reviews.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        return _buildReviewCard(review, colorScheme);
                      },
                    ),
    );
  }

  Widget _buildReviewCard(Review review, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.placeName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Optionally, add a badge for type if you want
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (i) {
                  if (i < review.rating) {
                    return const Icon(Icons.star, color: Color(0xFFFBBF24), size: 18);
                  } else {
                    return const Icon(Icons.star_outline, color: Color(0xFFFBBF24), size: 18);
                  }
                }),
                const SizedBox(width: 8),
                Text(
                  review.rating.toString(),
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.power, size: 16, color: Color(0xFF6750A4)),
                const SizedBox(width: 4),
                Text(
                  'Outlets: ${review.outlets}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.reviewText,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(review.createdAt),
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.reviews_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No reviews yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Places you review will appear here!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
