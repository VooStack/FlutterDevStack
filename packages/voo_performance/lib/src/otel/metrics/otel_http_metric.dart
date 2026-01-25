import 'package:voo_telemetry/voo_telemetry.dart';
import '../semantic_conventions.dart';

/// Export HTTP client metrics using OTEL instruments.
///
/// Tracks:
/// - Request duration as histogram for response time analysis
/// - Request count as counter for throughput
/// - Error count as counter for error rate
class OtelHttpMetric {
  final Meter _meter;

  late final Histogram _durationHistogram;
  late final Counter _requestCounter;
  late final Counter _errorCounter;

  /// Flag indicating if metrics are initialized.
  bool _initialized = false;

  OtelHttpMetric(this._meter);

  /// Initialize the HTTP metric instruments.
  void initialize() {
    if (_initialized) return;

    _durationHistogram = _meter.createHistogram(
      HttpSemanticConventions.httpClientRequestDuration,
      description: 'Duration of HTTP client requests',
      unit: 'ms',
      explicitBounds: [5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 10000],
    );

    _requestCounter = _meter.createCounter(
      'http.client.request.count',
      description: 'Count of HTTP client requests',
      unit: '{requests}',
    );

    _errorCounter = _meter.createCounter(
      'http.client.error.count',
      description: 'Count of HTTP client errors',
      unit: '{errors}',
    );

    _initialized = true;
  }

  /// Record an HTTP request metric.
  ///
  /// [method] The HTTP method (GET, POST, etc.).
  /// [url] The full URL of the request.
  /// [statusCode] The HTTP response status code.
  /// [durationMs] The request duration in milliseconds.
  /// [requestSize] Optional request body size in bytes.
  /// [responseSize] Optional response body size in bytes.
  void recordRequest({
    required String method,
    required String url,
    required int statusCode,
    required double durationMs,
    int? requestSize,
    int? responseSize,
  }) {
    if (!_initialized) return;

    final uri = Uri.tryParse(url);
    final route = uri?.path ?? url;
    final host = uri?.host ?? '';

    final attributes = <String, dynamic>{
      HttpSemanticConventions.httpRequestMethod: method,
      HttpSemanticConventions.httpResponseStatusCode: statusCode,
      'http.route': route,
      'url.path': route,
      if (host.isNotEmpty) 'server.address': host,
      if (requestSize != null) HttpSemanticConventions.httpRequestBodySize: requestSize,
      if (responseSize != null) HttpSemanticConventions.httpResponseBodySize: responseSize,
    };

    // Record duration
    _durationHistogram.record(durationMs, attributes: attributes);

    // Increment request count
    _requestCounter.increment(attributes: attributes);

    // Track errors (4xx and 5xx)
    if (statusCode >= 400) {
      _errorCounter.increment(attributes: attributes);
    }
  }
}
