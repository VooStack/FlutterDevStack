import 'dart:async';
import 'package:flutter/material.dart';
import 'package:voo_core/voo_core.dart';
import 'package:voo_analytics/src/domain/repositories/analytics_repository.dart';
import 'package:voo_analytics/src/data/repositories/analytics_repository_impl.dart';
import 'package:voo_analytics/src/presentation/widgets/analytics_route_observer.dart';
import 'package:voo_analytics/src/data/services/funnel_tracking_service.dart';
import 'package:voo_analytics/src/otel/otel_analytics_config.dart';
import 'package:voo_analytics/src/otel/screen_view_span_manager.dart';
import 'package:voo_analytics/src/otel/touch_event_metrics.dart';
import 'package:voo_analytics/src/otel/funnel_span_tracker.dart';
import 'package:voo_analytics/src/otel/replay_trace_correlator.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

class VooAnalyticsPlugin extends VooPlugin {
  static VooAnalyticsPlugin? _instance;
  AnalyticsRepository? repository;
  AnalyticsRouteObserver? _routeObserver;
  bool _initialized = false;

  // OTEL components
  OtelAnalyticsConfig? _otelConfig;
  Tracer? _otelTracer;
  Meter? _otelMeter;
  ScreenViewSpanManager? _screenViewSpanManager;
  TouchEventMetrics? _touchEventMetrics;
  FunnelSpanTracker? _funnelSpanTracker;
  ReplayTraceCorrelator? _replayTraceCorrelator;
  bool _otelEnabled = false;

  VooAnalyticsPlugin._();

  static VooAnalyticsPlugin get instance {
    _instance ??= VooAnalyticsPlugin._();
    return _instance!;
  }

  @override
  String get name => 'voo_analytics';

  @override
  String get version => '0.2.0';

  bool get isInitialized => _initialized;

  /// Whether OTEL export is enabled.
  bool get otelEnabled => _otelEnabled;

  /// Get the screen view span manager for OTEL integration.
  ScreenViewSpanManager? get screenViewSpanManager => _screenViewSpanManager;

  /// Get the touch event metrics for OTEL integration.
  TouchEventMetrics? get touchEventMetrics => _touchEventMetrics;

  /// Get the funnel span tracker for OTEL integration.
  FunnelSpanTracker? get funnelSpanTracker => _funnelSpanTracker;

  /// Get the replay trace correlator for OTEL integration.
  ReplayTraceCorrelator? get replayTraceCorrelator => _replayTraceCorrelator;

  RouteObserver<ModalRoute> get routeObserver {
    _routeObserver ??= AnalyticsRouteObserver();
    return _routeObserver!;
  }

  static Future<void> initialize({bool enableTouchTracking = true, bool enableEventLogging = true, bool enableUserProperties = true}) async {
    final plugin = instance;

    if (plugin._initialized) {
      return;
    }

    if (!Voo.isInitialized) {
      throw const VooException('Voo.initializeApp() must be called before initializing VooAnalytics', code: 'core-not-initialized');
    }

    plugin.repository = AnalyticsRepositoryImpl(enableTouchTracking: enableTouchTracking, enableEventLogging: enableEventLogging, enableUserProperties: enableUserProperties);

    await plugin.repository!.initialize();

    await Voo.registerPlugin(plugin);
    plugin._initialized = true;

    // Auto-enable OTEL when Voo.context is available
    final vooContext = Voo.context;
    if (vooContext != null && vooContext.canSync) {
      await plugin._autoEnableOtel(
        endpoint: vooContext.config.endpoint,
        apiKey: vooContext.config.apiKey,
        serviceName: 'voo-analytics',
        serviceVersion: Voo.deviceInfo?.appVersion ?? '1.0.0',
      );
    }

  }

  /// Internal method to enable OTEL (auto-called during initialize).
  Future<void> _autoEnableOtel({
    required String endpoint,
    required String apiKey,
    String serviceName = 'voo-analytics',
    String serviceVersion = '1.0.0',
  }) async {
    // Use default config
    _otelConfig = OtelAnalyticsConfig(
      enabled: true,
      endpoint: endpoint,
      apiKey: apiKey,
      serviceName: serviceName,
      serviceVersion: serviceVersion,
    );

    // Initialize VooTelemetry if not already done
    if (!VooTelemetry.isInitialized) {
      await VooTelemetry.initialize(
        endpoint: endpoint,
        apiKey: apiKey,
        serviceName: serviceName,
        serviceVersion: serviceVersion,
      );
    }

    // Get tracer and meter from VooTelemetry
    _otelTracer = VooTelemetry.instance.getTracer('voo-analytics');
    _otelMeter = VooTelemetry.instance.getMeter('voo-analytics');

    // Initialize screen view span manager
    if (_otelConfig!.exportScreenViews) {
      _screenViewSpanManager = ScreenViewSpanManager(_otelTracer!);
    }

    // Initialize touch event metrics
    if (_otelConfig!.exportTouchMetrics) {
      _touchEventMetrics = TouchEventMetrics(_otelMeter!);
      _touchEventMetrics!.initialize();
    }

    // Initialize funnel span tracker
    if (_otelConfig!.exportFunnels) {
      _funnelSpanTracker = FunnelSpanTracker(_otelTracer!);
    }

    // Initialize replay trace correlator
    if (_otelConfig!.correlateReplay && _screenViewSpanManager != null) {
      _replayTraceCorrelator = ReplayTraceCorrelator(_screenViewSpanManager!);
    }

    _otelEnabled = true;
  }

