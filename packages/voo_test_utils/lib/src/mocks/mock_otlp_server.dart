import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:voo_test_utils/src/mocks/mock_http_client.dart';

/// Types of OTLP endpoints.
enum OtlpEndpointType { traces, metrics, logs }

/// A captured OTLP request with parsed payload.
class CapturedOtlpRequest {
  final CapturedRequest request;
  final OtlpEndpointType endpointType;
  final Map<String, dynamic> payload;

  CapturedOtlpRequest({required this.request, required this.endpointType, required this.payload});

  String get method => request.method;
  String get url => request.url;
  Map<String, String> get headers => request.headers;
  DateTime get timestamp => request.timestamp;

  /// Get the resource from the payload.
  Map<String, dynamic>? get resource {
    switch (endpointType) {
      case OtlpEndpointType.traces:
        final resourceSpans = payload['resourceSpans'] as List?;
        if (resourceSpans != null && resourceSpans.isNotEmpty) {
          return resourceSpans[0]['resource'] as Map<String, dynamic>?;
        }
        return null;
      case OtlpEndpointType.metrics:
        final resourceMetrics = payload['resourceMetrics'] as List?;
        if (resourceMetrics != null && resourceMetrics.isNotEmpty) {
          return resourceMetrics[0]['resource'] as Map<String, dynamic>?;
        }
        return null;
      case OtlpEndpointType.logs:
        final resourceLogs = payload['resourceLogs'] as List?;
        if (resourceLogs != null && resourceLogs.isNotEmpty) {
          return resourceLogs[0]['resource'] as Map<String, dynamic>?;
        }
        return null;
    }
  }

