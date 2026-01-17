import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Configuration for cloud sync of performance metrics.
@immutable
class PerformanceCloudSyncConfig {
  final bool enabled;
  final String? endpoint;
  final String? apiKey;
  final String? projectId;
  final int batchSize;
  final Duration batchInterval;
  final int maxRetries;
  final Duration timeout;
  final int maxQueueSize;

  const PerformanceCloudSyncConfig({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.projectId,
    this.batchSize = 50,
    this.batchInterval = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 10),
    this.maxQueueSize = 1000,
  });

  bool get isValid =>
      enabled && endpoint != null && endpoint!.isNotEmpty && apiKey != null && apiKey!.isNotEmpty;

  String? get metricsEndpoint => endpoint != null ? '$endpoint/api/telemetry/performance' : null;

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
  final Map<String, dynamic>? tags;
  final String? sessionId;
  final String? deviceId;
  final String? appVersion;
  final String? platform;

  PerformanceMetricData({
    required this.name,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.tags,
    this.sessionId,
    this.deviceId,
    this.appVersion,
    this.platform,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'metricType': metricType,
        'value': value,
        'unit': unit,
        'timestamp': timestamp.toIso8601String(),
        'tags': tags,
        'sessionId': sessionId,
        'deviceId': deviceId,
        'appVersion': appVersion,
        'platform': platform,
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
}

/// Service for syncing performance metrics to a cloud backend.
class PerformanceCloudSyncService {
  final PerformanceCloudSyncConfig config;
  final http.Client _client;

  final Queue<PerformanceMetricData> _pendingMetrics = Queue();
  final Queue<NetworkMetricData> _pendingNetworkMetrics = Queue();
  Timer? _batchTimer;
  bool _isSyncing = false;

  void Function(String error)? onError;

  PerformanceCloudSyncService({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void initialize() {
    if (!config.isValid) {
      debugPrint('PerformanceCloudSync: Invalid configuration, sync disabled');
      return;
    }
    _startBatchTimer();
    debugPrint('PerformanceCloudSync: Initialized with endpoint ${config.endpoint}');
  }

  void queueMetric(PerformanceMetricData metric) {
    if (!config.enabled || !config.isValid) return;

    _pendingMetrics.add(metric);
    while (_pendingMetrics.length > config.maxQueueSize) {
      _pendingMetrics.removeFirst();
    }

    if (_pendingMetrics.length >= config.batchSize) {
      _flushNow();
    }
  }

  void queueNetworkMetric(NetworkMetricData metric) {
    if (!config.enabled || !config.isValid) return;

    _pendingNetworkMetrics.add(metric);
    while (_pendingNetworkMetrics.length > config.maxQueueSize) {
      _pendingNetworkMetrics.removeFirst();
    }

    if (_pendingNetworkMetrics.length >= config.batchSize) {
      _flushNow();
    }
  }

  Future<bool> flush() async => _flushNow();

  int get pendingCount => _pendingMetrics.length + _pendingNetworkMetrics.length;

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(config.batchInterval, (_) => _flushNow());
  }

  Future<bool> _flushNow() async {
    if (_isSyncing || !config.isValid) return false;

    final metricsToSync = <PerformanceMetricData>[];
    final networkMetricsToSync = <NetworkMetricData>[];

    final count = config.batchSize;
    for (var i = 0; i < count && _pendingMetrics.isNotEmpty; i++) {
      metricsToSync.add(_pendingMetrics.removeFirst());
    }
    for (var i = 0; i < count && _pendingNetworkMetrics.isNotEmpty; i++) {
      networkMetricsToSync.add(_pendingNetworkMetrics.removeFirst());
    }

    if (metricsToSync.isEmpty && networkMetricsToSync.isEmpty) return true;

    _isSyncing = true;

    try {
      final success = await _sendBatch(metricsToSync, networkMetricsToSync);
      if (!success) {
        for (final m in metricsToSync.reversed) {
          _pendingMetrics.addFirst(m);
        }
        for (final m in networkMetricsToSync.reversed) {
          _pendingNetworkMetrics.addFirst(m);
        }
      }
      return success;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _sendBatch(
    List<PerformanceMetricData> metrics,
    List<NetworkMetricData> networkMetrics,
  ) async {
    final endpoint = config.metricsEndpoint;
    if (endpoint == null) return false;

    final payload = {
      'projectId': config.projectId,
      'metrics': metrics.map((m) => m.toJson()).toList(),
      'networkMetrics': networkMetrics.map((m) => m.toJson()).toList(),
    };

    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                if (config.apiKey != null) 'X-API-Key': config.apiKey!,
              },
              body: jsonEncode(payload),
            )
            .timeout(config.timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint(
                'PerformanceCloudSync: Synced ${metrics.length} metrics, ${networkMetrics.length} network metrics');
          }
          return true;
        }

        onError?.call('HTTP ${response.statusCode}');
      } catch (e) {
        onError?.call(e.toString());
      }

      if (attempt < config.maxRetries) {
        await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
      }
    }

    return false;
  }

  void dispose() {
    _batchTimer?.cancel();
    _client.close();
  }
}
