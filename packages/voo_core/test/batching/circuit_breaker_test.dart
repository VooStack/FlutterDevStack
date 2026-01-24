import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker circuitBreaker;

    setUp(() {
      circuitBreaker = CircuitBreaker(
        threshold: 3,
        cooldown: const Duration(milliseconds: 100),
      );
    });

    group('initial state', () {
      test('should start in closed state', () {
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
      });

      test('should allow requests when closed', () {
        expect(circuitBreaker.allowRequest, isTrue);
      });
    });

    group('recordSuccess', () {
      test('should reset consecutive failures on success', () {
        circuitBreaker.recordFailure();
        circuitBreaker.recordFailure();
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));

        circuitBreaker.recordSuccess();

        // Should still allow requests after success
        expect(circuitBreaker.allowRequest, isTrue);
      });

      test('should close circuit breaker from half-open state', () async {
        // Open the circuit
        for (var i = 0; i < 3; i++) {
          circuitBreaker.recordFailure();
        }
        expect(circuitBreaker.state, equals(CircuitBreakerState.open));

        // Wait for cooldown
        await Future.delayed(const Duration(milliseconds: 150));

        // Should be half-open now
        expect(circuitBreaker.state, equals(CircuitBreakerState.halfOpen));

        // Success should close it
        circuitBreaker.recordSuccess();
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
      });
    });

    group('recordFailure', () {
      test('should increment consecutive failures', () {
        circuitBreaker.recordFailure();
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));

        circuitBreaker.recordFailure();
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
      });

      test('should open circuit after threshold failures', () {
        for (var i = 0; i < 3; i++) {
          circuitBreaker.recordFailure();
        }

        expect(circuitBreaker.state, equals(CircuitBreakerState.open));
        expect(circuitBreaker.allowRequest, isFalse);
      });

      test('should reopen circuit from half-open on failure', () async {
        // Open the circuit
        for (var i = 0; i < 3; i++) {
          circuitBreaker.recordFailure();
        }

        // Wait for cooldown
        await Future.delayed(const Duration(milliseconds: 150));
        expect(circuitBreaker.state, equals(CircuitBreakerState.halfOpen));

        // Failure should reopen
        circuitBreaker.recordFailure();
        expect(circuitBreaker.state, equals(CircuitBreakerState.open));
      });
    });

    group('state transitions', () {
      test('should transition from open to half-open after cooldown', () async {
        // Open the circuit
        for (var i = 0; i < 3; i++) {
          circuitBreaker.recordFailure();
        }
        expect(circuitBreaker.state, equals(CircuitBreakerState.open));

        // Wait for cooldown
        await Future.delayed(const Duration(milliseconds: 150));

        // Check state - should now be half-open
        expect(circuitBreaker.state, equals(CircuitBreakerState.halfOpen));
        expect(circuitBreaker.allowRequest, isTrue);
      });

      test('should not transition before cooldown', () async {
        // Open the circuit
        for (var i = 0; i < 3; i++) {
          circuitBreaker.recordFailure();
        }

        // Check immediately - should still be open
        expect(circuitBreaker.state, equals(CircuitBreakerState.open));
        expect(circuitBreaker.allowRequest, isFalse);
      });
    });

    group('reset', () {
      test('should reset to initial state', () {
        // Open the circuit
        for (var i = 0; i < 3; i++) {
          circuitBreaker.recordFailure();
        }
        expect(circuitBreaker.state, equals(CircuitBreakerState.open));

        circuitBreaker.reset();

        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
        expect(circuitBreaker.allowRequest, isTrue);
      });
    });

    group('configuration', () {
      test('should respect custom threshold', () {
        final customBreaker = CircuitBreaker(threshold: 5);

        for (var i = 0; i < 4; i++) {
          customBreaker.recordFailure();
        }
        expect(customBreaker.state, equals(CircuitBreakerState.closed));

        customBreaker.recordFailure();
        expect(customBreaker.state, equals(CircuitBreakerState.open));
      });

      test('should respect custom cooldown', () async {
        final customBreaker = CircuitBreaker(
          threshold: 1,
          cooldown: const Duration(milliseconds: 50),
        );

        customBreaker.recordFailure();
        expect(customBreaker.state, equals(CircuitBreakerState.open));

        await Future.delayed(const Duration(milliseconds: 75));
        expect(customBreaker.state, equals(CircuitBreakerState.halfOpen));
      });
    });
  });

  group('RetryPolicy', () {
    group('constructor', () {
      test('should create with default values', () {
        const policy = RetryPolicy();

        expect(policy.maxRetries, equals(3));
        expect(policy.baseDelay, equals(const Duration(seconds: 1)));
        expect(policy.multiplier, equals(2.0));
      });

      test('should create with custom values', () {
        const policy = RetryPolicy(
          maxRetries: 5,
          baseDelay: Duration(milliseconds: 500),
          maxDelay: Duration(seconds: 10),
          multiplier: 1.5,
        );

        expect(policy.maxRetries, equals(5));
        expect(policy.baseDelay, equals(const Duration(milliseconds: 500)));
        expect(policy.multiplier, equals(1.5));
      });
    });

    group('factory constructors', () {
      test('should create standard policy', () {
        final policy = RetryPolicy.standard();

        expect(policy.maxRetries, equals(3));
      });

      test('should create aggressive policy', () {
        final policy = RetryPolicy.aggressive();

        expect(policy.maxRetries, equals(5));
        expect(policy.baseDelay, equals(const Duration(milliseconds: 500)));
      });

      test('should create conservative policy', () {
        final policy = RetryPolicy.conservative();

        expect(policy.maxRetries, equals(2));
        expect(policy.baseDelay, equals(const Duration(seconds: 2)));
      });
    });

    group('getDelay', () {
      test('should return zero delay for attempt 0', () {
        const policy = RetryPolicy();

        expect(policy.getDelay(0), equals(Duration.zero));
      });

      test('should calculate exponential backoff', () {
        const policy = RetryPolicy(
          baseDelay: Duration(seconds: 1),
          multiplier: 2.0,
          jitterFactor: 0,
        );

        expect(policy.getDelay(1).inSeconds, equals(1));
        expect(policy.getDelay(2).inSeconds, equals(2));
        expect(policy.getDelay(3).inSeconds, equals(4));
      });

      test('should cap at max delay', () {
        const policy = RetryPolicy(
          baseDelay: Duration(seconds: 10),
          maxDelay: Duration(seconds: 30),
          multiplier: 3.0,
          jitterFactor: 0,
        );

        // 10 * 3^3 = 270 seconds, but capped at 30
        final delay = policy.getDelay(4);
        expect(delay.inSeconds, equals(30));
      });
    });

    group('copyWith', () {
      test('should create copy with modified values', () {
        const original = RetryPolicy(maxRetries: 3);
        final copy = original.copyWith(maxRetries: 5);

        expect(copy.maxRetries, equals(5));
        expect(copy.baseDelay, equals(original.baseDelay));
      });
    });
  });

  group('retryWithBackoff', () {
    test('should succeed on first attempt', () async {
      var attempts = 0;
      final result = await retryWithBackoff(() async {
        attempts++;
        return 'success';
      });

      expect(result, equals('success'));
      expect(attempts, equals(1));
    });

    test('should retry on failure', () async {
      var attempts = 0;
      final result = await retryWithBackoff(
        () async {
          attempts++;
          if (attempts < 3) throw Exception('fail');
          return 'success';
        },
        policy: const RetryPolicy(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result, equals('success'));
      expect(attempts, equals(3));
    });

    test('should throw after max retries', () async {
      var attempts = 0;

      await expectLater(
        () async {
          await retryWithBackoff(
            () async {
              attempts++;
              throw Exception('always fail');
            },
            policy: const RetryPolicy(
              maxRetries: 2,
              baseDelay: Duration(milliseconds: 10),
            ),
          );
        }(),
        throwsException,
      );

      // Initial + 2 retries = 3 attempts
      expect(attempts, equals(3));
    });

    test('should call onRetry callback', () async {
      final retryAttempts = <int>[];
      var attempts = 0;

      await retryWithBackoff(
        () async {
          attempts++;
          if (attempts < 2) throw Exception('fail');
          return 'success';
        },
        policy: const RetryPolicy(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
        onRetry: (attempt, error) => retryAttempts.add(attempt),
      );

      expect(retryAttempts, equals([1]));
    });

    test('should respect shouldRetry predicate', () async {
      var attempts = 0;

      try {
        await retryWithBackoff(
          () async {
            attempts++;
            throw ArgumentError('non-retryable');
          },
          policy: const RetryPolicy(maxRetries: 3),
          shouldRetry: (error) => error is! ArgumentError,
        );
      } catch (e) {
        // Expected
      }

      // Should only attempt once since shouldRetry returns false
      expect(attempts, equals(1));
    });

    test('should throw CircuitBreakerOpenException when circuit is open', () async {
      final breaker = CircuitBreaker(threshold: 1);
      breaker.recordFailure(); // Open the circuit

      expect(
        () => retryWithBackoff(
          () async => 'success',
          circuitBreaker: breaker,
        ),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });
  });

  group('CircuitBreakerOpenException', () {
    test('should contain message', () {
      final exception = CircuitBreakerOpenException('Test message');

      expect(exception.message, equals('Test message'));
      expect(exception.toString(), contains('Test message'));
    });
  });
}
