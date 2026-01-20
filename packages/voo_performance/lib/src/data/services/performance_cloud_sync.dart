import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

/// Configuration for cloud sync of performance metrics.
@immutable
class PerformanceCloudSyncConfig extends BaseSyncConfig {
  const PerformanceCloudSyncConfig({
    super.enabled = false,
    super.endpoint,
    super.apiKey,
    super.projectId,
    super.batchSize = 50,
    super.batchInterval = const Duration(seconds: 30),
    super.maxRetries = 3,
    super.timeout = const Duration(seconds: 10),
    super.maxQueueSize = 1000,
  });

  /// Returns the full endpoint URL for performance metrics ingestion.
  /// Note: endpoint should already include /api if needed (e.g., 'http://localhost:5001/api')
  String? get metricsEndpoint =>
      endpoint != null ? '$endpoint/v1/telemetry/performance' : null;

  factory PerformanceCloudSyncConfig.production({
    required String endpoint,
    required String apiKey,
    required String projectId,
  }) =>
      PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        projectId: projectId,
        batchSize: 100,
        batchInterval: const Duration(seconds: 60),
      );

  factory PerformanceCloudSyncConfig.development({
    required String endpoint,
    required String apiKey,
    required String projectId,
  }) =>
      PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        projectId: projectId,
        batchSize: 20,
        batchInterval: const Duration(seconds: 15),
      );

  PerformanceCloudSyncConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? apiKey,
    String? projectId,
    int? batchSize,
    Duration? batchInterval,
    int? maxRetries,
    Duration? timeout,
    int? maxQueueSize,
  }) =>
      PerformanceCloudSyncConfig(
        enabled: enabled ?? this.enabled,
        endpoint: endpoint ?? this.endpoint,
        apiKey: apiKey ?? this.apiKey,
        projectId: projectId ?? this.projectId,
        batchSize: batchSize ?? this.batchSize,
        batchInterval: batchInterval ?? this.batchInterval,
        maxRetries: maxRetries ?? this.maxRetries,
        timeout: timeout ?? this.timeout,
        maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      );
}

/// Performance metric data for cloud sync.
class PerformanceMetricData {
  final String name;
  final String metricType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, String>? tags;
  final String? source;
  final String? endpoint;
  final String? pageName;

  PerformanceMetricData({
    required this.name,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.tags,
    this.source,
    this.endpoint,
    this.pageName,
  });

  /// Converts to JSON matching API's MetricEntry structure.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': metricType, // API expects 'type', not 'metricType'
        'value': value,
        'unit': unit,
        'tags': tags ?? <String, String>{},
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'endpoint': endpoint,
        'pageName': pageName,
      };
}

/// Network metric data for cloud sync.
class NetworkMetricData {
  final String method;
  final String url;
  final int? statusCode;
  final int duration;
  final int? requestSize;
  final int? responseSize;
  final DateTime timestamp;
  final String? error;

  NetworkMetricData({
    required this.method,
    required this.url,
    this.statusCode,
    required this.duration,
    this.requestSize,
    this.responseSize,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'duration': duration,
        'requestSize': requestSize,
        'responseSize': responseSize,
        'timestamp': timestamp.toIso8601String(),
        'error': error,
      };

  /// Converts network metric to a PerformanceMetricData for API submission.
  /// The API expects MetricEntry format with type, value, unit, etc.
  PerformanceMetricData toPerformanceMetric() {
    // Extract endpoint path from URL (remove host/protocol)
    String endpointPath;
    try {
      final uri = Uri.parse(url);
      endpointPath = uri.path;
      if (uri.query.isNotEmpty) {
        endpointPath += '?${uri.query}';
      }
    } catch (_) {
      endpointPath = url;
    }

    return PerformanceMetricData(
      name: 'http.request.duration',
      metricType: 'timer',
      value: duration.toDouble(),
      unit: 'ms',
      timestamp: timestamp,
      source: 'backend', // Network requests are backend metrics
      endpoint: endpointPath,
      tags: {
        'method': method,
        if (statusCode != null) 'statusCode': statusCode.toString(),
        if (requestSize != null) 'requestSize': requestSize.toString(),
        if (responseSize != null) 'responseSize': responseSize.toString(),
        if (error != null) 'error': error!,
        'host': _extractHost(url),
      },
    );
  }

  String _extractHost(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return 'unknown';
    }
  }
}

