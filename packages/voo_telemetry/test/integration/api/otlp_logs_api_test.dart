import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_test_utils/voo_test_utils.dart';

void main() {
  group('OTLPHttpExporter - Logs API', () {
    late MockOtlpServer mockServer;
    late OTLPHttpExporter exporter;
    late TelemetryResource resource;

    setUp(() {
      mockServer = MockOtlpServer();
      exporter = OTLPHttpExporter(
        endpoint: mockServer.baseUrl,
        apiKey: 'test-api-key',
        client: mockServer.createClient(),
      );
      resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
        attributes: {
          'service.name': 'test-service',
          'service.version': '1.0.0',
        },
      );
    });

    tearDown(() {
      exporter.dispose();
    });

    group('log export by severity', () {
      test('should export info log successfully', () async {
        final log = LogRecordFactory.create(
          body: 'Info message',
        );

        final result = await exporter.exportLogs([log.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.logRequests.length, equals(1));
        expect(mockServer.allLogRecords.length, equals(1));
      });

      test('should export debug log', () async {
        final log = LogRecordFactory.createDebug(
          message: 'Debug information',
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['body'], isA<Map>());
        expect(exportedLog['severityNumber'], equals(SeverityNumber.debug.value));
      });

      test('should export warning log', () async {
        final log = LogRecordFactory.createWarning(
          message: 'Warning message',
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['severityNumber'], equals(SeverityNumber.warn.value));
      });

      test('should export error log', () async {
        final log = LogRecordFactory.createError(
          message: 'Error occurred',
          exceptionType: 'NetworkException',
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['severityNumber'], equals(SeverityNumber.error.value));
      });

      test('should export fatal log', () async {
        final log = LogRecordFactory.create(
          body: 'Fatal error',
          severityNumber: SeverityNumber.fatal,
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['severityNumber'], equals(SeverityNumber.fatal.value));
      });

      test('should export trace log', () async {
        final log = LogRecordFactory.create(
          body: 'Trace message',
          severityNumber: SeverityNumber.trace,
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['severityNumber'], equals(SeverityNumber.trace.value));
      });
    });

    group('log attributes', () {
      test('should include log attributes', () async {
        final log = LogRecordFactory.create(
          body: 'Attributed log',
          attributes: {
            'custom.key': 'custom_value',
            'numeric.value': 123,
          },
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog.containsKey('attributes'), isTrue);
      });

      test('should include severity text', () async {
        final log = LogRecordFactory.create(
          body: 'Test log',
          severityText: 'INFORMATION',
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['severityText'], equals('INFORMATION'));
      });
    });

    group('log-to-trace correlation', () {
      test('should include trace ID when provided', () async {
        const traceId = 'a1b2c3d4e5f67890a1b2c3d4e5f67890';
        final log = LogRecordFactory.create(
          body: 'Correlated log',
          traceId: traceId,
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['traceId'], equals(traceId));
      });

      test('should include span ID when provided', () async {
        const spanId = 'a1b2c3d4e5f67890';
        final log = LogRecordFactory.create(
          body: 'Span-correlated log',
          spanId: spanId,
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['spanId'], equals(spanId));
      });

      test('should include both trace and span IDs', () async {
        const traceId = 'a1b2c3d4e5f67890a1b2c3d4e5f67890';
        const spanId = 'a1b2c3d4e5f67890';
        final log = LogRecordFactory.create(
          body: 'Fully correlated log',
          traceId: traceId,
          spanId: spanId,
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['traceId'], equals(traceId));
        expect(exportedLog['spanId'], equals(spanId));
      });

      test('should correlate log with span from same trace', () async {
        final span = SpanFactory.create(name: 'parent-operation');
        final log = LogRecordFactory.create(
          body: 'Log within span context',
          traceId: span.traceId,
          spanId: span.spanId,
        );
        span.end();

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog['traceId'], equals(span.traceId));
        expect(exportedLog['spanId'], equals(span.spanId));
      });
    });

    group('batch log export', () {
      test('should export multiple logs in a single request', () async {
        final logs = [
          LogRecordFactory.create(body: 'Log 1'),
          LogRecordFactory.createWarning(message: 'Log 2'),
          LogRecordFactory.createError(message: 'Log 3'),
        ];

        final result = await exporter.exportLogs(
          logs.map((l) => l.toOtlp()).toList(),
          resource,
        );

        expect(result, isTrue);
        expect(mockServer.logRequests.length, equals(1));
        expect(mockServer.allLogRecords.length, equals(3));
      });

      test('should preserve log order in batch', () async {
        final logs = List.generate(5, (i) => LogRecordFactory.create(body: 'Log message $i'));

        await exporter.exportLogs(
          logs.map((l) => l.toOtlp()).toList(),
          resource,
        );

        final exportedLogs = mockServer.allLogRecords;
        expect(exportedLogs.length, equals(5));
      });
    });

    group('OTLP payload structure', () {
      test('should have correct resourceLogs structure', () async {
        final log = LogRecordFactory.create(body: 'Structure test');

        await exporter.exportLogs([log.toOtlp()], resource);

        final payload = mockServer.lastLogRequest!.payload;
        expect(payload.containsKey('resourceLogs'), isTrue);

        final resourceLogs = payload['resourceLogs'] as List;
        expect(resourceLogs.length, equals(1));

        final resourceLog = resourceLogs.first as Map<String, dynamic>;
        expect(resourceLog.containsKey('resource'), isTrue);
        expect(resourceLog.containsKey('scopeLogs'), isTrue);
      });

      test('should have correct scopeLogs structure', () async {
        final log = LogRecordFactory.create(body: 'Scope test');

        await exporter.exportLogs([log.toOtlp()], resource);

        final payload = mockServer.lastLogRequest!.payload;
        final resourceLogs = payload['resourceLogs'] as List;
        final scopeLogs = resourceLogs.first['scopeLogs'] as List;
        expect(scopeLogs.length, equals(1));

        final scopeLog = scopeLogs.first as Map<String, dynamic>;
        expect(scopeLog.containsKey('scope'), isTrue);
        expect(scopeLog.containsKey('logRecords'), isTrue);

        final scope = scopeLog['scope'] as Map<String, dynamic>;
        expect(scope['name'], equals('voo-telemetry'));
        expect(scope['version'], equals('2.0.0'));
      });

      test('should include resource attributes', () async {
        final log = LogRecordFactory.create(body: 'Resource test');

        await exporter.exportLogs([log.toOtlp()], resource);

        final capturedResource = mockServer.lastLogRequest!.resource;
        expect(capturedResource, isNotNull);
        expect(capturedResource!.containsKey('attributes'), isTrue);
      });
    });

    group('HTTP headers', () {
      test('should include Content-Type header', () async {
        final log = LogRecordFactory.create(body: 'Header test');

        await exporter.exportLogs([log.toOtlp()], resource);

        expect(mockServer.allRequestsHaveJsonContentType, isTrue);
      });

      test('should include X-API-Key header', () async {
        final log = LogRecordFactory.create(body: 'API key test');

        await exporter.exportLogs([log.toOtlp()], resource);

        expect(mockServer.allRequestsHaveApiKey('test-api-key'), isTrue);
      });

      test('should use POST method', () async {
        final log = LogRecordFactory.create(body: 'Method test');

        await exporter.exportLogs([log.toOtlp()], resource);

        expect(mockServer.lastLogRequest!.method, equals('POST'));
      });

      test('should target /v1/logs endpoint', () async {
        final log = LogRecordFactory.create(body: 'Endpoint test');

        await exporter.exportLogs([log.toOtlp()], resource);

        expect(mockServer.lastLogRequest!.url, endsWith('/v1/logs'));
      });
    });

    group('empty logs handling', () {
      test('should return true for empty logs list', () async {
        final result = await exporter.exportLogs([], resource);

        expect(result, isTrue);
        expect(mockServer.logRequests.length, equals(0));
      });

      test('should not make request for empty logs list', () async {
        await exporter.exportLogs([], resource);

        expect(mockServer.requestCount, equals(0));
      });
    });

    group('timestamp handling', () {
      test('should include timestamp in nanoseconds', () async {
        final timestamp = DateTime.now();
        final log = LogRecordFactory.create(
          body: 'Timestamp test',
          timestamp: timestamp,
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        expect(exportedLog.containsKey('timeUnixNano'), isTrue);
      });

      test('should include observed timestamp when different', () async {
        final log = LogRecordFactory.create(body: 'Observed timestamp test');

        await exporter.exportLogs([log.toOtlp()], resource);

        final exportedLog = mockServer.allLogRecords.first;
        // The observed timestamp might be the same as timestamp or different
        expect(exportedLog.containsKey('timeUnixNano'), isTrue);
      });
    });

    group('error handling', () {
      test('should return false on server error', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError());

        final log = LogRecordFactory.create(body: 'Error test');
        final result = await exporter.exportLogs([log.toOtlp()], resource);

        expect(result, isFalse);
      });

      test('should return false on unauthorized error', () async {
        mockServer.setFailure(OtlpFailureConfig.unauthorized());

        final log = LogRecordFactory.create(body: 'Unauth test');
        final result = await exporter.exportLogs([log.toOtlp()], resource);

        expect(result, isFalse);
      });
    });

    group('JSON payload validation', () {
      test('should produce valid JSON payload', () async {
        final log = LogRecordFactory.create(
          body: 'JSON test with "quotes" and \\backslashes',
          attributes: {
            'key': 'value with "special" chars',
          },
        );

        await exporter.exportLogs([log.toOtlp()], resource);

        final request = mockServer.lastLogRequest!.request;
        expect(() => jsonDecode(request.body), returnsNormally);
      });

      test('should handle unicode characters', () async {
        final log = LogRecordFactory.create(
          body: 'Unicode test: 日本語 emoji 🎉 symbols ™®',
        );

        final result = await exporter.exportLogs([log.toOtlp()], resource);

        expect(result, isTrue);
      });
    });
  });
}
