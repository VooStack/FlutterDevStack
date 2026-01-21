import 'package:flutter/material.dart';
import 'package:voo_analytics/src/voo_analytics_plugin.dart';

/// Route observer for analytics.
///
/// Add this to your MaterialApp or Navigator to automatically track
/// route changes and log analytics events for navigation.
///
/// ## Usage
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     AnalyticsRouteObserver(),
///   ],
///   // ...
/// )
/// ```
class AnalyticsRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange(route, 'push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange(previousRoute, 'pop');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logRouteChange(newRoute, 'replace');
    }
  }

  void _logRouteChange(Route<dynamic>? route, String action) {
    final routeName = route?.settings.name ?? 'unknown';

    VooAnalyticsPlugin.instance.logEvent(
      'route_$action',
      parameters: {
        'route': routeName,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
