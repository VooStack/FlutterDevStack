import 'package:voo_core/voo_core.dart';

/// Pre-built configuration fixtures for testing.
class ConfigFixtures {
  /// A valid BaseSyncConfig for testing.
  static BaseSyncConfig validBaseSyncConfig({
    bool enabled = true,
    int batchSize = 5,
    Duration batchInterval = const Duration(seconds: 30),
    int maxRetries = 3,
    int maxQueueSize = 100,
  }) => BaseSyncConfig(
    enabled: enabled,
    endpoint: 'https://api.test.com',
    apiKey: 'test-api-key',
    projectId: 'test-project-id',
    batchSize: batchSize,
    batchInterval: batchInterval,
    maxRetries: maxRetries,
    maxQueueSize: maxQueueSize,
  );

  /// A disabled BaseSyncConfig for testing.
  static BaseSyncConfig disabledBaseSyncConfig() => const BaseSyncConfig();

  /// A BaseSyncConfig missing endpoint for testing validation.
  static BaseSyncConfig invalidBaseSyncConfig() => const BaseSyncConfig(enabled: true, apiKey: 'key');

  /// A valid VooConfig for production-like testing.
  static VooConfig productionVooConfig({String endpoint = 'https://api.test.com', String apiKey = 'test-api-key', String projectId = 'test-project-id'}) =>
      VooConfig.production(endpoint: endpoint, apiKey: apiKey, projectId: projectId);

  /// A valid VooConfig for development-like testing.
  static VooConfig developmentVooConfig({String endpoint = 'https://api.test.com', String apiKey = 'test-api-key', String projectId = 'test-project-id'}) =>
      VooConfig.development(endpoint: endpoint, apiKey: apiKey, projectId: projectId);

  /// A local-only VooConfig for offline testing.
  static VooConfig localOnlyVooConfig() => VooConfig.localOnly();
}
