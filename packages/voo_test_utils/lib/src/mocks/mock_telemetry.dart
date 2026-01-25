import 'package:voo_telemetry/voo_telemetry.dart';

/// Factory methods for creating test Span instances.
class SpanFactory {
  /// Creates a Span for testing.
  static Span create({
    String name = 'test-span',
    String? traceId,
    String? spanId,
    String? parentSpanId,
    SpanKind kind = SpanKind.internal,
    DateTime? startTime,
  }) {
    final span = Span(name: name, traceId: traceId, spanId: spanId, parentSpanId: parentSpanId, kind: kind, startTime: startTime ?? DateTime.now());
    return span;
  }

  /// Creates a Span with attributes for testing.
  static Span createWithAttributes({String name = 'test-span', SpanKind kind = SpanKind.internal, Map<String, dynamic>? attributes}) {
    final span = Span(name: name, kind: kind, startTime: DateTime.now());
    if (attributes != null) {
      span.setAttributes(attributes);
    }
    return span;
  }

  /// Creates an HTTP client span for testing.
  static Span createHttpClient({String url = 'https://api.test.com/endpoint', String method = 'GET', int? statusCode}) {
    final span = Span(name: 'HTTP $method', kind: SpanKind.client, startTime: DateTime.now());
    span.setAttributes({'http.url': url, 'http.method': method, if (statusCode != null) 'http.status_code': statusCode});
    return span;
  }

  /// Creates an HTTP server span for testing.
  static Span createHttpServer({String route = '/api/test', String method = 'GET'}) {
    final span = Span(name: '$method $route', kind: SpanKind.server, startTime: DateTime.now());
    span.setAttributes({'http.route': route, 'http.method': method});
    return span;
  }

  /// Creates a database span for testing.
  static Span createDatabase({String operation = 'SELECT', String table = 'users', String dbSystem = 'sqlite'}) {
    final span = Span(name: '$operation $table', kind: SpanKind.client, startTime: DateTime.now());
    span.setAttributes({'db.system': dbSystem, 'db.operation': operation, 'db.sql.table': table});
    return span;
  }
}

/// Factory methods for creating test LogRecord instances.
class LogRecordFactory {
  /// Creates a LogRecord for testing.
  static LogRecord create({
    String body = 'Test log message',
    SeverityNumber severityNumber = SeverityNumber.info,
    String? severityText,
    Map<String, Object>? attributes,
    String? traceId,
    String? spanId,
    DateTime? timestamp,
  }) => LogRecord(
    body: body,
    severityNumber: severityNumber,
    severityText: severityText ?? severityNumber.name.toUpperCase(),
    attributes: attributes ?? {},
    traceId: traceId,
    spanId: spanId,
    timestamp: timestamp ?? DateTime.now(),
  );

  /// Creates an error log record for testing.
  static LogRecord createError({String message = 'Test error', String? exceptionType, String? stackTrace}) => LogRecord(
    body: message,
    severityNumber: SeverityNumber.error,
    severityText: 'ERROR',
    attributes: {if (exceptionType != null) 'exception.type': exceptionType, if (stackTrace != null) 'exception.stacktrace': stackTrace},
    timestamp: DateTime.now(),
  );

  /// Creates a warning log record for testing.
  static LogRecord createWarning({String message = 'Test warning'}) =>
      LogRecord(body: message, severityNumber: SeverityNumber.warn, severityText: 'WARN', timestamp: DateTime.now());

  /// Creates a debug log record for testing.
  static LogRecord createDebug({String message = 'Test debug message'}) =>
      LogRecord(body: message, severityNumber: SeverityNumber.debug, severityText: 'DEBUG', timestamp: DateTime.now());
}

/// Factory methods for creating test Metric instances.
class MetricFactory {
  /// Creates a Counter metric for testing.
  static CounterMetric createCounter({String name = 'test.counter', String? unit, String? description, int value = 1, Map<String, dynamic>? attributes}) =>
      CounterMetric(name: name, value: value, unit: unit, description: description, attributes: attributes);

  /// Creates a Gauge metric for testing.
  static GaugeMetric createGauge({String name = 'test.gauge', String? unit, double value = 0.0, Map<String, dynamic>? attributes}) =>
      GaugeMetric(name: name, value: value, unit: unit, attributes: attributes);

  /// Creates a Histogram metric for testing.
  static HistogramMetric createHistogram({
    String name = 'test.histogram',
    String? unit,
    List<double> values = const [10, 20, 30, 40, 50],
    Map<String, dynamic>? attributes,
  }) => HistogramMetric(name: name, values: values, unit: unit, attributes: attributes);
}

/// Factory methods for creating TelemetryConfig instances.
class TelemetryConfigFactory {
  /// Creates a TelemetryConfig for testing.
  static TelemetryConfig create({
    String endpoint = 'https://telemetry.test.com',
    String? apiKey = 'test-api-key',
    Duration batchInterval = const Duration(seconds: 5),
    int maxBatchSize = 100,
    bool debug = false,
    bool useBackgroundProcessing = false,
    bool enablePersistence = false,
  }) => TelemetryConfig(
    endpoint: endpoint,
    apiKey: apiKey,
    batchInterval: batchInterval,
    maxBatchSize: maxBatchSize,
    debug: debug,
    useBackgroundProcessing: useBackgroundProcessing,
    enablePersistence: enablePersistence,
  );

  /// Creates a disabled TelemetryConfig for testing (empty endpoint).
  static TelemetryConfig createDisabled() => TelemetryConfig(endpoint: '');

  /// Creates a debug TelemetryConfig for testing.
  static TelemetryConfig createDebug({String endpoint = 'https://telemetry.test.com', String? apiKey = 'test-api-key'}) =>
      TelemetryConfig(endpoint: endpoint, apiKey: apiKey, debug: true, batchInterval: const Duration(seconds: 1), maxBatchSize: 10);
}
