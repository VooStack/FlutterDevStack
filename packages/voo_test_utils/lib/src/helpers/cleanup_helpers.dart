/// Utilities for cleaning up test state.
///
/// This file provides helper functions for resetting singleton
/// and static state between tests.
library;

/// A registry of cleanup functions to run between tests.
class CleanupRegistry {
  static final List<void Function()> _cleanupFunctions = [];

  /// Registers a cleanup function to be called during tearDown.
  static void register(void Function() cleanupFn) {
    _cleanupFunctions.add(cleanupFn);
  }

  /// Runs all registered cleanup functions.
  static void runAll() {
    for (final fn in _cleanupFunctions) {
      try {
        fn();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  /// Clears all registered cleanup functions.
  static void clear() {
    _cleanupFunctions.clear();
  }

  /// Runs all cleanup functions and clears the registry.
  static void tearDown() {
    runAll();
    clear();
  }
}

/// Mixin for test classes that need cleanup utilities.
mixin TestCleanup {
  final List<void Function()> _cleanupCallbacks = [];

  /// Register a callback to run during test cleanup.
  void addCleanup(void Function() callback) {
    _cleanupCallbacks.add(callback);
  }

  /// Run all cleanup callbacks.
  void runCleanup() {
    for (final callback in _cleanupCallbacks.reversed) {
      try {
        callback();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
    _cleanupCallbacks.clear();
  }
}

/// Helper class for tracking disposable resources in tests.
class DisposableTracker {
  final List<dynamic> _disposables = [];

  /// Track a disposable resource.
  T track<T>(T disposable) {
    _disposables.add(disposable);
    return disposable;
  }

  /// Dispose all tracked resources.
  Future<void> disposeAll() async {
    for (final disposable in _disposables.reversed) {
      try {
        if (disposable is Function) {
          final result = disposable();
          if (result is Future) await result;
        } else if (_hasDispose(disposable)) {
          final result = disposable.dispose();
          if (result is Future) await result;
        } else if (_hasClose(disposable)) {
          final result = disposable.close();
          if (result is Future) await result;
        }
      } catch (_) {
        // Ignore dispose errors
      }
    }
    _disposables.clear();
  }

  bool _hasDispose(dynamic obj) {
    try {
      // ignore: avoid_dynamic_calls
      obj.dispose;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _hasClose(dynamic obj) {
    try {
      // ignore: avoid_dynamic_calls
      obj.close;
      return true;
    } catch (_) {
      return false;
    }
  }
}
