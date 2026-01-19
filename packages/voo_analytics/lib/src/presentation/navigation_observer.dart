import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

import '../voo_analytics_plugin.dart';
import '../replay/replay_capture_service.dart';

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

/// Navigation observer that automatically tracks screen views and breadcrumbs.
///
/// Add this observer to your MaterialApp or Navigator to automatically:
/// - Log screen view analytics events
/// - Add navigation breadcrumbs for error context
/// - Track screen transitions
///
/// ## Usage
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     VooNavigationObserver(),
///   ],
///   // ...
/// )
/// ```
///
/// Or with Go Router:
/// ```dart
/// GoRouter(
///   observers: [
///     VooNavigationObserver(),
///   ],
///   // ...
/// )
/// ```
class VooNavigationObserver extends NavigatorObserver {
  /// Whether to log screen view analytics events.
  final bool logScreenViews;

  /// Whether to add navigation breadcrumbs.
  final bool addBreadcrumbs;

  /// Callback when a screen is viewed.
  final void Function(ScreenViewEvent event)? onScreenView;

  /// Current screen name.
  String? _currentScreen;

  /// Creates a navigation observer.
  VooNavigationObserver({
    this.logScreenViews = true,
    this.addBreadcrumbs = true,
    this.onScreenView,
  });

  /// Get the current screen name.
  String? get currentScreen => _currentScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleNavigation(
      route: route,
      previousRoute: previousRoute,
      action: 'push',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _handleNavigation(
      route: previousRoute, // After pop, we're on the previous route
      previousRoute: route,
      action: 'pop',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _handleNavigation(
      route: newRoute,
      previousRoute: oldRoute,
      action: 'replace',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    // Just log breadcrumb, don't track as screen view
    if (addBreadcrumbs) {
      Voo.addNavigationBreadcrumb(
        from: _getRouteName(previousRoute),
        to: 'removed',
        action: 'remove',
      );
    }
  }

  /// Handle a navigation event.
  void _handleNavigation({
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
    required String action,
  }) {
    final screenName = _getRouteName(route);
    final previousScreenName = _getRouteName(previousRoute);

    if (screenName == 'unknown' && action == 'pop') {
      // Skip unknown screens on pop
      return;
    }

    _currentScreen = screenName;

    // Create screen view event
    final event = ScreenViewEvent(
      screenName: screenName,
      screenClass: _getRouteClassName(route),
      previousScreen: previousScreenName,
      routeParams: _getRouteParams(route),
      timestamp: DateTime.now(),
    );

    // Add navigation breadcrumb
    if (addBreadcrumbs) {
      Voo.addNavigationBreadcrumb(
        from: previousScreenName,
        to: screenName,
        action: action,
        routeParams: event.routeParams,
      );
    }

    // Log screen view analytics event
    if (logScreenViews) {
      _logScreenView(event);
    }

    // Notify callback
    onScreenView?.call(event);

    if (kDebugMode) {
      debugPrint('VooNavigationObserver: $action $previousScreenName -> $screenName');
    }
  }

  /// Log a screen view analytics event.
  void _logScreenView(ScreenViewEvent event) {
    try {
      if (VooAnalyticsPlugin.instance.isInitialized) {
        VooAnalyticsPlugin.instance.logEvent(
          'screen_view',
          parameters: event.toJson(),
        );
      }

      // Also capture for replay if enabled
      if (ReplayCaptureService.instance.isEnabled) {
        ReplayCaptureService.instance.captureScreenView(
          screenName: event.screenName,
          routePath: event.routeParams?['path'] as String?,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooNavigationObserver: Failed to log screen view: $e');
      }
    }
  }

  /// Extract the route name from a route.
  String _getRouteName(Route<dynamic>? route) {
    if (route == null) return 'unknown';

    // Try to get the route name from settings
    final settings = route.settings;
    if (settings.name != null && settings.name!.isNotEmpty) {
      return settings.name!;
    }

    // Fallback to route type
    return route.runtimeType.toString();
  }

  /// Extract the route class name.
  String? _getRouteClassName(Route<dynamic>? route) {
    if (route == null) return null;
    return route.runtimeType.toString();
  }

  /// Extract route parameters from settings.
  Map<String, dynamic>? _getRouteParams(Route<dynamic>? route) {
    if (route == null) return null;

    final settings = route.settings;
    final arguments = settings.arguments;

    if (arguments == null) return null;

    if (arguments is Map<String, dynamic>) {
      return arguments;
    }

    if (arguments is Map) {
      return Map<String, dynamic>.from(arguments);
    }

    // Wrap non-map arguments
    return {'arguments': arguments.toString()};
  }
}

/// Extension to make it easy to add VooNavigationObserver.
extension VooNavigationObserverExtension on MaterialApp {
  /// Add VooNavigationObserver to navigator observers.
  MaterialApp withVooNavigationObserver({
    bool logScreenViews = true,
    bool addBreadcrumbs = true,
  }) {
    final existingObservers = navigatorObservers ?? [];
    return MaterialApp(
      key: key,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: home,
      routes: routes ?? const {},
      initialRoute: initialRoute,
      onGenerateRoute: onGenerateRoute,
      onGenerateInitialRoutes: onGenerateInitialRoutes,
      onUnknownRoute: onUnknownRoute,
      navigatorObservers: [
        ...existingObservers,
        VooNavigationObserver(
          logScreenViews: logScreenViews,
          addBreadcrumbs: addBreadcrumbs,
        ),
      ],
      builder: builder,
      title: title,
      onGenerateTitle: onGenerateTitle,
      color: color,
      theme: theme,
      darkTheme: darkTheme,
      highContrastTheme: highContrastTheme,
      highContrastDarkTheme: highContrastDarkTheme,
      themeMode: themeMode,
      themeAnimationDuration: themeAnimationDuration,
      themeAnimationCurve: themeAnimationCurve,
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      localeListResolutionCallback: localeListResolutionCallback,
      localeResolutionCallback: localeResolutionCallback,
      supportedLocales: supportedLocales,
      debugShowMaterialGrid: debugShowMaterialGrid,
      showPerformanceOverlay: showPerformanceOverlay,
      checkerboardRasterCacheImages: checkerboardRasterCacheImages,
      checkerboardOffscreenLayers: checkerboardOffscreenLayers,
      showSemanticsDebugger: showSemanticsDebugger,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      shortcuts: shortcuts,
      actions: actions,
      restorationScopeId: restorationScopeId,
      scrollBehavior: scrollBehavior,
    );
  }
}
