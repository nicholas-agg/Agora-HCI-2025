import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/study_place.dart';
import '../services/favorites_manager.dart';
import 'place_details_page.dart';
import 'menu_page.dart';

class FavoritesPage extends StatefulWidget {
  final VoidCallback? onLogout;
  const FavoritesPage({super.key, this.onLogout});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  final _favoritesManager = FavoritesManager();
  bool _initLoading = true;
  late VoidCallback _listener;

  List<StudyPlace> get _allFavorites => _favoritesManager.favorites;

  List<StudyPlace> get _filteredFavorites {
    List<StudyPlace> filtered = _allFavorites;
    if (_selectedFilter != 'All') {
      filtered = filtered.where((place) {
        final type = place.type.toLowerCase();
        if (_selectedFilter == 'Library') {
          return type.contains('library');
        } else if (_selectedFilter == 'Cafe') {
          return type.contains('cafe');
        } else if (_selectedFilter == 'Coworking') {
          return type.contains('coworking');
        }
        return true;
      }).toList();
    }
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((place) =>
        place.name.toLowerCase().contains(_searchController.text.toLowerCase())
      ).toList();
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    _favoritesManager.addListener(_listener);
    _initFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh favorites whenever the page becomes visible
    _favoritesManager.forceSync();
  }

  Future<void> _initFavorites() async {
    await _favoritesManager.initialize();
    // Force sync to get latest data from Firebase
    await _favoritesManager.forceSync();
    if (!mounted) return;
    setState(() {
      _initLoading = false;
    });
  }

  Future<Map<String, dynamic>> _getAgoraStats(String placeId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('placeId', isEqualTo: placeId)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return {'rating': 0.0, 'count': 0};
      }
      
      final ratings = snapshot.docs.map((doc) => doc.data()['rating'] as int).toList();
      final sum = ratings.fold<int>(0, (prev, rating) => prev + rating);
      return {
        'rating': sum / ratings.length,
        'count': ratings.length,
      };
    } catch (e) {
      return {'rating': 0.0, 'count': 0};
    }
  }

  @override
  void dispose() {
    _favoritesManager.removeListener(_listener);
    _searchController.dispose();
    super.dispose();
  }

  String? _getPhotoUrl(String? photoReference) {
    if (photoReference == null) return null;
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photoreference=$photoReference&key=$apiKey';
  }

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('library')) {
      return const Color(0xFFDCFCE7); // Light green
    } else if (t.contains('cafe')) {
      return const Color(0xFFDBEAFE); // Light blue
    } else if (t.contains('coworking')) {
      return const Color(0xFFF3E8FF); // Light purple
    } else {
      return const Color(0xFFF3F4F6); // Light grey
    }
  }

  Color _getTypeTextColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('library')) {
      return const Color(0xFF15803D); // Green
    } else if (t.contains('cafe')) {
      return const Color(0xFF1D4ED8); // Blue
    } else if (t.contains('coworking')) {
      return const Color(0xFF7C3AED); // Purple
    } else {
      return const Color(0xFF4B5563); // Grey
    }
  }

  String _getTypeLabel(String type) {
    final t = type.toLowerCase();
    if (t.contains('library')) {
      return 'Library';
    } else if (t.contains('cafe')) {
      return 'Cafe';
    } else if (t.contains('coworking')) {
      return 'Coworking';
    } else {
      return 'Other';
    }
  }

  IconData _getCategoryIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('cafe')) return Icons.local_cafe;
    if (t.contains('library')) return Icons.menu_book;
    if (t.contains('coworking')) return Icons.work;
    return Icons.location_on;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Favourites',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_initLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),
          // Search Bar
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search for a place to study',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: IconButton(
                  icon: Icon(Icons.menu, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    if (widget.onLogout != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MenuPage(onSignOut: widget.onLogout!),
                        ),
                      );
                    }
                  },
                ),
                suffixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),

          // Filter Chips
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', Icons.stars, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterChip('Library', Icons.menu_book, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cafe', Icons.local_cafe, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterChip('Coworking', Icons.work, colorScheme),
                ],
              ),
            ),
          ),

          // Favorites List
          Expanded(
            child: _filteredFavorites.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFavorites.length,
                    itemBuilder: (context, index) {
                      return _buildFavoriteCard(_filteredFavorites[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, ColorScheme colorScheme) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          border: Border.all(
            color: isSelected ? Colors.transparent : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
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
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding places you love!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(StudyPlace place) {
    final photoUrl = _getPhotoUrl(place.photoReference);
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlaceDetailsPage(place: place),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(place.type);
                        },
                      )
                    : _buildPlaceholderImage(place.type),
              ),
              // Favorite Heart Button
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _favoritesManager.isFavorite(place)
                        ? Icons.favorite
                        : Icons.favorite_border,
                      color: _favoritesManager.isFavorite(place)
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () async {
                      final rootContext = context;
                      final wasFavorite = _favoritesManager.isFavorite(place);
                      await _favoritesManager.toggleFavorite(place);
                      if (!mounted) return;
                      setState(() {});
                      if (!rootContext.mounted) return;
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasFavorite
                              ? '${place.name} removed from favorites'
                              : '${place.name} added to favorites'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Type Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getTypeColor(place.type),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _getTypeLabel(place.type),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _getTypeTextColor(place.type),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ratings Summary (matching homepage style)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (place.rating != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.onSurface),
                            const SizedBox(width: 4),
                            Text(
                              '${place.rating!.toStringAsFixed(1)} (Google, ${place.userRatingsTotal ?? 0} reviews)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getAgoraStats(place.placeId ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        final stats = snapshot.data;
                        if (stats == null || stats['count'] == 0) {
                          return Row(
                            children: [
                              Icon(Icons.star_border, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                'No Agora reviews yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${stats['rating'].toStringAsFixed(1)} (Agora, ${stats['count']} reviews)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    // Note: Calculate actual distance from user location
                    Text(
                      'View on map',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildPlaceholderImage(String type) {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[300],
      child: Icon(
        _getCategoryIcon(type),
        size: 80,
        color: Colors.grey,
      ),
    );
  }
}
