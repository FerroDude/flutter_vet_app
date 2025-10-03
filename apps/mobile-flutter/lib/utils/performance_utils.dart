import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utility class for performance optimizations
class PerformanceUtils {
  /// Debounce function calls to prevent excessive API calls
  static void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _DebounceManager.instance.debounce(key, callback, delay);
  }

  /// Throttle function calls to limit execution frequency
  static void throttle(
    String key,
    VoidCallback callback, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    _ThrottleManager.instance.throttle(key, callback, interval);
  }

  /// Batch multiple notifications into a single update
  static void batchNotifications(
    List<VoidCallback> notifications, {
    Duration delay = const Duration(milliseconds: 16), // One frame
  }) {
    _BatchManager.instance.batch(notifications, delay);
  }

  /// Check if two objects are effectively equal for UI purposes
  static bool isEffectivelyEqual<T>(T? oldValue, T? newValue) {
    if (oldValue == null && newValue == null) return true;
    if (oldValue == null || newValue == null) return false;

    // For lists, check length and content
    if (oldValue is List && newValue is List) {
      if (oldValue.length != newValue.length) return false;
      for (int i = 0; i < oldValue.length; i++) {
        if (oldValue[i] != newValue[i]) return false;
      }
      return true;
    }

    // For maps, check keys and values
    if (oldValue is Map && newValue is Map) {
      if (oldValue.length != newValue.length) return false;
      for (final key in oldValue.keys) {
        if (!newValue.containsKey(key) || oldValue[key] != newValue[key]) {
          return false;
        }
      }
      return true;
    }

    return oldValue == newValue;
  }

  /// Dispose of performance utilities
  static void dispose() {
    _DebounceManager.instance.dispose();
    _ThrottleManager.instance.dispose();
    _BatchManager.instance.dispose();
  }
}

/// Internal debounce manager
class _DebounceManager {
  static final _DebounceManager _instance = _DebounceManager._internal();
  static _DebounceManager get instance => _instance;
  _DebounceManager._internal();

  final Map<String, Timer?> _timers = {};

  void debounce(String key, VoidCallback callback, Duration delay) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, () {
      callback();
      _timers.remove(key);
    });
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer?.cancel();
    }
    _timers.clear();
  }
}

/// Internal throttle manager
class _ThrottleManager {
  static final _ThrottleManager _instance = _ThrottleManager._internal();
  static _ThrottleManager get instance => _instance;
  _ThrottleManager._internal();

  final Map<String, DateTime> _lastExecution = {};

  void throttle(String key, VoidCallback callback, Duration interval) {
    final now = DateTime.now();
    final lastTime = _lastExecution[key];

    if (lastTime == null || now.difference(lastTime) >= interval) {
      _lastExecution[key] = now;
      callback();
    }
  }

  void dispose() {
    _lastExecution.clear();
  }
}

/// Internal batch manager
class _BatchManager {
  static final _BatchManager _instance = _BatchManager._internal();
  static _BatchManager get instance => _instance;
  _BatchManager._internal();

  Timer? _batchTimer;
  final List<VoidCallback> _pendingNotifications = [];

  void batch(List<VoidCallback> notifications, Duration delay) {
    _pendingNotifications.addAll(notifications);

    _batchTimer?.cancel();
    _batchTimer = Timer(delay, () {
      for (final notification in _pendingNotifications) {
        notification();
      }
      _pendingNotifications.clear();
    });
  }

  void dispose() {
    _batchTimer?.cancel();
    _pendingNotifications.clear();
  }
}

/// Mixin for optimized ChangeNotifier implementations
mixin OptimizedChangeNotifier on ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Only notify listeners if the value has actually changed
  void notifyListenersIfChanged<T>(T oldValue, T newValue) {
    if (!_disposed &&
        !PerformanceUtils.isEffectivelyEqual(oldValue, newValue)) {
      super.notifyListeners();
    }
  }

  /// Batch multiple property updates
  void batchUpdates(VoidCallback updates) {
    updates();
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
