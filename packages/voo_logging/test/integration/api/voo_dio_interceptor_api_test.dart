import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voo_logging/features/logging/domain/interceptors/dio_interceptor.dart';
import 'package:voo_logging/features/logging/domain/interceptors/network_interceptor.dart';

/// Mock handler for testing interceptor flow.
class MockHandler {
  bool nextCalled = false;
  dynamic nextValue;

  void next(dynamic value) {
    nextCalled = true;
    nextValue = value;
  }
}

/// Capture interceptor that records all method calls for verification.
class CaptureNetworkInterceptor implements NetworkInterceptor {
  final List<RequestCapture> requests = [];
  final List<ResponseCapture> responses = [];
  final List<ErrorCapture> errors = [];

  @override
  Future<void> onRequest({required String method, required String url, Map<String, String>? headers, dynamic body, Map<String, dynamic>? metadata}) async {
    requests.add(RequestCapture(method: method, url: url, headers: headers, body: body, metadata: metadata));
  }

  @override
  Future<void> onResponse({
    required int statusCode,
    required String url,
    required Duration duration,
    Map<String, String>? headers,
    dynamic body,
    int? contentLength,
    Map<String, dynamic>? metadata,
  }) async {
    responses.add(
      ResponseCapture(statusCode: statusCode, url: url, duration: duration, headers: headers, body: body, contentLength: contentLength, metadata: metadata),
    );
  }

  @override
  Future<void> onError({required String url, required Object error, StackTrace? stackTrace, Map<String, dynamic>? metadata}) async {
    errors.add(ErrorCapture(url: url, error: error, stackTrace: stackTrace, metadata: metadata));
  }

  void reset() {
    requests.clear();
    responses.clear();
    errors.clear();
  }
}

class RequestCapture {
  final String method;
  final String url;
  final Map<String, String>? headers;
  final dynamic body;
  final Map<String, dynamic>? metadata;

  RequestCapture({required this.method, required this.url, this.headers, this.body, this.metadata});
}

class ResponseCapture {
  final int statusCode;
  final String url;
  final Duration duration;
  final Map<String, String>? headers;
  final dynamic body;
  final int? contentLength;
  final Map<String, dynamic>? metadata;

  ResponseCapture({required this.statusCode, required this.url, required this.duration, this.headers, this.body, this.contentLength, this.metadata});
}

class ErrorCapture {
  final String url;
  final Object error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? metadata;

  ErrorCapture({required this.url, required this.error, this.stackTrace, this.metadata});
}

