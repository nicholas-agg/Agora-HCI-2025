import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/study_place.dart';
import '../services/favorites_manager.dart';
import 'place_details_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

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
        if (_selectedFilter == 'Libraries') {
          return type.contains('library');
        } else if (_selectedFilter == 'Cafeterias') {
          return type.contains('cafe') || type.contains('cafeteria');
        } else if (_selectedFilter == 'CoWorking') {
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

  Future<void> _initFavorites() async {
    await _favoritesManager.initialize();
    // Force sync to get latest data from Firebase
    await _favoritesManager.forceSync();
    if (!mounted) return;
    setState(() {
      _initLoading = false;
    });
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
    if (type.toLowerCase().contains('library')) {
      return const Color(0xFFDCFCE7); // Light green
    } else if (type.toLowerCase().contains('cafe') || type.toLowerCase().contains('cafeteria')) {
      return const Color(0xFFDBEAFE); // Light blue
    } else {
      return const Color(0xFFF3E8FF); // Light purple (coworking)
    }
  }

  Color _getTypeTextColor(String type) {
    if (type.toLowerCase().contains('library')) {
      return const Color(0xFF15803D); // Green
    } else if (type.toLowerCase().contains('cafe') || type.toLowerCase().contains('cafeteria')) {
      return const Color(0xFF1D4ED8); // Blue
    } else {
      return const Color(0xFF7C3AED); // Purple (coworking)
    }
  }

  String _getTypeLabel(String type) {
    if (type.toLowerCase().contains('library')) {
      return 'Library';
    } else if (type.toLowerCase().contains('cafe') || type.toLowerCase().contains('cafeteria')) {
      return 'Cafeteria';
    } else {
      return 'Coworking';
    }
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
                prefixIcon: Icon(Icons.menu, color: colorScheme.onSurfaceVariant),
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
                  _buildFilterChip('Libraries', Icons.menu_book, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cafeterias', Icons.local_cafe, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterChip('CoWorking', Icons.business_center, colorScheme),
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
                          return _buildPlaceholderImage();
                        },
                      )
                    : _buildPlaceholderImage(),
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

                // Rating
                if (place.rating != null)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        if (index < (place.rating ?? 0).floor()) {
                          return const Icon(Icons.star, color: Color(0xFFFBBF24), size: 20);
                        } else if (index < (place.rating ?? 0) && (place.rating ?? 0) % 1 != 0) {
                          return const Icon(Icons.star_half, color: Color(0xFFFBBF24), size: 20);
                        } else {
                          return const Icon(Icons.star_outline, color: Color(0xFFFBBF24), size: 20);
                        }
                      }),
                      const SizedBox(width: 8),
                      Text(
                        place.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (place.userRatingsTotal != null)
                        Text(
                          ' (${place.userRatingsTotal})',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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

  Widget _buildPlaceholderImage() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Icon(
        Icons.image,
        size: 80,
        color: Colors.grey,
      ),
    );
  }
}
