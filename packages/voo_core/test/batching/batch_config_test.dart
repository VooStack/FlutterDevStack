import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('BatchConfig', () {
    group('constructor', () {
      test('should create with default values', () {
        const config = BatchConfig();

        expect(config.batchSize, equals(100));
        expect(config.batchInterval, equals(const Duration(seconds: 30)));
        expect(config.priorityFlushInterval, equals(const Duration(seconds: 5)));
        expect(config.enableCompression, isTrue);
        expect(config.compressionThreshold, equals(1024));
        expect(config.maxQueueSize, equals(5000));
        expect(config.maxRetention, equals(const Duration(days: 7)));
        expect(config.enableNetworkAwareBatching, isTrue);
      });

      test('should create with custom values', () {
        const config = BatchConfig(
          batchSize: 50,
          batchInterval: Duration(seconds: 60),
          priorityFlushInterval: Duration(seconds: 10),
          enableCompression: false,
          compressionThreshold: 2048,
          maxQueueSize: 1000,
          maxRetention: Duration(days: 1),
          enableNetworkAwareBatching: false,
        );

        expect(config.batchSize, equals(50));
        expect(config.batchInterval, equals(const Duration(seconds: 60)));
        expect(config.enableCompression, isFalse);
        expect(config.enableNetworkAwareBatching, isFalse);
      });
    });

    group('factory constructors', () {
      test('should create wifi config', () {
        final config = BatchConfig.wifi();

        expect(config.batchSize, equals(100));
        expect(config.batchInterval, equals(const Duration(seconds: 30)));
        expect(config.compressionThreshold, equals(1024));
      });

      test('should create cellular config', () {
        final config = BatchConfig.cellular();

        expect(config.batchSize, equals(25));
        expect(config.batchInterval, equals(const Duration(seconds: 120)));
        expect(config.compressionThreshold, equals(512));
      });

      test('should create offline config', () {
        final config = BatchConfig.offline();

        expect(config.batchSize, equals(50));
        expect(config.batchInterval, equals(const Duration(minutes: 5)));
      });

      test('should create debug config', () {
        final config = BatchConfig.debug();

        expect(config.batchSize, equals(10));
        expect(config.batchInterval, equals(const Duration(seconds: 10)));
        expect(config.enableCompression, isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with modified values', () {
        const original = BatchConfig(batchSize: 100);
        final copy = original.copyWith(batchSize: 50);

        expect(copy.batchSize, equals(50));
        expect(copy.batchInterval, equals(original.batchInterval));
        expect(copy.enableCompression, equals(original.enableCompression));
      });

      test('should preserve unmodified values', () {
        const original = BatchConfig(
          batchSize: 100,
          enableCompression: false,
          maxQueueSize: 2000,
        );
        final copy = original.copyWith(batchSize: 50);

        expect(copy.enableCompression, isFalse);
        expect(copy.maxQueueSize, equals(2000));
      });
    });

    group('equality', () {
      test('should be equal for same values', () {
        const config1 = BatchConfig(batchSize: 50);
        const config2 = BatchConfig(batchSize: 50);

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('should not be equal for different values', () {
        const config1 = BatchConfig(batchSize: 50);
        const config2 = BatchConfig(batchSize: 100);

        expect(config1, isNot(equals(config2)));
      });
    });
  });

  group('NetworkType', () {
    test('should have all expected values', () {
      expect(NetworkType.values, contains(NetworkType.wifi));
      expect(NetworkType.values, contains(NetworkType.cellular));
      expect(NetworkType.values, contains(NetworkType.ethernet));
      expect(NetworkType.values, contains(NetworkType.none));
      expect(NetworkType.values, contains(NetworkType.unknown));
    });
  });

  group('BatchPriority', () {
    test('should have correct values', () {
      expect(BatchPriority.high.value, equals(0));
      expect(BatchPriority.normal.value, equals(1));
      expect(BatchPriority.low.value, equals(2));
    });

    test('should flush immediately for high priority', () {
      expect(BatchPriority.high.shouldFlushImmediately, isTrue);
      expect(BatchPriority.normal.shouldFlushImmediately, isFalse);
      expect(BatchPriority.low.shouldFlushImmediately, isFalse);
    });
  });
}