void main() {
  group('VooDioInterceptor API', () {
    late CaptureNetworkInterceptor captureInterceptor;
    late VooDioInterceptor interceptor;

    setUp(() {
      captureInterceptor = CaptureNetworkInterceptor();
      interceptor = VooDioInterceptor(interceptor: captureInterceptor);
    });

    group('onRequest', () {
      test('should log method and URL', () {
        final options = RequestOptions(path: '/api/users', baseUrl: 'https://api.example.com', method: 'GET');
        final handler = MockHandler();

        interceptor.onRequest(options, handler);

        expect(captureInterceptor.requests.length, equals(1));
        expect(captureInterceptor.requests.first.method, equals('GET'));
        expect(captureInterceptor.requests.first.url, contains('https://api.example.com/api/users'));
      });

      test('should log request headers', () {
        final options = RequestOptions(
          path: '/api/data',
          baseUrl: 'https://api.example.com',
          method: 'POST',
          headers: {'Authorization': 'Bearer token123', 'Content-Type': 'application/json'},
        );
        final handler = MockHandler();

        interceptor.onRequest(options, handler);

        final captured = captureInterceptor.requests.first;
        expect(captured.headers, isNotNull);
        expect(captured.headers!['Authorization'], equals('Bearer token123'));
        expect(captured.headers!['Content-Type'], equals('application/json'));
      });

      test('should log request body', () {
        final options = RequestOptions(
          path: '/api/users',
          baseUrl: 'https://api.example.com',
          method: 'POST',
          data: {'name': 'John', 'email': 'john@example.com'},
        );
        final handler = MockHandler();

        interceptor.onRequest(options, handler);

        final captured = captureInterceptor.requests.first;
        expect(captured.body, isNotNull);
        expect(captured.body['name'], equals('John'));
      });

      test('should store start time for duration calculation', () {
        final options = RequestOptions(path: '/api/users', baseUrl: 'https://api.example.com');
        final handler = MockHandler();

        interceptor.onRequest(options, handler);

        expect(options.extra['voo_start_time'], isA<DateTime>());
      });

      test('should include timeout metadata', () {
        final options = RequestOptions(
          path: '/api/users',
          baseUrl: 'https://api.example.com',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        );
        final handler = MockHandler();

        interceptor.onRequest(options, handler);

        final captured = captureInterceptor.requests.first;
        expect(captured.metadata, isNotNull);
        expect(captured.metadata!['connectTimeout'], equals(30000));
        expect(captured.metadata!['receiveTimeout'], equals(60000));
      });

      test('should call handler.next to continue request', () {
        final options = RequestOptions(path: '/api/test');
        final handler = MockHandler();

        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(handler.nextValue, equals(options));
      });

      test('should handle different HTTP methods', () {
        final methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];
        final handler = MockHandler();

        for (final method in methods) {
          captureInterceptor.reset();
          final options = RequestOptions(path: '/api/test', method: method);
          interceptor.onRequest(options, handler);

          expect(captureInterceptor.requests.first.method, equals(method));
        }
      });
    });

    group('onResponse', () {
      test('should calculate and log response duration', () async {
        final startTime = DateTime.now().subtract(const Duration(milliseconds: 150));
        final options = RequestOptions(path: '/api/users', baseUrl: 'https://api.example.com')..extra['voo_start_time'] = startTime;

        final response = Response(requestOptions: options, statusCode: 200, data: {'success': true});
        final handler = MockHandler();

        interceptor.onResponse(response, handler);

        final captured = captureInterceptor.responses.first;
        expect(captured.duration.inMilliseconds, greaterThanOrEqualTo(100));
      });

      test('should log status code', () {
        final options = RequestOptions(path: '/api/test');
        final response = Response(requestOptions: options, statusCode: 201);
        final handler = MockHandler();

        interceptor.onResponse(response, handler);

        expect(captureInterceptor.responses.first.statusCode, equals(201));
      });

      test('should log content length from headers', () {
        final options = RequestOptions(path: '/api/test');
        final response = Response(
          requestOptions: options,
          statusCode: 200,
          headers: Headers.fromMap({
            'content-length': ['1024'],
          }),
        );
        final handler = MockHandler();

        interceptor.onResponse(response, handler);

        expect(captureInterceptor.responses.first.contentLength, equals(1024));
      });

      test('should log response body', () {
        final options = RequestOptions(path: '/api/test');
        final response = Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'users': ['Alice', 'Bob'],
          },
        );
        final handler = MockHandler();

        interceptor.onResponse(response, handler);

        final captured = captureInterceptor.responses.first;
        expect(captured.body, isNotNull);
        expect((captured.body as Map)['users'], contains('Alice'));
      });

      test('should call handler.next to continue response', () {
        final options = RequestOptions(path: '/api/test');
        final response = Response(requestOptions: options, statusCode: 200);
        final handler = MockHandler();

        interceptor.onResponse(response, handler);

        expect(handler.nextCalled, isTrue);
        expect(handler.nextValue, equals(response));
      });

      test('should handle missing start time gracefully', () {
        final options = RequestOptions(path: '/api/test');
        final response = Response(requestOptions: options, statusCode: 200);
        final handler = MockHandler();

        interceptor.onResponse(response, handler);

        expect(captureInterceptor.responses.first.duration, equals(Duration.zero));
      });

      test('should log various status codes', () {
        final statusCodes = [200, 201, 204, 400, 401, 404, 500, 503];
        final handler = MockHandler();

        for (final statusCode in statusCodes) {
          captureInterceptor.reset();
          final options = RequestOptions(path: '/api/test');
          final response = Response(requestOptions: options, statusCode: statusCode);
          interceptor.onResponse(response, handler);

          expect(captureInterceptor.responses.first.statusCode, equals(statusCode));
        }
      });
    });

    group('onError', () {
      test('should log error with response (HTTP error)', () {
        final options = RequestOptions(path: '/api/users', baseUrl: 'https://api.example.com')..extra['voo_start_time'] = DateTime.now();

        final error = DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404, statusMessage: 'Not Found'),
          type: DioExceptionType.badResponse,
        );
        final handler = MockHandler();

        interceptor.onError(error, handler);

        // Error with response is logged as response, not error
        expect(captureInterceptor.responses.length, equals(1));
        expect(captureInterceptor.responses.first.statusCode, equals(404));
      });

      test('should log error without response (network error)', () {
        final options = RequestOptions(path: '/api/users', baseUrl: 'https://api.example.com');

        final error = DioException(requestOptions: options, type: DioExceptionType.connectionTimeout, message: 'Connection timed out');
        final handler = MockHandler();

        interceptor.onError(error, handler);

        expect(captureInterceptor.errors.length, equals(1));
        expect(captureInterceptor.errors.first.url, contains('/api/users'));
      });

      test('should include error metadata', () {
        final options = RequestOptions(path: '/api/test');
        final error = DioException(requestOptions: options, type: DioExceptionType.sendTimeout, message: 'Send timeout');
        final handler = MockHandler();

        interceptor.onError(error, handler);

        final captured = captureInterceptor.errors.first;
        expect(captured.metadata, isNotNull);
        expect(captured.metadata!['type'], contains('sendTimeout'));
      });

      test('should call handler.next to continue error handling', () {
        final options = RequestOptions(path: '/api/test');
        final error = DioException(requestOptions: options);
        final handler = MockHandler();

        interceptor.onError(error, handler);

        expect(handler.nextCalled, isTrue);
        expect(handler.nextValue, equals(error));
      });

      test('should handle different error types', () {
        final errorTypes = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.cancel,
          DioExceptionType.unknown,
        ];
        final handler = MockHandler();

        for (final errorType in errorTypes) {
          captureInterceptor.reset();
          final options = RequestOptions(path: '/api/test');
          final error = DioException(requestOptions: options, type: errorType);
          interceptor.onError(error, handler);

          expect(captureInterceptor.errors.length, equals(1));
        }
      });
    });

    group('integration flow', () {
      test('should handle complete request-response cycle', () {
        final options = RequestOptions(path: '/api/users', baseUrl: 'https://api.example.com', method: 'POST', data: {'name': 'Test User'});
        final handler = MockHandler();

        // Request phase
        interceptor.onRequest(options, handler);

        expect(captureInterceptor.requests.length, equals(1));
        expect(captureInterceptor.requests.first.method, equals('POST'));

        // Response phase
        final response = Response(requestOptions: options, statusCode: 201, data: {'id': 1, 'name': 'Test User'});
        interceptor.onResponse(response, handler);

        expect(captureInterceptor.responses.length, equals(1));
        expect(captureInterceptor.responses.first.statusCode, equals(201));
      });

      test('should handle request-error cycle', () {
        final options = RequestOptions(path: '/api/protected', baseUrl: 'https://api.example.com');
        final handler = MockHandler();

        // Request phase
        interceptor.onRequest(options, handler);

        expect(captureInterceptor.requests.length, equals(1));

        // Error phase
        final error = DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401, statusMessage: 'Unauthorized'),
          type: DioExceptionType.badResponse,
        );
        interceptor.onError(error, handler);

        expect(captureInterceptor.responses.length, equals(1));
        expect(captureInterceptor.responses.first.statusCode, equals(401));
      });
    });

    group('error handling', () {
      test('should not throw on malformed options', () {
        final handler = MockHandler();

        // Should not throw
        expect(() => interceptor.onRequest({'not': 'valid'}, handler), returnsNormally);
      });

      test('should continue request even if logging fails', () {
        final options = RequestOptions(path: '/api/test');
        final handler = MockHandler();

        // Even with errors, should call next
        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
      });
    });
  });
}
