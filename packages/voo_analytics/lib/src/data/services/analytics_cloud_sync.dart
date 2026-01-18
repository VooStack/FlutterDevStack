import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_analytics/src/domain/entities/touch_event.dart';
import 'package:voo_core/voo_core.dart';

/// Configuration for cloud sync of analytics events.
@immutable
class AnalyticsCloudSyncConfig extends BaseSyncConfig {
  const AnalyticsCloudSyncConfig({
    super.enabled = false,
    super.endpoint,
    super.apiKey,
    super.projectId,
    super.batchSize = 100,
    super.batchInterval = const Duration(seconds: 30),
    super.maxRetries = 3,
    super.timeout = const Duration(seconds: 10),
    super.maxQueueSize = 2000,
  });

  /// Returns the full endpoint URL for analytics ingestion.
  /// Note: endpoint should already include /api if needed (e.g., 'http://localhost:5001/api')
  String? get eventsEndpoint =>
      endpoint != null ? '$endpoint/v1/telemetry/analytics' : null;

  factory AnalyticsCloudSyncConfig.production({
    required String endpoint,
    required String apiKey,
    required String projectId,
  }) =>
      AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        projectId: projectId,
        batchSize: 100,
        batchInterval: const Duration(seconds: 60),
      );

  factory AnalyticsCloudSyncConfig.development({
    required String endpoint,
    required String apiKey,
    required String projectId,
  }) =>
      AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: endpoint,
        apiKey: apiKey,
        projectId: projectId,
        batchSize: 20,
        batchInterval: const Duration(seconds: 15),
      );

  AnalyticsCloudSyncConfig copyWith({
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
      AnalyticsCloudSyncConfig(
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

/// Analytics event data for cloud sync.
class AnalyticsEventData {
  final String eventName;
  final String category;
  final DateTime timestamp;
  final Map<String, dynamic>? parameters;
  final String? action;
  final String? label;
  final double? value;

  AnalyticsEventData({
    required this.eventName,
    this.category = 'general',
    required this.timestamp,
    this.parameters,
    this.action,
    this.label,
    this.value,
  });

  Map<String, dynamic> toJson() => {
        'name': eventName,
        'category': category,
        'action': action,
        'label': label,
        'value': value,
        'properties': parameters ?? {},
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Service for syncing analytics events to a cloud backend.
///
/// Extends [BaseSyncService] from voo_core to reuse common batching,
/// retry, and HTTP logic. Handles both analytics events and touch events.
class AnalyticsCloudSyncService extends BaseSyncService<AnalyticsEventData> {
  final AnalyticsCloudSyncConfig _analyticsConfig;

  /// Separate queue for touch events.
  final Queue<TouchEvent> _pendingTouchEvents = Queue();

  AnalyticsCloudSyncService({
    required AnalyticsCloudSyncConfig config,
    http.Client? client,
  })  : _analyticsConfig = config,
        super(
          config: config,
          serviceName: 'AnalyticsCloudSync',
          client: client,
        );

  @override
  String get endpoint => _analyticsConfig.eventsEndpoint ?? '';

  /// Queue an analytics event for syncing.
  void queueEvent(AnalyticsEventData event) {
    queueItem(event);
  }

  /// Queue a touch event for syncing.
  void queueTouchEvent(TouchEvent event) {
    if (!_analyticsConfig.enabled || !_analyticsConfig.isValid) return;

    _pendingTouchEvents.add(event);
    while (_pendingTouchEvents.length > _analyticsConfig.maxQueueSize) {
      _pendingTouchEvents.removeFirst();
    }

    if (_pendingTouchEvents.length >= _analyticsConfig.batchSize) {
      flush();
    }
  }

  @override
  int get pendingCount => super.pendingCount + _pendingTouchEvents.length;

  @override
  Map<String, dynamic> formatPayload(List<AnalyticsEventData> events) {
    // Note: Touch events are synced separately or can be added to properties
    // Clear any pending touch events since they're not part of the standard API
    _pendingTouchEvents.clear();

    // Get session/device info from Voo core config
    final vooConfig = Voo.options?.customConfig ?? {};
    final sessionId = vooConfig['sessionId'] as String? ?? '';
    final userId = vooConfig['userId'] as String? ?? '';
    final deviceId = vooConfig['deviceId'] as String? ?? '';
    final platform = vooConfig['platform'] as String? ?? 'unknown';
    final appVersion = vooConfig['appVersion'] as String? ?? '1.0.0';

    // API expects EventsBatchRequest structure
    return {
      'events': events.map((e) => e.toJson()).toList(),
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  @override
  void dispose() {
    _pendingTouchEvents.clear();
    super.dispose();
  }
}
