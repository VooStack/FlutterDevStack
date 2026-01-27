import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_test_utils/voo_test_utils.dart';

void main() {
  group('OTLPHttpExporter - Traces API', () {
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
          'deployment.environment': 'test',
        },
      );
    });

    tearDown(() {
      exporter.dispose();
    });

    group('single span export', () {
      test('should export a single span successfully', () async {
        final span = SpanFactory.create(name: 'test-operation');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.traceRequests.length, equals(1));
        expect(mockServer.allSpans.length, equals(1));
      });

      test('should include span attributes in payload', () async {
        final span = SpanFactory.create(name: 'attributed-span');
        span.setAttribute('custom.attribute', 'test-value');
        span.setAttribute('numeric.attribute', 42);
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final exportedSpan = mockServer.allSpans.first;
        expect(exportedSpan['name'], equals('attributed-span'));
        expect(exportedSpan['attributes'], isA<List>());
      });

      test('should include span events in payload', () async {
        final span = SpanFactory.create(name: 'span-with-events');
        span.addEvent('test-event', attributes: {'event.data': 'value'});
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final exportedSpan = mockServer.allSpans.first;
        expect(exportedSpan['events'], isA<List>());
        expect((exportedSpan['events'] as List).length, equals(1));
      });
    });

    group('batch span export', () {
      test('should export multiple spans in a single request', () async {
        final spans = List.generate(5, (i) {
          final span = SpanFactory.create(name: 'batch-span-$i');
          span.end();
          return span.toOtlp();
        });

        final result = await exporter.exportTraces(spans, resource);

        expect(result, isTrue);
        expect(mockServer.traceRequests.length, equals(1));
        expect(mockServer.allSpans.length, equals(5));
      });

      test('should preserve span order in batch', () async {
        final spans = List.generate(3, (i) {
          final span = SpanFactory.create(name: 'ordered-span-$i');
          span.end();
          return span.toOtlp();
        });

        await exporter.exportTraces(spans, resource);

        final exportedSpans = mockServer.allSpans;
        expect(exportedSpans[0]['name'], equals('ordered-span-0'));
        expect(exportedSpans[1]['name'], equals('ordered-span-1'));
        expect(exportedSpans[2]['name'], equals('ordered-span-2'));
      });
    });

    group('OTLP payload structure', () {
      test('should have correct resourceSpans structure', () async {
        final span = SpanFactory.create(name: 'structure-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final payload = mockServer.lastTraceRequest!.payload;
        expect(payload.containsKey('resourceSpans'), isTrue);

        final resourceSpans = payload['resourceSpans'] as List;
        expect(resourceSpans.length, equals(1));

        final resourceSpan = resourceSpans.first as Map<String, dynamic>;
        expect(resourceSpan.containsKey('resource'), isTrue);
        expect(resourceSpan.containsKey('scopeSpans'), isTrue);
      });

      test('should have correct scopeSpans structure', () async {
        final span = SpanFactory.create(name: 'scope-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final payload = mockServer.lastTraceRequest!.payload;
        final resourceSpans = payload['resourceSpans'] as List;
        final scopeSpans =
            resourceSpans.first['scopeSpans'] as List;
        expect(scopeSpans.length, equals(1));

        final scopeSpan = scopeSpans.first as Map<String, dynamic>;
        expect(scopeSpan.containsKey('scope'), isTrue);
        expect(scopeSpan.containsKey('spans'), isTrue);

        final scope = scopeSpan['scope'] as Map<String, dynamic>;
        expect(scope['name'], equals('voo-telemetry'));
        expect(scope['version'], equals('2.0.0'));
      });

      test('should include resource attributes', () async {
        final span = SpanFactory.create(name: 'resource-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final capturedResource = mockServer.lastTraceRequest!.resource;
        expect(capturedResource, isNotNull);
        expect(capturedResource!.containsKey('attributes'), isTrue);
      });
    });

    group('HTTP headers', () {
      test('should include Content-Type header', () async {
        final span = SpanFactory.create(name: 'header-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        expect(mockServer.allRequestsHaveJsonContentType, isTrue);
      });

      test('should include X-API-Key header when configured', () async {
        final span = SpanFactory.create(name: 'api-key-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        expect(mockServer.allRequestsHaveApiKey('test-api-key'), isTrue);
      });

      test('should not include X-API-Key header when not configured', () async {
        final exporterNoKey = OTLPHttpExporter(
          endpoint: mockServer.baseUrl,
          client: mockServer.createClient(),
        );

        final span = SpanFactory.create(name: 'no-key-test');
        span.end();

        await exporterNoKey.exportTraces([span.toOtlp()], resource);

        final request = mockServer.lastTraceRequest!.request;
        expect(request.headers.containsKey('x-api-key'), isFalse);

        exporterNoKey.dispose();
      });

      test('should use POST method', () async {
        final span = SpanFactory.create(name: 'method-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        expect(mockServer.lastTraceRequest!.method, equals('POST'));
      });

      test('should target /v1/traces endpoint', () async {
        final span = SpanFactory.create(name: 'endpoint-test');
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        expect(mockServer.lastTraceRequest!.url, endsWith('/v1/traces'));
      });
    });

    group('empty spans handling', () {
      test('should return true for empty spans list', () async {
        final result = await exporter.exportTraces([], resource);

        expect(result, isTrue);
        expect(mockServer.traceRequests.length, equals(0));
      });

      test('should not make request for empty spans list', () async {
        await exporter.exportTraces([], resource);

        expect(mockServer.requestCount, equals(0));
      });
    });

    group('span types', () {
      test('should export internal span', () async {
        final span = SpanFactory.create(
          name: 'internal-span',
        );
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final exportedSpan = mockServer.allSpans.first;
        expect(exportedSpan['kind'], equals(1)); // INTERNAL = 1
      });

      test('should export server span', () async {
        final span = SpanFactory.create(
          name: 'server-span',
          kind: SpanKind.server,
        );
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final exportedSpan = mockServer.allSpans.first;
        expect(exportedSpan['kind'], equals(2)); // SERVER = 2
      });

      test('should export client span', () async {
        final span = SpanFactory.create(
          name: 'client-span',
          kind: SpanKind.client,
        );
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final exportedSpan = mockServer.allSpans.first;
        expect(exportedSpan['kind'], equals(3)); // CLIENT = 3
      });
    });

    group('span timing', () {
      test('should include start and end timestamps', () async {
        final startTime = DateTime.now();
        final span = SpanFactory.create(
          name: 'timed-span',
          startTime: startTime,
        );
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final exportedSpan = mockServer.allSpans.first;
        expect(exportedSpan.containsKey('startTimeUnixNano'), isTrue);
        expect(exportedSpan.containsKey('endTimeUnixNano'), isTrue);
      });
    });

    group('span relationships', () {
      test('should include parent span ID when present', () async {
        final parentSpan = SpanFactory.create(name: 'parent-span');
        final childSpan = SpanFactory.create(
          name: 'child-span',
          parentSpanId: parentSpan.spanId,
          traceId: parentSpan.traceId,
        );
        parentSpan.end();
        childSpan.end();

        await exporter.exportTraces(
          [parentSpan.toOtlp(), childSpan.toOtlp()],
          resource,
        );

        final exportedSpans = mockServer.allSpans;
        final childExported =
            exportedSpans.firstWhere((s) => s['name'] == 'child-span');
        expect(childExported['parentSpanId'], isNotEmpty);
        expect(childExported['traceId'], equals(parentSpan.traceId));
      });
    });

    group('error handling', () {
      test('should return false on server error', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError());

        final span = SpanFactory.create(name: 'error-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
      });

      test('should return false on unauthorized error', () async {
        mockServer.setFailure(OtlpFailureConfig.unauthorized());

        final span = SpanFactory.create(name: 'unauth-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
      });

      test('should return false on bad request error', () async {
        mockServer.setFailure(OtlpFailureConfig.clientError());

        final span = SpanFactory.create(name: 'bad-request-test');
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isFalse);
      });
    });

    group('JSON payload validation', () {
      test('should produce valid JSON payload', () async {
        final span = SpanFactory.create(name: 'json-test');
        span.setAttribute('string', 'value');
        span.setAttribute('number', 123);
        span.setAttribute('boolean', true);
        span.end();

        await exporter.exportTraces([span.toOtlp()], resource);

        final request = mockServer.lastTraceRequest!.request;
        expect(() => jsonDecode(request.body), returnsNormally);
      });

      test('should handle special characters in span names', () async {
        final span = SpanFactory.create(
          name: 'span with "quotes" and \\backslashes',
        );
        span.end();

        final result = await exporter.exportTraces([span.toOtlp()], resource);

        expect(result, isTrue);
        final exportedSpan = mockServer.allSpans.first;
        expect(
          exportedSpan['name'],
          equals('span with "quotes" and \\backslashes'),
        );
      });
    });
  });
}
