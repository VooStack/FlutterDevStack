import 'screen_view_span_manager.dart';

/// Replay event types for capture.
enum ReplayEventType {
  touch,
  screenView,
  network,
  error,
  log,
  lifecycle,
  custom,
  screenshot,
}

/// A captured replay event with trace correlation.
class CorrelatedReplayEvent {
  final ReplayEventType eventType;
  final DateTime timestamp;
  final int offsetMs;
  final String? screenName;
  final double? x;
  final double? y;
  final String? touchType;
  final Map<String, dynamic>? metadata;

  /// Trace correlation
  final String? traceId;
  final String? spanId;

  const CorrelatedReplayEvent({
    required this.eventType,
    required this.timestamp,
    required this.offsetMs,
    this.screenName,
    this.x,
    this.y,
    this.touchType,
    this.metadata,
    this.traceId,
    this.spanId,
  });

  /// Convert to a map for serialization.
  Map<String, dynamic> toMap() => {
        'eventType': eventType.name,
        'timestamp': timestamp.toIso8601String(),
        'offsetMs': offsetMs,
        if (screenName != null) 'screenName': screenName,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (touchType != null) 'touchType': touchType,
        if (metadata != null) 'metadata': metadata,
        if (traceId != null) 'traceId': traceId,
        if (spanId != null) 'spanId': spanId,
      };
}

/// Correlates session replay events with distributed traces.
///
/// This allows replay events to be linked to the corresponding
/// OTEL traces for debugging and analysis.
class ReplayTraceCorrelator {
  final ScreenViewSpanManager _spanManager;
  DateTime? _sessionStartTime;

  ReplayTraceCorrelator(this._spanManager);

  /// Start a new session for offset calculation.
  void startSession() {
    _sessionStartTime = DateTime.now();
  }

  /// Calculate offset from session start.
  int _calculateOffset() {
    if (_sessionStartTime == null) return 0;
    return DateTime.now().difference(_sessionStartTime!).inMilliseconds;
  }

  /// Capture a replay event with trace context.
  CorrelatedReplayEvent captureEvent({
    required ReplayEventType eventType,
    String? screenName,
    double? x,
    double? y,
    String? touchType,
    Map<String, dynamic>? metadata,
  }) {
    final context = _spanManager.currentTraceContext;

    return CorrelatedReplayEvent(
      eventType: eventType,
      timestamp: DateTime.now(),
      offsetMs: _calculateOffset(),
      screenName: screenName ?? _getCurrentScreenName(),
      x: x,
      y: y,
      touchType: touchType,
      metadata: metadata,
      traceId: context?.traceId,
      spanId: context?.spanId,
    );
  }

  /// Capture a touch event with trace correlation.
  CorrelatedReplayEvent captureTouch({
    required double x,
    required double y,
    required String touchType,
    String? widgetType,
    String? widgetKey,
  }) {
    return captureEvent(
      eventType: ReplayEventType.touch,
      x: x,
      y: y,
      touchType: touchType,
      metadata: {
        if (widgetType != null) 'widgetType': widgetType,
        if (widgetKey != null) 'widgetKey': widgetKey,
      },
    );
  }

  /// Capture a screen view event with trace correlation.
  CorrelatedReplayEvent captureScreenView({
    required String screenName,
    String? previousScreen,
    String? navigationAction,
  }) {
    return captureEvent(
      eventType: ReplayEventType.screenView,
      screenName: screenName,
      metadata: {
        if (previousScreen != null) 'previousScreen': previousScreen,
        if (navigationAction != null) 'navigationAction': navigationAction,
      },
    );
  }

  /// Capture an error event with trace correlation.
  CorrelatedReplayEvent captureError({
    required String message,
    String? errorType,
    String? stackTrace,
  }) {
    return captureEvent(
      eventType: ReplayEventType.error,
      metadata: {
        'message': message,
        if (errorType != null) 'errorType': errorType,
        if (stackTrace != null) 'stackTrace': stackTrace,
      },
    );
  }

  /// Capture a network event with trace correlation.
  CorrelatedReplayEvent captureNetwork({
    required String method,
    required String url,
    int? statusCode,
    int? durationMs,
  }) {
    return captureEvent(
      eventType: ReplayEventType.network,
      metadata: {
        'method': method,
        'url': url,
        if (statusCode != null) 'statusCode': statusCode,
        if (durationMs != null) 'durationMs': durationMs,
      },
    );
  }

  /// Capture a custom event with trace correlation.
  CorrelatedReplayEvent captureCustom({
    required String eventName,
    Map<String, dynamic>? data,
  }) {
    return captureEvent(
      eventType: ReplayEventType.custom,
      metadata: {
        'eventName': eventName,
        ...?data,
      },
    );
  }

  /// Add trace context to an existing span event.
  void correlateWithSpan(Map<String, dynamic> event) {
    final span = _spanManager.activeScreenSpan;
    if (span == null) return;

    span.addEvent(
      'replay.${event['eventType']}',
      attributes: {
        'replay.offset_ms': event['offsetMs'],
        if (event['x'] != null) 'replay.x': event['x'],
        if (event['y'] != null) 'replay.y': event['y'],
        if (event['screenName'] != null) 'replay.screen': event['screenName'],
        ...?event['metadata'] as Map<String, dynamic>?,
      },
    );
  }

  String? _getCurrentScreenName() {
    // Try to get from active span attributes
    final span = _spanManager.activeScreenSpan;
    if (span != null && span.attributes.containsKey('ui.screen.name')) {
      return span.attributes['ui.screen.name'] as String?;
    }
    return null;
  }

  /// Get current trace context for external use.
  ({String? traceId, String? spanId}) getCurrentTraceContext() {
    final context = _spanManager.currentTraceContext;
    return (traceId: context?.traceId, spanId: context?.spanId);
  }
}