/// Service for syncing performance metrics to a cloud backend.
///
/// Extends [BaseSyncService] from voo_core to reuse common batching,
/// retry, and HTTP logic. Handles both performance metrics and network metrics.
class PerformanceCloudSyncService
    extends BaseSyncService<PerformanceMetricData> {
  final PerformanceCloudSyncConfig _perfConfig;

  /// Separate queue for network metrics.
  final Queue<NetworkMetricData> _pendingNetworkMetrics = Queue();

  PerformanceCloudSyncService({
    required PerformanceCloudSyncConfig super.config,
    super.client,
  })  : _perfConfig = config,
        super(
          serviceName: 'PerformanceCloudSync',
        );

  @override
  String get endpoint => _perfConfig.metricsEndpoint ?? '';

  /// Queue a performance metric for syncing.
  void queueMetric(PerformanceMetricData metric) {
    queueItem(metric);
  }

  /// Queue a network metric for syncing.
  void queueNetworkMetric(NetworkMetricData metric) {
    if (!_perfConfig.enabled || !_perfConfig.isValid) return;

    _pendingNetworkMetrics.add(metric);
    while (_pendingNetworkMetrics.length > _perfConfig.maxQueueSize) {
      _pendingNetworkMetrics.removeFirst();
    }

    // Trigger flush when we have enough network metrics
    if (_pendingNetworkMetrics.length >= _perfConfig.batchSize) {
      flushNetworkMetrics();
    }
  }

  /// Flush network metrics immediately.
  /// Network metrics are converted to performance metrics in the flush() override.
  Future<void> flushNetworkMetrics() async {
    if (_pendingNetworkMetrics.isEmpty) return;
    if (!_perfConfig.enabled || !_perfConfig.isValid) return;

    // Just call flush - the override handles conversion
    await flush();
  }

  @override
  int get pendingCount => super.pendingCount + _pendingNetworkMetrics.length;

  /// Override flush to include any pending network metrics.
  @override
  Future<bool> flush() async {
    // Convert any pending network metrics to performance metrics first
    if (_pendingNetworkMetrics.isNotEmpty) {
      final networkAsPerformance = _pendingNetworkMetrics
          .map((nm) => nm.toPerformanceMetric())
          .toList();
      _pendingNetworkMetrics.clear();

      // Queue them as regular performance metrics
      for (final metric in networkAsPerformance) {
        queueItem(metric);
      }
    }

    // Now flush all metrics (including converted network metrics)
    return super.flush();
  }

  @override
  Map<String, dynamic> formatPayload(List<PerformanceMetricData> metrics) {
    // Network metrics are converted via flushNetworkMetrics() and added to the
    // regular metrics queue, so they're already included in `metrics` param.
    // Use new typed context from Voo.context (preferred)
    final context = Voo.context;
    if (context != null) {
      return {
        'metrics': metrics.map((m) => m.toJson()).toList(),
        ...context.toSyncPayload(),
      };
    }

    // Fallback: Legacy customConfig extraction (backwards compatibility)
    // ignore: deprecated_member_use
    final vooConfig = Voo.options?.customConfig ?? {};
    final sessionId = vooConfig['sessionId'] as String? ?? '';
    final deviceId = vooConfig['deviceId'] as String? ?? '';
    final platform = vooConfig['platform'] as String? ?? 'unknown';
    final appVersion = vooConfig['appVersion'] as String? ?? '1.0.0';

    // API expects MetricsBatchRequest structure
    return {
      'metrics': metrics.map((m) => m.toJson()).toList(),
      'sessionId': sessionId,
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  @override
  void dispose() {
    _pendingNetworkMetrics.clear();
    super.dispose();
  }
}
