// lib/core/utils/keyboard_visibility_controller.dart

import 'dart:async';

import 'package:flutter/widgets.dart';

/// A controller that detects keyboard visibility changes.
class KeyboardVisibilityController {
  // Singleton pattern
  static final KeyboardVisibilityController _instance =
      KeyboardVisibilityController._internal();

  factory KeyboardVisibilityController() => _instance;

  KeyboardVisibilityController._internal() {
    // Initialize with a stream controller
    _streamController = StreamController<bool>.broadcast();

    // Set up the initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryKeyboardVisibility().then((bool visible) {
        _lastValue = visible;
        _streamController.add(visible);
      });
    });

    // Register a listener for metrics changes (includes keyboard visibility)
    WidgetsBinding.instance.addObserver(_VisibilityObserver(
      onVisibilityChanged: (bool visible) {
        if (_lastValue != visible) {
          _lastValue = visible;
          _streamController.add(visible);
        }
      },
    ));
  }

  late StreamController<bool> _streamController;
  bool _lastValue = false;

  /// Stream that emits when keyboard visibility changes
  Stream<bool> get onChange => _streamController.stream;

  /// Current keyboard visibility state
  bool get isVisible => _lastValue;

  /// Manually query the current keyboard visibility
  Future<bool> _queryKeyboardVisibility() async {
    try {
      // Use view insets to determine if keyboard is visible
      final viewInsets =
          WidgetsBinding.instance.platformDispatcher.views.first.viewInsets;
      return viewInsets.bottom > 0;
    } catch (e) {
      return false;
    }
  }

  /// Disposes resources
  void dispose() {
    _streamController.close();
  }
}

/// Observer that detects changes in keyboard visibility through metrics
class _VisibilityObserver extends WidgetsBindingObserver {
  final ValueChanged<bool> onVisibilityChanged;
  double _previousBottomInset = 0.0;

  _VisibilityObserver({required this.onVisibilityChanged});

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset != _previousBottomInset) {
      _previousBottomInset = bottomInset;
      onVisibilityChanged(bottomInset > 0);
    }
  }
}
