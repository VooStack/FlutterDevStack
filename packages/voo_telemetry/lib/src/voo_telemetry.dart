import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

import 'package:voo_telemetry/src/core/telemetry_config.dart';
import 'package:voo_telemetry/src/core/telemetry_resource.dart';
import 'package:voo_telemetry/src/exporters/otlp_http_exporter.dart';
import 'package:voo_telemetry/src/logs/log_record.dart';
import 'package:voo_telemetry/src/logs/logger.dart';
import 'package:voo_telemetry/src/logs/logger_provider.dart';
import 'package:voo_telemetry/src/metrics/meter.dart';
import 'package:voo_telemetry/src/metrics/meter_provider.dart';
import 'package:voo_telemetry/src/traces/trace_provider.dart';
import 'package:voo_telemetry/src/traces/tracer.dart';

/// Main entry point for VooTelemetry OpenTelemetry integration
class VooTelemetry {
  static VooTelemetry? _instance;

  final TelemetryConfig config;
  final TelemetryResource resource;
  final TraceProvider traceProvider;
  final MeterProvider meterProvider;
  final LoggerProvider loggerProvider;
  final OTLPHttpExporter exporter;

  bool _initialized = false;
  Timer? _flushTimer;

  VooTelemetry._({
    required this.config,
    required this.resource,
    required this.traceProvider,
    required this.meterProvider,
    required this.loggerProvider,
    required this.exporter,
  });

  /// Initialize VooTelemetry with configuration
  static Future<void> initialize({
    required String endpoint,
    String? apiKey,
    String serviceName = 'voo-flutter-app',
    String serviceVersion = '1.0.0',
    Map<String, dynamic>? additionalAttributes,
    Duration batchInterval = const Duration(seconds: 30),
    int maxBatchSize = 100,
    bool debug = false,
    TelemetryConfig? config,
  }) async {
    if (_instance != null) {
      throw StateError('VooTelemetry is already initialized');
    }

    final effectiveConfig =
        config ?? TelemetryConfig(endpoint: endpoint, apiKey: apiKey, batchInterval: batchInterval, maxBatchSize: maxBatchSize, debug: debug);

    // Build resource attributes with OTEL semantic conventions
    final resourceAttributes = _buildResourceAttributes(serviceName: serviceName, serviceVersion: serviceVersion, additionalAttributes: additionalAttributes);

    final resource = TelemetryResource(serviceName: serviceName, serviceVersion: serviceVersion, attributes: resourceAttributes);

    final exporter = OTLPHttpExporter(
      endpoint: effectiveConfig.endpoint,
      apiKey: effectiveConfig.apiKey,
      debug: effectiveConfig.debug,
      timeout: effectiveConfig.timeout,
      maxRetries: effectiveConfig.maxRetries,
      retryDelay: effectiveConfig.retryDelay,
      enableCompression: effectiveConfig.enableCompression,
      compressionThreshold: effectiveConfig.compressionThreshold,
    );

    final traceProvider = TraceProvider(resource: resource, exporter: exporter, config: effectiveConfig);

    final meterProvider = MeterProvider(resource: resource, exporter: exporter, config: effectiveConfig);

    final loggerProvider = LoggerProvider(resource: resource, exporter: exporter, config: effectiveConfig);

    // Wire up trace provider to logger provider for log-trace correlation
    loggerProvider.traceProvider = traceProvider;

    _instance = VooTelemetry._(
      config: effectiveConfig,
      resource: resource,
      traceProvider: traceProvider,
      meterProvider: meterProvider,
      loggerProvider: loggerProvider,
      exporter: exporter,
    );

    await _instance!._init();
  }

