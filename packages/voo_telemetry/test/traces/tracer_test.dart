import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('Tracer', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late TraceProvider traceProvider;
    late Tracer tracer;

    setUp(() {
      resource = TelemetryResource(serviceName: 'test-service', serviceVersion: '1.0.0');
      exporter = OTLPHttpExporter(endpoint: 'https://test.com');
      config = TelemetryConfig(endpoint: 'https://test.com');
      traceProvider = TraceProvider(resource: resource, exporter: exporter, config: config);
      tracer = traceProvider.getTracer('test-tracer');
    });

    group('startSpan', () {
      test('should create span with name', () {
        final span = tracer.startSpan('test-span');

        expect(span, isNotNull);
        expect(span.name, equals('test-span'));
        expect(span.isRecording, isTrue);

        span.end();
        traceProvider.popSpan();
      });

      test('should create span with kind', () {
        final span = tracer.startSpan('client-span', kind: SpanKind.client);

        expect(span.kind, equals(SpanKind.client));

        span.end();
        traceProvider.popSpan();
      });

      test('should create span with attributes', () {
        final span = tracer.startSpan('span-with-attrs', attributes: {'key': 'value', 'count': 42});

        expect(span.attributes['key'], equals('value'));
        expect(span.attributes['count'], equals(42));

        span.end();
        traceProvider.popSpan();
      });

      test('should create span with links', () {
        final link = SpanLink(traceId: 'abc123', spanId: 'def456', attributes: {'link.type': 'follows_from'});
        final span = tracer.startSpan('span-with-links', links: [link]);

        expect(span.links.length, equals(1));
        expect(span.links.first.traceId, equals('abc123'));

        span.end();
        traceProvider.popSpan();
      });

      test('should inherit traceId from parent span', () {
        final parentSpan = tracer.startSpan('parent-span');
        final childSpan = tracer.startSpan('child-span');

        expect(childSpan.traceId, equals(parentSpan.traceId));
        expect(childSpan.parentSpanId, equals(parentSpan.spanId));

        childSpan.end();
        traceProvider.popSpan();
        parentSpan.end();
        traceProvider.popSpan();
      });

      test('should push span onto stack', () {
        final span = tracer.startSpan('test-span');

        expect(traceProvider.activeSpan, equals(span));

        span.end();
        traceProvider.popSpan();
      });
    });

    group('withSpan', () {
      test('should execute function and set ok status on success', () async {
        String? result;

        result = await tracer.withSpan<String>('async-span', (span) async => 'success');

        expect(result, equals('success'));
      });

      test('should set error status and rethrow on exception', () async {
        expect(
          () => tracer.withSpan<String>('error-span', (span) async {
            throw Exception('test error');
          }),
          throwsException,
        );
      });

      test('should end span after execution', () async {
        Span? capturedSpan;

        await tracer.withSpan<void>('test-span', (span) async {
          capturedSpan = span;
        });

        expect(capturedSpan!.isRecording, isFalse);
      });

      test('should restore parent span after execution', () async {
        final parentSpan = tracer.startSpan('parent');

        await tracer.withSpan<void>('child', (span) async {
          expect(traceProvider.activeSpan, equals(span));
        });

        expect(traceProvider.activeSpan, equals(parentSpan));

        parentSpan.end();
        traceProvider.popSpan();
      });
    });

    group('withSpanSync', () {
      test('should execute function and set ok status on success', () {
        final result = tracer.withSpanSync<String>('sync-span', (span) => 'success');

        expect(result, equals('success'));
      });

      test('should set error status and rethrow on exception', () {
        expect(
          () => tracer.withSpanSync<String>('error-span', (span) {
            throw Exception('test error');
          }),
          throwsException,
        );
      });

      test('should end span after execution', () {
        Span? capturedSpan;

        tracer.withSpanSync<void>('test-span', (span) {
          capturedSpan = span;
        });

        expect(capturedSpan!.isRecording, isFalse);
      });

      test('should include attributes in span', () {
        Span? capturedSpan;

        tracer.withSpanSync<void>('test-span', (span) {
          capturedSpan = span;
        }, attributes: {'test.attr': 'value'});

        expect(capturedSpan!.attributes['test.attr'], equals('value'));
      });
    });
  });
}
