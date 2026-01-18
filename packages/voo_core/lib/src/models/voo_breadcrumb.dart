import 'package:flutter/foundation.dart';

/// The type of breadcrumb event.
enum VooBreadcrumbType {
  /// Navigation events (screen changes, route pushes/pops).
  navigation,

  /// HTTP request/response events.
  http,

  /// User interaction events (taps, swipes, form inputs).
  user,

  /// Console/debug messages.
  console,

  /// Error events (captured errors, exceptions).
  error,

  /// System events (app lifecycle, memory warnings).
  system,

  /// Custom/manual breadcrumbs.
  custom,
}

/// Severity level for breadcrumbs.
enum VooBreadcrumbLevel {
  /// Debug-level breadcrumb (verbose).
  debug,

  /// Informational breadcrumb (default).
  info,

  /// Warning-level breadcrumb.
  warning,

  /// Error-level breadcrumb.
  error,
}

/// A breadcrumb captures a single event in the user's journey.
///
/// Breadcrumbs are collected automatically (navigation, HTTP, user actions)
/// and can be added manually. They are attached to error reports to provide
/// context about what happened before the error occurred.
///
/// ## Example
///
/// ```dart
/// // Automatic breadcrumbs (handled by SDK)
/// // - Screen navigation
/// // - HTTP requests
/// // - User taps
///
/// // Manual breadcrumb
/// Voo.addBreadcrumb(VooBreadcrumb(
///   type: VooBreadcrumbType.custom,
///   category: 'checkout',
///   message: 'User started checkout with 3 items',
///   data: {'item_count': 3, 'cart_value': 99.99},
/// ));
/// ```
@immutable
class VooBreadcrumb {
  /// The type of this breadcrumb.
  final VooBreadcrumbType type;

  /// A category for grouping similar breadcrumbs.
  ///
  /// Examples:
  /// - `ui.click` for user taps
  /// - `http.request` for network requests
  /// - `navigation.push` for screen navigation
  /// - `auth.login` for authentication events
  final String category;

  /// A human-readable message describing the event.
  final String message;

  /// When this breadcrumb was captured.
  final DateTime timestamp;

  /// Additional data associated with this breadcrumb.
  ///
  /// For HTTP breadcrumbs: `{url, method, status_code, duration}`
  /// For navigation: `{from, to, route_params}`
  /// For user actions: `{element_id, element_type, value}`
  final Map<String, dynamic>? data;

  /// The severity level of this breadcrumb.
  final VooBreadcrumbLevel level;

  /// Creates a new breadcrumb.
  VooBreadcrumb({
    required this.type,
    required this.category,
    required this.message,
    DateTime? timestamp,
    this.data,
    this.level = VooBreadcrumbLevel.info,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a navigation breadcrumb.
  factory VooBreadcrumb.navigation({
    required String from,
    required String to,
    String action = 'push',
    Map<String, dynamic>? routeParams,
  }) {
    return VooBreadcrumb(
      type: VooBreadcrumbType.navigation,
      category: 'navigation.$action',
      message: '$action from $from to $to',
      data: {
        'from': from,
        'to': to,
        'action': action,
        if (routeParams != null) 'route_params': routeParams,
      },
    );
  }

  /// Creates an HTTP request breadcrumb.
  factory VooBreadcrumb.http({
    required String method,
    required String url,
    int? statusCode,
    int? durationMs,
    int? requestSize,
    int? responseSize,
    bool isError = false,
  }) {
    final message = statusCode != null
        ? '$method $url ($statusCode)'
        : '$method $url (pending)';

    return VooBreadcrumb(
      type: VooBreadcrumbType.http,
      category: 'http.${method.toLowerCase()}',
      message: message,
      level: isError ? VooBreadcrumbLevel.error : VooBreadcrumbLevel.info,
      data: {
        'method': method,
        'url': url,
        if (statusCode != null) 'status_code': statusCode,
        if (durationMs != null) 'duration_ms': durationMs,
        if (requestSize != null) 'request_size': requestSize,
        if (responseSize != null) 'response_size': responseSize,
      },
    );
  }

  /// Creates a user interaction breadcrumb.
  factory VooBreadcrumb.userAction({
    required String action,
    String? elementId,
    String? elementType,
    String? screenName,
    Map<String, dynamic>? additionalData,
  }) {
    final message = elementId != null
        ? '$action on $elementId'
        : '$action${screenName != null ? ' on $screenName' : ''}';

    return VooBreadcrumb(
      type: VooBreadcrumbType.user,
      category: 'ui.$action',
      message: message,
      data: {
        'action': action,
        if (elementId != null) 'element_id': elementId,
        if (elementType != null) 'element_type': elementType,
        if (screenName != null) 'screen_name': screenName,
        ...?additionalData,
      },
    );
  }

  /// Creates a console/debug breadcrumb.
  factory VooBreadcrumb.console({
    required String message,
    VooBreadcrumbLevel level = VooBreadcrumbLevel.debug,
    Map<String, dynamic>? data,
  }) {
    return VooBreadcrumb(
      type: VooBreadcrumbType.console,
      category: 'console.${level.name}',
      message: message,
      level: level,
      data: data,
    );
  }

  /// Creates an error breadcrumb.
  factory VooBreadcrumb.error({
    required String message,
    String? errorType,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    return VooBreadcrumb(
      type: VooBreadcrumbType.error,
      category: 'error.${errorType ?? 'unknown'}',
      message: message,
      level: VooBreadcrumbLevel.error,
      data: {
        if (errorType != null) 'error_type': errorType,
        if (stackTrace != null) 'stack_trace': stackTrace,
        ...?additionalData,
      },
    );
  }

  /// Creates a system event breadcrumb.
  factory VooBreadcrumb.system({
    required String event,
    VooBreadcrumbLevel level = VooBreadcrumbLevel.info,
    Map<String, dynamic>? data,
  }) {
    return VooBreadcrumb(
      type: VooBreadcrumbType.system,
      category: 'system.$event',
      message: 'System event: $event',
      level: level,
      data: data,
    );
  }

  /// Converts to JSON for sync payloads.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'category': category,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      if (data != null && data!.isNotEmpty) 'data': data,
    };
  }

  /// Creates from JSON.
  factory VooBreadcrumb.fromJson(Map<String, dynamic> json) {
    return VooBreadcrumb(
      type: VooBreadcrumbType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => VooBreadcrumbType.custom,
      ),
      category: json['category'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      level: VooBreadcrumbLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => VooBreadcrumbLevel.info,
      ),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'VooBreadcrumb($type, $category: $message)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VooBreadcrumb &&
        other.type == type &&
        other.category == category &&
        other.message == message &&
        other.timestamp == timestamp &&
        other.level == level &&
        mapEquals(other.data, data);
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      category,
      message,
      timestamp,
      level,
      data,
    );
  }
}
