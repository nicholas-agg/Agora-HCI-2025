import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';

import '../models/review.dart';
import '../models/study_place.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/noise_service.dart';
import '../services/storage_service.dart';

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
                        );
                        if (!mounted || !context.mounted) return;
                        Navigator.of(context).pop();
                        // Refresh user review
                        _checkIfUserReviewed();
                        setState(() {});
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
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final NoiseService _noiseService = NoiseService();
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  int _selectedRating = 0;
  String _selectedOutlets = 'None'; // None, Few, A lot
  bool _submittingReview = false;

  bool _isMeasuringNoise = false;
  double? _lastNoiseDb;
  String? _noiseError;

  XFile? _capturedPhoto;
  bool _pickingPhoto = false;
  String? _photoError;

  bool _checkingIn = false;
  bool _checkedIn = false;
  String? _checkInError;

  // Track if user already reviewed this place
  bool _hasReviewed = false;
  Review? _userReview;

  @override
  void initState() {
    super.initState();
    _checkIfUserReviewed();
    _checkIfCheckedIn();
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
    _reviewController.dispose();
    _editReviewController.dispose();
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

  Future<void> _measureNoise() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      setState(() {
        _noiseError = 'Microphone permission is required.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_noiseError!)),
      );
      return;
    }

    setState(() {
      _noiseError = null;
    });

    double? liveDb;
    int secondsLeft = 10;
    bool finished = false;
    List<double> readings = [];
    StreamSubscription<NoiseReading>? sub;
    Timer? timer;

    if (!mounted || !context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start measurement on first build
            if (sub == null) {
              sub = _noiseService.noiseStream.listen(
                (reading) {
                  readings.add(reading.meanDecibel);
                  setDialogState(() {
                    liveDb = reading.meanDecibel;
                  });
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!finished) {
                    finished = true;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (mounted) {
                      setState(() {
                        _noiseError = 'Noise measurement failed.';
                      });
                    }
                  }
                },
                cancelOnError: true,
              );
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (secondsLeft > 1) {
                  setDialogState(() {
                    secondsLeft--;
                  });
                } else {
                  t.cancel();
                  finished = true;
                  sub?.cancel();
                  sub = null;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              });
            }
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: const Text('Measuring Noise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ambient sound level'),
                  const SizedBox(height: 12),
                  // Animated decibel value
                  Text(
                    liveDb != null ? '${liveDb!.toStringAsFixed(1)} dB' : '-- dB',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: liveDb != null ? (liveDb!.clamp(30, 100) - 30) / 70 : 0,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('Time remaining: $secondsLeft s', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Please stay quiet during measurement.', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    finished = true;
                    timer?.cancel();
                    sub?.cancel();
                    sub = null;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    timer?.cancel();
    await sub?.cancel();
    sub = null;
    double? averageNoise;
    if (readings.isNotEmpty) {
      averageNoise = readings.reduce((a, b) => a + b) / readings.length;
    }
    if (!mounted) return;
    setState(() {
      _lastNoiseDb = averageNoise;
      _isMeasuringNoise = false;
    });
    if (averageNoise != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Average noise level: ${averageNoise.toStringAsFixed(1)} dB')),
        );
      }
    } else if (_noiseError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_noiseError!)),
        );
      }
    }
  }

  Future<void> _capturePlacePhoto() async {
    // Ask camera permission before launching picker
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      setState(() {
        _photoError = 'Camera permission is required.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable camera permission to take a photo.')),
      );
      return;
    }

    setState(() {
      _pickingPhoto = true;
      _photoError = null;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (!mounted) return;
      setState(() {
        _pickingPhoto = false;
        if (picked != null) {
          _capturedPhoto = picked;
        } else {
          _photoError = 'No photo captured. Try again.';
        }
      });
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() {
        _pickingPhoto = false;
        _photoError = 'Camera permission is required.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable camera permission to take a photo.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickingPhoto = false;
        _photoError = 'Failed to capture photo. Please try again.';
      });
    }
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

    String? photoUrl;
    try {
      if (_capturedPhoto != null) {
        photoUrl = await _storageService.uploadPlacePhoto(
          file: _capturedPhoto!,
          userId: user.uid,
          placeId: placeId,
        );
      }

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
        photoUrl: photoUrl,
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
                // Place photo capture card
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
                          'Place photo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_capturedPhoto != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_capturedPhoto!.path),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: const Center(
                              child: Text('No photo yet'),
                            ),
                          ),
                        if (_photoError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _photoError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: _pickingPhoto ? null : _capturePlacePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: Text(
                              _pickingPhoto ? 'Opening camera...' : 'Take photo',
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
                            CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: const Icon(Icons.place, color: Colors.white),
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
                                        ? 'Measuring...'
                                        : 'Tap to capture a snapshot',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isMeasuringNoise)
                              const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                            onPressed: _isMeasuringNoise ? null : _measureNoise,
                            icon: const Icon(Icons.hearing),
                            label: Text(
                              _isMeasuringNoise ? 'Measuring...' : 'Measure noise',
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
