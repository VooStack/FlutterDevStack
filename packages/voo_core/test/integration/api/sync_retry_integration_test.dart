import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_core/voo_core.dart';

/// Test item for sync service testing.
class TestRetryItem {
  final String id;
  final String data;

  TestRetryItem({required this.id, required this.data});

  Map<String, dynamic> toJson() => {'id': id, 'data': data};
}

/// Concrete implementation of BaseSyncService for retry testing.
class RetrySyncService extends BaseSyncService<TestRetryItem> {
  final List<TestRetryItem> syncedItems = [];

  RetrySyncService({required super.config, super.client})
      : super(serviceName: 'RetrySyncService');

  @override
  String get endpoint => '${config.endpoint}/api/retry-test';

  @override
  Map<String, dynamic> formatPayload(List<TestRetryItem> items) {
    syncedItems.addAll(items);
    return {
      'projectId': config.projectId,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

void main() {
  group('BaseSyncService - Retry Integration', () {
    late RetrySyncService syncService;

    BaseSyncConfig createConfig({
      int maxRetries = 3,
      Duration retryDelay = const Duration(milliseconds: 10),
      int batchSize = 5,
    }) {
      return BaseSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
        batchSize: batchSize,
        batchInterval: const Duration(hours: 1), // Long interval to prevent auto-flush
        maxRetries: maxRetries,
        retryDelay: retryDelay,
      );
    }

    tearDown(() {
      syncService.dispose();
    });

    group('retry with exponential backoff', () {
      test('should retry failed requests', () async {
        var attemptCount = 0;
        final client = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 3) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 3),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        final result = await syncService.flush();

        expect(result, isTrue);
        expect(attemptCount, equals(3)); // 2 failures + 1 success
      });

      test('should fail after max retries exceeded', () async {
        var attemptCount = 0;
        final client = MockClient((request) async {
          attemptCount++;
          return http.Response('{"error": "fail"}', 500);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 2),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        final result = await syncService.flush();

        expect(result, isFalse);
        // maxRetries=2 means 1 initial + 2 retries = 3 total attempts
        expect(attemptCount, equals(3));
      });

      test('should apply exponential backoff timing', () async {
        var attemptCount = 0;
        final attemptTimes = <DateTime>[];

        final client = MockClient((request) async {
          attemptTimes.add(DateTime.now());
          attemptCount++;
          if (attemptCount < 3) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(
            maxRetries: 4,
            retryDelay: const Duration(milliseconds: 50),
          ),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        await syncService.flush();

        // Verify delays increase (exponential backoff)
        if (attemptTimes.length >= 3) {
          final firstDelay = attemptTimes[1].difference(attemptTimes[0]);
          final secondDelay = attemptTimes[2].difference(attemptTimes[1]);

          // Second delay should be longer than first (exponential)
          // Allow some variance for timing
          expect(secondDelay.inMilliseconds, greaterThanOrEqualTo(firstDelay.inMilliseconds));
        }
      });
    });

    group('re-queue items on failure', () {
      test('should re-queue items when sync fails', () async {
        final client = MockClient((request) async {
          return http.Response('{"error": "fail"}', 500);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 1),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        await syncService.flush();

        // Items should be re-queued
        expect(syncService.pendingCount, equals(1));
      });

      test('should re-queue at front of queue', () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          // First 2 calls fail (covering maxRetries=1 which means 2 attempts)
          if (callCount <= 2) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 1, batchSize: 100),
          client: client,
        );
        syncService.initialize();

        // Queue item and fail (both attempts fail with maxRetries=1)
        syncService.queueItem(TestRetryItem(id: '1', data: 'first'));
        await syncService.flush();

        // Re-queued item should be at front
        expect(syncService.pendingCount, equals(1));

        // Queue another item
        syncService.queueItem(TestRetryItem(id: '2', data: 'second'));

        // Flush should send the first item first (re-queued at front)
        syncService.syncedItems.clear();
        await syncService.flush();

        // First synced should be the re-queued item
        expect(syncService.syncedItems.first.id, equals('1'));
      });
    });

    group('consecutive failures tracking', () {
      test('should track consecutive failures', () async {
        final client = MockClient((request) async {
          return http.Response('{"error": "fail"}', 500);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 1),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        await syncService.flush();

        expect(syncService.consecutiveFailures, equals(1));
      });

      test('should increment consecutive failures on repeated failures', () async {
        final client = MockClient((request) async {
          return http.Response('{"error": "fail"}', 500);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 1),
          client: client,
        );
        syncService.initialize();

        // First failure
        syncService.queueItem(TestRetryItem(id: '1', data: 'test1'));
        await syncService.flush();
        final firstFailureCount = syncService.consecutiveFailures;

        // Second failure
        await syncService.flush();
        final secondFailureCount = syncService.consecutiveFailures;

        expect(secondFailureCount, greaterThan(firstFailureCount));
      });

      test('should reset consecutive failures on success', () async {
        var shouldFail = true;
        final client = MockClient((request) async {
          if (shouldFail) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 1),
          client: client,
        );
        syncService.initialize();

        // First call fails
        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        await syncService.flush();
        expect(syncService.consecutiveFailures, equals(1));

        // Second call succeeds
        shouldFail = false;
        await syncService.flush();
        expect(syncService.consecutiveFailures, equals(0));
      });
    });

    group('concurrent sync prevention', () {
      test('should prevent concurrent sync operations', () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount++;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));

        // Start two flushes concurrently
        final future1 = syncService.flush();
        final future2 = syncService.flush();

        await Future.wait([future1, future2]);

        // Only one request should have been made
        expect(requestCount, equals(1));
      });

      test('should allow sequential sync operations', () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount++;
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(),
          client: client,
        );
        syncService.initialize();

        // First sync
        syncService.queueItem(TestRetryItem(id: '1', data: 'test1'));
        await syncService.flush();

        // Second sync
        syncService.queueItem(TestRetryItem(id: '2', data: 'test2'));
        await syncService.flush();

        // Both should have completed
        expect(requestCount, equals(2));
      });
    });

    group('retry on specific status codes', () {
      test('should retry on 500 internal server error', () async {
        var attemptCount = 0;
        final client = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 2) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 3),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        final result = await syncService.flush();

        expect(result, isTrue);
        expect(attemptCount, equals(2));
      });

      test('should retry on 503 service unavailable', () async {
        var attemptCount = 0;
        final client = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 2) {
            return http.Response('{"error": "unavailable"}', 503);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 3),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        final result = await syncService.flush();

        expect(result, isTrue);
        expect(attemptCount, equals(2));
      });

      test('should handle network errors gracefully', () async {
        var attemptCount = 0;
        final client = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 2) {
            throw Exception('Network error');
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 3),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        final result = await syncService.flush();

        expect(result, isTrue);
        expect(attemptCount, equals(2));
      });
    });

    group('success after transient failure', () {
      test('should eventually succeed after transient failures', () async {
        var attemptCount = 0;
        final client = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 3) {
            return http.Response('{"error": "transient"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(maxRetries: 5),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        final result = await syncService.flush();

        expect(result, isTrue);
        expect(syncService.consecutiveFailures, equals(0));
        expect(syncService.pendingCount, equals(0));
      });
    });

    group('config validation', () {
      test('should use configured retry delay', () async {
        final attemptTimes = <DateTime>[];
        final client = MockClient((request) async {
          attemptTimes.add(DateTime.now());
          if (attemptTimes.length < 2) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = RetrySyncService(
          config: createConfig(
            maxRetries: 3,
            retryDelay: const Duration(milliseconds: 100),
          ),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestRetryItem(id: '1', data: 'test'));
        await syncService.flush();

        if (attemptTimes.length >= 2) {
          final delay = attemptTimes[1].difference(attemptTimes[0]);
          expect(delay.inMilliseconds, greaterThanOrEqualTo(50)); // Allow variance
        }
      });
    });
  });
}
