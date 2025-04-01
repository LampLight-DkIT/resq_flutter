import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetectionService {
  static final ShakeDetectionService _instance =
      ShakeDetectionService._internal();
  factory ShakeDetectionService() => _instance;
  ShakeDetectionService._internal();

  Function()? _onShakeCallback;
  DateTime? _lastShakeTime;
  static const _minTimeBetweenShakes = Duration(milliseconds: 1000);
  static double _shakeThreshold =
      5000.0; // Very high threshold for extremely hard shakes
  StreamSubscription? _accelerometerSubscription;
  List<double> _accelerometerValues = [0, 0, 0];
  int _shakeCount = 0;
  DateTime? _firstShakeTime;
  static const _minShakeInterval = Duration(milliseconds: 100); // Minimum time between shake counts
  DateTime? _lastShakeCheck;

  void setSensitivity(double threshold) {
    _shakeThreshold = threshold;
    print('Shake sensitivity set to: $_shakeThreshold');
    // Restart the detector with new sensitivity
    dispose();
    initialize(onShake: _onShakeCallback);
  }

  void initialize({Function()? onShake}) {
    print('Initializing shake detection service...');
    _onShakeCallback = onShake;

    // Start listening to accelerometer
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _accelerometerValues = [event.x, event.y, event.z];

      // Calculate total acceleration
      double totalAcceleration =
          _accelerometerValues.map((x) => x * x).reduce((a, b) => a + b);

      // Check if acceleration exceeds threshold
      if (totalAcceleration > _shakeThreshold) {
        final now = DateTime.now();
        
        // Only count as shake if enough time has passed since last check
        if (_lastShakeCheck == null || 
            now.difference(_lastShakeCheck!) > _minShakeInterval) {
          _lastShakeCheck = now;
          
          // Reset shake count if too much time has passed
          if (_firstShakeTime != null && 
              now.difference(_firstShakeTime!) > Duration(seconds: 2)) {
            _shakeCount = 0;
            _firstShakeTime = null;
          }

          // Record first shake time if this is the first shake
          if (_shakeCount == 0) {
            _firstShakeTime = now;
          }

          _shakeCount++;
          print(
              'Shake detected! Count: $_shakeCount, Force: $totalAcceleration');

          // Check if we've reached the required number of shakes
          if (_shakeCount >= 1) {
            // Only need 1 very hard shake
            if (_lastShakeTime == null ||
                now.difference(_lastShakeTime!) > _minTimeBetweenShakes) {
              print('Shake detected! 🎯');
              _lastShakeTime = now;
              _onShakeCallback?.call();
              // Reset shake count after successful trigger
              _shakeCount = 0;
              _firstShakeTime = null;
            }
          }
        }
      }
    });
  }

  void dispose() {
    _accelerometerSubscription?.cancel();
    _onShakeCallback = null;
    _lastShakeTime = null;
    _shakeCount = 0;
    _firstShakeTime = null;
    print('Shake detection service disposed');
  }
}

 