import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/review.dart';
import '../models/study_place.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/noise_service.dart';
import '../services/points_service.dart';

import '../services/image_service.dart';
import '../services/user_display_name_cache.dart';
import '../services/favorites_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PlaceDetailsPage extends StatefulWidget {
  final StudyPlace place;
  
  const PlaceDetailsPage({super.key, required this.place});

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}


class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  final ScrollController _scrollController = ScrollController();
  final FavoritesManager _favoritesManager = FavoritesManager();

    // For editing review
    int _editRating = 0;
    String _editOutlets = 'None';
    final TextEditingController _editReviewController = TextEditingController();
    final TextEditingController _editPriceController = TextEditingController();
    int _editWifiQuality = 0;
    int _editComfortLevel = 0;
    int _editAestheticRating = 0;
    double? _editNoiseLevel;
    List<String> _editPhotoBase64List = [];


    void _showEditReviewDialog(Review review) {
      _editRating = review.rating;
      _editOutlets = review.outlets;
      _editReviewController.text = review.reviewText;
      _editPriceController.text = review.averagePrice ?? '';
      _editWifiQuality = review.wifiQuality ?? 0;
      _editComfortLevel = review.comfortLevel ?? 0;
      _editAestheticRating = review.aestheticRating ?? 0;
      _editNoiseLevel = review.noiseLevel;
      _editPhotoBase64List = List.from(review.userPhotos ?? []);
      
      if (!mounted) return;
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
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Optional Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildEditSlider('Wi-Fi Quality', Icons.wifi, _editWifiQuality, (val) {
                        setDialogState(() => _editWifiQuality = val.round());
                      }, colorScheme),
                      const SizedBox(height: 8),
                      // Removed: Outlets star slider (now using None/Few/A lot system)
                      const SizedBox(height: 8),
                      _buildEditSlider('Comfort', Icons.chair, _editComfortLevel, (val) {
                        setDialogState(() => _editComfortLevel = val.round());
                      }, colorScheme),
                      const SizedBox(height: 8),
                      _buildEditSlider('Aesthetic', Icons.palette, _editAestheticRating, (val) {
                        setDialogState(() => _editAestheticRating = val.round());
                      }, colorScheme),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _editPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Average Price',
                          hintText: 'e.g., €5',
                          prefixIcon: Icon(Icons.euro),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_editNoiseLevel != null)
                        Text(
                          'Noise Level: ${_editNoiseLevel!.toStringAsFixed(1)} dB (${NoiseService.getNoiseCategory(_editNoiseLevel!)})',
                          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                        ),
                      if (_editPhotoBase64List.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Photos: ${_editPhotoBase64List.length}', style: const TextStyle(fontSize: 14)),
                      ],
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
                      try {
                        await _databaseService.updateReview(
                          reviewId: review.id,
                          rating: _editRating,
                          outlets: _editOutlets,
                          reviewText: _editReviewController.text.trim(),
                          wifiQuality: _editWifiQuality > 0 ? _editWifiQuality : null,
                          comfortLevel: _editComfortLevel > 0 ? _editComfortLevel : null,
                          aestheticRating: _editAestheticRating > 0 ? _editAestheticRating : null,
                          averagePrice: _editPriceController.text.trim().isNotEmpty ? _editPriceController.text.trim() : null,
                          noiseLevel: _editNoiseLevel,
                          userPhotos: _editPhotoBase64List.isNotEmpty ? _editPhotoBase64List : null,
                        );
                        if (!mounted || !context.mounted) return;
                        Navigator.of(context).pop();
                        // Refresh user review
                        _checkIfUserReviewed();
                        setState(() {
                          // Refresh averages and photos since data has changed
                          if (widget.place.placeId != null) {
                            _photosFuture = _databaseService.getPlacePhotos(widget.place.placeId!);
                            _attributeAveragesFuture = _databaseService.getPlaceAttributeAverages(widget.place.placeId!);
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Review updated!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                         if (!mounted || !context.mounted) return;
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update review: $e'), backgroundColor: Colors.red),
                        );
                      }
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

    Widget _buildEditSlider(String label, IconData icon, int value, Function(double) onChanged, ColorScheme colorScheme) {
      return Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onVerticalDragStart: (_) {},
                        child: Slider(
                          value: value.toDouble(),
                          min: 0,
                          max: 5,
                          divisions: 5,
                          label: value == 0 ? 'Not set' : '$value',
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                    Text('$value', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                try {
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
                } catch (e) {
                   if (!dialogContext.mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete review: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final NoiseService _noiseService = NoiseService();
  final ImagePicker _imagePicker = ImagePicker();
  final PointsService _pointsService = PointsService();
  
  int _selectedRating = 0;
  String _selectedOutlets = 'None'; // None, Few, A lot
  bool _submittingReview = false;
  
  // New enhanced review attributes
  int _wifiQuality = 0; // 0-5
  int _comfortLevel = 0; // 0-5
  int _aestheticRating = 0; // 0-5
  double? _measuredNoiseLevel;
  List<String> _photoBase64List = []; // Base64 encoded photos
  bool _isPickingPhoto = false;

  final bool _isMeasuringNoise = false;
  double? _lastNoiseDb;
  String? _noiseError;

  bool _checkingIn = false;
  bool _checkedIn = false;
  String? _checkInError;

  // Track if user already reviewed this place
  bool _hasReviewed = false;
  Review? _userReview;

  late Future<List<String>> _photosFuture;
  late Future<Map<String, dynamic>> _attributeAveragesFuture;
  late Stream<List<Review>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _photosFuture = widget.place.placeId != null 
        ? _databaseService.getPlacePhotos(widget.place.placeId!) 
        : Future.value([]);
    _attributeAveragesFuture = widget.place.placeId != null 
        ? _databaseService.getPlaceAttributeAverages(widget.place.placeId!) 
        : Future.value({});
    _reviewsStream = _databaseService.getPlaceReviews(widget.place.placeId ?? '');
    _checkIfUserReviewed();
    _checkIfCheckedIn();
    _favoritesManager.initialize();
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
      if (!mounted) return;
      setState(() {
        _hasReviewed = true;
        _userReview = userReview;
      });
    }
  }

  Future<void> _checkIfCheckedIn() async {
    final user = _authService.currentUser;
    final placeId = widget.place.placeId;
    if (user == null || placeId == null) return;
    final already = await _databaseService.isCheckedIn(userId: user.uid, placeId: placeId);
    if (!mounted) return;
    setState(() {
      _checkedIn = already;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _reviewController.dispose();
    _editReviewController.dispose();
    _priceController.dispose();
    _noiseService.dispose();
    super.dispose();
  }

  String? _getPhotoUrl(String? photoReference) {
    if (photoReference == null) return null;
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      return null;
    }
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoReference&key=$apiKey';
  }

  IconData _getCategoryIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('cafe')) return Icons.local_cafe;
    if (t.contains('library')) return Icons.menu_book;
    if (t.contains('coworking')) return Icons.work;
    return Icons.location_on;
  }

  Future<void> _checkIn() async {
    final user = _authService.currentUser;
    final placeId = widget.place.placeId;

    if (user == null || placeId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to check in.')),
      );
      return;
    }

    if (_checkedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already checked in here.')),
      );
      return;
    }

    // Request location permission and fetch current location
    final locPermission = await Geolocator.requestPermission();
    if (locPermission == LocationPermission.denied ||
        locPermission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _checkInError = 'Location permission is required for check-in proximity validation.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location permission to check in.')),
      );
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkInError = 'Failed to get current location.';
      });
      return;
    }

    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.place.location.latitude,
      widget.place.location.longitude,
    );

    const allowedRadiusMeters = 200.0;
    if (distanceMeters > allowedRadiusMeters) {
      if (!mounted) return;
      setState(() {
        _checkInError = 'You are too far from this place to check in.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Move closer to the place to check in.')),
      );
      return;
    }

    setState(() {
      _checkingIn = true;
      _checkInError = null;
    });

    try {
      await _databaseService.createCheckIn(
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        placeId: placeId,
        placeName: widget.place.name,
        placeLocation: widget.place.location,
        userLatitude: position.latitude,
        userLongitude: position.longitude,
        distanceMeters: distanceMeters,
        noiseDb: _lastNoiseDb,
      );

      if (!mounted) return;
      setState(() {
        _checkingIn = false;
        _checkedIn = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checked in successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingIn = false;
        _checkInError = 'Check-in failed. Please try again.';
      });
    }
  }

  // Pick and compress photo to base64 (always downsize/compress on device)
  Future<void> _pickPhoto() async {
    if (_photoBase64List.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    setState(() {
      _isPickingPhoto = true;
    });

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (photo == null) {
        setState(() {
          _isPickingPhoto = false;
        });
        return;
      }

      // Always downsize and compress on device
      String? base64String;
      try {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          photo.path,
          minWidth: 800,
          minHeight: 800,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressedBytes != null) {
          base64String = ImageService.compressBytesToBase64(compressedBytes);
        } else {
          // Fallback: just use original bytes
          final bytes = await photo.readAsBytes();
          base64String = ImageService.compressBytesToBase64(bytes);
        }
      } catch (_) {
        // Fallback: just use original bytes
        final bytes = await photo.readAsBytes();
        base64String = ImageService.compressBytesToBase64(bytes);
      }

      if (base64String == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image could not be compressed enough. Please try a different photo.')),
        );
        setState(() {
          _isPickingPhoto = false;
        });
        return;
      }

      setState(() {
        _photoBase64List.add(base64String!);
        _isPickingPhoto = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo added (${ImageService.estimateSizeKB(base64String).toStringAsFixed(0)} KB)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPickingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photo: $e')),
      );
    }
  }

  // Measure noise level using existing NoiseService
  Future<void> _measureNoiseLevel() async {
    // Check microphone permission first
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to measure noise level.')),
      );
      return;
    }

    try {
      if (!mounted) return;
      
      // Show dialog with countdown
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Measuring Noise'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Recording for 10 seconds...'),
                const SizedBox(height: 8),
                Text(
                  'Keep your phone still',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      );

      // Measure average noise level over 10 seconds
      final noiseLevel = await _noiseService.measureAverage(
        duration: const Duration(seconds: 10),
      );
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close dialog
      
      if (noiseLevel != null) {
        setState(() {
          _measuredNoiseLevel = noiseLevel;
        });
        
        final category = NoiseService.getNoiseCategory(noiseLevel);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Noise measured: ${noiseLevel.toStringAsFixed(1)} dB ($category)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to measure noise. No readings captured.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close dialog if open
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error measuring noise: $e')),
      );
    }
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
      // Check if all detailed attributes are filled
        final hasAllAttributes = _wifiQuality > 0 &&
          _comfortLevel > 0 &&
          _aestheticRating > 0 &&
          _priceController.text.trim().isNotEmpty;

      await _databaseService.createReview(
        userId: user.uid,
        placeId: widget.place.placeId ?? '',
        placeName: widget.place.name,
        rating: _selectedRating,
        outlets: _selectedOutlets,
        reviewText: _reviewController.text.trim(),
        wifiQuality: _wifiQuality > 0 ? _wifiQuality : null,
        averagePrice: _priceController.text.trim().isNotEmpty ? _priceController.text.trim() : null,
        noiseLevel: _measuredNoiseLevel,
        comfortLevel: _comfortLevel > 0 ? _comfortLevel : null,
        aestheticRating: _aestheticRating > 0 ? _aestheticRating : null,
        userPhotos: _photoBase64List.isNotEmpty ? _photoBase64List : null,
      );

      // Award points for the review
      await _pointsService.awardPointsForReview(
        userId: user.uid,
        hasPhotos: _photoBase64List.isNotEmpty,
        hasNoiseMeasurement: _measuredNoiseLevel != null,
        hasAllAttributes: hasAllAttributes,
      );

      if (!mounted) return;
      
      // Clear the form
      _reviewController.clear();
      _priceController.clear();
      setState(() {
        _selectedRating = 0;
        _selectedOutlets = 'None';
        _wifiQuality = 0;
        _comfortLevel = 0;
        _aestheticRating = 0;
        _measuredNoiseLevel = null;
        _photoBase64List = [];
        _submittingReview = false;
        
        // Refresh averages and photos since data has changed
        if (widget.place.placeId != null) {
          _photosFuture = _databaseService.getPlacePhotos(widget.place.placeId!);
          _attributeAveragesFuture = _databaseService.getPlaceAttributeAverages(widget.place.placeId!);
        }
      });

      // Calculate points earned
      int pointsEarned = 10; // Base points
      if (_photoBase64List.isNotEmpty) pointsEarned += 5;
      if (_measuredNoiseLevel != null) pointsEarned += 15;
      if (hasAllAttributes) pointsEarned += 20;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted! +$pointsEarned points earned'),
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
    final isFavorite = _favoritesManager.isFavorite(widget.place);
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
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () async {
              final messengerContext = context;
              await _favoritesManager.toggleFavorite(widget.place);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(messengerContext).showSnackBar(
                SnackBar(
                  content: Text(isFavorite ? 'Removed from favorites' : 'Added to favorites'),
                  backgroundColor: isFavorite ? Colors.red : Colors.green,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'View on Map',
            onPressed: _openMap,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place Photo
              if (_getPhotoUrl(widget.place.photoReference) != null)
                Hero(
                  tag: 'place-image-${widget.place.placeId}',
                  child: ClipRRect(
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
                  ),
                )
              else
                Hero(
                  tag: 'place-image-${widget.place.placeId}',
                  child: Container(
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
                ),
              
              const SizedBox(height: 24),

              // User Photos Gallery (if available)
              if (widget.place.placeId != null)
                FutureBuilder<List<String>>(
                  future: _photosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final photos = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Photos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, index) {
                              final imageBytes = ImageService.decodeBase64(photos[index]);
                              if (imageBytes == null) return const SizedBox.shrink();
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    // Show full-screen image viewer with gallery
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.black,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Align(
                                              alignment: Alignment.topRight,
                                              child: IconButton(
                                                icon: Icon(Icons.close, color: Colors.white),
                                                onPressed: () => Navigator.of(context).pop(),
                                              ),
                                            ),
                                            Expanded(
                                              child: PageView.builder(
                                                controller: PageController(initialPage: index),
                                                itemCount: photos.length,
                                                itemBuilder: (context, pageIndex) {
                                                  final bytes = ImageService.decodeBase64(photos[pageIndex]);
                                                  if (bytes == null) return const SizedBox.shrink();
                                                  return InteractiveViewer(
                                                    child: Center(
                                                      child: Image.memory(
                                                        bytes,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Text(
                                                '${index + 1} / ${photos.length}',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      imageBytes,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

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
                    stream: _reviewsStream,
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
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.identity()
                              ..scale(index < _selectedRating ? 1.1 : 1.0),
                            child: Icon(
                              index < _selectedRating ? Icons.star : Icons.star_border,
                              size: 40,
                              color: colorScheme.primary,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Place Attributes Section (if data exists)
              if (widget.place.placeId != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: _attributeAveragesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    final attrs = snapshot.data;
                    if (attrs == null || attrs.isEmpty || attrs.values.every((v) => v == null)) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Place Details',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                if (attrs['wifiQuality'] != null)
                                  _buildAttributeRow(
                                    Icons.wifi,
                                    'Wi-Fi Quality',
                                    attrs['wifiQuality'],
                                    colorScheme,
                                  ),
                                if (attrs['comfortLevel'] != null)
                                  _buildAttributeRow(
                                    Icons.chair,
                                    'Comfort',
                                    attrs['comfortLevel'],
                                    colorScheme,
                                  ),
                                if (attrs['aestheticRating'] != null)
                                  _buildAttributeRow(
                                    Icons.palette,
                                    'Aesthetic',
                                    attrs['aestheticRating'],
                                    colorScheme,
                                  ),
                                if (attrs['noiseLevel'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          duration: const Duration(seconds: 1),
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          builder: (context, value, child) {
                                            return Icon(
                                              Icons.volume_up,
                                              color: colorScheme.primary.withValues(alpha: value),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Noise Level',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${attrs['noiseLevel'].toStringAsFixed(1)} dB',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (attrs['averagePrice'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.euro, color: colorScheme.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Average Price',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          attrs['averagePrice'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),

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

                // Check-in card
                Card(
                  elevation: 2,
                  color: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check in',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 500),
                              tween: Tween(begin: 1.0, end: _checkedIn ? 1.2 : 1.0),
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: CircleAvatar(
                                    backgroundColor: _checkedIn ? Colors.green : colorScheme.primaryContainer,
                                    child: Icon(
                                      _checkedIn ? Icons.check : Icons.place,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _checkedIn ? 'You are checked in here' : 'Not checked in yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    _checkedIn
                                        ? 'Great! Others can see your presence.'
                                        : 'Tap to check in for your study session.',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (_checkingIn)
                              const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        if (_checkInError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _checkInError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: (_checkingIn || _checkedIn) ? null : _checkIn,
                            icon: const Icon(Icons.login),
                            label: Text(
                              _checkedIn
                                  ? 'Checked in'
                                  : _checkingIn
                                      ? 'Checking in...'
                                      : 'Check in here',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6750A4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Noise measurement card
                Card(
                  elevation: 2,
                  color: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Noise level (dB)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_isMeasuringNoise)
                              _buildSoundWave(colorScheme)
                            else
                              CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: const Icon(Icons.volume_up, color: Colors.white),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lastNoiseDb != null
                                        ? '${_lastNoiseDb!.toStringAsFixed(1)} dB'
                                        : '-- dB',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    _isMeasuringNoise
                                        ? (NoiseService.getNoiseCategory(_lastNoiseDb ?? 0))
                                        : 'Tap to capture a snapshot',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_noiseError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _noiseError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: _measureNoiseLevel,
                            icon: const Icon(Icons.hearing),
                            label: Text(
                              _measuredNoiseLevel != null 
                                  ? 'Measured: ${_measuredNoiseLevel!.toStringAsFixed(1)} dB'
                                  : 'Measure noise',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6750A4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Enhanced Review Attributes
                Text(
                  'Optional Details (earn more points!)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // Wi-Fi Quality Slider
                _buildSliderCard(
                  'Wi-Fi Quality',
                  Icons.wifi,
                  _wifiQuality,
                  (value) => setState(() => _wifiQuality = value.round()),
                  colorScheme,
                ),
                const SizedBox(height: 12),

                // Comfort Level Slider
                _buildSliderCard(
                  'Comfort Level',
                  Icons.chair,
                  _comfortLevel,
                  (value) => setState(() => _comfortLevel = value.round()),
                  colorScheme,
                ),
                const SizedBox(height: 12),

                // Aesthetic Rating Slider
                _buildSliderCard(
                  'Aesthetic Rating',
                  Icons.palette,
                  _aestheticRating,
                  (value) => setState(() => _aestheticRating = value.round()),
                  colorScheme,
                ),
                const SizedBox(height: 12),

                // Average Price Input
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.euro, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              labelText: 'Average Price (e.g., €5-10)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Photo Upload Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.photo_library, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Photos (${_photoBase64List.length}/3)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: (_photoBase64List.length >= 3 || _isPickingPhoto) ? null : _pickPhoto,
                              icon: _isPickingPhoto 
                                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(Icons.add_photo_alternate, size: 18),
                              label: Text(_isPickingPhoto ? 'Loading...' : 'Add'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        if (_photoBase64List.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _photoBase64List.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          ImageService.decodeBase64(_photoBase64List[index])!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _photoBase64List.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
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
                  stream: _reviewsStream,
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
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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

  Future<void> _openMap() async {
    final placeId = widget.place.placeId;
    final name = Uri.encodeComponent(widget.place.name);
    String url;
    if (placeId != null && placeId.isNotEmpty) {
      // Use Google Maps Place ID search
      url = 'https://www.google.com/maps/search/?api=1&query=Google&query_place_id=$placeId';
    } else {
      // Fallback to coordinates
      final lat = widget.place.location.latitude;
      final lng = widget.place.location.longitude;
      url = 'https://www.google.com/maps/search/?api=1&query=$name&query=$lat,$lng';
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map.')),
      );
    }
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
            review.userId != null
                ? FutureBuilder<String>(
                    future: UserDisplayNameCache().getDisplayName(review.userId!),
                    builder: (context, snapshot) {
                      final displayName = snapshot.data ?? '...';
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
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
                                  displayName,
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
                      );
                    },
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          (review.displayName != null && review.displayName!.isNotEmpty)
                              ? review.displayName![0].toUpperCase()
                              : '?',
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
                              review.displayName ?? 'Anonymous',
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

            // Display enhanced attributes if available
            if (review.wifiQuality != null || review.comfortLevel != null || review.aestheticRating != null || review.noiseLevel != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (review.wifiQuality != null)
                      _buildAttributeChip(Icons.wifi, 'Wi-Fi ${review.wifiQuality}/5', colorScheme),
                    if (review.comfortLevel != null)
                      _buildAttributeChip(Icons.chair, 'Comfort ${review.comfortLevel}/5', colorScheme),
                    if (review.aestheticRating != null)
                      _buildAttributeChip(Icons.palette, 'Aesthetic ${review.aestheticRating}/5', colorScheme),
                    if (review.noiseLevel != null)
                      _buildAttributeChip(Icons.volume_up, '${review.noiseLevel!.toStringAsFixed(1)} dB', colorScheme),
                    if (review.averagePrice != null)
                      _buildAttributeChip(Icons.euro, review.averagePrice!, colorScheme),
                  ],
                ),
              ),

            // Display user photos if available
            if (review.userPhotos != null && review.userPhotos!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: review.userPhotos!.length,
                        itemBuilder: (context, index) {
                          final base64Photo = review.userPhotos![index];
                          final imageBytes = ImageService.decodeBase64(base64Photo);
                          if (imageBytes == null) return const SizedBox.shrink();
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                // Show full-screen image
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    backgroundColor: Colors.black,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: IconButton(
                                            icon: Icon(Icons.close, color: Colors.white),
                                            onPressed: () => Navigator.of(context).pop(),
                                          ),
                                        ),
                                        InteractiveViewer(
                                          child: Image.memory(
                                            imageBytes,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  imageBytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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

  Widget _buildAttributeRow(IconData icon, String label, double value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (value > 0)
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < value.round() ? Icons.star : Icons.star_border,
                  size: 18,
                  color: colorScheme.primary,
                );
              }),
            )
          else
            Text(
              'No data',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttributeChip(IconData icon, String label, ColorScheme colorScheme) {
    return Chip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(
        label,
        style: TextStyle(fontSize: 12),
      ),
      backgroundColor: colorScheme.primaryContainer.withAlpha(100),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSliderCard(String label, IconData icon, int value, Function(double) onChanged, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (value > 0)
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < value ? Icons.star : Icons.star_border,
                        size: 18,
                        color: colorScheme.primary,
                      );
                    }),
                  ),
              ],
            ),
            GestureDetector(
              onVerticalDragStart: (_) {},
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                label: value == 0 ? 'Not rated' : value.toString(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundWave(ColorScheme colorScheme) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) => _AnimatedBar(index: index, colorScheme: colorScheme)),
      ),
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  final int index;
  final ColorScheme colorScheme;
  const _AnimatedBar({required this.index, required this.colorScheme});

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index * 150)),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 4,
          height: 30 * _animation.value,
          decoration: BoxDecoration(
            color: widget.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
