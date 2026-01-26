import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_core/src/models/voo_context.dart';
import 'package:voo_core/src/models/voo_feature.dart';
import 'package:voo_core/src/services/voo_breadcrumb_service.dart';
import 'package:voo_core/src/services/voo_feature_config_service.dart';
import 'package:voo_core/src/voo.dart';

/// Callback type for external error capture (e.g., from VooLogger).
typedef VooErrorCaptureCallback = void Function({
  required String message,
  String? errorType,
  String? stackTrace,
});

/// Service for automatically submitting errors to the error tracking endpoint.
///
/// This service is automatically enabled when [Voo.initializeApp()] is called.
/// It submits errors to `POST {endpoint}/v1/errors/{projectId}` for the Error Tracking
/// dashboard.
///
/// ## Automatic Setup
///
/// Error tracking is automatically enabled after `Voo.initializeApp()`:
///
/// ```dart
/// await Voo.initializeApp(
///   config: VooConfig(
///     endpoint: 'https://api.example.com/api',
///     apiKey: 'your-api-key',
///     projectId: 'your-project-id',
///   ),
/// );
/// // Error tracking is now active!
/// ```
///
/// ## Manual Error Submission
///
/// ```dart
/// await VooErrorTrackingService.instance.submitError(
///   message: 'Something went wrong',
///   errorType: 'NullPointerException',
///   stackTrace: stackTrace.toString(),
/// );
/// ```
///
/// ## Integration with VooLogger
///
/// VooLogger automatically wires itself to this service during initialization,
/// so any `VooLogger.error()` or `VooLogger.fatal()` calls are automatically
/// submitted to error tracking.
class VooErrorTrackingService {
  static final VooErrorTrackingService _instance = VooErrorTrackingService._();
  static VooErrorTrackingService get instance => _instance;

  VooErrorTrackingService._();

  bool _enabled = false;

  /// Whether error tracking is currently enabled.
  bool get isEnabled => _enabled;

  /// Enable error tracking.
  ///
  /// This is called automatically by [Voo.initializeApp()].
  void enable() {
    _enabled = true;
  }

  /// Disable error tracking.
  void disable() {
    _enabled = false;
  }

  /// Submit an error to the error tracking endpoint.
  ///
  /// This is a fire-and-forget operation - errors during submission are
  /// logged but do not throw.
  ///
  /// Parameters:
  /// - [message]: The error message (required)
  /// - [errorType]: The exception/error class name
  /// - [stackTrace]: The stack trace string
  /// - [severity]: Error severity: 'low', 'medium', 'high', or 'critical'
  /// - [isFatal]: Whether this error caused an app crash
  /// - [source]: Source file where error occurred
  /// - [method]: Method name where error occurred
  /// - [lineNumber]: Line number where error occurred
  /// - [metadata]: Additional context data
  /// - [includeBreadcrumbs]: Whether to include recent breadcrumbs (default: true)
  Future<void> submitError({
    required String message,
    String? errorType,
    String? stackTrace,
    String severity = 'high',
    bool isFatal = false,
    String? source,
    String? method,
    int? lineNumber,
    Map<String, dynamic>? metadata,
    bool includeBreadcrumbs = true,
  }) async {
    if (!_enabled) return;
    // Check project-level feature toggle
    if (!VooFeatureConfigService.instance.isEnabled(VooFeature.errorTracking)) {
      return;
    }

    final context = Voo.context;
    if (context == null) {
      return;
    }

    final projectId = context.config.projectId;
    if (projectId == null || projectId.isEmpty) {
      return;
    }

    // Don't await - fire and forget
    _submitErrorAsync(
      context: context,
      projectId: projectId,  // Now guaranteed non-null after check
      message: message,
      errorType: errorType,
      stackTrace: stackTrace,
      severity: severity,
      isFatal: isFatal,
      source: source,
      method: method,
      lineNumber: lineNumber,
      metadata: metadata,
      includeBreadcrumbs: includeBreadcrumbs,
    );
  }

  Future<void> _submitErrorAsync({
    required VooContext context,
    required String projectId,
    required String message,
    String? errorType,
    String? stackTrace,
    String severity = 'high',
    bool isFatal = false,
    String? source,
    String? method,
    int? lineNumber,
    Map<String, dynamic>? metadata,
    bool includeBreadcrumbs = true,
  }) async {
    try {
      // Use telemetry errors endpoint (API key authenticated)
      final url = '${context.config.endpoint}/v1/telemetry/errors';

      // Collect breadcrumbs for error context
      List<Map<String, dynamic>>? breadcrumbsJson;
      if (includeBreadcrumbs) {
        final breadcrumbs = VooBreadcrumbService.getRecentBreadcrumbs(20);
        if (breadcrumbs.isNotEmpty) {
          breadcrumbsJson = breadcrumbs.map((b) => b.toJson()).toList();
        }
      }

      // Build error entry matching ErrorEntry DTO
      final errorEntry = {
        'message': message,
        'type': errorType ?? 'UnknownError',
        'severity': severity,
        'stackTrace': stackTrace ?? '',
        if (source != null) 'source': source,
        if (method != null) 'method': method,
        if (lineNumber != null) 'lineNumber': lineNumber,
        'context': {
          ...?metadata,
          if (breadcrumbsJson != null) 'breadcrumbs': breadcrumbsJson,
        },
        'isFatal': isFatal,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Build batch request matching ErrorsBatchRequest DTO
      final payload = {
        'errors': [errorEntry],
        'sessionId': Voo.sessionId ?? '',
        'deviceId': context.deviceId,
        'platform': _getPlatform(),
        'appVersion': context.appVersion,
      };

      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': context.config.apiKey,
        },
        body: jsonEncode(payload),
      );
    } catch (_) {
      // ignore
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }

  /// Creates an error capture callback for use with VooLogger.
  ///
  /// This returns a callback function that can be assigned to
  /// `LoggerRepositoryImpl.onErrorCaptured` to automatically submit
  /// errors to the error tracking endpoint.
  ///
  /// Example:
  /// ```dart
  /// import 'package:voo_logging/voo_logging.dart';
  /// import 'package:voo_core/voo_core.dart';
  ///
  /// // In your logger initialization:
  /// final repo = VooLogger.instance.repository as LoggerRepositoryImpl;
  /// repo.onErrorCaptured = VooErrorTrackingService.instance.createErrorCaptureCallback();
  /// ```
  VooErrorCaptureCallback createErrorCaptureCallback() {
    return ({
      required String message,
      String? errorType,
      String? stackTrace,
    }) {
      // Fire and forget - don't await
      submitError(
        message: message,
        errorType: errorType,
        stackTrace: stackTrace,
      );
    };
  }

  /// Reset the service state.
  void reset() {
    _enabled = false;
  }
}
