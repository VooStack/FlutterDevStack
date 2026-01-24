import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('TraceProvider', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late TraceProvider traceProvider;

    setUp(() {
      resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
      exporter = OTLPHttpExporter(endpoint: 'https://test.com');
      config = TelemetryConfig(endpoint: 'https://test.com');
      traceProvider = TraceProvider(
        resource: resource,
        exporter: exporter,
        config: config,
      );
    });

    group('initialization', () {
      test('should create with required parameters', () {
        expect(traceProvider, isNotNull);
      });

      test('should initialize without error', () async {
        await expectLater(traceProvider.initialize(), completes);
      });
    });

    group('getTracer', () {
      test('should create a new tracer', () {
        final tracer = traceProvider.getTracer('test-tracer');

        expect(tracer, isNotNull);
        expect(tracer.name, equals('test-tracer'));
      });

      test('should return same tracer for same name', () {
        final tracer1 = traceProvider.getTracer('test-tracer');
        final tracer2 = traceProvider.getTracer('test-tracer');

        expect(identical(tracer1, tracer2), isTrue);
      });

      test('should return different tracers for different names', () {
        final tracer1 = traceProvider.getTracer('tracer-1');
        final tracer2 = traceProvider.getTracer('tracer-2');

        expect(identical(tracer1, tracer2), isFalse);
      });
    });

    group('span stack management', () {
      test('should have no active span initially', () {
        expect(traceProvider.activeSpan, isNull);
      });

      test('should push span onto stack', () {
        final span = Span(name: 'test-span');
        traceProvider.pushSpan(span);

        expect(traceProvider.activeSpan, equals(span));
      });

      test('should pop span from stack', () {
        final span = Span(name: 'test-span');
        traceProvider.pushSpan(span);

        final poppedSpan = traceProvider.popSpan();

        expect(poppedSpan, equals(span));
        expect(traceProvider.activeSpan, isNull);
      });

      test('should return null when popping empty stack', () {
        final poppedSpan = traceProvider.popSpan();

        expect(poppedSpan, isNull);
      });

      test('should maintain LIFO order', () {
        final span1 = Span(name: 'span-1');
        final span2 = Span(name: 'span-2');
        final span3 = Span(name: 'span-3');

        traceProvider.pushSpan(span1);
        traceProvider.pushSpan(span2);
        traceProvider.pushSpan(span3);

        expect(traceProvider.activeSpan, equals(span3));
        expect(traceProvider.popSpan(), equals(span3));
        expect(traceProvider.activeSpan, equals(span2));
        expect(traceProvider.popSpan(), equals(span2));
        expect(traceProvider.activeSpan, equals(span1));
      });
    });

    group('addSpan', () {
      test('should add span without error', () {
        final span = Span(name: 'test-span');
        span.end();

        expect(() => traceProvider.addSpan(span), returnsNormally);
      });
    });

    group('flush', () {
      test('should flush without error when no pending spans', () async {
        await expectLater(traceProvider.flush(), completes);
      });

      test('should flush pending spans', () async {
        final span = Span(name: 'test-span');
        span.end();
        traceProvider.addSpan(span);

        await expectLater(traceProvider.flush(), completes);
      });
    });

    group('shutdown', () {
      test('should shutdown without error', () async {
        await expectLater(traceProvider.shutdown(), completes);
      });

      test('should clear span stack on shutdown', () async {
        traceProvider.pushSpan(Span(name: 'test-span'));
        await traceProvider.shutdown();

        expect(traceProvider.activeSpan, isNull);
      });
    });
  });
}