  /// Build resource attributes with device and user context
  static Map<String, dynamic> _buildResourceAttributes({
    required String serviceName,
    required String serviceVersion,
    Map<String, dynamic>? additionalAttributes,
  }) {
    final attributes = <String, dynamic>{
      // Service attributes (OTEL semantic conventions)
      'service.name': serviceName,
      'service.version': serviceVersion,

      // SDK attributes
      'telemetry.sdk.name': 'voo-telemetry',
      'telemetry.sdk.version': '2.0.0',
      'telemetry.sdk.language': 'dart',

      // Process attributes
      'process.runtime.name': 'flutter',
      'process.runtime.version': defaultTargetPlatform.name,
    };

    // Add device info from Voo.deviceInfo if available
    final deviceInfo = Voo.deviceInfo;
    if (deviceInfo != null) {
      // Device attributes (OTEL semantic conventions)
      attributes['device.id'] = deviceInfo.deviceId;
      attributes['device.model.name'] = deviceInfo.deviceModel;
      attributes['device.manufacturer'] = deviceInfo.manufacturer;

      // OS attributes
      attributes['os.type'] = deviceInfo.osName.toLowerCase();
      attributes['os.name'] = deviceInfo.osName;
      attributes['os.version'] = deviceInfo.osVersion;

      // App attributes
      attributes['app.version'] = deviceInfo.appVersion;
      attributes['app.build'] = deviceInfo.buildNumber;
      attributes['app.package'] = deviceInfo.packageName;

      // Platform (using osName as the platform identifier)
      attributes['platform'] = deviceInfo.osName;
    }

    // Add user context from Voo.userContext if available
    final userContext = Voo.userContext;
    if (userContext != null) {
      attributes['session.id'] = userContext.sessionId;
      if (userContext.userId != null) {
        attributes['user.id'] = userContext.userId;
      }
    }

    // Add project context from Voo.config if available
    final vooConfig = Voo.config;
    if (vooConfig != null) {
      if (vooConfig.projectId != null) {
        attributes['project.id'] = vooConfig.projectId;
      }
      attributes['deployment.environment'] = vooConfig.environment;
    }

    // Add any additional custom attributes
    if (additionalAttributes != null) {
      attributes.addAll(additionalAttributes);
    }

    return attributes;
  }

  /// Get the singleton instance
  static VooTelemetry get instance {
    if (_instance == null) {
      throw StateError('VooTelemetry is not initialized. Call VooTelemetry.initialize() first.');
    }
    return _instance!;
  }

  /// Check if VooTelemetry is initialized
  static bool get isInitialized => _instance != null;

  Future<void> _init() async {
    if (_initialized) return;

    // Initialize providers
    await traceProvider.initialize();
    await meterProvider.initialize();
    await loggerProvider.initialize();

    _initialized = true;

    // Start self-rescheduling flush timer (waits for flush to complete before rescheduling)
    _scheduleFlush();

    if (config.debug) {
      debugPrint('VooTelemetry initialized with endpoint: ${config.endpoint}');
    }
  }

  /// Schedule the next flush after the configured interval.
  /// Uses self-rescheduling timer to ensure flush completes before next timer fires.
  void _scheduleFlush() {
    _flushTimer = Timer(config.batchInterval, () async {
      await flush();
      if (_initialized) {
        _scheduleFlush();
      }
    });
  }

  /// Manually flush all telemetry data
  Future<void> flush() async {
    if (config.useCombinedEndpoint) {
      await _flushCombined();
    } else {
      await _flushSeparate();
    }
  }

  /// Flush using separate endpoints (3 HTTP requests)
  Future<void> _flushSeparate() async {
    await Future.wait([
      traceProvider.flush(),
      meterProvider.flush(),
      loggerProvider.flush(),
    ]);
  }

  /// Flush using combined endpoint (1 HTTP request)
  Future<void> _flushCombined() async {
    // Collect all pending telemetry in parallel
    final results = await Future.wait([
      traceProvider.collectPendingOtlp(),
      meterProvider.collectPendingOtlp(),
      loggerProvider.collectPendingOtlp(),
    ]);

    final spans = results[0];
    final metrics = results[1];
    final logs = results[2];

    // Skip export if nothing to send
    if (spans.isEmpty && metrics.isEmpty && logs.isEmpty) {
      return;
    }

    final result = await exporter.exportCombined(
      spans: spans,
      metrics: metrics,
      logRecords: logs,
      resource: resource,
    );

    if (config.debug) {
      debugPrint('Combined export: $result');
    }
  }

  /// Shutdown VooTelemetry and flush remaining data
  static Future<void> shutdown() async {
    if (_instance == null) return;

    _instance!._flushTimer?.cancel();
    await _instance!.flush();

    await Future.wait([_instance!.traceProvider.shutdown(), _instance!.meterProvider.shutdown(), _instance!.loggerProvider.shutdown()]);

    _instance = null;
  }