  /// Get the spans from a traces request.
  List<Map<String, dynamic>> get spans {
    if (endpointType != OtlpEndpointType.traces) return [];
    final resourceSpans = payload['resourceSpans'] as List?;
    if (resourceSpans == null || resourceSpans.isEmpty) return [];
    final scopeSpans = resourceSpans[0]['scopeSpans'] as List?;
    if (scopeSpans == null || scopeSpans.isEmpty) return [];
    return (scopeSpans[0]['spans'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Get the metrics from a metrics request.
  List<Map<String, dynamic>> get metrics {
    if (endpointType != OtlpEndpointType.metrics) return [];
    final resourceMetrics = payload['resourceMetrics'] as List?;
    if (resourceMetrics == null || resourceMetrics.isEmpty) return [];
    final scopeMetrics = resourceMetrics[0]['scopeMetrics'] as List?;
    if (scopeMetrics == null || scopeMetrics.isEmpty) return [];
    return (scopeMetrics[0]['metrics'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Get the log records from a logs request.
  List<Map<String, dynamic>> get logRecords {
    if (endpointType != OtlpEndpointType.logs) return [];
    final resourceLogs = payload['resourceLogs'] as List?;
    if (resourceLogs == null || resourceLogs.isEmpty) return [];
    final scopeLogs = resourceLogs[0]['scopeLogs'] as List?;
    if (scopeLogs == null || scopeLogs.isEmpty) return [];
    return (scopeLogs[0]['logRecords'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
}

/// Configuration for failure scenarios.
class OtlpFailureConfig {
  /// Status code to return on failure.
  final int statusCode;

  /// Response body to return on failure.
  final String body;

  /// Number of times to fail before succeeding (0 = always fail).
  final int failCount;

  /// Delay before responding.
  final Duration? delay;

  /// Specific endpoint types to fail (null = all).
  final Set<OtlpEndpointType>? endpointTypes;

  const OtlpFailureConfig({required this.statusCode, this.body = '{"error": "server error"}', this.failCount = 0, this.delay, this.endpointTypes});

  /// Creates a rate limit failure config.
  factory OtlpFailureConfig.rateLimit({int retryAfterSeconds = 60, int failCount = 1}) => OtlpFailureConfig(
    statusCode: 429,
    body: jsonEncode({'error': 'rate_limit_exceeded', 'message': 'Too many requests', 'retry_after': retryAfterSeconds}),
    failCount: failCount,
  );

  /// Creates a server error config.
  factory OtlpFailureConfig.serverError({int statusCode = 500, int failCount = 0}) =>
      OtlpFailureConfig(statusCode: statusCode, body: '{"error": "internal_server_error"}', failCount: failCount);

  /// Creates a client error config.
  factory OtlpFailureConfig.clientError({int statusCode = 400, String message = 'Bad request'}) =>
      OtlpFailureConfig(statusCode: statusCode, body: jsonEncode({'error': 'client_error', 'message': message}));

  /// Creates an unauthorized error config.
  factory OtlpFailureConfig.unauthorized() => const OtlpFailureConfig(statusCode: 401, body: '{"error": "unauthorized", "message": "Invalid API key"}');
}

/// Mock OTLP server for testing telemetry exports.
class MockOtlpServer {
  final String baseUrl;
  final List<CapturedOtlpRequest> _traceRequests = [];
  final List<CapturedOtlpRequest> _metricRequests = [];
  final List<CapturedOtlpRequest> _logRequests = [];
  final List<CapturedRequest> _allRequests = [];

  OtlpFailureConfig? _failureConfig;
  int _failureCount = 0;
  int _requestCount = 0;

  MockOtlpServer({this.baseUrl = 'https://mock-otlp.example.com'});

  /// All captured trace requests.
  List<CapturedOtlpRequest> get traceRequests => List.unmodifiable(_traceRequests);

  /// All captured metric requests.
  List<CapturedOtlpRequest> get metricRequests => List.unmodifiable(_metricRequests);

  /// All captured log requests.
  List<CapturedOtlpRequest> get logRequests => List.unmodifiable(_logRequests);

  /// All captured requests (regardless of type).
  List<CapturedRequest> get allRequests => List.unmodifiable(_allRequests);

  /// Total number of requests received.
  int get requestCount => _requestCount;

  /// Most recent trace request.
  CapturedOtlpRequest? get lastTraceRequest => _traceRequests.isNotEmpty ? _traceRequests.last : null;

  /// Most recent metric request.
  CapturedOtlpRequest? get lastMetricRequest => _metricRequests.isNotEmpty ? _metricRequests.last : null;

  /// Most recent log request.
  CapturedOtlpRequest? get lastLogRequest => _logRequests.isNotEmpty ? _logRequests.last : null;

  /// Configure failure scenarios.
  void setFailure(OtlpFailureConfig? config) {
    _failureConfig = config;
    _failureCount = 0;
  }

  /// Clear failure configuration.
  void clearFailure() {
    _failureConfig = null;
    _failureCount = 0;
  }

  /// Reset all captured requests.
  void reset() {
    _traceRequests.clear();
    _metricRequests.clear();
    _logRequests.clear();
    _allRequests.clear();
    _requestCount = 0;
    _failureCount = 0;
    _failureConfig = null;
  }

  /// Creates a MockClient that simulates the OTLP server.
  MockClient createClient() => MockClient((request) async {
    _requestCount++;
    final capturedRequest = CapturedRequest(request);
    _allRequests.add(capturedRequest);

    // Determine endpoint type from URL
    final path = request.url.path;
    OtlpEndpointType? endpointType;

    if (path.endsWith('/v1/traces')) {
      endpointType = OtlpEndpointType.traces;
    } else if (path.endsWith('/v1/metrics')) {
      endpointType = OtlpEndpointType.metrics;
    } else if (path.endsWith('/v1/logs')) {
      endpointType = OtlpEndpointType.logs;
    }

    // Parse payload
    Map<String, dynamic> payload = {};
    try {
      if (request.body.isNotEmpty) {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Invalid JSON
    }

    // Store captured request
    if (endpointType != null) {
      final otlpRequest = CapturedOtlpRequest(request: capturedRequest, endpointType: endpointType, payload: payload);

      switch (endpointType) {
        case OtlpEndpointType.traces:
          _traceRequests.add(otlpRequest);
          break;
        case OtlpEndpointType.metrics:
          _metricRequests.add(otlpRequest);
          break;
        case OtlpEndpointType.logs:
          _logRequests.add(otlpRequest);
          break;
      }
    }

    // Check for failure config
    if (_failureConfig != null) {
      final config = _failureConfig!;

      // Check if this endpoint type should fail
      final shouldFailType = config.endpointTypes == null || (endpointType != null && config.endpointTypes!.contains(endpointType));

      if (shouldFailType) {
        // Apply delay if configured
        if (config.delay != null) {
          await Future<void>.delayed(config.delay!);
        }

        // Check if we should still fail
        if (config.failCount == 0 || _failureCount < config.failCount) {
          _failureCount++;
          return http.Response(config.body, config.statusCode, headers: _buildHeaders(config.statusCode));
        }
      }
    }

    // Success response
    return http.Response('{}', 200, headers: {'content-type': 'application/json'});
  });

  Map<String, String> _buildHeaders(int statusCode) {
    final headers = <String, String>{'content-type': 'application/json'};

    // Add retry-after header for rate limit responses
    if (statusCode == 429 && _failureConfig != null) {
      try {
        final body = jsonDecode(_failureConfig!.body) as Map<String, dynamic>;
        if (body.containsKey('retry_after')) {
          headers['retry-after'] = body['retry_after'].toString();
        }
      } catch (_) {
        // Ignore JSON parsing errors
      }
    }

    return headers;
  }

  /// Get all spans from all trace requests.
  List<Map<String, dynamic>> get allSpans => _traceRequests.expand((r) => r.spans).toList();

  /// Get all metrics from all metric requests.
  List<Map<String, dynamic>> get allMetrics => _metricRequests.expand((r) => r.metrics).toList();

  /// Get all log records from all log requests.
  List<Map<String, dynamic>> get allLogRecords => _logRequests.expand((r) => r.logRecords).toList();

  /// Verify that a request was made with the expected headers.
  bool hasRequestWithHeaders(Map<String, String> expectedHeaders) =>
      _allRequests.any((request) => expectedHeaders.entries.every((entry) => request.headers[entry.key] == entry.value));

  /// Verify that the Content-Type header is application/json.
  bool get allRequestsHaveJsonContentType => _allRequests.every((request) => request.headers['content-type'] == 'application/json');

  /// Verify that all requests have the expected API key header.
  bool allRequestsHaveApiKey(String apiKey) => _allRequests.every((request) => request.headers['x-api-key'] == apiKey);
}
