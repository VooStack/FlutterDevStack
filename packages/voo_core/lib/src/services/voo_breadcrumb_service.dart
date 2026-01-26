import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:voo_core/src/models/voo_breadcrumb.dart';

/// Service for managing the breadcrumb trail.
///
/// Breadcrumbs capture the user's journey through the app and are attached
/// to error reports to provide context. The service maintains a circular
/// buffer of the most recent breadcrumbs.
///
/// ## Usage
///
/// ```dart
/// // Initialize during app startup
/// VooBreadcrumbService.initialize(maxBreadcrumbs: 100);
///
/// // Add breadcrumbs (automatic for navigation, HTTP, etc.)
/// VooBreadcrumbService.addBreadcrumb(VooBreadcrumb.navigation(
///   from: 'HomeScreen',
///   to: 'ProfileScreen',
/// ));
///
/// // Get recent breadcrumbs for error context
/// final trail = VooBreadcrumbService.getRecentBreadcrumbs(50);
/// ```
class VooBreadcrumbService {
  static VooBreadcrumbService? _instance;
  static bool _initialized = false;
  static int _maxBreadcrumbs = 100;

  /// The breadcrumb trail (circular buffer).
  final Queue<VooBreadcrumb> _breadcrumbs = Queue<VooBreadcrumb>();

  /// Callbacks for when breadcrumbs are added.
  final List<void Function(VooBreadcrumb)> _listeners = [];

  VooBreadcrumbService._();

  /// Get the singleton instance.
  static VooBreadcrumbService get instance {
    _instance ??= VooBreadcrumbService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Current number of breadcrumbs in the trail.
  static int get count => instance._breadcrumbs.length;

  /// Maximum number of breadcrumbs to retain.
  static int get maxBreadcrumbs => _maxBreadcrumbs;

  /// Initialize the breadcrumb service.
  ///
  /// [maxBreadcrumbs] sets the maximum number of breadcrumbs to retain.
  /// Older breadcrumbs are removed when this limit is exceeded.
  static void initialize({int maxBreadcrumbs = 100}) {
    _maxBreadcrumbs = maxBreadcrumbs;
    _initialized = true;
  }

  /// Add a breadcrumb to the trail.
  ///
  /// If the trail exceeds [maxBreadcrumbs], the oldest breadcrumb is removed.
  static void addBreadcrumb(VooBreadcrumb breadcrumb) {
    if (!_initialized) {
      initialize();
    }

    instance._breadcrumbs.add(breadcrumb);

    // Enforce max size (remove oldest)
    while (instance._breadcrumbs.length > _maxBreadcrumbs) {
      instance._breadcrumbs.removeFirst();
    }

    // Notify listeners
    for (final listener in instance._listeners) {
      try {
        listener(breadcrumb);
      } catch (_) {
        // ignore
      }
    }
  }

  /// Add a navigation breadcrumb.
  static void addNavigationBreadcrumb({
    required String from,
    required String to,
    String action = 'push',
    Map<String, dynamic>? routeParams,
  }) {
    addBreadcrumb(VooBreadcrumb.navigation(
      from: from,
      to: to,
      action: action,
      routeParams: routeParams,
    ));
  }

  /// Add an HTTP request breadcrumb.
  static void addHttpBreadcrumb({
    required String method,
    required String url,
    int? statusCode,
    int? durationMs,
    int? requestSize,
    int? responseSize,
    bool isError = false,
  }) {
    addBreadcrumb(VooBreadcrumb.http(
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: durationMs,
      requestSize: requestSize,
      responseSize: responseSize,
      isError: isError,
    ));
  }

  /// Add a user action breadcrumb.
  static void addUserActionBreadcrumb({
    required String action,
    String? elementId,
    String? elementType,
    String? screenName,
    Map<String, dynamic>? additionalData,
  }) {
    addBreadcrumb(VooBreadcrumb.userAction(
      action: action,
      elementId: elementId,
      elementType: elementType,
      screenName: screenName,
      additionalData: additionalData,
    ));
  }

  /// Add a console/debug breadcrumb.
  static void addConsoleBreadcrumb({
    required String message,
    VooBreadcrumbLevel level = VooBreadcrumbLevel.debug,
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(VooBreadcrumb.console(
      message: message,
      level: level,
      data: data,
    ));
  }

  /// Add an error breadcrumb.
  static void addErrorBreadcrumb({
    required String message,
    String? errorType,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    addBreadcrumb(VooBreadcrumb.error(
      message: message,
      errorType: errorType,
      stackTrace: stackTrace,
      additionalData: additionalData,
    ));
  }

  /// Add a system event breadcrumb.
  static void addSystemBreadcrumb({
    required String event,
    VooBreadcrumbLevel level = VooBreadcrumbLevel.info,
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(VooBreadcrumb.system(
      event: event,
      level: level,
      data: data,
    ));
  }

  /// Get the most recent breadcrumbs.
  ///
  /// Returns up to [count] breadcrumbs, newest first.
  static List<VooBreadcrumb> getRecentBreadcrumbs([int count = 50]) {
    final all = instance._breadcrumbs.toList();
    final startIndex = all.length > count ? all.length - count : 0;
    return all.sublist(startIndex).reversed.toList();
  }

  /// Get all breadcrumbs.
  ///
  /// Returns breadcrumbs in chronological order (oldest first).
  static List<VooBreadcrumb> getAllBreadcrumbs() {
    return instance._breadcrumbs.toList();
  }

  /// Get breadcrumbs as JSON for sync payloads.
  static List<Map<String, dynamic>> getRecentBreadcrumbsJson([int count = 50]) {
    return getRecentBreadcrumbs(count).map((b) => b.toJson()).toList();
  }

  /// Get breadcrumbs filtered by type.
  static List<VooBreadcrumb> getBreadcrumbsByType(VooBreadcrumbType type) {
    return instance._breadcrumbs.where((b) => b.type == type).toList();
  }

  /// Get breadcrumbs filtered by level.
  static List<VooBreadcrumb> getBreadcrumbsByLevel(VooBreadcrumbLevel level) {
    return instance._breadcrumbs.where((b) => b.level == level).toList();
  }

  /// Clear all breadcrumbs.
  static void clear() {
    instance._breadcrumbs.clear();
  }

  /// Add a listener to be notified when breadcrumbs are added.
  static void addListener(void Function(VooBreadcrumb) listener) {
    instance._listeners.add(listener);
  }

  /// Remove a listener.
  static void removeListener(void Function(VooBreadcrumb) listener) {
    instance._listeners.remove(listener);
  }

  /// Dispose the service.
  static void dispose() {
    instance._breadcrumbs.clear();
    instance._listeners.clear();
    _initialized = false;
    _instance = null;
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    instance._breadcrumbs.clear();
    instance._listeners.clear();
    _initialized = false;
    _instance = null;
    _maxBreadcrumbs = 100;
  }
}
