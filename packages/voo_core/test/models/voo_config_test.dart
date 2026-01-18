import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooConfig', () {
    test('should create config with required fields', () {
      final config = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      expect(config.endpoint, 'https://api.example.com');
      expect(config.apiKey, 'test-api-key');
      expect(config.projectId, 'test-project-id');
      expect(config.organizationId, isNull);
      expect(config.environment, 'development');
      expect(config.enableCloudSync, true);
    });

    test('should create config with optional fields', () {
      final config = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
        organizationId: 'test-org-id',
        environment: 'production',
        enableCloudSync: false,
        batchSize: 100,
        syncInterval: const Duration(seconds: 60),
      );

      expect(config.organizationId, 'test-org-id');
      expect(config.environment, 'production');
      expect(config.enableCloudSync, false);
      expect(config.batchSize, 100);
      expect(config.syncInterval, const Duration(seconds: 60));
    });

    test('should generate correct endpoint URLs', () {
      final config = VooConfig(
        endpoint: 'https://api.example.com/api',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      expect(config.logsEndpoint, 'https://api.example.com/api/v1/telemetry/logs');
      expect(config.analyticsEndpoint, 'https://api.example.com/api/v1/telemetry/analytics');
      expect(config.performanceEndpoint, 'https://api.example.com/api/v1/telemetry/performance');
    });

    test('should validate config correctly', () {
      final validConfig = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      final invalidConfig = VooConfig(
        endpoint: '',
        apiKey: '',
        projectId: '',
      );

      expect(validConfig.isValid, true);
      expect(invalidConfig.isValid, false);
    });

    test('should create production config with sensible defaults', () {
      final config = VooConfig.production(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      expect(config.environment, 'production');
      expect(config.batchSize, 100);
      expect(config.syncInterval, const Duration(seconds: 60));
    });

    test('should create development config with more frequent syncing', () {
      final config = VooConfig.development(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      expect(config.environment, 'development');
      expect(config.batchSize, 20);
      expect(config.syncInterval, const Duration(seconds: 15));
    });

    test('should create local-only config without cloud sync', () {
      final config = VooConfig.localOnly();

      expect(config.enableCloudSync, false);
      expect(config.endpoint, '');
      expect(config.apiKey, '');
    });

    test('should support copyWith', () {
      final original = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      final modified = original.copyWith(
        environment: 'staging',
        batchSize: 50,
      );

      expect(modified.endpoint, original.endpoint);
      expect(modified.apiKey, original.apiKey);
      expect(modified.projectId, original.projectId);
      expect(modified.environment, 'staging');
      expect(modified.batchSize, 50);
    });

    test('should serialize to and from JSON', () {
      final config = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
        organizationId: 'test-org-id',
        environment: 'production',
      );

      final json = config.toJson();
      final restored = VooConfig.fromJson(json);

      expect(restored.endpoint, config.endpoint);
      expect(restored.apiKey, config.apiKey);
      expect(restored.projectId, config.projectId);
      expect(restored.organizationId, config.organizationId);
      expect(restored.environment, config.environment);
    });

    test('should implement equality correctly', () {
      final config1 = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      final config2 = VooConfig(
        endpoint: 'https://api.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      final config3 = VooConfig(
        endpoint: 'https://different.example.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
      expect(config1.hashCode, equals(config2.hashCode));
    });
  });
}
