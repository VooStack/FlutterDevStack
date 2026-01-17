import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_core/voo_core.dart';

/// Test item for sync service testing.
class TestItem {
  final String id;
  final String message;
  final DateTime timestamp;

  TestItem({required this.id, required this.message, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Concrete implementation of BaseSyncService for testing.
class TestSyncService extends BaseSyncService<TestItem> {
  final String _endpoint;
  final List<TestItem> sentItems = [];
  bool shouldFilterItems = false;
  bool shouldFlushImmediatelyFlag = false;

  TestSyncService({
    required BaseSyncConfig config,
    http.Client? client,
    String? endpoint,
  })  : _endpoint = endpoint ?? 'https://api.test.com/test',
        super(
          config: config,
          serviceName: 'TestSyncService',
          client: client,
        );

  @override
  String get endpoint => _endpoint;

  @override
  Map<String, dynamic> formatPayload(List<TestItem> items) {
    sentItems.addAll(items);
    return {
      'projectId': config.projectId,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool shouldQueueItem(TestItem item) {
    if (shouldFilterItems) {
      return !item.message.startsWith('skip');
    }
    return true;
  }

  @override
  bool shouldFlushImmediately(TestItem item) {
    if (shouldFlushImmediatelyFlag) {
      return item.message.startsWith('priority');
    }
    return false;
  }
}

void main() {
  group('BaseSyncService', () {
    late TestSyncService syncService;
    late MockClient mockClient;
    int requestCount = 0;
    List<http.Request> capturedRequests = [];

    BaseSyncConfig createValidConfig({
      int batchSize = 5,
      Duration batchInterval = const Duration(seconds: 30),
      int maxRetries = 3,
      int maxQueueSize = 100,
    }) {
      return BaseSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
        batchSize: batchSize,
        batchInterval: batchInterval,
        maxRetries: maxRetries,
        maxQueueSize: maxQueueSize,
      );
    }

    MockClient createMockClient({
      int statusCode = 200,
      String body = '{"success": true}',
      Duration? delay,
      bool Function(http.Request)? shouldFail,
    }) {
      return MockClient((request) async {
        capturedRequests.add(request);
        requestCount++;

        if (delay != null) {
          await Future.delayed(delay);
        }

        if (shouldFail != null && shouldFail(request)) {
          return http.Response('{"error": "failed"}', 500);
        }

        return http.Response(body, statusCode);
      });
    }

    setUp(() {
      requestCount = 0;
      capturedRequests = [];
    });

    tearDown(() {
      syncService.dispose();
    });

    group('initialization', () {
      test('should initialize with valid config', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );

        syncService.initialize();

        expect(syncService.status, equals(SyncStatus.idle));
        expect(syncService.pendingCount, equals(0));
      });

      test('should set status to disabled with invalid config', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: const BaseSyncConfig(enabled: false),
          client: mockClient,
        );

        syncService.initialize();

        expect(syncService.status, equals(SyncStatus.disabled));
      });

      test('should set status to disabled when endpoint is missing', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: const BaseSyncConfig(
            enabled: true,
            apiKey: 'key',
          ),
          client: mockClient,
        );

        syncService.initialize();

        expect(syncService.status, equals(SyncStatus.disabled));
      });
    });

