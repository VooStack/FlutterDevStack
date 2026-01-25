import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_test_utils/voo_test_utils.dart';

void main() {
  group('OTLPHttpExporter - Metrics API', () {
    late MockOtlpServer mockServer;
    late OTLPHttpExporter exporter;
    late TelemetryResource resource;

    setUp(() {
      mockServer = MockOtlpServer();
      exporter = OTLPHttpExporter(endpoint: mockServer.baseUrl, apiKey: 'test-api-key', client: mockServer.createClient());
      resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
        attributes: {'service.name': 'test-service', 'service.version': '1.0.0'},
      );
    });

    tearDown(() {
      exporter.dispose();
    });

    group('counter metric export', () {
      test('should export counter metric successfully', () async {
        final counter = MetricFactory.createCounter(value: 42);

        final result = await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.metricRequests.length, equals(1));
        expect(mockServer.allMetrics.length, equals(1));
      });

      test('should include counter attributes', () async {
        final counter = MetricFactory.createCounter(name: 'attributed.counter', value: 10, attributes: {'environment': 'test', 'version': '1.0'});

        await exporter.exportMetrics([counter.toOtlp()], resource);

        final exportedMetric = mockServer.allMetrics.first;
        expect(exportedMetric['name'], equals('attributed.counter'));
      });

      test('should export counter with unit', () async {
        final counter = MetricFactory.createCounter(name: 'bytes.sent', value: 1024, unit: 'bytes');

        await exporter.exportMetrics([counter.toOtlp()], resource);

        final exportedMetric = mockServer.allMetrics.first;
        expect(exportedMetric['unit'], equals('bytes'));
      });
    });

    group('gauge metric export', () {
      test('should export gauge metric successfully', () async {
        final gauge = MetricFactory.createGauge(value: 75.5);

        final result = await exporter.exportMetrics([gauge.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.allMetrics.length, equals(1));
      });

      test('should export gauge with integer value', () async {
        final gauge = MetricFactory.createGauge(name: 'active.connections', value: 100);

        await exporter.exportMetrics([gauge.toOtlp()], resource);

        final exportedMetric = mockServer.allMetrics.first;
        expect(exportedMetric['name'], equals('active.connections'));
      });

      test('should export gauge with negative value', () async {
        final gauge = MetricFactory.createGauge(name: 'temperature', value: -10.5, unit: 'celsius');

        await exporter.exportMetrics([gauge.toOtlp()], resource);

        expect(mockServer.allMetrics.length, equals(1));
      });
    });

    group('histogram metric export', () {
      test('should export histogram metric successfully', () async {
        final histogram = MetricFactory.createHistogram(name: 'request.duration', values: [10.0, 20.0, 30.0, 15.0, 25.0]);

        final result = await exporter.exportMetrics([histogram.toOtlp()], resource);

        expect(result, isTrue);
        expect(mockServer.allMetrics.length, equals(1));
      });

      test('should export histogram with various values', () async {
        final histogram = MetricFactory.createHistogram(name: 'latency.ms', values: [5.0, 15.0, 50.0, 100.0, 250.0]);

        await exporter.exportMetrics([histogram.toOtlp()], resource);

        final exportedMetric = mockServer.allMetrics.first;
        expect(exportedMetric['name'], equals('latency.ms'));
      });

      test('should export histogram with unit', () async {
        final histogram = MetricFactory.createHistogram(name: 'response.size', values: [100.0, 200.0, 500.0], unit: 'bytes');

        await exporter.exportMetrics([histogram.toOtlp()], resource);

        final exportedMetric = mockServer.allMetrics.first;
        expect(exportedMetric['unit'], equals('bytes'));
      });
    });

    group('batch metric export', () {
      test('should export multiple metrics in a single request', () async {
        final metrics = [
          MetricFactory.createCounter(name: 'counter.1', value: 10),
          MetricFactory.createGauge(name: 'gauge.1', value: 50.0),
          MetricFactory.createHistogram(name: 'histogram.1', values: [1.0, 2.0]),
        ];

        final result = await exporter.exportMetrics(metrics.map((m) => m.toOtlp()).toList(), resource);

        expect(result, isTrue);
        expect(mockServer.metricRequests.length, equals(1));
        expect(mockServer.allMetrics.length, equals(3));
      });

      test('should preserve metric order in batch', () async {
        final metrics = List.generate(5, (i) => MetricFactory.createCounter(name: 'metric.$i', value: i * 10));

        await exporter.exportMetrics(metrics.map((m) => m.toOtlp()).toList(), resource);

        final exportedMetrics = mockServer.allMetrics;
        for (var i = 0; i < 5; i++) {
          expect(exportedMetrics[i]['name'], equals('metric.$i'));
        }
      });
    });

    group('OTLP payload structure', () {
      test('should have correct resourceMetrics structure', () async {
        final counter = MetricFactory.createCounter(name: 'structure.test');

        await exporter.exportMetrics([counter.toOtlp()], resource);

        final payload = mockServer.lastMetricRequest!.payload;
        expect(payload.containsKey('resourceMetrics'), isTrue);

        final resourceMetrics = payload['resourceMetrics'] as List;
        expect(resourceMetrics.length, equals(1));

        final resourceMetric = resourceMetrics.first as Map<String, dynamic>;
        expect(resourceMetric.containsKey('resource'), isTrue);
        expect(resourceMetric.containsKey('scopeMetrics'), isTrue);
      });

      test('should have correct scopeMetrics structure', () async {
        final gauge = MetricFactory.createGauge(name: 'scope.test', value: 42.0);

        await exporter.exportMetrics([gauge.toOtlp()], resource);

        final payload = mockServer.lastMetricRequest!.payload;
        final resourceMetrics = payload['resourceMetrics'] as List;
        final scopeMetrics = resourceMetrics.first['scopeMetrics'] as List;
        expect(scopeMetrics.length, equals(1));

        final scopeMetric = scopeMetrics.first as Map<String, dynamic>;
        expect(scopeMetric.containsKey('scope'), isTrue);
        expect(scopeMetric.containsKey('metrics'), isTrue);

        final scope = scopeMetric['scope'] as Map<String, dynamic>;
        expect(scope['name'], equals('voo-telemetry'));
        expect(scope['version'], equals('2.0.0'));
      });

      test('should include resource attributes', () async {
        final counter = MetricFactory.createCounter(name: 'resource.attr.test', value: 5);

        await exporter.exportMetrics([counter.toOtlp()], resource);

        final capturedResource = mockServer.lastMetricRequest!.resource;
        expect(capturedResource, isNotNull);
        expect(capturedResource!.containsKey('attributes'), isTrue);
      });
    });

    group('HTTP headers', () {
      test('should include Content-Type header', () async {
        final counter = MetricFactory.createCounter(name: 'header.test');

        await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(mockServer.allRequestsHaveJsonContentType, isTrue);
      });

      test('should include X-API-Key header', () async {
        final counter = MetricFactory.createCounter(name: 'api.key.test');

        await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(mockServer.allRequestsHaveApiKey('test-api-key'), isTrue);
      });

      test('should use POST method', () async {
        final counter = MetricFactory.createCounter(name: 'method.test');

        await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(mockServer.lastMetricRequest!.method, equals('POST'));
      });

      test('should target /v1/metrics endpoint', () async {
        final counter = MetricFactory.createCounter(name: 'endpoint.test');

        await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(mockServer.lastMetricRequest!.url, endsWith('/v1/metrics'));
      });
    });

    group('empty metrics handling', () {
      test('should return true for empty metrics list', () async {
        final result = await exporter.exportMetrics([], resource);

        expect(result, isTrue);
        expect(mockServer.metricRequests.length, equals(0));
      });

      test('should not make request for empty metrics list', () async {
        await exporter.exportMetrics([], resource);

        expect(mockServer.requestCount, equals(0));
      });
    });

    group('error handling', () {
      test('should return false on server error', () async {
        mockServer.setFailure(OtlpFailureConfig.serverError());

        final counter = MetricFactory.createCounter(name: 'error.test');
        final result = await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(result, isFalse);
      });

      test('should return false on unauthorized error', () async {
        mockServer.setFailure(OtlpFailureConfig.unauthorized());

        final counter = MetricFactory.createCounter(name: 'unauth.test');
        final result = await exporter.exportMetrics([counter.toOtlp()], resource);

        expect(result, isFalse);
      });
    });

    group('JSON payload validation', () {
      test('should produce valid JSON payload', () async {
        final counter = MetricFactory.createCounter(name: 'json.test', value: 100, attributes: {'key': 'value'});

        await exporter.exportMetrics([counter.toOtlp()], resource);

        final request = mockServer.lastMetricRequest!.request;
        expect(() => jsonDecode(request.body), returnsNormally);
      });
    });
  });
}
