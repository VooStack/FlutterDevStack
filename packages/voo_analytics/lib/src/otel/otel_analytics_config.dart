/// Configuration for OpenTelemetry analytics integration.
///
/// When enabled, analytics events will be exported as OTEL signals:
/// - Screen views become Spans
/// - Touch events become Metrics (Counter/Histogram)
/// - Custom events become Span Events
/// - Funnels become linked Spans
class OtelAnalyticsConfig {
  /// Whether OTEL export is enabled.
  final bool enabled;

  /// OTLP collector endpoint.
  final String? endpoint;

  /// Optional API key for authentication.
  final String? apiKey;

  /// Service name for OTEL resource.
  final String serviceName;

  /// Service version for OTEL resource.
  final String serviceVersion;

  /// Whether to export screen views as spans.
  final bool exportScreenViews;

  /// Whether to export touch events as metrics.
  final bool exportTouchMetrics;

  /// Whether to export custom events as span events.
  final bool exportCustomEvents;

  /// Whether to export funnel tracking as linked spans.
  final bool exportFunnels;

  /// Whether to add trace correlation to replay events.
  final bool correlateReplay;

  /// Batch size for OTLP export.
  final int batchSize;

  /// Batch interval for OTLP export.
  final Duration batchInterval;

  const OtelAnalyticsConfig({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.serviceName = 'voo-analytics',
    this.serviceVersion = '1.0.0',
    this.exportScreenViews = true,
    this.exportTouchMetrics = true,
    this.exportCustomEvents = true,
    this.exportFunnels = true,
    this.correlateReplay = true,
    this.batchSize = 50,
    this.batchInterval = const Duration(seconds: 5),
  });

  /// Create a production configuration.
  factory OtelAnalyticsConfig.production({
    required String endpoint,
    String? apiKey,
    String serviceName = 'voo-analytics',
    String serviceVersion = '1.0.0',
  }) =>
      OtelAnalyticsConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        serviceName: serviceName,
        serviceVersion: serviceVersion,
        exportScreenViews: true,
        exportTouchMetrics: true,
        exportCustomEvents: true,
        exportFunnels: true,
        correlateReplay: true,
        batchSize: 100,
        batchInterval: const Duration(seconds: 10),
      );

  /// Create a development configuration.
  factory OtelAnalyticsConfig.development({
    required String endpoint,
    String? apiKey,
  }) =>
      OtelAnalyticsConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        serviceName: 'voo-analytics-dev',
        serviceVersion: '1.0.0-dev',
        exportScreenViews: true,
        exportTouchMetrics: true,
        exportCustomEvents: true,
        exportFunnels: true,
        correlateReplay: true,
        batchSize: 10,
        batchInterval: const Duration(seconds: 2),
      );

  /// Check if the config has a valid endpoint.
  bool get isValid => enabled && endpoint != null && endpoint!.isNotEmpty;

  OtelAnalyticsConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? apiKey,
    String? serviceName,
    String? serviceVersion,
    bool? exportScreenViews,
    bool? exportTouchMetrics,
    bool? exportCustomEvents,
    bool? exportFunnels,
    bool? correlateReplay,
    int? batchSize,
    Duration? batchInterval,
  }) =>
      OtelAnalyticsConfig(
        enabled: enabled ?? this.enabled,
        endpoint: endpoint ?? this.endpoint,
        apiKey: apiKey ?? this.apiKey,
        serviceName: serviceName ?? this.serviceName,
        serviceVersion: serviceVersion ?? this.serviceVersion,
        exportScreenViews: exportScreenViews ?? this.exportScreenViews,
        exportTouchMetrics: exportTouchMetrics ?? this.exportTouchMetrics,
        exportCustomEvents: exportCustomEvents ?? this.exportCustomEvents,
        exportFunnels: exportFunnels ?? this.exportFunnels,
        correlateReplay: correlateReplay ?? this.correlateReplay,
        batchSize: batchSize ?? this.batchSize,
        batchInterval: batchInterval ?? this.batchInterval,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtelAnalyticsConfig &&
        other.enabled == enabled &&
        other.endpoint == endpoint &&
        other.apiKey == apiKey &&
        other.serviceName == serviceName &&
        other.serviceVersion == serviceVersion &&
        other.exportScreenViews == exportScreenViews &&
        other.exportTouchMetrics == exportTouchMetrics &&
        other.exportCustomEvents == exportCustomEvents &&
        other.exportFunnels == exportFunnels &&
        other.correlateReplay == correlateReplay &&
        other.batchSize == batchSize &&
        other.batchInterval == batchInterval;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        endpoint,
        apiKey,
        serviceName,
        serviceVersion,
        exportScreenViews,
        exportTouchMetrics,
        exportCustomEvents,
        exportFunnels,
        correlateReplay,
        batchSize,
        batchInterval,
      );
}
