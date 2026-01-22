import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_performance/src/domain/entities/performance_trace.dart';
import 'package:voo_performance/src/domain/entities/network_metric.dart';
import 'package:voo_performance/src/otel/otel_performance_trace.dart';
import 'package:voo_performance/src/otel/semantic_conventions.dart';
import 'package:voo_performance/src/otel/metrics/otel_fps_metric.dart';
import 'package:voo_performance/src/otel/metrics/otel_memory_metric.dart';
import 'package:voo_performance/src/otel/metrics/otel_app_launch_metric.dart';

class VooPerformancePlugin extends VooPlugin {
  static VooPerformancePlugin? _instance;
  bool _initialized = false;
  final Map<String, PerformanceTrace> _activeTraces = {};
  final List<NetworkMetric> _networkMetrics = [];
  final List<PerformanceMetrics> _performanceMetrics = [];

  // OTEL integration
  Tracer? _otelTracer;
  Meter? _otelMeter;
  OtelFpsMetric? _fpsMetric;
  OtelMemoryMetric? _memoryMetric;
  OtelAppLaunchMetric? _appLaunchMetric;
  bool _otelEnabled = false;

  /// Check if OTEL is enabled.
  bool get isOtelEnabled => _otelEnabled;

  VooPerformancePlugin._();

  static VooPerformancePlugin get instance {
    _instance ??= VooPerformancePlugin._();
    return _instance!;
  }

  @override
  String get name => 'voo_performance';

  @override
  String get version => '0.2.0';

  bool get isInitialized => _initialized;

  static Future<void> initialize({bool enableNetworkMonitoring = true, bool enableTraceMonitoring = true, bool enableAutoAppStartTrace = true}) async {
    final plugin = instance;

    if (plugin._initialized) {
      return;
    }

    if (!Voo.isInitialized) {
      throw const VooException('Voo.initializeApp() must be called before initializing VooPerformance', code: 'core-not-initialized');
    }

    // Set initialized flag before creating traces
    plugin._initialized = true;
    await Voo.registerPlugin(plugin);

    // Auto-enable OTEL when Voo.context is available
    final vooContext = Voo.context;
    if (vooContext != null && vooContext.canSync) {
      await plugin._autoEnableOtel(
        endpoint: vooContext.config.endpoint,
        apiKey: vooContext.config.apiKey,
        serviceName: 'voo-performance',
        serviceVersion: Voo.deviceInfo?.appVersion ?? '1.0.0',
      );
    }

    if (enableAutoAppStartTrace) {
      final appStartTrace = plugin.newTrace('app_start');
      appStartTrace.start();
      // Don't await this - let it complete in background
      Future.delayed(const Duration(milliseconds: 100), () {
        if (plugin._initialized) {
          appStartTrace.stop();
        }
      });
    }

    if (kDebugMode) {
      debugPrint('[VooPerformance] Initialized (OTEL: ${plugin._otelEnabled})');
    }
  }

  /// Internal method to enable OTEL (auto-called during initialize).
  Future<void> _autoEnableOtel({
    required String endpoint,
    required String apiKey,
    String serviceName = 'voo-performance',
    String serviceVersion = '1.0.0',
  }) async {
    // Initialize VooTelemetry if not already done
    if (!VooTelemetry.isInitialized) {
      await VooTelemetry.initialize(
        endpoint: endpoint,
        apiKey: apiKey,
        serviceName: serviceName,
        serviceVersion: serviceVersion,
      );
    }

    // Get tracer and meter
    _otelTracer = VooTelemetry.instance.getTracer('voo-performance');
    _otelMeter = VooTelemetry.instance.getMeter('voo-performance');

    // Initialize OTEL metrics
    _fpsMetric = OtelFpsMetric(_otelMeter!);
    _fpsMetric!.initialize();

    _memoryMetric = OtelMemoryMetric(_otelMeter!);
    _memoryMetric!.initialize();

    _appLaunchMetric = OtelAppLaunchMetric(_otelTracer!, _otelMeter!);
    _appLaunchMetric!.initialize();

    _otelEnabled = true;

    if (kDebugMode) {
      debugPrint('[VooPerformance] OTEL auto-enabled with endpoint: $endpoint');
    }
  }

