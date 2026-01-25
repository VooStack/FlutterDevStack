import 'dart:convert';

/// Fixtures for API response testing.
class ApiResponseFixtures {
  ApiResponseFixtures._();

  // OTLP Success Responses

  /// Standard OTLP success response (empty JSON object).
  static const String otlpSuccess = '{}';

  /// OTLP success response with partial success status.
  static String otlpPartialSuccess({
    int rejectedSpans = 1,
    String? errorMessage,
  }) =>
      jsonEncode({
        'partialSuccess': {
          'rejectedSpans': rejectedSpans,
          if (errorMessage != null) 'errorMessage': errorMessage,
        },
      });

  /// OTLP success response with all data accepted.
  static String otlpFullSuccess() => jsonEncode({
        'partialSuccess': {
          'rejectedSpans': 0,
          'rejectedLogRecords': 0,
          'rejectedDataPoints': 0,
        },
      });

  // Error Responses

  /// Bad request error (400).
  static String badRequest({String message = 'Invalid request format'}) =>
      jsonEncode({
        'error': 'bad_request',
        'message': message,
        'code': 400,
      });

  /// Unauthorized error (401).
  static String unauthorized({String message = 'Invalid API key'}) =>
      jsonEncode({
        'error': 'unauthorized',
        'message': message,
        'code': 401,
      });

  /// Forbidden error (403).
  static String forbidden({String message = 'Access denied'}) => jsonEncode({
        'error': 'forbidden',
        'message': message,
        'code': 403,
      });

  /// Rate limit exceeded error (429).
  static String rateLimited({
    int retryAfterSeconds = 60,
    String message = 'Rate limit exceeded',
  }) =>
      jsonEncode({
        'error': 'rate_limit_exceeded',
        'message': message,
        'code': 429,
        'retry_after': retryAfterSeconds,
      });

  /// Internal server error (500).
  static String internalServerError({
    String message = 'Internal server error',
  }) =>
      jsonEncode({
        'error': 'internal_server_error',
        'message': message,
        'code': 500,
      });

  /// Bad gateway error (502).
  static String badGateway({String message = 'Bad gateway'}) => jsonEncode({
        'error': 'bad_gateway',
        'message': message,
        'code': 502,
      });

  /// Service unavailable error (503).
  static String serviceUnavailable({
    String message = 'Service temporarily unavailable',
    int? retryAfterSeconds,
  }) =>
      jsonEncode({
        'error': 'service_unavailable',
        'message': message,
        'code': 503,
        if (retryAfterSeconds != null) 'retry_after': retryAfterSeconds,
      });

  /// Gateway timeout error (504).
  static String gatewayTimeout({String message = 'Gateway timeout'}) =>
      jsonEncode({
        'error': 'gateway_timeout',
        'message': message,
        'code': 504,
      });

  // Sync Service Responses

  /// Successful sync response.
  static String syncSuccess({int itemsProcessed = 1}) => jsonEncode({
        'success': true,
        'items_processed': itemsProcessed,
      });

  /// Sync conflict response.
  static String syncConflict({
    String message = 'Conflict detected',
    List<String>? conflictingIds,
  }) =>
      jsonEncode({
        'error': 'conflict',
        'message': message,
        'code': 409,
        if (conflictingIds != null) 'conflicting_ids': conflictingIds,
      });

  /// Payload too large response (413).
  static String payloadTooLarge({
    int maxSizeBytes = 1048576,
    String message = 'Payload too large',
  }) =>
      jsonEncode({
        'error': 'payload_too_large',
        'message': message,
        'code': 413,
        'max_size_bytes': maxSizeBytes,
      });

  // Network Simulation Responses

  /// Connection timeout simulation (empty body).
  static const String connectionTimeout = '';

  /// Malformed JSON response.
  static const String malformedJson = '{invalid json}';

  /// Empty response.
  static const String emptyResponse = '';
}

/// HTTP status codes used in API responses.
class HttpStatusCodes {
  HttpStatusCodes._();

  // Success codes
  static const int ok = 200;
  static const int created = 201;
  static const int accepted = 202;
  static const int noContent = 204;

  // Client error codes
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int payloadTooLarge = 413;
  static const int tooManyRequests = 429;

  // Server error codes
  static const int internalServerError = 500;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeout = 504;

  /// Status codes that indicate a retryable error.
  static const List<int> retryable = [
    tooManyRequests,
    internalServerError,
    badGateway,
    serviceUnavailable,
    gatewayTimeout,
  ];

  /// Status codes that indicate a non-retryable client error.
  static const List<int> nonRetryable = [
    badRequest,
    unauthorized,
    forbidden,
    notFound,
  ];

  /// Check if a status code indicates success.
  static bool isSuccess(int code) => code >= 200 && code < 300;

  /// Check if a status code is retryable.
  static bool isRetryable(int code) => retryable.contains(code);

  /// Check if a status code is a client error that should not be retried.
  static bool isNonRetryable(int code) => nonRetryable.contains(code);
}

/// HTTP headers commonly used in API responses.
class ApiHeaders {
  ApiHeaders._();

  /// Standard JSON content type.
  static const Map<String, String> json = {
    'content-type': 'application/json',
  };

  /// Headers with retry-after.
  static Map<String, String> withRetryAfter(int seconds) => {
        'content-type': 'application/json',
        'retry-after': seconds.toString(),
      };

  /// Headers with request ID.
  static Map<String, String> withRequestId(String requestId) => {
        'content-type': 'application/json',
        'x-request-id': requestId,
      };
}
