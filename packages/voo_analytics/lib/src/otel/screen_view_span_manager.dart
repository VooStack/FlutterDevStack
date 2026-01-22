import 'package:voo_telemetry/voo_telemetry.dart';

/// Manages screen view spans for analytics tracking.
///
/// Creates and manages OTEL spans representing screen views, allowing
/// touch events and other analytics events to be correlated with the
/// active screen context.
class ScreenViewSpanManager {
  final Tracer _tracer;
  Span? _activeScreenSpan;
  final Map<String, Span> _screenSpanStack = {};
  DateTime? _screenStartTime;

  /// Session ID for correlation.
  String? sessionId;

  /// User ID for correlation.
  String? userId;

  ScreenViewSpanManager(this._tracer);

  /// Start a new screen view span, ending the previous one.
  ///
  /// Returns the created span for additional attribute setting.
  Span startScreenView({
    required String screenName,
    String? screenClass,
    String? previousScreen,
    Map<String, dynamic>? routeParams,
    String? navigationAction,
  }) {
    // End previous span with engagement metrics
    _endCurrentScreenSpan();

    _screenStartTime = DateTime.now();

    // Create new screen_view span
    _activeScreenSpan = _tracer.startSpan(
      'screen_view',
      kind: SpanKind.internal,
      attributes: {
        'ui.screen.name': screenName,
        if (screenClass != null) 'ui.screen.class': screenClass,
        if (previousScreen != null) 'ui.previous_screen': previousScreen,
        if (navigationAction != null) 'ui.navigation.action': navigationAction,
        if (routeParams != null && routeParams.isNotEmpty)
          'ui.route.params': _serializeParams(routeParams),
        if (sessionId != null) 'session.id': sessionId,
        if (userId != null) 'user.id': userId,
      },
    );

    // Track in stack for nested navigation
    _screenSpanStack[screenName] = _activeScreenSpan!;

    return _activeScreenSpan!;
  }

  /// End the current screen view span.
  void _endCurrentScreenSpan() {
    if (_activeScreenSpan != null && _activeScreenSpan!.isRecording) {
      // Calculate engagement metrics
      if (_screenStartTime != null) {
        final duration = DateTime.now().difference(_screenStartTime!);
        _activeScreenSpan!.setAttribute(
          'ui.screen.duration_ms',
          duration.inMilliseconds,
        );
      }

      _activeScreenSpan!.status = SpanStatus.ok();
      _activeScreenSpan!.end();
    }
    _activeScreenSpan = null;
    _screenStartTime = null;
  }

  /// Get the currently active screen span.
  Span? get activeScreenSpan => _activeScreenSpan;

  /// Get the trace context for correlation.
  SpanContext? get currentTraceContext => _activeScreenSpan?.context;

  /// Get trace ID for correlation.
  String? get traceId => _activeScreenSpan?.traceId;

  /// Get span ID for correlation.
  String? get spanId => _activeScreenSpan?.spanId;

  /// Add an event to the current screen span.
  ///
  /// Use this to track interactions and events within the screen context.
  void addScreenEvent(
    String eventName, {
    Map<String, dynamic>? attributes,
  }) {
    _activeScreenSpan?.addEvent(eventName, attributes: attributes);
  }

  /// Record a user interaction on the current screen.
  void recordInteraction({
    required String interactionType,
    String? elementId,
    String? elementType,
    double? x,
    double? y,
    Map<String, dynamic>? additionalAttributes,
  }) {
    final attributes = <String, dynamic>{
      'interaction.type': interactionType,
      if (elementId != null) 'interaction.element.id': elementId,
      if (elementType != null) 'interaction.element.type': elementType,
      if (x != null) 'interaction.x': x,
      if (y != null) 'interaction.y': y,
      ...?additionalAttributes,
    };

    _activeScreenSpan?.addEvent('interaction', attributes: attributes);
  }

  /// Set an attribute on the current screen span.
  void setScreenAttribute(String key, dynamic value) {
    _activeScreenSpan?.setAttribute(key, value);
  }

  /// End all screen spans (call on app termination).
  void dispose() {
    _endCurrentScreenSpan();
    for (final span in _screenSpanStack.values) {
      if (span.isRecording) {
        span.end();
      }
    }
    _screenSpanStack.clear();
  }

  String _serializeParams(Map<String, dynamic> params) {
    return params.entries.map((e) => '${e.key}=${e.value}').join('&');
  }
}