  /// Get the OTEL Tracer (available when OTEL is auto-enabled).
  Tracer? get otelTracer => _otelTracer;

  /// Get the OTEL Meter (available after enableOtel is called).
  Meter? get otelMeter => _otelMeter;

  /// Get the FPS metric recorder (available after enableOtel is called).
  OtelFpsMetric? get fpsMetric => _fpsMetric;

  /// Get the Memory metric recorder (available after enableOtel is called).
  OtelMemoryMetric? get memoryMetric => _memoryMetric;

  /// Get the App Launch metric recorder (available after enableOtel is called).
  OtelAppLaunchMetric? get appLaunchMetric => _appLaunchMetric;

  /// Create a new performance trace.
  ///
  /// When OTEL is enabled, this returns an [OtelPerformanceTrace] that
  /// automatically exports to the OTLP endpoint. Otherwise, it returns
  /// a standard [PerformanceTrace] for local tracking.
  PerformanceTrace newTrace(String name) {
    if (!_initialized) {
      throw const VooException('VooPerformance not initialized. Call initialize() first.', code: 'not-initialized');
    }

    // Use OTEL-backed trace when enabled
    if (_otelEnabled && _otelTracer != null) {
      final otelTrace = OtelPerformanceTrace.create(
        tracer: _otelTracer!,
        name: name,
        kind: SpanKind.internal,
      );
      otelTrace.setStopCallback(recordTrace);
      _activeTraces[otelTrace.id] = otelTrace;
      return otelTrace;
    }

    // Fallback to standard trace
    final trace = PerformanceTrace(name: name, startTime: DateTime.now());
    trace.setStopCallback(recordTrace);
    _activeTraces[trace.id] = trace;
    return trace;
  }

  /// Create a new HTTP trace with CLIENT span kind for distributed tracing.
  ///
  /// When OTEL is enabled, this creates a span with proper HTTP semantic
  /// conventions and W3C trace context for distributed tracing.
  PerformanceTrace newHttpTrace(String url, String method) {
    if (!_initialized) {
      throw const VooException('VooPerformance not initialized. Call initialize() first.', code: 'not-initialized');
    }

    // Use OTEL-backed trace with CLIENT kind when enabled
    if (_otelEnabled && _otelTracer != null) {
      final otelTrace = OtelPerformanceTrace.create(
        tracer: _otelTracer!,
        name: HttpSemanticConventions.getHttpSpanName(method),
        kind: SpanKind.client,
        attributes: {
          HttpSemanticConventions.httpRequestMethod: method,
          HttpSemanticConventions.urlFull: url,
        },
      );
      otelTrace.setStopCallback(recordTrace);
      _activeTraces[otelTrace.id] = otelTrace;
      return otelTrace;
    }

    // Fallback to standard trace
    final trace = newTrace('http_$method');
    trace.putAttribute('url', url);
    trace.putAttribute('method', method);
    return trace;
  }

