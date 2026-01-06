import 'dart:async';

import 'package:noise_meter/noise_meter.dart';

/// Provides a single-shot noise reading in decibels.
class NoiseService {
  NoiseService({NoiseMeter? meter}) : _noiseMeter = meter ?? NoiseMeter();

  final NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _subscription;

  Future<double?> measureOnce({Duration timeout = const Duration(seconds: 2)}) async {
    await _subscription?.cancel();
    _subscription = null;

    final completer = Completer<double?>();

    try {
      _subscription = _noiseMeter.noise.listen(
        (reading) {
          if (!completer.isCompleted) {
            completer.complete(reading.meanDecibel);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
        cancelOnError: true,
      );

      final value = await completer.future.timeout(timeout, onTimeout: () => null);
      await _subscription?.cancel();
      _subscription = null;
      return value;
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
