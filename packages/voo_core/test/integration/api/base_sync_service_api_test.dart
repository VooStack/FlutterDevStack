import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';
import 'package:voo_test_utils/voo_test_utils.dart';

/// Test item for sync service testing.
class TestSyncItem {
  final String id;
  final String data;
  final DateTime timestamp;

  TestSyncItem({
    required this.id,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Concrete implementation of BaseSyncService for testing.
class TestApiSyncService extends BaseSyncService<TestSyncItem> {
  final String _endpointPath;
  final List<TestSyncItem> syncedItems = [];

  TestApiSyncService({
    required super.config,
    super.client,
    String? endpoint,
  })  : _endpointPath = endpoint ?? '/api/sync',
        super(serviceName: 'TestApiSyncService');

  @override
  String get endpoint => '${config.endpoint ?? ''}$_endpointPath';

  @override
  Map<String, dynamic> formatPayload(List<TestSyncItem> items) {
    syncedItems.addAll(items);
    return {
      'projectId': config.projectId,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

void main() {
  group('BaseSyncService API Integration', () {
    late MockHttpClient mockHttpClient;
    late TestApiSyncService syncService;

    BaseSyncConfig createConfig({
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

    setUp(() {
      mockHttpClient = MockHttpClient();
    });

    tearDown(() {
      syncService.dispose();
    });

    group('auto-flush on batch size', () {
      test('should auto-flush when batch size is reached', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(batchSize: 3),
          client: client,
        );
        syncService.initialize();

        // Queue items one at a time
        syncService.queueItem(TestSyncItem(id: '1', data: 'item1'));
        syncService.queueItem(TestSyncItem(id: '2', data: 'item2'));

        // Should not have flushed yet
        expect(mockHttpClient.requestCount, equals(0));

        // Third item should trigger auto-flush
        syncService.queueItem(TestSyncItem(id: '3', data: 'item3'));

        // Wait for async flush
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(mockHttpClient.requestCount, equals(1));
        expect(syncService.syncedItems.length, equals(3));
      });

      test('should flush multiple batches as items accumulate', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(batchSize: 2),
          client: client,
        );
        syncService.initialize();

        // Queue first batch of 2 items
        syncService.queueItem(TestSyncItem(id: '0', data: 'item0'));
        syncService.queueItem(TestSyncItem(id: '1', data: 'item1'));

        // Wait for first auto-flush to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockHttpClient.requestCount, equals(1));
        expect(syncService.syncedItems.length, equals(2));

        // Queue second batch of 2 items
        syncService.queueItem(TestSyncItem(id: '2', data: 'item2'));
        syncService.queueItem(TestSyncItem(id: '3', data: 'item3'));

        // Wait for second auto-flush to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockHttpClient.requestCount, equals(2));
        expect(syncService.syncedItems.length, equals(4));

        // Queue one more item (below threshold)
        syncService.queueItem(TestSyncItem(id: '4', data: 'item4'));
        expect(syncService.pendingCount, equals(1)); // 1 item remaining
      });
    });

    group('periodic flush', () {
      test('should flush on timer interval', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(
            batchSize: 100, // High batch size so auto-flush won't trigger
            batchInterval: const Duration(milliseconds: 200),
          ),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'item1'));

        expect(mockHttpClient.requestCount, equals(0));

        // Wait for timer - just over one interval but less than two
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(mockHttpClient.requestCount, equals(1));
        expect(syncService.syncedItems.length, equals(1));
      });
    });

    group('max queue size enforcement', () {
      test('should enforce max queue size with FIFO drop', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(
            batchSize: 100, // High batch size to prevent auto-flush
            maxQueueSize: 3,
          ),
          client: client,
        );
        syncService.initialize();

        // Queue 5 items
        for (var i = 1; i <= 5; i++) {
          syncService.queueItem(TestSyncItem(id: '$i', data: 'item$i'));
        }

        // Should only have 3 items (oldest dropped)
        expect(syncService.pendingCount, equals(3));

        // Flush to verify which items remain
        await syncService.flush();

        // Should have the last 3 items (items 3, 4, 5)
        expect(syncService.syncedItems.length, equals(3));
      });
    });

    group('status updates', () {
      test('should start with idle status', () {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
        );
        syncService.initialize();

        expect(syncService.status, equals(SyncStatus.idle));
      });

      test('should transition to syncing during flush', () async {
        final statusChanges = <SyncStatus>[];
        final client = mockHttpClient.createMockClient(
          delay: const Duration(milliseconds: 50),
        );
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
        );
        syncService.onStatusChanged = statusChanges.add;
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'item1'));

        // Start flush but don't wait
        final flushFuture = syncService.flush();

        // Should be syncing
        expect(statusChanges, contains(SyncStatus.syncing));

        await flushFuture;
      });

      test('should transition to success after successful flush', () async {
        final statusChanges = <SyncStatus>[];
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
        );
        syncService.onStatusChanged = statusChanges.add;
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'item1'));
        await syncService.flush();

        expect(statusChanges, contains(SyncStatus.success));
      });

      test('should transition to error after failed flush', () async {
        final statusChanges = <SyncStatus>[];
        final client = mockHttpClient.createMockClient(statusCode: 500);
        syncService = TestApiSyncService(
          config: createConfig(maxRetries: 1),
          client: client,
        );
        syncService.onStatusChanged = statusChanges.add;
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'item1'));
        await syncService.flush();

        expect(statusChanges, contains(SyncStatus.error));
      });

      test('should set disabled status for invalid config', () {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: const BaseSyncConfig(enabled: false),
          client: client,
        );
        syncService.initialize();

        expect(syncService.status, equals(SyncStatus.disabled));
      });
    });

    group('HTTP request format', () {
      test('should send POST request to correct endpoint', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
          endpoint: '/v1/events',
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test'));
        await syncService.flush();

        final request = mockHttpClient.lastRequest!;
        expect(request.method, equals('POST'));
        expect(request.url, endsWith('/v1/events'));
      });

      test('should include required headers', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test'));
        await syncService.flush();

        final request = mockHttpClient.lastRequest!;
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(request.headers['X-API-Key'], equals('test-api-key'));
        expect(request.headers['X-Project-Id'], equals('test-project-id'));
      });

      test('should send JSON formatted payload', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test-data'));
        await syncService.flush();

        final request = mockHttpClient.lastRequest!;
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['projectId'], equals('test-project-id'));
        expect(body['items'], isA<List>());
        expect((body['items'] as List).length, equals(1));
        expect((body['items'] as List).first['id'], equals('1'));
      });
    });

    group('error callback', () {
      test('should call onError callback on failure', () async {
        final errors = <(String, int)>[];
        final client = mockHttpClient.createMockClient(statusCode: 500);
        syncService = TestApiSyncService(
          config: createConfig(maxRetries: 2),
          client: client,
        );
        syncService.onError = (error, retryCount) {
          errors.add((error, retryCount));
        };
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test'));
        await syncService.flush();

        // maxRetries=2 means 1 initial + 2 retries = 3 total attempts
        expect(errors.length, equals(3));
        expect(errors[0].$2, equals(0)); // First attempt
        expect(errors[1].$2, equals(1)); // First retry
        expect(errors[2].$2, equals(2)); // Second retry
      });
    });

    group('queue management', () {
      test('should queue items when enabled', () {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(batchSize: 100),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test'));

        expect(syncService.pendingCount, equals(1));
      });

      test('should not queue items when disabled', () {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: const BaseSyncConfig(enabled: false),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test'));

        expect(syncService.pendingCount, equals(0));
      });

      test('should queue multiple items at once', () {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(batchSize: 100),
          client: client,
        );
        syncService.initialize();

        syncService.queueItems([
          TestSyncItem(id: '1', data: 'test1'),
          TestSyncItem(id: '2', data: 'test2'),
          TestSyncItem(id: '3', data: 'test3'),
        ]);

        expect(syncService.pendingCount, equals(3));
      });
    });

    group('empty queue handling', () {
      test('should return true when flushing empty queue', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(),
          client: client,
        );
        syncService.initialize();

        final result = await syncService.flush();

        expect(result, isTrue);
        expect(mockHttpClient.requestCount, equals(0));
      });
    });

    group('dispose behavior', () {
      test('should cancel batch timer on dispose', () async {
        final client = mockHttpClient.createMockClient();
        syncService = TestApiSyncService(
          config: createConfig(batchInterval: const Duration(milliseconds: 50)),
          client: client,
        );
        syncService.initialize();

        syncService.queueItem(TestSyncItem(id: '1', data: 'test'));
        syncService.dispose();

        // Wait past the timer interval
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Should not have made any requests since timer was cancelled
        expect(mockHttpClient.requestCount, equals(0));
      });
    });
  });
}
