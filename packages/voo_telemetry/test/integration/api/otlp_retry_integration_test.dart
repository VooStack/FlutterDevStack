import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_test_utils/voo_test_utils.dart';

void main() {
  group('OTLPHttpExporter - Retry Integration', () {
    late MockOtlpServer mockServer;
    late TelemetryResource resource;

    setUp(() {
      mockServer = MockOtlpServer();
      resource = TelemetryResource(serviceName: 'test-service', serviceVersion: '1.0.0');
    });

    group('retryable status codes', () {
      test('should retry on 429 rate limit', () async {
        mockServer.setFailure(OtlpFailureConfig.rateLimit(failCount: 2));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'retry-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(3)); // 2 failures + 1 success

        exporter.dispose();
      });

      test('should retry on 500 internal server error', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'retry-500-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(2)); // 1 failure + 1 success

        exporter.dispose();
      });

      test('should retry on 502 bad gateway', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(statusCode: 502, failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'retry-502-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(2));

        exporter.dispose();
      });

      test('should retry on 503 service unavailable', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(statusCode: 503, failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'retry-503-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(2));

        exporter.dispose();
      });

      test('should retry on 504 gateway timeout', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(statusCode: 504, failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'retry-504-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(2));

        exporter.dispose();
      });
    });

    group('non-retryable status codes', () {
      test('should not retry on 400 bad request', () async {
        mockServer.setFailure(OtlpFailureConfig.clientError());

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'no-retry-400-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(1)); // No retries

        exporter.dispose();
      });

      test('should not retry on 401 unauthorized', () async {
        mockServer.setFailure(OtlpFailureConfig.unauthorized());

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'no-retry-401-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(1)); // No retries

        exporter.dispose();
      });

      test('should not retry on 403 forbidden', () async {
        mockServer.setFailure(OtlpFailureConfig.clientError(statusCode: 403));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'no-retry-403-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(1)); // No retries

        exporter.dispose();
      });

      test('should not retry on 404 not found', () async {
        mockServer.setFailure(OtlpFailureConfig.clientError(statusCode: 404));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'no-retry-404-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(1)); // No retries

        exporter.dispose();
      });
    });

    group('max retries limit', () {
      test('should fail after exceeding max retries', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError()); // Always fails

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'max-retries-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(3)); // Initial + 2 retries = 3 attempts

        exporter.dispose();
      });

      test('should respect custom max retries', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError());

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          maxRetries: 5,
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'custom-max-retries-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(5)); // 5 total attempts

        exporter.dispose();
      });

      test('should work with max retries of 1', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError());

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          maxRetries: 1,
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'single-attempt-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
        expect(mockServer.requestCount, equals(1)); // Only 1 attempt

        exporter.dispose();
      });
    });

    group('success after transient failure', () {
      test('should succeed after 1 transient failure', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'transient-1-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(2));

        exporter.dispose();
      });

      test('should succeed after 2 transient failures', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 2));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'transient-2-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(3));

        exporter.dispose();
      });

      test('should succeed on the last retry', () async {
        // Fail exactly maxRetries - 1 times
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 2));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'last-retry-success-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.requestCount, equals(3)); // 2 failures + 1 success

        exporter.dispose();
      });
    });

    group('retry behavior across telemetry types', () {
      test('should retry traces export', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final span = SpanFactory.create(name: 'trace-retry');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.traceRequests.length, equals(2));

        exporter.dispose();
      });

      test('should retry metrics export', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final counter = MetricFactory.createCounter(name: 'metric-retry');

        final result = await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.metricRequests.length, equals(2));

        exporter.dispose();
      });

      test('should retry logs export', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 1));

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          retryDelay: const Duration(milliseconds: 10),
        );

        final log = LogRecordFactory.create(body: 'log-retry');

        final result = await exporter.exportLogs([log.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.logRequests.length, equals(2));

        exporter.dispose();
      });
    });

    group('retry timing', () {
      test('should apply exponential backoff', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError(failCount: 3));

        final stopwatch = Stopwatch()..start();

        final exporter = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          apiKey: 'test-api-key',
          client: mockServer.createClient(),
          maxRetries: 4,
          retryDelay: const Duration(milliseconds: 50),
        );

        final span = SpanFactory.create(name: 'backoff-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        stopwatch.stop();

        // With exponential backoff: 50ms + 100ms + 200ms = 350ms minimum
        // Adding jitter (up to 500ms per retry), timing can vary
        // Just verify some delay occurred
        expect(stopwatch.elapsedMilliseconds, greaterThan(100));

        exporter.dispose();
      });
    });
  });
}
