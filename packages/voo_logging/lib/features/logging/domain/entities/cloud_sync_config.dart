import 'package:flutter/foundation.dart';

/// Configuration for cloud sync of logs to a backend API.
///
/// ## Basic Setup
///
/// ```dart
/// await VooLogger.initialize(
///   config: LoggingConfig(
///     cloudSync: CloudSyncConfig(
///       enabled: true,
///       endpoint: 'https://api.yourbackend.com',
///       apiKey: 'your-api-key',
///       projectId: 'your-project-id',
///     ),
///   ),
/// );
/// ```
///
/// ## Configuration Options
///
/// - [endpoint]: Base URL for the logging API
/// - [apiKey]: Authentication key for the API
/// - [projectId]: Project identifier for multi-project support
/// - [batchSize]: Number of logs to batch before sending (default: 50)
/// - [batchInterval]: Time interval for automatic batch flush (default: 30s)
/// - [maxRetries]: Number of retry attempts on failure (default: 3)
/// - [retryDelay]: Delay between retries (default: 1s)
/// - [syncMinimumLevel]: Only sync logs at or above this level
@immutable
class CloudSyncConfig {
  /// Whether cloud sync is enabled.
  final bool enabled;

  /// Base URL for the logging API (e.g., 'https://api.devstack.io').
  final String? endpoint;

  /// API key for authentication.
  final String? apiKey;

  /// Project ID for multi-project support.
  final String? projectId;

  /// Number of logs to accumulate before sending a batch.
  final int batchSize;

  /// Time interval for automatic batch flush.
  final Duration batchInterval;

  /// Maximum number of retry attempts on failure.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// HTTP timeout for requests.
  final Duration timeout;

  /// Only sync logs at or above this level (null = sync all).
  final String? syncMinimumLevel;

  /// Custom headers to include in requests.
  final Map<String, String>? headers;

  /// Whether to compress request payloads.
  final bool enableCompression;

  /// Whether to sync immediately for error/fatal logs.
  final bool prioritizeErrors;

  /// Maximum number of logs to queue locally before dropping old ones.
  final int maxQueueSize;

  const CloudSyncConfig({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.projectId,
    this.batchSize = 50,
    this.batchInterval = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 10),
    this.syncMinimumLevel,
    this.headers,
    this.enableCompression = false,
    this.prioritizeErrors = true,
    this.maxQueueSize = 1000,
  });

  /// Creates a production-ready configuration.
  factory CloudSyncConfig.production({
    required String endpoint,
    required String apiKey,
    required String projectId,
  }) =>
      CloudSyncConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        projectId: projectId,
        batchSize: 100,
        batchInterval: const Duration(seconds: 60),
        syncMinimumLevel: 'info',
        prioritizeErrors: true,
        maxQueueSize: 2000,
      );

  /// Creates a development configuration with smaller batches.
  factory CloudSyncConfig.development({
    required String endpoint,
    required String apiKey,
    required String projectId,
  }) =>
      CloudSyncConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        projectId: projectId,
        batchSize: 10,
        batchInterval: const Duration(minutes: 10),
        prioritizeErrors: true,
      );

  /// Validates that the configuration is complete for syncing.
  bool get isValid => enabled && endpoint != null && endpoint!.isNotEmpty && apiKey != null && apiKey!.isNotEmpty;

  /// Returns the full endpoint URL for log ingestion.
  /// Uses VooDevStackAPI's batch endpoint format.
  /// Expects endpoint to already include '/api' base path (e.g., 'http://localhost:5001/api').
  String? get logEndpoint => endpoint != null ? '$endpoint/v1/logs/batch' : null;

  CloudSyncConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? apiKey,
    String? projectId,
    int? batchSize,
    Duration? batchInterval,
    int? maxRetries,
    Duration? retryDelay,
    Duration? timeout,
    String? syncMinimumLevel,
    Map<String, String>? headers,
    bool? enableCompression,
    bool? prioritizeErrors,
    int? maxQueueSize,
  }) =>
      CloudSyncConfig(
        enabled: enabled ?? this.enabled,
        endpoint: endpoint ?? this.endpoint,
        apiKey: apiKey ?? this.apiKey,
        projectId: projectId ?? this.projectId,
        batchSize: batchSize ?? this.batchSize,
        batchInterval: batchInterval ?? this.batchInterval,
        maxRetries: maxRetries ?? this.maxRetries,
        retryDelay: retryDelay ?? this.retryDelay,
        timeout: timeout ?? this.timeout,
        syncMinimumLevel: syncMinimumLevel ?? this.syncMinimumLevel,
        headers: headers ?? this.headers,
        enableCompression: enableCompression ?? this.enableCompression,
        prioritizeErrors: prioritizeErrors ?? this.prioritizeErrors,
        maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CloudSyncConfig &&
        other.enabled == enabled &&
        other.endpoint == endpoint &&
        other.apiKey == apiKey &&
        other.projectId == projectId &&
        other.batchSize == batchSize &&
        other.batchInterval == batchInterval &&
        other.maxRetries == maxRetries &&
        other.retryDelay == retryDelay &&
        other.timeout == timeout &&
        other.syncMinimumLevel == syncMinimumLevel &&
        other.enableCompression == enableCompression &&
        other.prioritizeErrors == prioritizeErrors &&
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
        syncMinimumLevel,
        enableCompression,
        prioritizeErrors,
        maxQueueSize,
      );
}
