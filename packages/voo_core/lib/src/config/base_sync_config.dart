import 'package:flutter/foundation.dart';

/// Base configuration for cloud sync services.
///
/// This class provides common configuration options shared across
/// all telemetry sync services (logging, analytics, performance).
///
/// ## Usage
///
/// Subclasses should extend this class and add any domain-specific
/// configuration options they need.
///
/// ```dart
/// class LoggingSyncConfig extends BaseSyncConfig {
///   final String? syncMinimumLevel;
///   final bool prioritizeErrors;
///
///   const LoggingSyncConfig({
///     super.enabled,
///     super.endpoint,
///     super.apiKey,
///     super.projectId,
///     this.syncMinimumLevel,
///     this.prioritizeErrors = true,
///   });
/// }
/// ```
@immutable
class BaseSyncConfig {
  /// Whether cloud sync is enabled.
  final bool enabled;

  /// Base URL for the API endpoint.
  final String? endpoint;

  /// API key for authentication (sent as X-API-Key header).
  final String? apiKey;

  /// Project ID for multi-project support.
  final String? projectId;

  /// Number of items to accumulate before sending a batch.
  final int batchSize;

  /// Time interval for automatic batch flush.
  final Duration batchInterval;

  /// Maximum number of retry attempts on failure.
  final int maxRetries;

  /// Delay between retry attempts (used for exponential backoff).
  final Duration retryDelay;

  /// HTTP timeout for requests.
  final Duration timeout;

  /// Maximum number of items to queue locally before dropping old ones.
  final int maxQueueSize;

  /// Custom headers to include in requests.
  final Map<String, String>? headers;

  const BaseSyncConfig({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.projectId,
    this.batchSize = 50,
    this.batchInterval = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 10),
    this.maxQueueSize = 1000,
    this.headers,
  });

  /// Creates a production-ready configuration with larger batches and intervals.
  const BaseSyncConfig.production({
    required String this.endpoint,
    required String this.apiKey,
    required String this.projectId,
    this.headers,
  })  : enabled = true,
        batchSize = 100,
        batchInterval = const Duration(seconds: 60),
        maxRetries = 3,
        retryDelay = const Duration(seconds: 1),
        timeout = const Duration(seconds: 10),
        maxQueueSize = 2000;

  /// Creates a development configuration with smaller batches for faster feedback.
  const BaseSyncConfig.development({
    required String this.endpoint,
    required String this.apiKey,
    required String this.projectId,
    this.headers,
  })  : enabled = true,
        batchSize = 20,
        batchInterval = const Duration(seconds: 15),
        maxRetries = 3,
        retryDelay = const Duration(seconds: 1),
        timeout = const Duration(seconds: 10),
        maxQueueSize = 1000;

  /// Validates that the configuration is complete for syncing.
  bool get isValid =>
      enabled &&
      endpoint != null &&
      endpoint!.isNotEmpty &&
      apiKey != null &&
      apiKey!.isNotEmpty;

  /// Returns the exponential backoff delay for a given attempt number.
  Duration getBackoffDelay(int attempt) {
    return retryDelay * (1 << attempt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseSyncConfig &&
        other.enabled == enabled &&
        other.endpoint == endpoint &&
        other.apiKey == apiKey &&
        other.projectId == projectId &&
        other.batchSize == batchSize &&
        other.batchInterval == batchInterval &&
        other.maxRetries == maxRetries &&
        other.retryDelay == retryDelay &&
        other.timeout == timeout &&
        other.maxQueueSize == maxQueueSize;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        endpoint,
        apiKey,
        projectId,
        batchSize,
        batchInterval,
        maxRetries,
        retryDelay,
        timeout,
        maxQueueSize,
      );
}

/// Status of a cloud sync service.
enum SyncStatus {
  /// Sync is disabled or not configured.
  disabled,

  /// Service is idle, ready to sync.
  idle,

  /// Currently syncing items.
  syncing,

  /// Recent sync succeeded.
  success,

  /// Recent sync failed.
  error,
}