  /// Create an OTEL span directly (only available when OTEL is enabled).
  ///
  /// This provides direct access to the underlying OTEL Span API for
  /// advanced use cases like span links and custom span events.
  Span? newOtelSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, dynamic>? attributes,
  }) {
    if (!_otelEnabled || _otelTracer == null) {
      return null;
    }
    return _otelTracer!.startSpan(name, kind: kind, attributes: attributes);
  }

  Future<void> recordTrace(PerformanceTrace trace) async {
    _activeTraces.remove(trace.id);

    final metrics = PerformanceMetrics(
      timestamp: trace.startTime,
      duration: trace.duration ?? Duration.zero,
      customMetrics: {'name': trace.name, ...trace.attributes, if (trace.metrics.isNotEmpty) 'metrics': trace.metrics},
    );

    _performanceMetrics.add(metrics);

    if (_performanceMetrics.length > 1000) {
      _performanceMetrics.removeRange(0, 100);
    }

    // Send to DevTools
    _sendToDevTools(
      category: 'Performance',
      message: 'Performance trace: ${trace.name}',
      metadata: {
        'operationType': 'trace',
        'operation': trace.name,
        'duration': trace.duration?.inMilliseconds ?? 0,
        'startTime': trace.startTime.toIso8601String(),
        ...trace.attributes,
        if (trace.metrics.isNotEmpty) 'metrics': trace.metrics,
      },
    );
  }

  Future<void> recordNetworkMetric(NetworkMetric metric) async {
    _networkMetrics.add(metric);

    if (_networkMetrics.length > 1000) {
      _networkMetrics.removeRange(0, 100);
    }

    // Network metrics are now exported via OTEL traces
    // CloudSync is deprecated and no longer used

    // Send to DevTools
    _sendToDevTools(
      category: 'Network',
      message: '${metric.method} ${metric.url}',
      metadata: {
        'operationType': 'network',
        'operation': '${metric.method} ${Uri.parse(metric.url).path}',
        'method': metric.method,
        'url': metric.url,
        'statusCode': metric.statusCode,
        'duration': metric.duration.inMilliseconds,
        'requestSize': metric.requestSize,
        'responseSize': metric.responseSize,
        'timestamp': metric.timestamp.toIso8601String(),
      },
    );
  }

  void _sendToDevTools({required String category, required String message, Map<String, dynamic>? metadata}) {
    try {
      final timestamp = DateTime.now();

      // Create entry data, filtering out null values for web compatibility
      final entryData = <String, dynamic>{
        'id': '${category.toLowerCase()}_${timestamp.millisecondsSinceEpoch}',
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        'level': 'info',
        'category': category,
        'tag': 'VooPerformance',
      };

      // Add metadata if present, filtering out null values
      if (metadata != null) {
        final cleanMetadata = <String, dynamic>{};
        metadata.forEach((key, value) {
          if (value != null) cleanMetadata[key] = value;
        });
        if (cleanMetadata.isNotEmpty) entryData['metadata'] = cleanMetadata;
      }

      final structuredData = {'__voo_logger__': true, 'entry': entryData};

      // Send via postEvent for DevTools extension
      developer.postEvent('voo_performance_event', structuredData);
    } catch (_) {
      // Silent fail - logging is best effort
    }
  }

  Map<String, dynamic> getMetricsSummary() {
    final avgResponseTime = _networkMetrics.isEmpty ? 0 : _networkMetrics.map((m) => m.duration.inMilliseconds).reduce((a, b) => a + b) / _networkMetrics.length;

    final errorRate = _networkMetrics.isEmpty ? 0 : _networkMetrics.where((m) => m.statusCode >= 400).length / _networkMetrics.length;

    return {
      'network': {'total_requests': _networkMetrics.length, 'average_response_time_ms': avgResponseTime, 'error_rate': errorRate},
      'traces': {'total_traces': _performanceMetrics.length, 'active_traces': _activeTraces.length},
    };
  }

  List<NetworkMetric> getNetworkMetrics({DateTime? startDate, DateTime? endDate}) {
    return _networkMetrics.where((metric) {
      if (startDate != null && metric.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && metric.timestamp.isAfter(endDate)) {
        return false;
      }
      return true;
    }).toList();
  }

  void clearMetrics() {
    _networkMetrics.clear();
    _performanceMetrics.clear();
    _activeTraces.clear();
  }

  @override
  FutureOr<void> onAppInitialized(VooApp app) {
    if (!_initialized && app.options.autoRegisterPlugins) {
      if (kDebugMode) {
        debugPrint('[VooPerformance] Plugin auto-registered');
      }
    }
  }

  @override
  FutureOr<void> onAppDeleted(VooApp app) {
    // Clean up any app-specific resources if needed
  }

  @override
  dynamic getInstanceForApp(VooApp app) {
    // Return the plugin instance for telemetry to access
    return this;
  }

  @override
  FutureOr<void> dispose() {
    clearMetrics();
    _initialized = false;
    _instance = null;
  }

  @override
  Map<String, dynamic> getInfo() {
    return {...super.getInfo(), 'initialized': _initialized, 'metrics': getMetricsSummary()};
  }
}
