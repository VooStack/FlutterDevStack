import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:voo_analytics/src/utils/isolate_processing.dart';
import 'package:voo_core/voo_core.dart';

/// Configuration for replay capture.
class ReplayCaptureConfig {
  /// Whether replay capture is enabled.
  final bool enabled;

  /// Maximum events to buffer before flushing.
  final int maxBufferSize;

  /// Flush interval in milliseconds.
  final int flushIntervalMs;

  /// Whether to capture touch events.
  final bool captureTouches;

  /// Whether to capture screen transitions.
  final bool captureScreenViews;

  /// Whether to capture network requests.
  final bool captureNetwork;

  /// Whether to capture logs.
  final bool captureLogs;

  /// Whether to capture errors.
  final bool captureErrors;

  /// Whether to capture screenshots at screen transitions.
  final bool captureScreenshots;

  /// Quality for screenshot compression (0.0 to 1.0).
  final double screenshotQuality;

  /// Maximum screenshot width (height scales proportionally).
  final int maxScreenshotWidth;

  const ReplayCaptureConfig({
    this.enabled = false,
    this.maxBufferSize = 100,
    this.flushIntervalMs = 5000,
    this.captureTouches = true,
    this.captureScreenViews = true,
    this.captureNetwork = true,
    this.captureLogs = false,
    this.captureErrors = true,
    this.captureScreenshots = true,
    this.screenshotQuality = 0.7,
    this.maxScreenshotWidth = 720,
  });

  ReplayCaptureConfig copyWith({
    bool? enabled,
    int? maxBufferSize,
    int? flushIntervalMs,
    bool? captureTouches,
    bool? captureScreenViews,
    bool? captureNetwork,
    bool? captureLogs,
    bool? captureErrors,
    bool? captureScreenshots,
    double? screenshotQuality,
    int? maxScreenshotWidth,
  }) {
    return ReplayCaptureConfig(
      enabled: enabled ?? this.enabled,
      maxBufferSize: maxBufferSize ?? this.maxBufferSize,
      flushIntervalMs: flushIntervalMs ?? this.flushIntervalMs,
      captureTouches: captureTouches ?? this.captureTouches,
      captureScreenViews: captureScreenViews ?? this.captureScreenViews,
      captureNetwork: captureNetwork ?? this.captureNetwork,
      captureLogs: captureLogs ?? this.captureLogs,
      captureErrors: captureErrors ?? this.captureErrors,
      captureScreenshots: captureScreenshots ?? this.captureScreenshots,
      screenshotQuality: screenshotQuality ?? this.screenshotQuality,
      maxScreenshotWidth: maxScreenshotWidth ?? this.maxScreenshotWidth,
    );
  }
}

/// A single replay event to be captured.
class ReplayEventCapture {
  final String eventType;
  final DateTime timestamp;
  final int offsetMs;
  final String? screenName;
  final double? x;
  final double? y;
  final String? touchType;
  final Map<String, dynamic>? metadata;

  ReplayEventCapture({required this.eventType, required this.timestamp, required this.offsetMs, this.screenName, this.x, this.y, this.touchType, this.metadata});

