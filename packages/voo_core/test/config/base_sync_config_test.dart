import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('BaseSyncConfig', () {
    group('constructor', () {
      test('should create with default values', () {
        const config = BaseSyncConfig();

        expect(config.enabled, isFalse);
        expect(config.endpoint, isNull);
        expect(config.apiKey, isNull);
        expect(config.projectId, isNull);
        expect(config.batchSize, equals(50));
        expect(config.batchInterval, equals(const Duration(seconds: 30)));
        expect(config.maxRetries, equals(3));
        expect(config.retryDelay, equals(const Duration(seconds: 1)));
        expect(config.timeout, equals(const Duration(seconds: 10)));
        expect(config.maxQueueSize, equals(1000));
        expect(config.headers, isNull);
      });

      test('should create with custom values', () {
        const config = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
          projectId: 'test-project',
          batchSize: 100,
          batchInterval: Duration(seconds: 60),
          maxRetries: 5,
          retryDelay: Duration(seconds: 2),
          timeout: Duration(seconds: 30),
          maxQueueSize: 2000,
          headers: {'X-Custom': 'value'},
        );

        expect(config.enabled, isTrue);
        expect(config.endpoint, equals('https://api.example.com'));
        expect(config.apiKey, equals('test-key'));
        expect(config.projectId, equals('test-project'));
        expect(config.batchSize, equals(100));
        expect(config.batchInterval, equals(const Duration(seconds: 60)));
        expect(config.maxRetries, equals(5));
        expect(config.retryDelay, equals(const Duration(seconds: 2)));
        expect(config.timeout, equals(const Duration(seconds: 30)));
        expect(config.maxQueueSize, equals(2000));
        expect(config.headers, equals({'X-Custom': 'value'}));
      });
    });

    group('production factory', () {
      test('should create production config with correct defaults', () {
        const config = BaseSyncConfig.production(
          endpoint: 'https://api.prod.com',
          apiKey: 'prod-key',
          projectId: 'prod-project',
        );

        expect(config.enabled, isTrue);
        expect(config.endpoint, equals('https://api.prod.com'));
        expect(config.apiKey, equals('prod-key'));
        expect(config.projectId, equals('prod-project'));
        expect(config.batchSize, equals(100));
        expect(config.batchInterval, equals(const Duration(seconds: 60)));
        expect(config.maxQueueSize, equals(2000));
      });
    });

    group('development factory', () {
      test('should create development config with smaller batches', () {
        const config = BaseSyncConfig.development(
          endpoint: 'https://api.dev.com',
          apiKey: 'dev-key',
          projectId: 'dev-project',
        );

        expect(config.enabled, isTrue);
        expect(config.endpoint, equals('https://api.dev.com'));
        expect(config.apiKey, equals('dev-key'));
        expect(config.projectId, equals('dev-project'));
        expect(config.batchSize, equals(20));
        expect(config.batchInterval, equals(const Duration(seconds: 15)));
        expect(config.maxQueueSize, equals(1000));
      });
    });

    group('isValid', () {
      test('should return false when disabled', () {
        const config = BaseSyncConfig(
          enabled: false,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
        );

        expect(config.isValid, isFalse);
      });

      test('should return false when endpoint is null', () {
        const config = BaseSyncConfig(
          enabled: true,
          endpoint: null,
          apiKey: 'test-key',
        );

        expect(config.isValid, isFalse);
      });

      test('should return false when endpoint is empty', () {
        const config = BaseSyncConfig(
          enabled: true,
          endpoint: '',
          apiKey: 'test-key',
        );

        expect(config.isValid, isFalse);
      });

      test('should return false when apiKey is null', () {
        const config = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: null,
        );

        expect(config.isValid, isFalse);
      });

      test('should return false when apiKey is empty', () {
        const config = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: '',
        );

        expect(config.isValid, isFalse);
      });

      test('should return true when properly configured', () {
        const config = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
        );

        expect(config.isValid, isTrue);
      });
    });

    group('getBackoffDelay', () {
      test('should return exponential backoff delays', () {
        const config = BaseSyncConfig(
          retryDelay: Duration(seconds: 1),
        );

        expect(config.getBackoffDelay(0), equals(const Duration(seconds: 1)));
        expect(config.getBackoffDelay(1), equals(const Duration(seconds: 2)));
        expect(config.getBackoffDelay(2), equals(const Duration(seconds: 4)));
        expect(config.getBackoffDelay(3), equals(const Duration(seconds: 8)));
      });

      test('should work with custom retry delay', () {
        const config = BaseSyncConfig(
          retryDelay: Duration(milliseconds: 500),
        );

        expect(config.getBackoffDelay(0), equals(const Duration(milliseconds: 500)));
        expect(config.getBackoffDelay(1), equals(const Duration(milliseconds: 1000)));
        expect(config.getBackoffDelay(2), equals(const Duration(milliseconds: 2000)));
      });
    });

    group('equality', () {
      test('should be equal when all properties match', () {
        const config1 = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
          projectId: 'test-project',
        );

        const config2 = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
          projectId: 'test-project',
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('should not be equal when properties differ', () {
        const config1 = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
        );

        const config2 = BaseSyncConfig(
          enabled: true,
          endpoint: 'https://api.other.com',
          apiKey: 'test-key',
        );

        expect(config1, isNot(equals(config2)));
      });
    });
  });

  group('SyncStatus', () {
    test('should have all expected values', () {
      expect(SyncStatus.values, containsAll([
        SyncStatus.disabled,
        SyncStatus.idle,
        SyncStatus.syncing,
        SyncStatus.success,
        SyncStatus.error,
      ]));
    });
  });
}
