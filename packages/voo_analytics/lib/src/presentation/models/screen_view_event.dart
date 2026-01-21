import 'package:flutter/foundation.dart';

/// A screen view event for analytics.
@immutable
class ScreenViewEvent {
  /// Name of the screen (usually the route name).
  final String screenName;

  /// Class name of the screen widget (optional).
  final String? screenClass;

  /// Previous screen name (for navigation context).
  final String? previousScreen;

  /// Route parameters (if any).
  final Map<String, dynamic>? routeParams;

  /// Timestamp when the screen was viewed.
  final DateTime timestamp;

  const ScreenViewEvent({
    required this.screenName,
    this.screenClass,
    this.previousScreen,
    this.routeParams,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'screen_name': screenName,
      if (screenClass != null) 'screen_class': screenClass,
      if (previousScreen != null) 'previous_screen': previousScreen,
      if (routeParams != null) 'route_params': routeParams,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
