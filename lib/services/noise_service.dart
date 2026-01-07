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
}
