import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/study_place.dart';
import '../services/favorites_manager.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  final _favoritesManager = FavoritesManager();
  
  List<StudyPlace> get _allFavorites => _favoritesManager.favorites;

  List<StudyPlace> get _filteredFavorites {
    List<StudyPlace> filtered = _allFavorites;
    
    if (_selectedFilter != 'All') {
      filtered = filtered.where((place) {
        if (_selectedFilter == 'Libraries') {
          return place.type.toLowerCase().contains('library');
        } else if (_selectedFilter == 'Cafeterias') {
          return place.type.toLowerCase().contains('cafe') || 
                 place.type.toLowerCase().contains('cafeteria');
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
  void dispose() {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Favourites',
          style: TextStyle(
            color: Color(0xFF1D1B20),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search for a place to study',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.menu, color: Color(0xFF6B7280)),
                suffixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
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
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                _buildFilterChip('All', Icons.stars),
                const SizedBox(width: 8),
                _buildFilterChip('Libraries', Icons.menu_book),
                const SizedBox(width: 8),
                _buildFilterChip('Cafeterias', Icons.local_cafe),
              ],
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

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6750A4) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFCAC4D0),
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF49454F),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF49454F),
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
    
    return Card(
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
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _favoritesManager.removeFavorite(place);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${place.name} removed from favorites'),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      if (place.userRatingsTotal != null)
                        Text(
                          ' (${place.userRatingsTotal})',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    // TODO: Calculate actual distance from user location
                    const Text(
                      'View on map',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
