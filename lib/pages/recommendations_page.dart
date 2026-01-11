import 'package:flutter/material.dart';
import '../services/recommendation_service.dart';
import '../models/study_place.dart';
import 'place_details_page.dart';

class RecommendationsPage extends StatefulWidget {
  final List<StudyPlace> recommendations;
  const RecommendationsPage({super.key, required this.recommendations});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  List<StudyPlace> _recommendations = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recommendations = widget.recommendations;
    if (_recommendations.isEmpty) {
      _fetchRecommendations();
    }
  }

  Future<void> _fetchRecommendations() async {
    final RecommendationService _recommendationService = RecommendationService();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recs = await _recommendationService.getRecommendations(limit: 20);
      if (!mounted) return;
      setState(() {
        _recommendations = recs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load recommendations: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 0.5,
                  child: Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.auto_awesome,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Recommended for You'),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 1,
      ),
      body: _loading
          ? _buildLoadingState(colorScheme)
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              : _recommendations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No recommendations found.'),
                          const SizedBox(height: 12),
                          Text(
                            'If you see this often, make sure you have places in your Firestore "places" collection and that you have viewed, favorited, or reviewed some places.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _recommendations.length,
                      itemBuilder: (context, i) {
                        final place = _recommendations[i];
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + (i * 100)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutQuad,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              title: Text(
                                place.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(place.type),
                              trailing: place.rating != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        Text(place.rating!.toStringAsFixed(1)),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlaceDetailsPage(place: place),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 1000 + (index * 200)),
          tween: Tween(begin: 0.3, end: 1.0),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Container(
                height: 16,
                width: 150,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              trailing: Container(
                height: 24,
                width: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