  /// Record a screen view as an OTEL span.
  ///
  /// Call this when navigating to a new screen to create a span for the screen view.
  /// The span will be automatically ended when [endScreenView] is called or
  /// when a new screen view is started.
  void recordScreenView({
    required String screenName,
    String? screenClass,
    String? previousScreen,
    Map<String, dynamic>? routeParams,
    String? navigationAction,
  }) {
    if (!_otelEnabled || _screenViewSpanManager == null) return;

    _screenViewSpanManager!.startScreenView(
      screenName: screenName,
      screenClass: screenClass,
      previousScreen: previousScreen,
      routeParams: routeParams,
      navigationAction: navigationAction,
    );
  }

  /// Record a touch event as OTEL metrics.
  ///
  /// This records the touch as a counter increment and position histogram
  /// for heatmap generation.
  void recordTouch({
    required String screenName,
    required TouchType touchType,
    required double normalizedX,
    required double normalizedY,
    String? region,
    String? widgetType,
  }) {
    if (!_otelEnabled || _touchEventMetrics == null) return;

    _touchEventMetrics!.recordTouch(
      screenName: screenName,
      touchType: touchType,
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      region: region,
      widgetType: widgetType,
    );
  }

  /// Get the current trace context for correlation.
  ///
  /// Returns a record with traceId and spanId if OTEL is enabled.
  ({String? traceId, String? spanId}) getCurrentTraceContext() {
    if (!_otelEnabled || _replayTraceCorrelator == null) {
      return (traceId: null, spanId: null);
    }
    return _replayTraceCorrelator!.getCurrentTraceContext();
  }

  Future<void> logEvent(String name, {String? category, Map<String, dynamic>? parameters}) async {
    if (!_initialized) {
      throw const VooException('VooAnalytics not initialized. Call initialize() first.', code: 'not-initialized');
    }

    // Add category to parameters if provided
    final params = parameters != null ? Map<String, dynamic>.from(parameters) : <String, dynamic>{};
    if (category != null) {
      params['event_category'] = category;
    }

    await repository!.logEvent(name, parameters: params.isNotEmpty ? params : null);

    // Notify funnel tracking service (don't recurse on funnel events)
    if (category != 'funnel' && FunnelTrackingService.isInitialized) {
      FunnelTrackingService.onEvent(name, parameters);
    }

    // Add as span event if OTEL is enabled
    if (_otelEnabled && _otelConfig!.exportCustomEvents && _screenViewSpanManager != null) {
      _screenViewSpanManager!.addScreenEvent(
        'analytics.$name',
        attributes: {
          'event.name': name,
          if (category != null) 'event.category': category,
          ...?parameters,
        },
      );
    }
  }

  /// Sets a user property for analytics.
  ///
  /// Also forwards to [Voo.setUserProperty] to keep central context in sync.
  /// Consider using [Voo.setUserProperty] directly for a unified approach.
  Future<void> setUserProperty(String name, String value) async {
    if (!_initialized) {
      throw const VooException('VooAnalytics not initialized. Call initialize() first.', code: 'not-initialized');
    }
    // Forward to Voo central context
    Voo.setUserProperty(name, value);
    await repository!.setUserProperty(name, value);
  }

  /// Sets the user ID for analytics.
  ///
  /// Also forwards to [Voo.setUserId] to keep central context in sync.
  /// Consider using [Voo.setUserId] directly for a unified approach.
  Future<void> setUserId(String userId) async {
    if (!_initialized) {
      throw const VooException('VooAnalytics not initialized. Call initialize() first.', code: 'not-initialized');
    }
    // Forward to Voo central context
    Voo.setUserId(userId);
    await repository!.setUserId(userId);
  }

  Future<Map<String, dynamic>> getHeatMapData({DateTime? startDate, DateTime? endDate}) async {
    if (!_initialized) {
      throw const VooException('VooAnalytics not initialized. Call initialize() first.', code: 'not-initialized');
    }
    return repository!.getHeatMapData(startDate: startDate, endDate: endDate);
  }

  Future<void> clearData() async {
    if (!_initialized) return;
    await repository!.clearData();
  }

  @override
  FutureOr<void> onAppInitialized(VooApp app) {
    // Auto-registration handled by framework
  }

  @override
  FutureOr<void> onAppDeleted(VooApp app) {
    // Clean up any app-specific resources if needed
  }

  @override
  dynamic getInstanceForApp(VooApp app) {
    // Return the repository for telemetry to access
    return repository;
  }

  @override
  FutureOr<void> dispose() {
    // Dispose OTEL components
    _screenViewSpanManager?.dispose();
    _funnelSpanTracker?.dispose();
    _screenViewSpanManager = null;
    _touchEventMetrics = null;
    _funnelSpanTracker = null;
    _replayTraceCorrelator = null;
    _otelTracer = null;
    _otelMeter = null;
    _otelConfig = null;
    _otelEnabled = false;

    repository?.dispose();
    repository = null;
    _initialized = false;
    _instance = null;
  }

  @override
  Map<String, dynamic> getInfo() {
    return {
      ...super.getInfo(),
      'initialized': _initialized,
      'features': {
        'touchTracking': repository?.enableTouchTracking ?? false,
        'eventLogging': repository?.enableEventLogging ?? false,
        'userProperties': repository?.enableUserProperties ?? false,
      },
      'otel': {
        'enabled': _otelEnabled,
        'endpoint': _otelConfig?.endpoint,
        'exportScreenViews': _otelConfig?.exportScreenViews ?? false,
        'exportTouchMetrics': _otelConfig?.exportTouchMetrics ?? false,
        'exportCustomEvents': _otelConfig?.exportCustomEvents ?? false,
        'exportFunnels': _otelConfig?.exportFunnels ?? false,
        'correlateReplay': _otelConfig?.correlateReplay ?? false,
      },
    };
  }
}
