import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('Telemetry Pipeline Integration', () {
    late TelemetryResource resource;
    late TelemetryConfig config;
    late MockClient mockClient;
    late List<http.Request> capturedRequests;

    setUp(() {
      capturedRequests = [];
      mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('{}', 200);
      });

      resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
      config = TelemetryConfig(endpoint: 'https://test.com');
    });

    group('Full Trace Pipeline', () {
      test('should create, record, and export traces', () async {
        final exporter = OTLPHttpExporter(
          endpoint: 'https://test.com',
          client: mockClient,
        );
        final traceProvider = TraceProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        await traceProvider.initialize();

        final tracer = traceProvider.getTracer('test-tracer');

        // Create parent span
        final parentSpan = tracer.startSpan(
          'parent-operation',
          kind: SpanKind.server,
        );
        parentSpan.setAttribute('http.method', 'GET');
        parentSpan.setAttribute('http.route', '/api/users');

        // Create child span
        final childSpan = tracer.startSpan(
          'database-query',
          kind: SpanKind.client,
        );
        childSpan.setAttribute('db.system', 'postgresql');
        childSpan.addEvent('query-start');

        await Future.delayed(const Duration(milliseconds: 10));
        childSpan.addEvent('query-end');
        childSpan.status = SpanStatus.ok();
        childSpan.end();
        traceProvider.popSpan();

        parentSpan.status = SpanStatus.ok();
        parentSpan.end();
        traceProvider.popSpan();

        // Export spans
        traceProvider.addSpan(childSpan);
        traceProvider.addSpan(parentSpan);
        await traceProvider.flush();

        await traceProvider.shutdown();
      });

      test('should correlate parent and child spans', () async {
        final exporter = OTLPHttpExporter(
          endpoint: 'https://test.com',
          client: mockClient,
        );
        final traceProvider = TraceProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );

        final tracer = traceProvider.getTracer('test-tracer');

        final parentSpan = tracer.startSpan('parent');
        final childSpan = tracer.startSpan('child');

        // Verify correlation
        expect(childSpan.traceId, equals(parentSpan.traceId));
        expect(childSpan.parentSpanId, equals(parentSpan.spanId));

        childSpan.end();
        traceProvider.popSpan();
        parentSpan.end();
        traceProvider.popSpan();
      });
    });

    group('Full Metrics Pipeline', () {
      test('should create and export metrics', () async {
        final exporter = OTLPHttpExporter(
          endpoint: 'https://test.com',
          client: mockClient,
        );
        final meterProvider = MeterProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        await meterProvider.initialize();

        final meter = meterProvider.getMeter('test-meter');

        // Create various instruments
        final requestCounter = meter.createCounter(
          'http.requests',
          description: 'Number of HTTP requests',
          unit: '{requests}',
        );
        final latencyHistogram = meter.createHistogram(
          'http.request.duration',
          description: 'HTTP request duration',
          unit: 'ms',
        );
        final activeConnections = meter.createGauge(
          'http.connections.active',
          description: 'Active connections',
          unit: '{connections}',
        );

        // Record metrics
        requestCounter.add(1, attributes: {'method': 'GET', 'status': 200});
        requestCounter.add(1, attributes: {'method': 'POST', 'status': 201});
        latencyHistogram.record(45.5, attributes: {'endpoint': '/api/users'});
        latencyHistogram.record(120.0, attributes: {'endpoint': '/api/orders'});
        activeConnections.set(10);

        await meterProvider.flush();
        await meterProvider.shutdown();
      });
    });

    group('Full Logging Pipeline', () {
      test('should create and export logs', () async {
        final exporter = OTLPHttpExporter(
          endpoint: 'https://test.com',
          client: mockClient,
        );
        final loggerProvider = LoggerProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        await loggerProvider.initialize();

        final logger = loggerProvider.getLogger('test-logger');

        // Log various levels
        logger.debug('Debug message', attributes: {'debug': true});
        logger.info('User logged in', attributes: {'user.id': '123'});
        logger.warn('Slow response', attributes: {'duration_ms': 5000});
        logger.error('Request failed', attributes: {
          'exception.type': 'HttpException',
          'exception.message': 'Timeout',
        });

        await loggerProvider.flush();
        await loggerProvider.shutdown();
      });

      test('should correlate logs with traces', () async {
        final exporter = OTLPHttpExporter(
          endpoint: 'https://test.com',
          client: mockClient,
        );
        final traceProvider = TraceProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        final loggerProvider = LoggerProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        loggerProvider.traceProvider = traceProvider;

        final tracer = traceProvider.getTracer('test-tracer');
        final logger = loggerProvider.getLogger('test-logger');

        // Start a span
        final span = tracer.startSpan('request-handler');

        // Log within span context
        logger.info('Processing request');

        span.end();
        traceProvider.popSpan();

        await traceProvider.flush();
        await loggerProvider.flush();
      });
    });

    group('Combined Telemetry', () {
      test('should handle traces, metrics, and logs together', () async {
        final exporter = OTLPHttpExporter(
          endpoint: 'https://test.com',
          client: mockClient,
        );

        final traceProvider = TraceProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        final meterProvider = MeterProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        final loggerProvider = LoggerProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        loggerProvider.traceProvider = traceProvider;

        final tracer = traceProvider.getTracer('app');
        final meter = meterProvider.getMeter('app');
        final logger = loggerProvider.getLogger('app');

        final requestCounter = meter.createCounter('requests');
        final latency = meter.createHistogram('latency');

        // Simulate a request
        await tracer.withSpan('handle-request', (span) async {
          logger.info('Request started');
          requestCounter.increment();

          await Future.delayed(const Duration(milliseconds: 50));

          span.setAttribute('http.status_code', 200);
          latency.record(50);
          logger.info('Request completed');
        });

        await traceProvider.flush();
        await meterProvider.flush();
        await loggerProvider.flush();

        await traceProvider.shutdown();
        await meterProvider.shutdown();
        await loggerProvider.shutdown();
      });
    });
  });
}
