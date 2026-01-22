import 'package:voo_telemetry/voo_telemetry.dart';
import '../semantic_conventions.dart';

/// Launch type classification.
enum LaunchType {
  /// First launch after installation or update.
  cold,

  /// Launch from background after app was terminated.
  warm,

  /// Launch from background while app was still in memory.
  hot,
}

/// Export app launch metrics using OTEL Histogram instruments.
///
/// Tracks:
/// - Total launch duration
/// - Time to first frame (TTFF)
/// - Time to interactive (TTI)
class OtelAppLaunchMetric {
  final Tracer _tracer;
  final Meter _meter;

  late final Histogram _launchDurationHistogram;
  late final Histogram _ttffHistogram;
  late final Histogram _ttiHistogram;

  /// Flag indicating if metrics are initialized.
  bool _initialized = false;

  OtelAppLaunchMetric(this._tracer, this._meter);

  /// Initialize the app launch metric instruments.
  void initialize() {
    if (_initialized) return;

    _launchDurationHistogram = _meter.createHistogram(
      AppSemanticConventions.appLaunchDurationMs,
      description: 'Total app launch duration in milliseconds',
      unit: 'ms',
      explicitBounds: [500, 1000, 2000, 3000, 5000, 7500, 10000],
    );

    _ttffHistogram = _meter.createHistogram(
      AppSemanticConventions.appLaunchTtffMs,
      description: 'Time to first frame in milliseconds',
      unit: 'ms',
      explicitBounds: [100, 250, 500, 1000, 2000, 3000],
    );

    _ttiHistogram = _meter.createHistogram(
      AppSemanticConventions.appLaunchTtiMs,
      description: 'Time to interactive in milliseconds',
      unit: 'ms',
      explicitBounds: [500, 1000, 2000, 3000, 5000, 7500, 10000],
    );

    _initialized = true;
  }

  /// Record app launch metrics.
  ///
  /// [launchType] The type of launch (cold, warm, hot).
  /// [totalLaunchMs] Total duration from start to interactive.
  /// [timeToFirstFrameMs] Time until first frame was rendered.
  /// [timeToInteractiveMs] Time until app was fully interactive.
  /// [isSuccessful] Whether the launch completed successfully.
  /// [isSlow] Whether the launch exceeded acceptable thresholds.
  void recordLaunch({
    required LaunchType launchType,
    int? totalLaunchMs,
    int? timeToFirstFrameMs,
    int? timeToInteractiveMs,
    bool isSuccessful = true,
    bool isSlow = false,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      AppSemanticConventions.appLaunchType: launchType.name,
      AppSemanticConventions.appLaunchIsSuccessful: isSuccessful,
      AppSemanticConventions.appLaunchIsSlow: isSlow,
    };

    if (totalLaunchMs != null) {
      _launchDurationHistogram.record(
        totalLaunchMs.toDouble(),
        attributes: attributes,
      );
    }

    if (timeToFirstFrameMs != null) {
      _ttffHistogram.record(
        timeToFirstFrameMs.toDouble(),
        attributes: attributes,
      );
    }

    if (timeToInteractiveMs != null) {
      _ttiHistogram.record(
        timeToInteractiveMs.toDouble(),
        attributes: attributes,
      );
    }
  }

  /// Create a span for app launch tracing.
  ///
  /// Returns a span that should be ended when the launch is complete.
  Span startLaunchSpan(LaunchType type) {
    return _tracer.startSpan(
      'app.launch',
      kind: SpanKind.internal,
      attributes: {
        AppSemanticConventions.appLaunchType: type.name,
      },
    );
  }

  /// End a launch span with metrics.
  void endLaunchSpan(
    Span span, {
    bool isSuccessful = true,
    bool isSlow = false,
    int? timeToFirstFrameMs,
    int? timeToInteractiveMs,
  }) {
    span.setAttributes({
      AppSemanticConventions.appLaunchIsSuccessful: isSuccessful,
      AppSemanticConventions.appLaunchIsSlow: isSlow,
      if (timeToFirstFrameMs != null) AppSemanticConventions.appLaunchTtffMs: timeToFirstFrameMs,
      if (timeToInteractiveMs != null) AppSemanticConventions.appLaunchTtiMs: timeToInteractiveMs,
    });

    if (isSuccessful) {
      span.status = SpanStatus.ok();
    } else {
      span.status = SpanStatus.error(description: 'App launch failed');
    }

    span.end();
  }
}
