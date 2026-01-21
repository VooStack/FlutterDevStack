import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
  String? get eventsEndpoint => endpoint != null ? '$endpoint/v1/telemetry/analytics' : null;

  /// Returns the full endpoint URL for touch events (heatmaps).
  String? get touchEventsEndpoint => endpoint != null ? '$endpoint/v1/telemetry/touch-events' : null;

  factory AnalyticsCloudSyncConfig.production({required String endpoint, required String apiKey, String? projectId}) =>
      AnalyticsCloudSyncConfig(enabled: true, endpoint: endpoint, apiKey: apiKey, projectId: projectId, batchSize: 100, batchInterval: const Duration(seconds: 60));

  factory AnalyticsCloudSyncConfig.development({required String endpoint, required String apiKey, String? projectId}) =>
      AnalyticsCloudSyncConfig(enabled: true, endpoint: endpoint, apiKey: apiKey, projectId: projectId, batchSize: 20, batchInterval: const Duration(seconds: 15));

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
  }) => AnalyticsCloudSyncConfig(
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

  AnalyticsEventData({required this.eventName, this.category = 'general', required this.timestamp, this.parameters, this.action, this.label, this.value});

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

  AnalyticsCloudSyncService({required AnalyticsCloudSyncConfig super.config, super.client}) : _analyticsConfig = config, super(serviceName: 'AnalyticsCloudSync');

  @override
  String get endpoint => _analyticsConfig.eventsEndpoint ?? '';

  /// Queue an analytics event for syncing.
  ///
  /// Does nothing if the analytics feature is disabled at the project level.
  void queueEvent(AnalyticsEventData event) {
    // Check project-level feature toggle
    if (!Voo.featureConfig.isEnabled(VooFeature.analytics)) return;
    queueItem(event);
  }

  /// Queue a touch event for syncing.
  ///
  /// Does nothing if the touch tracking feature is disabled at the project level.
  void queueTouchEvent(TouchEvent event) {
    // Check project-level feature toggle
    if (!Voo.featureConfig.isEnabled(VooFeature.touchTracking)) return;
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
  Future<bool> flush() async {
    // Flush analytics events via parent class
    final analyticsResult = await super.flush();

    // Also flush touch events to separate endpoint
    final touchResult = await _flushTouchEvents();

    return analyticsResult || touchResult;
  }

  /// Flush pending touch events to the heatmap endpoint.
  Future<bool> _flushTouchEvents() async {
    if (_pendingTouchEvents.isEmpty) return false;
    if (_analyticsConfig.touchEventsEndpoint == null || _analyticsConfig.apiKey == null) return false;

    // Take up to batchSize events
    final eventsToSend = <TouchEvent>[];
    while (eventsToSend.length < _analyticsConfig.batchSize && _pendingTouchEvents.isNotEmpty) {
      eventsToSend.add(_pendingTouchEvents.removeFirst());
    }

    if (eventsToSend.isEmpty) return false;

    try {
      final context = Voo.context;
      final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final logicalSize = screenSize / devicePixelRatio;

      final payload = {
        'sessionId': context?.sessionId ?? Voo.sessionId ?? '',
        'deviceId': context?.deviceId ?? '',
        'userId': context?.userId ?? '',
        'platform': context?.platform ?? 'unknown',
        'appVersion': context?.appVersion ?? '1.0.0',
        'events': eventsToSend.map((e) {
          return {
            'timestamp': e.timestamp.toIso8601String(),
            'x': e.position.dx,
            'y': e.position.dy,
            'normalizedX': logicalSize.width > 0 ? (e.position.dx / logicalSize.width).clamp(0.0, 1.0) : 0.0,
            'normalizedY': logicalSize.height > 0 ? (e.position.dy / logicalSize.height).clamp(0.0, 1.0) : 0.0,
            'screenName': e.screenName,
            'routePath': e.route,
            'screenWidth': logicalSize.width,
            'screenHeight': logicalSize.height,
            'widgetType': e.widgetType,
            'widgetKey': e.widgetKey,
            'touchType': e.type.name,
          };
        }).toList(),
      };

      final response = await http.post(
        Uri.parse(_analyticsConfig.touchEventsEndpoint!),
        headers: {'Content-Type': 'application/json', 'X-API-Key': _analyticsConfig.apiKey!},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          debugPrint('[AnalyticsCloudSync] Synced ${eventsToSend.length} touch events');
        }
        return true;
      } else {
        // Re-queue events on failure (up to limit)
        for (final event in eventsToSend.reversed) {
          if (_pendingTouchEvents.length < _analyticsConfig.maxQueueSize) {
            _pendingTouchEvents.addFirst(event);
          }
        }
        if (kDebugMode) {
          debugPrint('[AnalyticsCloudSync] Failed to sync touch events: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      // Re-queue events on error (up to limit)
      for (final event in eventsToSend.reversed) {
        if (_pendingTouchEvents.length < _analyticsConfig.maxQueueSize) {
          _pendingTouchEvents.addFirst(event);
        }
      }
      if (kDebugMode) {
        debugPrint('[AnalyticsCloudSync] Error syncing touch events: $e');
      }
      return false;
    }
  }

  @override
  Map<String, dynamic> formatPayload(List<AnalyticsEventData> events) {
    // Use new typed context from Voo.context (preferred)
    final context = Voo.context;
    if (context != null) {
      return {'events': events.map((e) => e.toJson()).toList(), ...context.toSyncPayload()};
    }

    // Fallback: Legacy customConfig extraction (backwards compatibility)
    // ignore: deprecated_member_use
    final vooConfig = Voo.options?.customConfig ?? {};
    final sessionId = vooConfig['sessionId'] as String? ?? '';
    final userId = vooConfig['userId'] as String? ?? '';
    final deviceId = vooConfig['deviceId'] as String? ?? '';
    final platform = vooConfig['platform'] as String? ?? 'unknown';
    final appVersion = vooConfig['appVersion'] as String? ?? '1.0.0';

    // API expects EventsBatchRequest structure
    return {'events': events.map((e) => e.toJson()).toList(), 'sessionId': sessionId, 'userId': userId, 'deviceId': deviceId, 'platform': platform, 'appVersion': appVersion};
  }

  @override
  void dispose() {
    _pendingTouchEvents.clear();
    super.dispose();
  }
}
