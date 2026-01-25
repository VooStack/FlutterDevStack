import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb, immutable, visibleForTesting;
import 'package:flutter/scheduler.dart';

/// A single FPS measurement sample.
@immutable
class FpsSample {
  /// Frames per second at this sample time.
  final double fps;

  /// Whether the frame was considered janky (dropped frame).
  final bool isJanky;

  /// Frame build duration in milliseconds.
  final double frameDurationMs;

  /// Timestamp of this sample.
  final DateTime timestamp;

  const FpsSample({
    required this.fps,
    required this.isJanky,
    required this.frameDurationMs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'fps': fps,
      'isJanky': isJanky,
      'frameDurationMs': frameDurationMs,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Aggregated FPS statistics over a time period.
@immutable
class FpsStats {
  /// Average FPS over the period.
  final double averageFps;

  /// Minimum FPS observed.
  final double minFps;

  /// Maximum FPS observed.
  final double maxFps;

  /// Number of janky frames (dropped frames).
  final int jankyFrameCount;

  /// Total number of frames measured.
  final int totalFrameCount;

  /// Percentage of frames that were janky.
  final double jankyPercentage;

  /// Start of the measurement period.
  final DateTime startTime;

  /// End of the measurement period.
  final DateTime endTime;

  const FpsStats({
    required this.averageFps,
    required this.minFps,
    required this.maxFps,
    required this.jankyFrameCount,
    required this.totalFrameCount,
    required this.jankyPercentage,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'averageFps': averageFps,
      'minFps': minFps,
      'maxFps': maxFps,
      'jankyFrameCount': jankyFrameCount,
      'totalFrameCount': totalFrameCount,
      'jankyPercentage': jankyPercentage,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FpsStats(avg: ${averageFps.toStringAsFixed(1)} fps, '
        'jank: ${jankyPercentage.toStringAsFixed(1)}%, '
        'dropped: $jankyFrameCount/$totalFrameCount)';
  }
}

/// Service for monitoring frames per second and detecting jank.
///
/// Jank occurs when frames take longer than expected to render,
/// causing visible stuttering in the UI. This service uses
/// Flutter's [SchedulerBinding] to track frame timings.
///
/// ## Usage
///
/// ```dart
/// // Start monitoring
/// FpsMonitorService.startMonitoring();
///
/// // Get current FPS
/// print('Current FPS: ${FpsMonitorService.currentFps}');
///
/// // Check if janking
/// if (FpsMonitorService.isJanking) {
///   print('Warning: UI is janking!');
/// }
///
/// // Get statistics
/// final stats = FpsMonitorService.getStats();
/// print('Jank rate: ${stats.jankyPercentage}%');
///
/// // Listen to FPS changes
/// FpsMonitorService.fpsStream.listen((sample) {
///   if (sample.isJanky) {
///     print('Janky frame detected!');
///   }
/// });
///
/// // Stop monitoring
/// FpsMonitorService.stopMonitoring();
/// ```
class FpsMonitorService {
  static FpsMonitorService? _instance;
  static bool _isMonitoring = false;

  /// Target frame duration (60 FPS = 16.67ms per frame).
  static const double _targetFrameDurationMs = 1000.0 / 60.0;

  /// Threshold for considering a frame as janky (missed 2+ frames).
  static const double _jankThresholdMs = _targetFrameDurationMs * 2;

  /// Rolling window of recent samples for statistics.
  final Queue<FpsSample> _samples = Queue();

  /// Maximum samples to keep for rolling statistics.
  static const int _maxSamples = 120; // ~2 seconds at 60fps

  /// Stream controller for FPS samples.
  final StreamController<FpsSample> _fpsController =
      StreamController<FpsSample>.broadcast();

  /// Start time of the current monitoring session.
  DateTime? _sessionStartTime;

  /// Count of janky frames in the current session.
  int _sessionJankyFrames = 0;

  /// Total frames in the current session.
  int _sessionTotalFrames = 0;

  FpsMonitorService._();

  /// Get the singleton instance.
  static FpsMonitorService get instance {
    _instance ??= FpsMonitorService._();
    return _instance!;
  }

  /// Whether FPS monitoring is active.
  static bool get isMonitoring => _isMonitoring;

  /// Stream of FPS samples.
  static Stream<FpsSample> get fpsStream => instance._fpsController.stream;

  /// Current instantaneous FPS.
  static double get currentFps {
    if (instance._samples.isEmpty) return 60.0;
    return instance._samples.last.fps;
  }

  /// Whether the UI is currently experiencing jank.
  ///
  /// Returns true if the last few frames have been janky.
  static bool get isJanking {
    if (instance._samples.length < 3) return false;

    // Check last 3 frames
    final recent = instance._samples.toList().reversed.take(3);
    final jankyCount = recent.where((s) => s.isJanky).length;
    return jankyCount >= 2;
  }

  /// Number of dropped/janky frames in the current session.
  static int get droppedFrameCount => instance._sessionJankyFrames;

  /// Total frames counted in the current session.
  static int get totalFrameCount => instance._sessionTotalFrames;

  /// Jank percentage in the current session.
  static double get jankPercentage {
    if (instance._sessionTotalFrames == 0) return 0.0;
    return (instance._sessionJankyFrames / instance._sessionTotalFrames) * 100;
  }

  /// Timer for web fallback FPS simulation.
  Timer? _webFallbackTimer;

  /// Start monitoring FPS.
  static void startMonitoring() {
    if (_isMonitoring) return;

    instance._samples.clear();
    instance._sessionStartTime = DateTime.now();
    instance._sessionJankyFrames = 0;
    instance._sessionTotalFrames = 0;

    if (kIsWeb) {
      // On web, frame timings are not available, use a periodic timer fallback
      instance._startWebFallback();
    } else {
      // Add frame timing callback (works on mobile/desktop)
      SchedulerBinding.instance.addTimingsCallback(instance._onFrameTimings);
    }
    _isMonitoring = true;

    if (kDebugMode) {
      debugPrint('FpsMonitorService: Started monitoring (web: $kIsWeb)');
    }
  }

  /// Stop monitoring FPS.
  static void stopMonitoring() {
    if (!_isMonitoring) return;

    if (kIsWeb) {
      instance._webFallbackTimer?.cancel();
      instance._webFallbackTimer = null;
    } else {
      SchedulerBinding.instance.removeTimingsCallback(instance._onFrameTimings);
    }
    _isMonitoring = false;

    if (kDebugMode) {
      final stats = getStats();
      debugPrint('FpsMonitorService: Stopped - $stats');
    }
  }

  /// Web fallback: emit estimated FPS samples periodically.
  /// On web, we can't get actual frame timings, so we emit baseline metrics.
  void _startWebFallback() {
    // Emit an FPS sample every 500ms (assuming smooth 60fps on web)
    _webFallbackTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // Since we can't measure actual frame timing on web, assume 60fps baseline
      // This at least sends data to show the pipeline is working
      final sample = FpsSample(
        fps: 60.0,
        isJanky: false,
        frameDurationMs: _targetFrameDurationMs,
        timestamp: DateTime.now(),
      );

      _sessionTotalFrames += 30; // ~30 frames per 500ms at 60fps
      _samples.add(sample);
      while (_samples.length > _maxSamples) {
        _samples.removeFirst();
      }

      _fpsController.add(sample);

      if (kDebugMode) {
        debugPrint('FpsMonitorService [web]: Emitted FPS sample');
      }
    });
  }

  /// Get aggregated statistics for the current session.
  static FpsStats getStats() {
    final samples = instance._samples.toList();

    if (samples.isEmpty) {
      return FpsStats(
        averageFps: 60.0,
        minFps: 60.0,
        maxFps: 60.0,
        jankyFrameCount: 0,
        totalFrameCount: 0,
        jankyPercentage: 0.0,
        startTime: instance._sessionStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
      );
    }

    final fpsValues = samples.map((s) => s.fps).toList();
    final avgFps = fpsValues.reduce((a, b) => a + b) / fpsValues.length;
    final minFps = fpsValues.reduce((a, b) => a < b ? a : b);
    final maxFps = fpsValues.reduce((a, b) => a > b ? a : b);

    return FpsStats(
      averageFps: avgFps,
      minFps: minFps,
      maxFps: maxFps,
      jankyFrameCount: instance._sessionJankyFrames,
      totalFrameCount: instance._sessionTotalFrames,
      jankyPercentage: jankPercentage,
      startTime: instance._sessionStartTime ?? samples.first.timestamp,
      endTime: samples.last.timestamp,
    );
  }

  /// Get recent FPS samples.
  static List<FpsSample> getRecentSamples([int count = 60]) {
    final samples = instance._samples.toList();
    if (samples.length <= count) return samples;
    return samples.sublist(samples.length - count);
  }

  /// Frame timing callback.
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _processFrameTiming(timing);
    }
  }

  /// Process a single frame timing.
  void _processFrameTiming(FrameTiming timing) {
    // Calculate frame duration
    final buildDuration = timing.buildDuration.inMicroseconds / 1000.0;
    final rasterDuration = timing.rasterDuration.inMicroseconds / 1000.0;
    final totalDuration = buildDuration + rasterDuration;

    // Calculate FPS from frame duration
    final fps = 1000.0 / totalDuration;
    final isJanky = totalDuration > _jankThresholdMs;

    _sessionTotalFrames++;
    if (isJanky) {
      _sessionJankyFrames++;
    }

    final sample = FpsSample(
      fps: fps.clamp(0.0, 120.0), // Clamp to reasonable range
      isJanky: isJanky,
      frameDurationMs: totalDuration,
      timestamp: DateTime.now(),
    );

    // Add to rolling window
    _samples.add(sample);
    while (_samples.length > _maxSamples) {
      _samples.removeFirst();
    }

    // Notify listeners
    _fpsController.add(sample);

    if (kDebugMode && isJanky) {
      debugPrint(
          'FpsMonitorService: Jank detected! Frame took ${totalDuration.toStringAsFixed(1)}ms');
    }
  }

  /// Dispose resources.
  static Future<void> dispose() async {
    stopMonitoring();
    await instance._fpsController.close();
    instance._samples.clear();
    _instance = null;

    if (kDebugMode) {
      debugPrint('FpsMonitorService: Disposed');
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    if (_isMonitoring) {
      stopMonitoring();
    }
    instance._samples.clear();
    instance._sessionJankyFrames = 0;
    instance._sessionTotalFrames = 0;
    _instance = null;
  }
}