  Map<String, dynamic> toJson() => {
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    'offsetMs': offsetMs,
    if (screenName != null) 'screenName': screenName,
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    if (touchType != null) 'touchType': touchType,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Service for capturing session replay events.
///
/// This service captures events like touches, screen transitions, network
/// requests, and errors to enable session replay functionality.
///
/// ## Usage
///
/// ```dart
/// // Enable replay capture
/// ReplayCaptureService.instance.enable();
///
/// // Capture a touch event
/// ReplayCaptureService.instance.captureTouch(
///   x: 0.5,
///   y: 0.3,
///   touchType: 'tap',
///   screenName: 'HomeScreen',
/// );
///
/// // Disable when needed
/// ReplayCaptureService.instance.disable();
/// ```
class ReplayCaptureService {
  static final ReplayCaptureService _instance = ReplayCaptureService._();
  static ReplayCaptureService get instance => _instance;

  ReplayCaptureConfig _config = const ReplayCaptureConfig();
  final List<ReplayEventCapture> _eventBuffer = [];
  Timer? _flushTimer;
  DateTime? _sessionStartTime;
  String? _currentScreenName;
  bool _isEnabled = false;

  /// Global key for the RepaintBoundary to capture screenshots.
  /// Set this to the key of a RepaintBoundary wrapping your app content.
  RenderRepaintBoundary? _repaintBoundary;

  /// Set to true when a screenshot capture is in progress.
  bool _isCapturing = false;

  ReplayCaptureService._();

  /// Set the render object to capture screenshots from.
  /// This should be a RenderRepaintBoundary from a RepaintBoundary widget.
  void setRepaintBoundary(RenderRepaintBoundary? boundary) {
    _repaintBoundary = boundary;
  }

  /// Whether replay capture is currently enabled and active.
  ///
  /// Returns false if:
  /// - The service is not enabled locally
  /// - The local config has `enabled` set to false
  /// - The project-level feature toggle for session replay is disabled
  bool get isEnabled {
    // Check project-level feature toggle first
    if (!Voo.featureConfig.isEnabled(VooFeature.sessionReplay)) {
      return false;
    }
    // Then check local config
    return _isEnabled && _config.enabled;
  }

  /// Current configuration.
  ReplayCaptureConfig get config => _config;

  /// Number of events currently buffered.
  int get bufferSize => _eventBuffer.length;

  /// Configure the replay capture service.
  void configure(ReplayCaptureConfig config) {
    _config = config;
    if (config.enabled && _isEnabled) {
      _startFlushTimer();
    }
  }

  /// Enable replay capture for the current session.
  void enable() {
    if (_isEnabled) return;

    _isEnabled = true;
    _sessionStartTime = DateTime.now();
    _eventBuffer.clear();

    if (_config.enabled) {
      _startFlushTimer();
    }
  }

  /// Disable replay capture.
  void disable() {
    if (!_isEnabled) return;

    _isEnabled = false;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Flush remaining events
    if (_eventBuffer.isNotEmpty) {
      _flush();
    }
  }

  /// Capture a touch event.
  void captureTouch({required double x, required double y, String? touchType, String? screenName}) {
    if (!isEnabled || !_config.captureTouches) return;

    _addEvent(
      ReplayEventCapture(
        eventType: 'touch',
        timestamp: DateTime.now(),
        offsetMs: _calculateOffset(),
        screenName: screenName ?? _currentScreenName,
        x: x,
        y: y,
        touchType: touchType ?? 'tap',
      ),
    );
  }

  /// Capture a screen view transition.
  void captureScreenView({required String screenName, String? routePath}) {
    if (!isEnabled || !_config.captureScreenViews) {
      return;
    }

    _currentScreenName = screenName;

    _addEvent(
      ReplayEventCapture(
        eventType: 'screenView',
        timestamp: DateTime.now(),
        offsetMs: _calculateOffset(),
        screenName: screenName,
        metadata: routePath != null ? {'routePath': routePath} : null,
      ),
    );

    // Also capture screenshot if enabled
    if (_config.captureScreenshots) {
      // Delay slightly to let the new screen render
      Future.delayed(const Duration(milliseconds: 100), () {
        captureScreenshot(screenName: screenName, captureReason: 'screen_transition');
      });
    }
  }

  /// Capture a screenshot of the current screen.
  ///
  /// The screenshot is captured from the RepaintBoundary set via
  /// [setRepaintBoundary]. If no boundary is set, this method does nothing.
  ///
  /// Screenshots are uploaded to the backend asynchronously.
  Future<void> captureScreenshot({String? screenName, String captureReason = 'manual'}) async {
    if (!isEnabled || !_config.captureScreenshots) {
      return;
    }
    if (_repaintBoundary == null) {
      return;
    }
    if (_isCapturing) {
      return;
    }

    _isCapturing = true;

    try {
      final boundary = _repaintBoundary!;

      // Check if boundary is attached and has valid size
      if (!boundary.attached) {
        return;
      }

      // Calculate pixel ratio for downscaling
      final originalWidth = boundary.size.width;
      final originalHeight = boundary.size.height;

      if (originalWidth <= 0 || originalHeight <= 0) {
        return;
      }

      final targetWidth = _config.maxScreenshotWidth.toDouble();
      final pixelRatio = originalWidth > targetWidth ? targetWidth / originalWidth : 1.0;

      // Capture the image
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return;
      }

      final bytes = byteData.buffer.asUint8List();

      if (bytes.isEmpty) {
        return;
      }

      // Process screenshot in isolate to avoid UI jank
      // This moves base64 encoding and SHA256 hashing off the main thread
      final result = await IsolateProcessing.processScreenshot(bytes);
      final base64Data = result.base64Data;
      final contentHash = result.contentHash;

      final effectiveScreenName = screenName ?? _currentScreenName ?? 'unknown';

      // Upload to backend
      await _uploadScreenshot(
        screenName: effectiveScreenName,
        contentHash: contentHash,
        base64Data: base64Data,
        width: image.width,
        height: image.height,
        sizeBytes: bytes.length,
        captureReason: captureReason,
      );
    } catch (_) {
      // ignore
    } finally {
      _isCapturing = false;
    }
  }

  /// Upload a screenshot to the backend.
  Future<void> _uploadScreenshot({
    required String screenName,
    required String contentHash,
    required String base64Data,
    required int width,
    required int height,
    required int sizeBytes,
    required String captureReason,
  }) async {
    final sessionId = Voo.sessionId;
    final context = Voo.context;

    if (sessionId == null) {
      return;
    }

    if (context == null) {
      return;
    }

    final url = '${context.config.endpoint}/v1/replay/sessions/$sessionId/screenshots';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'X-API-Key': context.config.apiKey},
        body: jsonEncode({
          'screenName': screenName,
          'contentHash': contentHash,
          'base64Data': base64Data,
          'width': width,
          'height': height,
          'sizeBytes': sizeBytes,
          'offsetMs': _calculateOffset(),
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'captureReason': captureReason,
          // Include device info for auto-creating session if needed
          'platform': context.platform,
          'appVersion': context.appVersion,
          'deviceId': context.deviceId,
        }),
      );

