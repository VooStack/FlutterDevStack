import 'dart:math';

import 'package:flutter/foundation.dart';

/// Configuration for retry behavior with exponential backoff.
@immutable
class RetryPolicy {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Base delay between retries.
  final Duration baseDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  final double multiplier;

  /// Jitter factor (+/- percentage) to add randomness.
  final double jitterFactor;

  /// Number of consecutive failures before opening circuit breaker.
  final int circuitBreakerThreshold;

  /// How long to wait before attempting to close circuit breaker.
  final Duration circuitBreakerCooldown;

  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    this.multiplier = 2.0,
    this.jitterFactor = 0.1,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerCooldown = const Duration(seconds: 30),
  });

  /// Default policy for most operations.
  factory RetryPolicy.standard() => const RetryPolicy();

  /// Aggressive policy for high-priority operations.
  factory RetryPolicy.aggressive() => const RetryPolicy(
        maxRetries: 5,
        baseDelay: Duration(milliseconds: 500),
        maxDelay: Duration(minutes: 2),
        multiplier: 1.5,
      );

  /// Conservative policy for low-priority operations.
  factory RetryPolicy.conservative() => const RetryPolicy(
        maxRetries: 2,
        baseDelay: Duration(seconds: 2),
        maxDelay: Duration(minutes: 10),
        multiplier: 3.0,
      );

  /// Calculate delay for a specific attempt number.
  Duration getDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    // Exponential backoff
    final exponentialDelay = baseDelay.inMilliseconds *
        pow(multiplier, attempt - 1).toInt();

    // Cap at max delay
    final cappedDelay = min(exponentialDelay, maxDelay.inMilliseconds);

    // Add jitter
    final jitter = _calculateJitter(cappedDelay);

    return Duration(milliseconds: cappedDelay + jitter);
  }

  int _calculateJitter(int delay) {
    if (jitterFactor <= 0) return 0;
    final random = Random();
    final jitterRange = (delay * jitterFactor).toInt();
    return random.nextInt(jitterRange * 2) - jitterRange;
  }

  /// Create a copy with modifications.
  RetryPolicy copyWith({
    int? maxRetries,
    Duration? baseDelay,
    Duration? maxDelay,
    double? multiplier,
    double? jitterFactor,
    int? circuitBreakerThreshold,
    Duration? circuitBreakerCooldown,
  }) =>
      RetryPolicy(
        maxRetries: maxRetries ?? this.maxRetries,
        baseDelay: baseDelay ?? this.baseDelay,
        maxDelay: maxDelay ?? this.maxDelay,
        multiplier: multiplier ?? this.multiplier,
        jitterFactor: jitterFactor ?? this.jitterFactor,
        circuitBreakerThreshold:
            circuitBreakerThreshold ?? this.circuitBreakerThreshold,
        circuitBreakerCooldown:
            circuitBreakerCooldown ?? this.circuitBreakerCooldown,
      );
}

/// A circuit breaker to prevent cascading failures.
///
/// Opens after [threshold] consecutive failures, preventing further
/// requests until [cooldown] has passed.
class CircuitBreaker {
  final int threshold;
  final Duration cooldown;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  CircuitBreakerState _state = CircuitBreakerState.closed;

  CircuitBreaker({
    this.threshold = 5,
    this.cooldown = const Duration(seconds: 30),
  });

  /// Current state of the circuit breaker.
  CircuitBreakerState get state {
    _checkHalfOpen();
    return _state;
  }

  /// Whether requests are allowed.
  bool get allowRequest {
    _checkHalfOpen();
    return _state != CircuitBreakerState.open;
  }

  /// Record a successful operation.
  void recordSuccess() {
    _consecutiveFailures = 0;
    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.closed;
      _openedAt = null;
      if (kDebugMode) {
        debugPrint('CircuitBreaker: Closed after successful request');
      }
    }
  }

  /// Record a failed operation.
  void recordFailure() {
    _consecutiveFailures++;

    if (_consecutiveFailures >= threshold &&
        _state == CircuitBreakerState.closed) {
      _state = CircuitBreakerState.open;
      _openedAt = DateTime.now();
      if (kDebugMode) {
        debugPrint(
            'CircuitBreaker: Opened after $threshold consecutive failures');
      }
    } else if (_state == CircuitBreakerState.halfOpen) {
      // Failed during half-open, go back to open
      _state = CircuitBreakerState.open;
      _openedAt = DateTime.now();
    }
  }

  /// Check if we should transition to half-open.
  void _checkHalfOpen() {
    if (_state == CircuitBreakerState.open && _openedAt != null) {
      final elapsed = DateTime.now().difference(_openedAt!);
      if (elapsed >= cooldown) {
        _state = CircuitBreakerState.halfOpen;
        if (kDebugMode) {
          debugPrint('CircuitBreaker: Half-open, allowing test request');
        }
      }
    }
  }

  /// Reset the circuit breaker.
  void reset() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _state = CircuitBreakerState.closed;
  }
}

/// States for the circuit breaker.
enum CircuitBreakerState {
  /// Normal operation, requests allowed.
  closed,

  /// Too many failures, requests blocked.
  open,

  /// Testing if service recovered, limited requests allowed.
  halfOpen,
}

/// Execute an operation with retry logic.
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  RetryPolicy policy = const RetryPolicy(),
  CircuitBreaker? circuitBreaker,
  bool Function(Object error)? shouldRetry,
  void Function(int attempt, Object error)? onRetry,
}) async {
  int attempt = 0;

  while (true) {
    attempt++;

    // Check circuit breaker
    if (circuitBreaker != null && !circuitBreaker.allowRequest) {
      throw CircuitBreakerOpenException(
        'Circuit breaker is open, request blocked',
      );
    }

    try {
      final result = await operation();
      circuitBreaker?.recordSuccess();
      return result;
    } catch (e) {
      circuitBreaker?.recordFailure();

      // Check if we should retry
      final canRetry = shouldRetry?.call(e) ?? true;
      if (!canRetry || attempt >= policy.maxRetries) {
        rethrow;
      }

      // Calculate delay
      final delay = policy.getDelay(attempt);
      onRetry?.call(attempt, e);

      if (kDebugMode) {
        debugPrint('Retry attempt $attempt after ${delay.inMilliseconds}ms');
      }

      await Future.delayed(delay);
    }
  }
}

/// Exception thrown when circuit breaker blocks a request.
class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}
