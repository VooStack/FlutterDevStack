import 'package:voo_telemetry/voo_telemetry.dart';
import '../semantic_conventions.dart';

/// Export FPS metrics using OTEL Histogram and Counter instruments.
///
/// Tracks:
/// - FPS values as histogram for distribution analysis
/// - Jank count as counter for total jank events
/// - Frame duration as histogram for detailed timing analysis
class OtelFpsMetric {
  final Meter _meter;

  late final Histogram _fpsHistogram;
  late final Counter _jankCounter;
  late final Histogram _frameDurationHistogram;

  /// Flag indicating if metrics are initialized.
  bool _initialized = false;

  OtelFpsMetric(this._meter);

  /// Initialize the FPS metric instruments.
  void initialize() {
    if (_initialized) return;

    _fpsHistogram = _meter.createHistogram(
      AppSemanticConventions.appRenderFps,
      description: 'Frames per second measurement',
      unit: 'fps',
      explicitBounds: [15, 30, 45, 55, 58, 60, 90, 120],
    );

    _jankCounter = _meter.createCounter(
      AppSemanticConventions.appRenderJankCount,
      description: 'Count of janky frames (>33.33ms)',
      unit: '{frames}',
    );

    _frameDurationHistogram = _meter.createHistogram(
      AppSemanticConventions.appRenderFrameDurationMs,
      description: 'Frame render duration in milliseconds',
      unit: 'ms',
      explicitBounds: [8, 16, 24, 33, 50, 100, 200],
    );

    _initialized = true;
  }

  /// Record an FPS sample.
  ///
  /// [fps] The measured frames per second.
  /// [frameDurationMs] The frame duration in milliseconds.
  /// [isJanky] Whether this frame is considered janky (>16.67ms for 60fps).
  /// [screenName] Optional screen context for correlation.
  void recordSample({
    required double fps,
    required double frameDurationMs,
    required bool isJanky,
    String? screenName,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      AppSemanticConventions.appRenderIsJanky: isJanky,
      if (screenName != null) 'ui.screen.name': screenName,
    };

    _fpsHistogram.record(fps, attributes: attributes);
    _frameDurationHistogram.record(frameDurationMs, attributes: attributes);

    if (isJanky) {
      _jankCounter.increment(attributes: attributes);
    }
  }

  /// Record FPS statistics from a batch of samples.
  ///
  /// Useful for recording aggregated FPS data from FpsMonitorService.
  void recordStats({
    required double avgFps,
    required double minFps,
    required double maxFps,
    required int jankFrameCount,
    required int totalFrameCount,
    String? screenName,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      'fps.min': minFps,
      'fps.max': maxFps,
      'fps.jank_percentage': totalFrameCount > 0 ? (jankFrameCount / totalFrameCount * 100) : 0,
      if (screenName != null) 'ui.screen.name': screenName,
    };

    _fpsHistogram.record(avgFps, attributes: attributes);
  }
}
