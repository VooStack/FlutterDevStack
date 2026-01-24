import 'dart:async';

/// Utility functions for testing asynchronous code.
class AsyncHelpers {
  /// Waits for a condition to be true, with timeout.
  ///
  /// Returns true if condition was met, false if timed out.
  static Future<bool> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return true;
      await Future.delayed(pollInterval);
    }

    return false;
  }

  /// Waits for an async condition to be true, with timeout.
  static Future<bool> waitForAsync(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return true;
      await Future.delayed(pollInterval);
    }

    return false;
  }

  /// Collects values from a stream for a given duration.
  static Future<List<T>> collectStreamValues<T>(
    Stream<T> stream, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    final values = <T>[];
    final subscription = stream.listen(values.add);

    await Future.delayed(duration);
    await subscription.cancel();

    return values;
  }

  /// Collects a specific number of values from a stream.
  static Future<List<T>> collectStreamValuesCount<T>(
    Stream<T> stream, {
    required int count,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final values = <T>[];
    final completer = Completer<List<T>>();

    final subscription = stream.listen(
      (value) {
        values.add(value);
        if (values.length >= count && !completer.isCompleted) {
          completer.complete(values);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // Set timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(values);
      }
    });

    final result = await completer.future;
    await subscription.cancel();
    return result;
  }

  /// Runs a function and waits for a short delay.
  static Future<T> runWithDelay<T>(
    T Function() fn, {
    Duration delay = const Duration(milliseconds: 50),
  }) async {
    final result = fn();
    await Future.delayed(delay);
    return result;
  }

  /// Waits for the next microtask to complete.
  static Future<void> waitForMicrotask() {
    return Future.microtask(() {});
  }

  /// Pumps the event loop a specified number of times.
  static Future<void> pumpEventLoop({int times = 10}) async {
    for (int i = 0; i < times; i++) {
      await Future.delayed(Duration.zero);
    }
  }
}
