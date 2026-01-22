import 'package:voo_telemetry/voo_telemetry.dart';

/// OpenTelemetry configuration for VooLogger.
///
/// Configure OTLP export settings for logs including endpoint,
/// authentication, batching, and resource attributes.
///
/// **DEPRECATED**: This class is deprecated and will be removed in a future version.
/// Configuration is now managed through [VooTelemetry.initialize()] with [TelemetryConfig].
///
/// To migrate:
/// 1. Remove otelConfig from LoggingConfig
/// 2. Configure telemetry through VooTelemetry.initialize() instead
/// 3. Logs will automatically flow through VooTelemetry when it's initialized
@Deprecated(
  'OtelLoggingConfig is deprecated. Use VooTelemetry.initialize() with TelemetryConfig instead.',
)
class OtelLoggingConfig {
  /// Whether OTEL export is enabled.
  final bool enabled;

  /// OTLP endpoint URL (e.g., 'https://otel-collector.example.com').
  final String? endpoint;

  /// API key for authentication.
  final String? apiKey;

  /// Service name for Resource attribute.
  final String serviceName;

  /// Service version for Resource attribute.
  final String serviceVersion;

  /// Additional Resource attributes.
  final Map<String, dynamic>? additionalAttributes;

  /// Number of logs to batch before sending.
  final int batchSize;

  /// Interval between automatic flushes.
  final Duration batchInterval;

  /// Maximum number of logs to queue before dropping oldest.
  final int maxQueueSize;

  /// HTTP timeout for OTLP requests.
  final Duration timeout;

  /// Maximum retry attempts for failed exports.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Whether to immediately flush error/fatal logs.
  final bool prioritizeErrors;

  /// Additional HTTP headers for OTLP requests.
  final Map<String, String>? headers;

  /// Enable debug logging for the exporter.
  final bool debug;

  /// Instrumentation scope name.
  final String instrumentationScopeName;

  /// Instrumentation scope version.
  final String instrumentationScopeVersion;

  const OtelLoggingConfig({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.serviceName = 'voo-flutter-app',
    this.serviceVersion = '1.0.0',
    this.additionalAttributes,
    this.batchSize = 50,
    this.batchInterval = const Duration(seconds: 30),
    this.maxQueueSize = 1000,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.prioritizeErrors = true,
    this.headers,
    this.debug = false,
    this.instrumentationScopeName = 'voo-logging',
    this.instrumentationScopeVersion = '2.0.0',
  });

  /// Check if configuration is valid for export.
  bool get isValid => enabled && endpoint != null && endpoint!.isNotEmpty;

  /// Build TelemetryResource with standard OTEL attributes.
  TelemetryResource buildResource() => TelemetryResource(
        serviceName: serviceName,
        serviceVersion: serviceVersion,
        attributes: {
          'service.name': serviceName,
          'service.version': serviceVersion,
          'telemetry.sdk.name': 'voo-logging',
          'telemetry.sdk.version': instrumentationScopeVersion,
          'telemetry.sdk.language': 'dart',
          ...?additionalAttributes,
        },
      );

  /// Create a production-ready configuration.
  ///
  /// Optimized for production use with larger batch sizes and
  /// longer intervals to reduce network overhead.
  factory OtelLoggingConfig.production({
    required String endpoint,
    required String apiKey,
    String serviceName = 'voo-flutter-app',
    String serviceVersion = '1.0.0',
  }) =>
      OtelLoggingConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        serviceName: serviceName,
        serviceVersion: serviceVersion,
        batchSize: 100,
        batchInterval: const Duration(seconds: 60),
        maxQueueSize: 2000,
      );

  /// Create a development configuration.
  ///
  /// Smaller batch sizes and shorter intervals for faster feedback.
  factory OtelLoggingConfig.development({
    required String endpoint,
    String? apiKey,
    String serviceName = 'voo-flutter-app-dev',
    String serviceVersion = '1.0.0-dev',
  }) =>
      OtelLoggingConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        serviceName: serviceName,
        serviceVersion: serviceVersion,
        batchSize: 10,
        batchInterval: const Duration(seconds: 10),
        maxQueueSize: 500,
        debug: true,
      );

  /// Copy with modifications.
  OtelLoggingConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? apiKey,
    String? serviceName,
    String? serviceVersion,
    Map<String, dynamic>? additionalAttributes,
    int? batchSize,
    Duration? batchInterval,
    int? maxQueueSize,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
    bool? prioritizeErrors,
    Map<String, String>? headers,
    bool? debug,
  }) =>
      OtelLoggingConfig(
        enabled: enabled ?? this.enabled,
        endpoint: endpoint ?? this.endpoint,
        apiKey: apiKey ?? this.apiKey,
        serviceName: serviceName ?? this.serviceName,
        serviceVersion: serviceVersion ?? this.serviceVersion,
        additionalAttributes: additionalAttributes ?? this.additionalAttributes,
        batchSize: batchSize ?? this.batchSize,
        batchInterval: batchInterval ?? this.batchInterval,
        maxQueueSize: maxQueueSize ?? this.maxQueueSize,
        timeout: timeout ?? this.timeout,
        maxRetries: maxRetries ?? this.maxRetries,
        retryDelay: retryDelay ?? this.retryDelay,
        prioritizeErrors: prioritizeErrors ?? this.prioritizeErrors,
        headers: headers ?? this.headers,
        debug: debug ?? this.debug,
      );
}
