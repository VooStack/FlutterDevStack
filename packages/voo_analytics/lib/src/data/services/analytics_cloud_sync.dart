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
  String? get eventsEndpoint =>
      endpoint != null ? '$endpoint/api/v1/telemetry/analytics' : null;

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
  final DateTime timestamp;
  final Map<String, dynamic>? parameters;
  final String? screenName;
  final String? userId;

  AnalyticsEventData({
    required this.eventName,
    required this.timestamp,
    this.parameters,
    this.screenName,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'timestamp': timestamp.toIso8601String(),
        'parameters': parameters,
        'screenName': screenName,
        'userId': userId,
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
    // Extract touch events to include in payload
    final touchEventsToSync = <TouchEvent>[];
    final count = _analyticsConfig.batchSize;
    for (var i = 0; i < count && _pendingTouchEvents.isNotEmpty; i++) {
      touchEventsToSync.add(_pendingTouchEvents.removeFirst());
    }

    return {
      'projectId': _analyticsConfig.projectId,
      'events': events.map((e) => e.toJson()).toList(),
      'touchEvents': touchEventsToSync
          .map((e) => {
                'x': e.x,
                'y': e.y,
                'screenName': e.screenName,
                'route': e.route,
                'type': e.type.name,
                'timestamp': e.timestamp.toIso8601String(),
                'widgetKey': e.widgetKey,
                'widgetType': e.widgetType,
              })
          .toList(),
    };
  }

  @override
  void dispose() {
    _pendingTouchEvents.clear();
    super.dispose();
  }
}