    group('queueItem', () {
      test('should queue items when enabled', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));

        expect(syncService.pendingCount, equals(1));
      });

      test('should not queue items when disabled', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: const BaseSyncConfig(enabled: false),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));

        expect(syncService.pendingCount, equals(0));
      });

      test('should enforce max queue size', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(maxQueueSize: 3, batchSize: 10),
          client: mockClient,
        );
        syncService.initialize();

        for (var i = 0; i < 5; i++) {
          syncService.queueItem(TestItem(id: '$i', message: 'test $i'));
        }

        expect(syncService.pendingCount, equals(3));
      });

      test('should auto-flush when batch size reached', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(batchSize: 3),
          client: mockClient,
        );
        syncService.initialize();

        for (var i = 0; i < 3; i++) {
          syncService.queueItem(TestItem(id: '$i', message: 'test $i'));
        }

        await Future.delayed(const Duration(milliseconds: 100));

        expect(requestCount, equals(1));
        expect(syncService.sentItems.length, equals(3));
      });

      test('should respect shouldQueueItem filter', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.shouldFilterItems = true;
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'keep this'));
        syncService.queueItem(TestItem(id: '2', message: 'skip this'));
        syncService.queueItem(TestItem(id: '3', message: 'keep this too'));

        expect(syncService.pendingCount, equals(2));
      });
    });

    group('queueItems', () {
      test('should queue multiple items at once', () {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItems([
          TestItem(id: '1', message: 'test 1'),
          TestItem(id: '2', message: 'test 2'),
          TestItem(id: '3', message: 'test 3'),
        ]);

        expect(syncService.pendingCount, equals(3));
      });
    });

    group('flush', () {
      test('should send queued items', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        expect(requestCount, equals(1));
        expect(syncService.sentItems.length, equals(1));
        expect(syncService.pendingCount, equals(0));
      });

      test('should return true when queue is empty', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        final result = await syncService.flush();

        expect(result, isTrue);
        expect(requestCount, equals(0));
      });

      test('should include correct headers', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        final request = capturedRequests.first;
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(request.headers['X-API-Key'], equals('test-api-key'));
        expect(request.headers['X-Project-Id'], equals('test-project-id'));
      });

      test('should format payload correctly', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        final request = capturedRequests.first;
        final body = jsonDecode(request.body);
        expect(body['projectId'], equals('test-project-id'));
        expect(body['items'], isA<List>());
        expect(body['items'].length, equals(1));
      });
    });

    group('retry logic', () {
      test('should retry on failure', () async {
        var attemptCount = 0;
        mockClient = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 3) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 3),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        final result = await syncService.flush();

        expect(result, isTrue);
        expect(attemptCount, equals(3));
      });

      test('should fail after max retries exceeded', () async {
        mockClient = createMockClient(statusCode: 500);
        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 2),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        final result = await syncService.flush();

        expect(result, isFalse);
        expect(requestCount, equals(3)); // Initial + 2 retries
      });

      test('should re-queue items on failure', () async {
        mockClient = createMockClient(statusCode: 500);
        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 0),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        expect(syncService.pendingCount, equals(1));
      });
    });

    group('status tracking', () {
      test('should update status during sync', () async {
        final statusChanges = <SyncStatus>[];
        mockClient = createMockClient(delay: const Duration(milliseconds: 50));
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.onStatusChanged = (status) => statusChanges.add(status);
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        expect(statusChanges, contains(SyncStatus.syncing));
        expect(statusChanges, contains(SyncStatus.success));
      });

      test('should set error status on failure', () async {
        final statusChanges = <SyncStatus>[];
        mockClient = createMockClient(statusCode: 500);
        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 0),
          client: mockClient,
        );
        syncService.onStatusChanged = (status) => statusChanges.add(status);
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        expect(statusChanges, contains(SyncStatus.error));
      });

      test('should track consecutive failures', () async {
        mockClient = createMockClient(statusCode: 500);
        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 0),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        expect(syncService.consecutiveFailures, equals(1));
      });

      test('should reset consecutive failures on success', () async {
        var shouldFail = true;
        mockClient = MockClient((request) async {
          if (shouldFail) {
            return http.Response('{"error": "fail"}', 500);
          }
          return http.Response('{"success": true}', 200);
        });

        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 0),
          client: mockClient,
        );
        syncService.initialize();

        // First request fails
        syncService.queueItem(TestItem(id: '1', message: 'test 1'));
        await syncService.flush();
        expect(syncService.consecutiveFailures, equals(1));

        // Second request succeeds
        shouldFail = false;
        await syncService.flush();
        expect(syncService.consecutiveFailures, equals(0));
      });
    });

    group('error callback', () {
      test('should call onError callback on failure', () async {
        final errors = <String>[];
        mockClient = createMockClient(statusCode: 500);
        syncService = TestSyncService(
          config: createValidConfig(maxRetries: 1),
          client: mockClient,
        );
        syncService.onError = (error, retry) => errors.add('$error:$retry');
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        await syncService.flush();

        expect(errors.length, equals(2)); // Initial + 1 retry
        expect(errors[0], contains(':0'));
        expect(errors[1], contains(':1'));
      });
    });

    group('batching', () {
      test('should batch items according to batch size', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(batchSize: 2, batchInterval: const Duration(hours: 1)),
          client: mockClient,
        );
        syncService.initialize();

        // Queue items one at a time without triggering auto-flush
        syncService.queueItem(TestItem(id: '0', message: 'test 0'));
        expect(syncService.pendingCount, equals(1));

        // Second item triggers auto-flush since batch size is 2
        syncService.queueItem(TestItem(id: '1', message: 'test 1'));

        // Wait for async auto-flush to complete
        await Future.delayed(const Duration(milliseconds: 50));
        expect(syncService.sentItems.length, equals(2));
        expect(syncService.pendingCount, equals(0));

        // Queue 3 more items
        syncService.queueItem(TestItem(id: '2', message: 'test 2'));
        syncService.queueItem(TestItem(id: '3', message: 'test 3'));
        await Future.delayed(const Duration(milliseconds: 50));
        expect(syncService.sentItems.length, equals(4)); // 2 + 2

        syncService.queueItem(TestItem(id: '4', message: 'test 4'));
        expect(syncService.pendingCount, equals(1)); // 1 remaining

        // Manually flush the remaining item
        await syncService.flush();
        expect(syncService.sentItems.length, equals(5)); // All 5 sent
      });
    });

    group('dispose', () {
      test('should cancel batch timer on dispose', () async {
        mockClient = createMockClient();
        syncService = TestSyncService(
          config: createValidConfig(batchInterval: const Duration(milliseconds: 100)),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test'));
        syncService.dispose();

        // Wait for what would have been the batch interval
        await Future.delayed(const Duration(milliseconds: 200));

        // Should not have sent any requests since timer was cancelled
        expect(requestCount, equals(0));
      });
    });

    group('concurrent sync prevention', () {
      test('should prevent concurrent sync operations', () async {
        mockClient = createMockClient(delay: const Duration(milliseconds: 100));
        syncService = TestSyncService(
          config: createValidConfig(),
          client: mockClient,
        );
        syncService.initialize();

        syncService.queueItem(TestItem(id: '1', message: 'test 1'));
        syncService.queueItem(TestItem(id: '2', message: 'test 2'));

        // Start two flushes concurrently
        final future1 = syncService.flush();
        final future2 = syncService.flush();

        await Future.wait([future1, future2]);

        // Only one request should have been made (second flush returns early)
        expect(requestCount, equals(1));
      });
    });
  });
}
