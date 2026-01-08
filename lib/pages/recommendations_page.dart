import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/recommendation_service.dart';
import '../models/study_place.dart';
import 'place_details_page.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  final RecommendationService _recommendationService = RecommendationService();
  List<StudyPlace> _recommendations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'You must be signed in to get recommendations.';
      });
      return;
    }
    try {
      final recs = await _recommendationService.getRecommendations(
        user.uid,
        limit: 20,
      );
      setState(() {
        _recommendations = recs;
        _loading = false;
      });
    } catch (e) {
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
          ? const Center(child: CircularProgressIndicator())
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
                        return Card(
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
                        );
                      },
                    ),
    );
  }
}
