import 'package:voo_telemetry/voo_telemetry.dart';

/// Touch event types for metrics.
enum TouchType {
  tap,
  doubleTap,
  longPress,
  panStart,
  panUpdate,
  panEnd,
  scaleStart,
  scaleUpdate,
  scaleEnd,
}

/// OTEL metrics for touch event tracking.
///
/// Tracks touch interactions as OTEL metrics for aggregate analysis
/// and heatmap generation.
class TouchEventMetrics {
  final Meter _meter;

  late final Counter _touchCounter;
  late final Histogram _touchXHistogram;
  late final Histogram _touchYHistogram;
  late final Histogram _gestureDurationHistogram;

  bool _initialized = false;

  TouchEventMetrics(this._meter);

  /// Initialize the touch event metric instruments.
  void initialize() {
    if (_initialized) return;

    _touchCounter = _meter.createCounter(
      'analytics.touch.count',
      description: 'Count of touch interactions by type and screen',
      unit: '{touches}',
    );

    _touchXHistogram = _meter.createHistogram(
      'analytics.touch.position_x',
      description: 'Normalized X position distribution (0-1)',
      unit: '1',
      explicitBounds: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
    );

    _touchYHistogram = _meter.createHistogram(
      'analytics.touch.position_y',
      description: 'Normalized Y position distribution (0-1)',
      unit: '1',
      explicitBounds: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
    );

    _gestureDurationHistogram = _meter.createHistogram(
      'analytics.gesture.duration',
      description: 'Duration of gesture interactions',
      unit: 'ms',
      explicitBounds: [50, 100, 200, 500, 1000, 2000],
    );

    _initialized = true;
  }

  /// Record a touch event as metrics.
  ///
  /// [screenName] The screen where the touch occurred.
  /// [touchType] The type of touch interaction.
  /// [normalizedX] Normalized X position (0-1).
  /// [normalizedY] Normalized Y position (0-1).
  /// [region] Optional screen region classification.
  /// [widgetType] Optional widget type that was touched.
  void recordTouch({
    required String screenName,
    required TouchType touchType,
    required double normalizedX,
    required double normalizedY,
    String? region,
    String? widgetType,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      'ui.screen.name': screenName,
      'touch.type': touchType.name,
      if (region != null) 'touch.region': region,
      if (widgetType != null) 'touch.widget_type': widgetType,
    };

    // Increment touch counter
    _touchCounter.increment(attributes: attributes);

    // Record position histograms for heatmap data
    _touchXHistogram.record(normalizedX, attributes: {
      'ui.screen.name': screenName,
      'axis': 'x',
    });

    _touchYHistogram.record(normalizedY, attributes: {
      'ui.screen.name': screenName,
      'axis': 'y',
    });
  }

  /// Record a gesture with duration.
  ///
  /// Use this for gestures like long press, pan, and scale.
  void recordGesture({
    required String screenName,
    required TouchType gestureType,
    required int durationMs,
    double? normalizedX,
    double? normalizedY,
    Map<String, dynamic>? additionalAttributes,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      'ui.screen.name': screenName,
      'gesture.type': gestureType.name,
      if (normalizedX != null) 'gesture.x': normalizedX,
      if (normalizedY != null) 'gesture.y': normalizedY,
      ...?additionalAttributes,
    };

    _gestureDurationHistogram.record(durationMs.toDouble(), attributes: attributes);
  }

  /// Calculate the screen region from normalized coordinates.
  ///
  /// Returns one of: 'top-left', 'top-center', 'top-right',
  /// 'middle-left', 'center', 'middle-right',
  /// 'bottom-left', 'bottom-center', 'bottom-right'
  static String calculateRegion(double normalizedX, double normalizedY) {
    String horizontal;
    String vertical;

    if (normalizedX < 0.33) {
      horizontal = 'left';
    } else if (normalizedX < 0.67) {
      horizontal = 'center';
    } else {
      horizontal = 'right';
    }

    if (normalizedY < 0.33) {
      vertical = 'top';
    } else if (normalizedY < 0.67) {
      vertical = 'middle';
    } else {
      vertical = 'bottom';
    }

    if (vertical == 'middle' && horizontal == 'center') {
      return 'center';
    }

    return '$vertical-$horizontal';
  }
}
