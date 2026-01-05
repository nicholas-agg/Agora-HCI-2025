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

    // For editing review
    int _editRating = 0;
    String _editOutlets = 'None';
    final TextEditingController _editReviewController = TextEditingController();


    void _showEditReviewDialog(Review review) {
      _editRating = review.rating;
      _editOutlets = review.outlets;
      _editReviewController.text = review.reviewText;
      showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final colorScheme = Theme.of(context).colorScheme;
              return AlertDialog(
                title: const Text('Edit Review'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rating'),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < _editRating ? Icons.star : Icons.star_border,
                                color: colorScheme.primary,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  _editRating = index + 1;
                                });
                              },
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Power outlets'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: _editOutlets == 'None',
                            onSelected: (_) {
                              setDialogState(() {
                                _editOutlets = 'None';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Few'),
                            selected: _editOutlets == 'Few',
                            onSelected: (_) {
                              setDialogState(() {
                                _editOutlets = 'Few';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('A lot'),
                            selected: _editOutlets == 'A lot',
                            onSelected: (_) {
                              setDialogState(() {
                                _editOutlets = 'A lot';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _editReviewController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Edit your review',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _databaseService.updateReview(
                        reviewId: review.id,
                        rating: _editRating,
                        outlets: _editOutlets,
                        reviewText: _editReviewController.text.trim(),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      // Refresh user review
                      _checkIfUserReviewed();
                      setState(() {});
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review updated!'), backgroundColor: Colors.green),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    void _confirmDeleteReview(Review review) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Review'),
          content: const Text('Are you sure you want to delete your review?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _databaseService.deleteReview(review.id);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                setState(() {
                  _hasReviewed = false;
                  _userReview = null;
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review deleted'), backgroundColor: Colors.red),
                );
              },
            ),
          ],
        ),
      );
    }
  final TextEditingController _reviewController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  int _selectedRating = 0;
  String _selectedOutlets = 'None'; // None, Few, A lot
  bool _submittingReview = false;

  // Track if user already reviewed this place
  bool _hasReviewed = false;
  Review? _userReview;

  @override
  void initState() {
    super.initState();
    _checkIfUserReviewed();
  }

  Future<void> _checkIfUserReviewed() async {
    final user = _authService.currentUser;
    final placeId = widget.place.placeId;
    if (user == null || placeId == null) return;
    final query = await _databaseService
        .getPlaceReviews(placeId)
        .first;
    Review? userReview;
    try {
      userReview = query.firstWhere((review) => review.userId == user.uid);
    } catch (e) {
      userReview = null;
    }
    if (userReview != null) {
      setState(() {
        _hasReviewed = true;
        _userReview = userReview;
      });
    }
  }

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

  IconData _getCategoryIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('cafe')) return Icons.local_cafe;
    if (t.contains('library')) return Icons.menu_book;
    if (t.contains('coworking')) return Icons.work;
    return Icons.location_on;
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getCategoryIcon(widget.place.type), color: colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.place.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                  fontSize: 22,
                ),
              ),
            ),
          ],
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
                      _getCategoryIcon(widget.place.type),
                      size: 60,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),

              // Ratings Summary (matching homepage card style)
              Column(
                children: [
                  if (widget.place.rating != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 18, color: colorScheme.onSurface),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.place.rating!.toStringAsFixed(1)} (Google, ${widget.place.userRatingsTotal ?? 0} reviews)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  StreamBuilder<List<Review>>(
                    stream: _databaseService.getPlaceReviews(widget.place.placeId ?? ''),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      final reviews = snapshot.data ?? [];
                      if (reviews.isEmpty) {
                        return Row(
                          children: [
                            Icon(Icons.star_border, size: 18, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              'No Agora reviews yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        );
                      }
                      final avg = reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;
                      return Row(
                        children: [
                          Icon(Icons.star, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${avg.toStringAsFixed(1)} (Agora, ${reviews.length} reviews)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),
              
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
              if (_hasReviewed && _userReview != null) ...[
                Card(
                  elevation: 2,
                  color: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'You have already reviewed this place.',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit',
                                  onPressed: () => _showEditReviewDialog(_userReview!),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDeleteReview(_userReview!),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your review:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_userReview!.reviewText),
                      ],
                    ),
                  ),
                ),
              ] else ...[
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
              ],
              
              // Power Outlets Section
              if (!_hasReviewed) ...[
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
              ],
              
              // Submit Button
              if (!_hasReviewed) ...[
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
              ],
              
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

                    // Calculate summary
                    final totalReviews = reviews.length;
                    final averageRating = reviews.fold<double>(0, (sum, r) => sum + r.rating) / totalReviews;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card
                        Card(
                          elevation: 0,
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      averageRating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < averageRating.round() ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: const Color(0xFFFBBF24),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalReviews reviews',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Agora Community Summary',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Based on feedback from local students and researchers in Athens.',
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
                          ),
                        ),
                        const SizedBox(height: 24),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            return _buildReviewCard(reviews[index]);
                          },
                        ),
                      ],
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