  /// Set the API key used for OTLP export.
  /// Call this when the user selects a different project.
  static set apiKey(String? apiKey) {
    _instance?.exporter.apiKeyValue = apiKey;
  }

  /// Get a tracer for creating spans
  Tracer getTracer([String name = 'default']) => traceProvider.getTracer(name);

  /// Get a meter for creating metrics
  Meter getMeter([String name = 'default']) => meterProvider.getMeter(name);

  /// Get a logger for creating logs
  Logger getLogger([String name = 'default']) => loggerProvider.getLogger(name);

  /// Record an exception with trace context
  void recordException(dynamic exception, StackTrace? stackTrace, {Map<String, dynamic>? attributes}) {
    final span = traceProvider.activeSpan;
    if (span != null) {
      span.recordException(exception, stackTrace, attributes: attributes);
    }

    loggerProvider
        .getLogger('exception')
        .error(
          'Exception occurred',
          attributes: {
            'exception.type': exception.runtimeType.toString(),
            'exception.message': exception.toString(),
            if (stackTrace != null) 'exception.stacktrace': stackTrace.toString(),
            ...?attributes,
          },
        );
  }

  /// Add a log record directly to the logger provider.
  ///
  /// This is a convenience method for packages that need to send
  /// logs through the unified OTEL pipeline.
  void addLogRecord(LogRecord record) {
    loggerProvider.addLogRecord(record);
  }

  /// Create a LogRecord from log entry parameters.
  ///
  /// This is a helper for converting voo_logging LogEntry format
  /// to OTEL LogRecord format.
  static LogRecord createLogRecord({
    required String message,
    required SeverityNumber severity,
    DateTime? timestamp,
    String? category,
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    String? stackTrace,
    String? userId,
    String? sessionId,
    String? traceId,
    String? spanId,
  }) {
    final attributes = <String, dynamic>{
      if (category != null) 'log.category': category,
      if (tag != null) 'log.tag': tag,
      if (userId != null) 'user.id': userId,
      if (sessionId != null) 'session.id': sessionId,
      if (error != null) 'error.type': error.runtimeType.toString(),
      if (error != null) 'error.message': error.toString(),
      if (stackTrace != null) 'error.stacktrace': stackTrace,
      ...?metadata,
    };

    return LogRecord(
      severityNumber: severity,
      severityText: _severityToText(severity),
      body: message,
      timestamp: timestamp ?? DateTime.now(),
      attributes: attributes,
      traceId: traceId,
      spanId: spanId,
    );
  }

  /// Convert severity number to text
  static String _severityToText(SeverityNumber severity) {
    switch (severity) {
      case SeverityNumber.trace:
      case SeverityNumber.trace2:
      case SeverityNumber.trace3:
      case SeverityNumber.trace4:
        return 'TRACE';
      case SeverityNumber.debug:
      case SeverityNumber.debug2:
      case SeverityNumber.debug3:
      case SeverityNumber.debug4:
        return 'DEBUG';
      case SeverityNumber.info:
      case SeverityNumber.info2:
      case SeverityNumber.info3:
      case SeverityNumber.info4:
        return 'INFO';
      case SeverityNumber.warn:
      case SeverityNumber.warn2:
      case SeverityNumber.warn3:
      case SeverityNumber.warn4:
        return 'WARN';
      case SeverityNumber.error:
      case SeverityNumber.error2:
      case SeverityNumber.error3:
      case SeverityNumber.error4:
        return 'ERROR';
      case SeverityNumber.fatal:
      case SeverityNumber.fatal2:
      case SeverityNumber.fatal3:
      case SeverityNumber.fatal4:
        return 'FATAL';
      default:
        return 'UNSPECIFIED';
    }
  }

  /// Get the current trace context (traceId and spanId) if available.
  ///
  /// Returns null if no active span exists.
  ({String traceId, String spanId})? get currentTraceContext {
    final span = traceProvider.activeSpan;
    if (span != null) {
      return (traceId: span.context.traceId, spanId: span.context.spanId);
    }
    return null;
  }
}
