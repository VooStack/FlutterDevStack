import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:voo_test_utils/src/mocks/mock_otlp_server.dart';

/// Environment variable names for API testing configuration.
class ApiTestEnv {
  ApiTestEnv._();

  /// Set to 'true' to run tests against real endpoints.
  static const String useRealEndpoint = 'VOO_TEST_REAL_ENDPOINT';

  /// The real OTLP collector endpoint URL.
  static const String otlpEndpoint = 'VOO_OTLP_ENDPOINT';

  /// The API key for authentication with real endpoints.
  static const String apiKey = 'VOO_API_KEY';

  /// The project ID for real endpoint testing.
  static const String projectId = 'VOO_PROJECT_ID';

  /// Timeout in seconds for real endpoint tests (default: 30).
  static const String timeout = 'VOO_TEST_TIMEOUT';
}

/// Configuration for API integration tests.
///
/// This class provides helpers to detect whether tests should run against
/// real endpoints or mock servers based on environment variables.
class ApiTestConfig {
  /// Whether to use real endpoints instead of mocks.
  final bool useRealEndpoint;

  /// The OTLP collector endpoint URL (real or mock).
  final String otlpEndpoint;

  /// The API key for authentication.
  final String? apiKey;

  /// The project ID.
  final String? projectId;

  /// The HTTP client to use.
  final http.Client client;

  /// Timeout duration for requests.
  final Duration timeout;

  /// The mock server (only available when not using real endpoint).
  final MockOtlpServer? mockServer;

  ApiTestConfig._({
    required this.useRealEndpoint,
    required this.otlpEndpoint,
    this.apiKey,
    this.projectId,
    required this.client,
    required this.timeout,
    this.mockServer,
  });

  /// Creates a configuration by reading environment variables.
  ///
  /// If `VOO_TEST_REAL_ENDPOINT` is 'true', the test will use real endpoints.
  /// Otherwise, a mock server will be created.
  factory ApiTestConfig.fromEnvironment() {
    final useReal = Platform.environment[ApiTestEnv.useRealEndpoint]?.toLowerCase() == 'true';

    if (useReal) {
      final endpoint = Platform.environment[ApiTestEnv.otlpEndpoint];
      if (endpoint == null || endpoint.isEmpty) {
        throw StateError('VOO_OTLP_ENDPOINT must be set when VOO_TEST_REAL_ENDPOINT=true');
      }

      final timeoutSeconds = int.tryParse(Platform.environment[ApiTestEnv.timeout] ?? '30') ?? 30;

      return ApiTestConfig._(
        useRealEndpoint: true,
        otlpEndpoint: endpoint,
        apiKey: Platform.environment[ApiTestEnv.apiKey],
        projectId: Platform.environment[ApiTestEnv.projectId],
        client: http.Client(),
        timeout: Duration(seconds: timeoutSeconds),
      );
    }

    // Create mock configuration
    final mockServer = MockOtlpServer();
    return ApiTestConfig._(
      useRealEndpoint: false,
      otlpEndpoint: mockServer.baseUrl,
      apiKey: 'test-api-key',
      projectId: 'test-project',
      client: mockServer.createClient(),
      timeout: const Duration(seconds: 5),
      mockServer: mockServer,
    );
  }

  /// Creates a mock-only configuration for testing.
  factory ApiTestConfig.mock({String? baseUrl, String apiKey = 'test-api-key', String projectId = 'test-project'}) {
    final mockServer = MockOtlpServer(baseUrl: baseUrl ?? 'https://mock-otlp.example.com');
    return ApiTestConfig._(
      useRealEndpoint: false,
      otlpEndpoint: mockServer.baseUrl,
      apiKey: apiKey,
      projectId: projectId,
      client: mockServer.createClient(),
      timeout: const Duration(seconds: 5),
      mockServer: mockServer,
    );
  }

  /// Creates a configuration for a real endpoint (for manual testing).
  factory ApiTestConfig.real({required String endpoint, required String apiKey, String? projectId, Duration timeout = const Duration(seconds: 30)}) =>
      ApiTestConfig._(useRealEndpoint: true, otlpEndpoint: endpoint, apiKey: apiKey, projectId: projectId, client: http.Client(), timeout: timeout);

  /// Whether this config is using a mock server.
  bool get isMock => !useRealEndpoint && mockServer != null;

  /// Reset the mock server state. Only works for mock configurations.
  void resetMock() {
    mockServer?.reset();
  }

  /// Set a failure scenario on the mock server. Only works for mock configs.
  void setMockFailure(OtlpFailureConfig? config) {
    mockServer?.setFailure(config);
  }

  /// Dispose of resources (closes the HTTP client if using real endpoint).
  void dispose() {
    if (useRealEndpoint) {
      client.close();
    }
  }
}

/// A test helper that provides conditional test execution based on endpoint.
class ApiTestRunner {
  final ApiTestConfig config;

  ApiTestRunner(this.config);

  /// Runs a test only when using mock endpoints.
  void runMockOnly(String description, void Function() testFn) {
    if (!config.useRealEndpoint) {
      testFn();
    }
  }

  /// Runs a test only when using real endpoints.
  void runRealOnly(String description, void Function() testFn) {
    if (config.useRealEndpoint) {
      testFn();
    }
  }

  /// Skips a test when using real endpoints (for tests that would incur costs).
  bool get shouldSkipRealEndpoint => config.useRealEndpoint;

  /// Returns the appropriate skip reason or null.
  String? skipIfReal([String reason = 'Test skipped for real endpoints']) => config.useRealEndpoint ? reason : null;

  /// Returns the appropriate skip reason or null.
  String? skipIfMock([String reason = 'Test requires real endpoint']) => config.isMock ? reason : null;
}

/// Extension methods for convenient mock server assertions.
extension MockServerAssertions on ApiTestConfig {
  /// Get the number of trace requests made.
  int get traceRequestCount => mockServer?.traceRequests.length ?? 0;

  /// Get the number of metric requests made.
  int get metricRequestCount => mockServer?.metricRequests.length ?? 0;

  /// Get the number of log requests made.
  int get logRequestCount => mockServer?.logRequests.length ?? 0;

  /// Get all captured spans.
  List<Map<String, dynamic>> get capturedSpans => mockServer?.allSpans ?? [];

  /// Get all captured metrics.
  List<Map<String, dynamic>> get capturedMetrics => mockServer?.allMetrics ?? [];

  /// Get all captured log records.
  List<Map<String, dynamic>> get capturedLogRecords => mockServer?.allLogRecords ?? [];

  /// Check if all requests have the expected API key.
  bool hasApiKeyHeader(String expectedKey) => mockServer?.allRequestsHaveApiKey(expectedKey) ?? false;

  /// Check if all requests have JSON content type.
  bool get hasJsonContentType => mockServer?.allRequestsHaveJsonContentType ?? false;
}
