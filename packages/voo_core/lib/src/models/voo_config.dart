import 'package:flutter/foundation.dart';

/// Primary configuration for Voo SDK initialization.
///
/// This is the main configuration class passed to [Voo.initializeApp].
/// It contains the essential API configuration needed for telemetry sync.
///
/// The API key is the primary identifier - the server derives the project
/// from the API key, so `projectId` is optional and only used for local
/// reference or debugging.
///
/// Example usage:
/// ```dart
/// await Voo.initializeApp(
///   config: VooConfig(
///     endpoint: 'https://api.example.com/api',
///     apiKey: 'your-api-key',
///   ),
/// );
/// ```
@immutable
class VooConfig {
  /// The base API endpoint for telemetry services.
  ///
  /// Should include the base path if applicable (e.g., 'https://api.example.com/api').
  /// Child packages will append their specific paths (e.g., '/v1/telemetry/logs').
  final String endpoint;

  /// The API key for authenticating telemetry requests.
  ///
  /// This is the primary identifier. The server derives the project from
  /// this key, so explicit projectId is not required.
  final String apiKey;

  /// The project ID (optional, for local reference only).
  ///
  /// The server derives the actual project from the API key, so this field
  /// is not required for cloud sync. It may be useful for local debugging
  /// or filtering.
  final String? projectId;

  /// The organization ID (optional, for multi-org support).
  final String? organizationId;

  /// The environment name ('development', 'staging', 'production').
  ///
  /// Defaults to 'development'. Used for filtering and routing telemetry.
  final String environment;

  /// Whether cloud sync is enabled.
  ///
  /// When false, telemetry is only stored locally.
  final bool enableCloudSync;

  /// Batch size for sync operations.
  ///
  /// Number of items to batch before sending to the server.
  final int batchSize;

  /// Interval between automatic sync flushes.
  final Duration syncInterval;

  const VooConfig({
    required this.endpoint,
    required this.apiKey,
    this.projectId,
    this.organizationId,
    this.environment = 'development',
    this.enableCloudSync = true,
    this.batchSize = 50,
    this.syncInterval = const Duration(seconds: 30),
  });

  /// Creates a production configuration with sensible defaults.
  factory VooConfig.production({
    required String endpoint,
    required String apiKey,
    String? projectId,
    String? organizationId,
  }) {
    return VooConfig(
      endpoint: endpoint,
      apiKey: apiKey,
      projectId: projectId,
      organizationId: organizationId,
      environment: 'production',
      enableCloudSync: true,
      batchSize: 100,
      syncInterval: const Duration(seconds: 60),
    );
  }

  /// Creates a development configuration with more frequent syncing.
  factory VooConfig.development({
    required String endpoint,
    required String apiKey,
    String? projectId,
    String? organizationId,
  }) {
    return VooConfig(
      endpoint: endpoint,
      apiKey: apiKey,
      projectId: projectId,
      organizationId: organizationId,
      environment: 'development',
      enableCloudSync: true,
      batchSize: 20,
      syncInterval: const Duration(seconds: 15),
    );
  }

  /// Creates a local-only configuration (no cloud sync).
  factory VooConfig.localOnly({
    String? projectId,
    String? organizationId,
  }) {
    return VooConfig(
      endpoint: '',
      apiKey: '',
      projectId: projectId ?? 'local',
      organizationId: organizationId,
      environment: 'development',
      enableCloudSync: false,
    );
  }

  /// Full endpoint URL for logs ingestion.
  String get logsEndpoint => '$endpoint/v1/telemetry/logs';

  /// Full endpoint URL for analytics events ingestion.
  String get analyticsEndpoint => '$endpoint/v1/telemetry/analytics';

  /// Full endpoint URL for performance metrics ingestion.
  String get performanceEndpoint => '$endpoint/v1/telemetry/performance';

  /// Whether this configuration is valid for cloud sync.
  ///
  /// Returns true if endpoint and API key are present.
  /// The API key is sufficient - the server derives project from it.
  bool get isValid => endpoint.isNotEmpty && apiKey.isNotEmpty;

  /// Creates a copy with the given fields replaced.
  VooConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? projectId,
    String? organizationId,
    String? environment,
    bool? enableCloudSync,
    int? batchSize,
    Duration? syncInterval,
  }) {
    return VooConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      projectId: projectId ?? this.projectId,
      organizationId: organizationId ?? this.organizationId,
      environment: environment ?? this.environment,
      enableCloudSync: enableCloudSync ?? this.enableCloudSync,
      batchSize: batchSize ?? this.batchSize,
      syncInterval: syncInterval ?? this.syncInterval,
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'apiKey': apiKey,
        if (projectId != null) 'projectId': projectId,
        if (organizationId != null) 'organizationId': organizationId,
        'environment': environment,
        'enableCloudSync': enableCloudSync,
        'batchSize': batchSize,
        'syncIntervalMs': syncInterval.inMilliseconds,
      };

  /// Creates a VooConfig from a JSON map.
  factory VooConfig.fromJson(Map<String, dynamic> json) {
    return VooConfig(
      endpoint: json['endpoint'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      projectId: json['projectId'] as String?,
      organizationId: json['organizationId'] as String?,
      environment: json['environment'] as String? ?? 'development',
      enableCloudSync: json['enableCloudSync'] as bool? ?? true,
      batchSize: json['batchSize'] as int? ?? 50,
      syncInterval: Duration(
        milliseconds: json['syncIntervalMs'] as int? ?? 30000,
      ),
    );
  }

  @override
  String toString() {
    return 'VooConfig(endpoint: $endpoint, projectId: $projectId, '
        'organizationId: $organizationId, environment: $environment)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VooConfig &&
        other.endpoint == endpoint &&
        other.apiKey == apiKey &&
        other.projectId == projectId &&
        other.organizationId == organizationId &&
        other.environment == environment &&
        other.enableCloudSync == enableCloudSync &&
        other.batchSize == batchSize &&
        other.syncInterval == syncInterval;
  }

  @override
  int get hashCode {
    return Object.hash(
      endpoint,
      apiKey,
      projectId,
      organizationId,
      environment,
      enableCloudSync,
      batchSize,
      syncInterval,
    );
  }
}
