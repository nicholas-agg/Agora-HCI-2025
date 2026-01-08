import 'dart:async';
import 'package:noise_meter/noise_meter.dart';

/// Provides a 10-second noise snapshot and calculates the average decibel level.
class NoiseService {
  NoiseService({NoiseMeter? meter}) : _noiseMeter = meter ?? NoiseMeter();

  final NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _subscription;

  /// Exposes the noise stream for live readings (for UI feedback)
  Stream<NoiseReading> get noiseStream => _noiseMeter.noise;

  Future<double?> measureAverage({Duration duration = const Duration(seconds: 10)}) async {
    await _subscription?.cancel();
    _subscription = null;

    final completer = Completer<double?>();
    final readings = <double>[];
    Timer? timer;

    try {
      _subscription = _noiseMeter.noise.listen(
        (reading) {
          readings.add(reading.meanDecibel);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
        cancelOnError: true,
      );

      timer = Timer(duration, () async {
        await _subscription?.cancel();
        _subscription = null;
        if (!completer.isCompleted) {
          if (readings.isNotEmpty) {
            final average = readings.reduce((a, b) => a + b) / readings.length;
            completer.complete(average);
          } else {
            completer.complete(null);
          }
        }
      });

      return await completer.future;
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
      timer?.cancel();
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  // Get noise level category
  static String getNoiseCategory(double decibels) {
    if (decibels < 40) return 'Very Quiet';
    if (decibels < 50) return 'Quiet';
    if (decibels < 60) return 'Moderate';
    if (decibels < 70) return 'Noisy';
    return 'Very Noisy';
  }

  // Get color for noise level
  static String getNoiseCategoryColor(double decibels) {
    if (decibels < 40) return '#4CAF50'; // Green
    if (decibels < 50) return '#8BC34A'; // Light Green
    if (decibels < 60) return '#FFC107'; // Amber
    if (decibels < 70) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }
}