      if (response.statusCode >= 400) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow; // Re-throw so the caller knows it failed
    }
  }

  /// Capture a network request.
  void captureNetwork({required String method, required String url, int? statusCode, int? durationMs, bool isError = false}) {
    if (!isEnabled || !_config.captureNetwork) return;

    _addEvent(
      ReplayEventCapture(
        eventType: 'network',
        timestamp: DateTime.now(),
        offsetMs: _calculateOffset(),
        screenName: _currentScreenName,
        metadata: {'method': method, 'url': url, if (statusCode != null) 'statusCode': statusCode, if (durationMs != null) 'durationMs': durationMs, 'isError': isError},
      ),
    );
  }

  /// Capture an error.
  void captureError({required String message, String? errorType, String? stackTrace}) {
    if (!isEnabled || !_config.captureErrors) return;

    _addEvent(
      ReplayEventCapture(
        eventType: 'error',
        timestamp: DateTime.now(),
        offsetMs: _calculateOffset(),
        screenName: _currentScreenName,
        metadata: {'message': message, if (errorType != null) 'errorType': errorType, if (stackTrace != null) 'stackTrace': stackTrace},
      ),
    );
  }

  /// Capture a log entry.
  void captureLog({required String level, required String message, String? category}) {
    if (!isEnabled || !_config.captureLogs) return;

    _addEvent(
      ReplayEventCapture(
        eventType: 'log',
        timestamp: DateTime.now(),
        offsetMs: _calculateOffset(),
        screenName: _currentScreenName,
        metadata: {'level': level, 'message': message, if (category != null) 'category': category},
      ),
    );
  }

  /// Capture a lifecycle event (app foreground/background).
  void captureLifecycle({required String state}) {
    if (!isEnabled) return;

    _addEvent(ReplayEventCapture(eventType: 'lifecycle', timestamp: DateTime.now(), offsetMs: _calculateOffset(), screenName: _currentScreenName, metadata: {'state': state}));
  }

  /// Capture a custom event.
  void captureCustom({required String name, Map<String, dynamic>? data}) {
    if (!isEnabled) return;

    _addEvent(
      ReplayEventCapture(
        eventType: 'custom',
        timestamp: DateTime.now(),
        offsetMs: _calculateOffset(),
        screenName: _currentScreenName,
        metadata: {'name': name, if (data != null) ...data},
      ),
    );
  }

  void _addEvent(ReplayEventCapture event) {
    _eventBuffer.add(event);

    // Check if buffer is full
    if (_eventBuffer.length >= _config.maxBufferSize) {
      _flush();
    }
  }

  int _calculateOffset() {
    if (_sessionStartTime == null) return 0;
    return DateTime.now().difference(_sessionStartTime!).inMilliseconds;
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(Duration(milliseconds: _config.flushIntervalMs), (_) => _flush());
  }

  Future<void> _flush() async {
    if (_eventBuffer.isEmpty) return;

    final sessionId = Voo.sessionId;
    final context = Voo.context;

    if (sessionId == null || context == null) {
      return;
    }

    // Copy and clear buffer
    final events = List<ReplayEventCapture>.from(_eventBuffer);
    _eventBuffer.clear();

    try {
      // Build payload
      final payload = {'events': events.map((e) => e.toJson()).toList()};

      // Send to backend
      await _sendToBackend(sessionId, payload);
    } catch (_) {
      // Re-add events to buffer on failure (with limit)
      final remaining = _config.maxBufferSize - _eventBuffer.length;
      if (remaining > 0) {
        _eventBuffer.insertAll(0, events.take(remaining));
      }
    }
  }

  Future<void> _sendToBackend(String sessionId, Map<String, dynamic> payload) async {
    final context = Voo.context;
    if (context == null) return;

    final url = '${context.config.endpoint}/v1/replay/sessions/$sessionId/events';

    try {
      final response = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'X-API-Key': context.config.apiKey}, body: jsonEncode(payload));

      if (response.statusCode >= 400) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Force flush all buffered events immediately.
  Future<void> flushNow() => _flush();

  /// Clear all buffered events without sending.
  void clearBuffer() {
    _eventBuffer.clear();
  }

  /// Reset the service state.
  void reset() {
    disable();
    _sessionStartTime = null;
    _currentScreenName = null;
    _eventBuffer.clear();
    _config = const ReplayCaptureConfig();
  }

  /// Creates an error capture callback for use with VooLogger.
  ///
  /// This returns a callback function that can be assigned to
  /// `LoggerRepositoryImpl.onErrorCaptured` to automatically capture
  /// errors for session replay.
  ///
  /// Example:
  /// ```dart
  /// import 'package:voo_logging/voo_logging.dart';
  /// import 'package:voo_analytics/voo_analytics.dart';
  ///
  /// // In your app initialization:
  /// final repo = VooLogger.instance.repository as LoggerRepositoryImpl;
  /// repo.onErrorCaptured = ReplayCaptureService.instance.createErrorCaptureCallback();
  /// ```
  void Function({required String message, String? errorType, String? stackTrace}) createErrorCaptureCallback() {
    return ({required String message, String? errorType, String? stackTrace}) {
      captureError(message: message, errorType: errorType, stackTrace: stackTrace);
    };
  }
}
