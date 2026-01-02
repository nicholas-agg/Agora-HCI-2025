import 'package:flutter/material.dart';
import '../models/study_place.dart';
import '../models/review.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlaceDetailsPage extends StatefulWidget {
  final StudyPlace place;
  
  const PlaceDetailsPage({super.key, required this.place});

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  final TextEditingController _reviewController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  int _selectedRating = 0;
  String _selectedOutlets = 'None'; // None, Few, A lot
  bool _submittingReview = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String? _getPhotoUrl(String? photoReference) {
    if (photoReference == null) return null;
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoReference&key=$apiKey';
  }

  void _measureNoise() {
    // TODO: Implement noise measurement functionality
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Noise measurement feature coming soon')),
    );
  }

  Future<void> _submitReview() async {
    final user = _authService.currentUser;
    
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a review')),
      );
      return;
    }

    if (_selectedRating == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    if (_reviewController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review')),
      );
      return;
    }

    setState(() {
      _submittingReview = true;
    });

    try {
      await _databaseService.createReview(
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Anonymous',
        placeId: widget.place.placeId ?? '',
        placeName: widget.place.name,
        rating: _selectedRating,
        outlets: _selectedOutlets,
        reviewText: _reviewController.text.trim(),
      );

      if (!mounted) return;
      
      // Clear the form
      _reviewController.clear();
      setState(() {
        _selectedRating = 0;
        _selectedOutlets = 'None';
        _submittingReview = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingReview = false;
      });
      
      String errorMessage = 'Failed to submit review';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Access denied. Please sign in again.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('An error occurred')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Agora',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place Photo
              if (_getPhotoUrl(widget.place.photoReference) != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.network(
                    _getPhotoUrl(widget.place.photoReference)!,
                    height: 253,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 253,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE6F0),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 60),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 253,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE6F0),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Icon(
                      widget.place.type.toLowerCase().contains('cafe')
                          ? Icons.local_cafe
                          : widget.place.type.toLowerCase().contains('library')
                              ? Icons.menu_book
                              : Icons.work,
                      size: 60,
                      color: const Color(0xFF6750A4),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Rating Section
              Text(
                'Rating',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        _selectedRating = index + 1;
                      });
                    },
                    child: Icon(
                      index < _selectedRating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 32),
              
              // Review Section
              Text(
                'Your Review',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _reviewController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your review about this place',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(8),
                      hintStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Measure Noise Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: _measureNoise,
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                  label: const Text(
                    'Measure noise',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Power Outlets Section
              Center(
                child: Text(
                  'Power outlets',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildOutletButton('None'),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildOutletButton('Few'),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildOutletButton('A lot'),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submittingReview ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: _submittingReview
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // All Reviews Section
              if (widget.place.placeId != null) ...[
                Text(
                  'Reviews',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Review>>(
                  stream: _databaseService.getPlaceReviews(widget.place.placeId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'Error loading reviews',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      );
                    }
                    
                    final reviews = snapshot.data ?? [];
                    
                    if (reviews.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No reviews yet. Be the first to review!',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        return _buildReviewCard(reviews[index]);
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutletButton(String label) {
    final isSelected = _selectedOutlets == label;
    final isFirst = label == 'None';
    final isLast = label == 'A lot';
    
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedOutlets = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF625B71) : const Color(0xFFE8DEF8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 100 : 8),
            bottomLeft: Radius.circular(isFirst ? 100 : 8),
            topRight: Radius.circular(isLast ? 28 : 8),
            bottomRight: Radius.circular(isLast ? 28 : 8),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.power,
                size: 24,
                color: isSelected ? Colors.white : const Color(0xFF4A4459),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF4A4459),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: User name and date
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    review.userName[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _formatDate(review.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Rating stars
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  size: 20,
                  color: const Color(0xFFFBBF24),
                );
              }),
            ),
            const SizedBox(height: 8),
            
            // Outlets info
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
            const SizedBox(height: 12),
            
            // Review text
            Text(
              review.reviewText,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
