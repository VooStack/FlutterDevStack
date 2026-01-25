import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('OTLPHttpExporter', () {
    late TelemetryResource resource;

    setUp(() {
      resource = TelemetryResource(serviceName: 'test-service', serviceVersion: '1.0.0');
    });

    group('constructor', () {
      test('should create with endpoint', () {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com');

        expect(exporter, isNotNull);
        expect(exporter.endpoint, equals('https://test.com'));
      });

      test('should create with api key', () {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', apiKey: 'test-api-key');

        expect(exporter.apiKey, equals('test-api-key'));
      });

      test('should create with debug mode', () {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', debug: true);

        expect(exporter.debug, isTrue);
      });

      test('should create with custom timeout', () {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', timeout: const Duration(seconds: 30));

        expect(exporter.timeout, equals(const Duration(seconds: 30)));
      });
    });

    group('apiKeyValue setter', () {
      test('should update api key', () {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com');

        exporter.apiKeyValue = 'new-api-key';

        expect(exporter.apiKey, equals('new-api-key'));
      });
    });

    group('exportTraces', () {
      test('should return true when spans list is empty', () async {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com');

        final result = await exporter.exportTraces([], resource);

        expect(result, isTrue);
      });

      test('should export spans successfully', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('/v1/traces'));
          expect(request.method, equals('POST'));
          return http.Response('{}', 200);
        });

        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', client: mockClient);

        final spans = [Span(name: 'test-span').toOtlp()];

        final result = await exporter.exportTraces(spans, resource);

        expect(result, isTrue);
      });

      test('should return false on server error', () async {
        final mockClient = MockClient((request) async => http.Response('{"error": "Server Error"}', 500));

        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', client: mockClient, maxRetries: 1, retryDelay: const Duration(milliseconds: 10));

        final spans = [Span(name: 'test-span').toOtlp()];

        final result = await exporter.exportTraces(spans, resource);

        expect(result, isFalse);
      });
    });

    group('exportMetrics', () {
      test('should return true when metrics list is empty', () async {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com');

        final result = await exporter.exportMetrics([], resource);

        expect(result, isTrue);
      });

      test('should export metrics successfully', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('/v1/metrics'));
          return http.Response('{}', 200);
        });

        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', client: mockClient);

        final metrics = [CounterMetric(name: 'test.counter', value: 10).toOtlp()];

        final result = await exporter.exportMetrics(metrics, resource);

        expect(result, isTrue);
      });
    });

    group('exportLogs', () {
      test('should return true when logs list is empty', () async {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com');

        final result = await exporter.exportLogs([], resource);

        expect(result, isTrue);
      });

      test('should export logs successfully', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('/v1/logs'));
          return http.Response('{}', 200);
        });

        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', client: mockClient);

        final logs = [LogRecord(body: 'Test log', severityNumber: SeverityNumber.info, severityText: 'INFO').toOtlp()];

        final result = await exporter.exportLogs(logs, resource);

        expect(result, isTrue);
      });
    });

    group('retry behavior', () {
      test('should retry on transient failure', () async {
        int attemptCount = 0;

        final mockClient = MockClient((request) async {
          attemptCount++;
          if (attemptCount < 2) {
            return http.Response('{}', 500);
          }
          return http.Response('{}', 200);
        });

        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', client: mockClient, retryDelay: const Duration(milliseconds: 10));

        final spans = [Span(name: 'test').toOtlp()];
        final result = await exporter.exportTraces(spans, resource);

        expect(result, isTrue);
        expect(attemptCount, equals(2));
      });

      test('should not retry on 4xx client error', () async {
        int attemptCount = 0;

        final mockClient = MockClient((request) async {
          attemptCount++;
          return http.Response('{"error": "Bad Request"}', 400);
        });

        final exporter = OTLPHttpExporter(endpoint: 'https://test.com', client: mockClient, retryDelay: const Duration(milliseconds: 10));

        final spans = [Span(name: 'test').toOtlp()];
        final result = await exporter.exportTraces(spans, resource);

        expect(result, isFalse);
        expect(attemptCount, equals(1)); // No retries for 4xx
      });
    });

    group('dispose', () {
      test('should dispose without error', () {
        final exporter = OTLPHttpExporter(endpoint: 'https://test.com');

        expect(exporter.dispose, returnsNormally);
      });
    });
  });
}
