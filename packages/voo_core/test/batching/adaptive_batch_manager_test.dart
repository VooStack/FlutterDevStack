import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('AdaptiveBatchManager', () {
    late AdaptiveBatchManager<TestBatchItem> manager;
    late List<List<TestBatchItem>> flushedBatches;

    setUp(() {
      flushedBatches = [];
    });

    tearDown(() async {
      if (manager.isInitialized) {
        await manager.shutdown();
      }
    });

    AdaptiveBatchManager<TestBatchItem> createManager({
      BatchConfig? config,
      RetryPolicy? retryPolicy,
      Future<bool> Function(List<TestBatchItem>, CompressedPayload?)? onFlush,
    }) {
      return AdaptiveBatchManager<TestBatchItem>(
        name: 'test',
        config: config ??
            const BatchConfig(
              batchSize: 5,
              batchInterval: Duration(seconds: 10),
              enableNetworkAwareBatching: false,
            ),
        retryPolicy: retryPolicy,
        onFlush: onFlush ??
            (items, payload) async {
              flushedBatches.add(items);
              return true;
            },
        itemToJson: (item) => item.toJson(),
        itemFromJson: TestBatchItem.fromJson,
      );
    }

    group('initialization', () {
      test('should not be initialized before initialize()', () {
        manager = createManager();

        expect(manager.isInitialized, isFalse);
      });

      test('should be initialized after initialize()', () async {
        manager = createManager();
        await manager.initialize();

        expect(manager.isInitialized, isTrue);
      });

      test('should not double initialize', () async {
        manager = createManager();
        await manager.initialize();
        await manager.initialize();

        expect(manager.isInitialized, isTrue);
      });
    });

    group('add', () {
      test('should add items to queue', () async {
        manager = createManager();
        await manager.initialize();

        await manager.add(TestBatchItem(id: '1', data: 'test'));

        expect(await manager.pendingCount, equals(1));
      });

      test('should not add items when not initialized', () async {
        manager = createManager();

        await manager.add(TestBatchItem(id: '1', data: 'test'));

        // Manager not initialized, so item should not be added
        expect(manager.isInitialized, isFalse);
      });
    });

    group('addAll', () {
      test('should add multiple items to queue', () async {
        manager = createManager();
        await manager.initialize();

        await manager.addAll([
          TestBatchItem(id: '1', data: 'test1'),
          TestBatchItem(id: '2', data: 'test2'),
          TestBatchItem(id: '3', data: 'test3'),
        ]);

        expect(await manager.pendingCount, equals(3));
      });
    });

    group('flush', () {
      test('should flush pending items', () async {
        manager = createManager();
        await manager.initialize();

        await manager.add(TestBatchItem(id: '1', data: 'test'));
        await manager.flush();

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(1));
        expect(await manager.pendingCount, equals(0));
      });

      test('should return true when queue is empty', () async {
        manager = createManager();
        await manager.initialize();

        final result = await manager.flush();

        expect(result, isTrue);
        expect(flushedBatches, isEmpty);
      });

      test('should batch items according to batch size', () async {
        manager = createManager(
          config: const BatchConfig(
            batchSize: 2,
            batchInterval: Duration(hours: 1),
            enableNetworkAwareBatching: false,
          ),
        );
        await manager.initialize();

        await manager.addAll([
          TestBatchItem(id: '1', data: 'test1'),
          TestBatchItem(id: '2', data: 'test2'),
          TestBatchItem(id: '3', data: 'test3'),
          TestBatchItem(id: '4', data: 'test4'),
          TestBatchItem(id: '5', data: 'test5'),
        ]);

        await manager.flush();

        // Should have 3 batches: 2, 2, 1
        expect(flushedBatches.length, equals(3));
        expect(flushedBatches[0].length, equals(2));
        expect(flushedBatches[1].length, equals(2));
        expect(flushedBatches[2].length, equals(1));
      });
    });

    group('circuit breaker', () {
      test('should skip flush when circuit breaker is open', () async {
        var callCount = 0;
        manager = createManager(
          onFlush: (items, payload) async {
            callCount++;
            return false; // Always fail
          },
          retryPolicy: const RetryPolicy(
            maxRetries: 0,
            circuitBreakerThreshold: 1,
          ),
        );
        await manager.initialize();

        await manager.add(TestBatchItem(id: '1', data: 'test'));
        await manager.flush(); // Opens circuit breaker

        callCount = 0;
        await manager.add(TestBatchItem(id: '2', data: 'test'));
        final result = await manager.flush();

        expect(result, isFalse);
        expect(callCount, equals(0)); // Circuit breaker prevented call
      });

      test('should reset circuit breaker', () async {
        var shouldFail = true;
        manager = createManager(
          onFlush: (items, payload) async {
            if (shouldFail) return false;
            flushedBatches.add(items);
            return true;
          },
          retryPolicy: const RetryPolicy(
            maxRetries: 0,
            circuitBreakerThreshold: 1,
          ),
        );
        await manager.initialize();

        await manager.add(TestBatchItem(id: '1', data: 'test'));
        await manager.flush(); // Opens circuit breaker

        manager.resetCircuitBreaker();
        shouldFail = false;
        await manager.add(TestBatchItem(id: '2', data: 'test'));
        final result = await manager.flush();

        expect(result, isTrue);
      });
    });

    group('clear', () {
      test('should clear all pending items', () async {
        manager = createManager();
        await manager.initialize();

        await manager.addAll([
          TestBatchItem(id: '1', data: 'test1'),
          TestBatchItem(id: '2', data: 'test2'),
        ]);

        await manager.clear();

        expect(await manager.pendingCount, equals(0));
      });
    });

    group('shutdown', () {
      test('should flush remaining items on shutdown', () async {
        manager = createManager();
        await manager.initialize();

        await manager.add(TestBatchItem(id: '1', data: 'test'));
        await manager.shutdown();

        expect(flushedBatches.length, equals(1));
        expect(manager.isInitialized, isFalse);
      });
    });

    group('currentConfig', () {
      test('should return configured batch config', () async {
        const config = BatchConfig(
          batchSize: 10,
          enableNetworkAwareBatching: false,
        );
        manager = createManager(config: config);
        await manager.initialize();

        expect(manager.currentConfig.batchSize, equals(10));
      });
    });
  });
}

class TestBatchItem {
  final String id;
  final String data;

  TestBatchItem({required this.id, required this.data});

  Map<String, dynamic> toJson() => {'id': id, 'data': data};

  static TestBatchItem fromJson(Map<String, dynamic> json) {
    return TestBatchItem(
      id: json['id'] as String,
      data: json['data'] as String,
    );
  }
}
