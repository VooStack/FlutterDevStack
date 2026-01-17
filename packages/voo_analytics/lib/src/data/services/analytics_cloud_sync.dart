import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_analytics/src/domain/entities/touch_event.dart';

/// Configuration for cloud sync of analytics events.
@immutable
class AnalyticsCloudSyncConfig {
  final bool enabled;
  final String? endpoint;
  final String? apiKey;
  final String? projectId;
  final int batchSize;
  final Duration batchInterval;
  final int maxRetries;
  final Duration timeout;
  final int maxQueueSize;

  const AnalyticsCloudSyncConfig({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.projectId,
    this.batchSize = 100,
    this.batchInterval = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 10),
    this.maxQueueSize = 2000,
  });

  bool get isValid =>
      enabled && endpoint != null && endpoint!.isNotEmpty && apiKey != null && apiKey!.isNotEmpty;

  String? get eventsEndpoint => endpoint != null ? '$endpoint/api/telemetry/analytics' : null;

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
class AnalyticsCloudSyncService {
  final AnalyticsCloudSyncConfig config;
  final http.Client _client;

  final Queue<AnalyticsEventData> _pendingEvents = Queue();
  final Queue<TouchEvent> _pendingTouchEvents = Queue();
  Timer? _batchTimer;
  bool _isSyncing = false;

  void Function(String error)? onError;

  AnalyticsCloudSyncService({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void initialize() {
    if (!config.isValid) {
      debugPrint('AnalyticsCloudSync: Invalid configuration, sync disabled');
      return;
    }
    _startBatchTimer();
    debugPrint('AnalyticsCloudSync: Initialized with endpoint ${config.endpoint}');
  }

  void queueEvent(AnalyticsEventData event) {
    if (!config.enabled || !config.isValid) return;

    _pendingEvents.add(event);
    while (_pendingEvents.length > config.maxQueueSize) {
      _pendingEvents.removeFirst();
    }

    if (_pendingEvents.length >= config.batchSize) {
      _flushNow();
    }
  }

  void queueTouchEvent(TouchEvent event) {
    if (!config.enabled || !config.isValid) return;

    _pendingTouchEvents.add(event);
    while (_pendingTouchEvents.length > config.maxQueueSize) {
      _pendingTouchEvents.removeFirst();
    }

    if (_pendingTouchEvents.length >= config.batchSize) {
      _flushNow();
    }
  }

  Future<bool> flush() async => _flushNow();

  int get pendingCount => _pendingEvents.length + _pendingTouchEvents.length;

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(config.batchInterval, (_) => _flushNow());
  }

  Future<bool> _flushNow() async {
    if (_isSyncing || !config.isValid) return false;

    final eventsToSync = <AnalyticsEventData>[];
    final touchEventsToSync = <TouchEvent>[];

    final count = config.batchSize;
    for (var i = 0; i < count && _pendingEvents.isNotEmpty; i++) {
      eventsToSync.add(_pendingEvents.removeFirst());
    }
    for (var i = 0; i < count && _pendingTouchEvents.isNotEmpty; i++) {
      touchEventsToSync.add(_pendingTouchEvents.removeFirst());
    }

    if (eventsToSync.isEmpty && touchEventsToSync.isEmpty) return true;

    _isSyncing = true;

    try {
      final success = await _sendBatch(eventsToSync, touchEventsToSync);
      if (!success) {
        // Re-queue on failure
        for (final e in eventsToSync.reversed) {
          _pendingEvents.addFirst(e);
        }
        for (final e in touchEventsToSync.reversed) {
          _pendingTouchEvents.addFirst(e);
        }
      }
      return success;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _sendBatch(
    List<AnalyticsEventData> events,
    List<TouchEvent> touchEvents,
  ) async {
    final endpoint = config.eventsEndpoint;
    if (endpoint == null) return false;

    final payload = {
      'projectId': config.projectId,
      'events': events.map((e) => e.toJson()).toList(),
      'touchEvents': touchEvents
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
                'AnalyticsCloudSync: Synced ${events.length} events, ${touchEvents.length} touch events');
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
