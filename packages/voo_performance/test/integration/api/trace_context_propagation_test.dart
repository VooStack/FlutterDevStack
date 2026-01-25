import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/otel/otel_context_propagator.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_test_utils/voo_test_utils.dart';

void main() {
  group('OtelContextPropagator - Trace Context Propagation', () {
    group('inject traceparent header', () {
      test('should inject traceparent header from span', () {
        final span = SpanFactory.create(name: 'test-operation');
        span.end();

        final headers = OtelContextPropagator.inject(span);

        expect(headers.containsKey('traceparent'), isTrue);
        expect(headers['traceparent'], isNotEmpty);
      });

      test('should format traceparent as 00-traceId-spanId-flags', () {
        final span = SpanFactory.create(name: 'traceparent-format-test');
        span.end();

        final headers = OtelContextPropagator.inject(span);
        final traceparent = headers['traceparent']!;

        // Format: 00-{32char traceId}-{16char spanId}-{2char flags}
        final parts = traceparent.split('-');
        expect(parts.length, equals(4));
        expect(parts[0], equals('00')); // Version
        expect(parts[1].length, equals(32)); // Trace ID
        expect(parts[2].length, equals(16)); // Span ID
        expect(parts[3].length, equals(2)); // Flags
      });

      test('should include trace ID from span', () {
        final span = SpanFactory.create(
          name: 'trace-id-test',
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
        );
        span.end();

        final headers = OtelContextPropagator.inject(span);
        final traceparent = headers['traceparent']!;

        expect(traceparent, contains('a1b2c3d4e5f67890a1b2c3d4e5f67890'));
      });

      test('should include span ID from span', () {
        final span = SpanFactory.create(
          name: 'span-id-test',
          spanId: 'a1b2c3d4e5f67890',
        );
        span.end();

        final headers = OtelContextPropagator.inject(span);
        final traceparent = headers['traceparent']!;

        expect(traceparent, contains('a1b2c3d4e5f67890'));
      });

      test('should preserve existing headers when injecting', () {
        final span = SpanFactory.create(name: 'preserve-headers-test');
        span.end();

        final existingHeaders = {
          'Authorization': 'Bearer token123',
          'Content-Type': 'application/json',
        };

        final headers = OtelContextPropagator.inject(span, existingHeaders);

        expect(headers['Authorization'], equals('Bearer token123'));
        expect(headers['Content-Type'], equals('application/json'));
        expect(headers['traceparent'], isNotEmpty);
      });
    });

    group('inject from SpanContext', () {
      test('should inject traceparent from SpanContext', () {
        final context = SpanContext(
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
          spanId: 'b1c2d3e4f5678901',
          traceFlags: 1,
        );

        final headers = OtelContextPropagator.injectContext(context);

        expect(headers['traceparent'], isNotEmpty);
        expect(
          headers['traceparent'],
          equals('00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01'),
        );
      });

      test('should inject tracestate when present', () {
        final context = SpanContext(
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
          spanId: 'b1c2d3e4f5678901',
          traceFlags: 1,
          traceState: 'vendor1=value1,vendor2=value2',
        );

        final headers = OtelContextPropagator.injectContext(context);

        expect(headers['tracestate'], equals('vendor1=value1,vendor2=value2'));
      });

      test('should not inject tracestate when empty', () {
        final context = SpanContext(
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
          spanId: 'b1c2d3e4f5678901',
          traceFlags: 1,
          traceState: '',
        );

        final headers = OtelContextPropagator.injectContext(context);

        expect(headers.containsKey('tracestate'), isFalse);
      });

      test('should not inject tracestate when null', () {
        final context = SpanContext(
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
          spanId: 'b1c2d3e4f5678901',
          traceFlags: 1,
        );

        final headers = OtelContextPropagator.injectContext(context);

        expect(headers.containsKey('tracestate'), isFalse);
      });
    });

    group('extract trace context', () {
      test('should extract SpanContext from valid traceparent', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        final context = OtelContextPropagator.extract(headers);

        expect(context, isNotNull);
        expect(context!.traceId, equals('a1b2c3d4e5f67890a1b2c3d4e5f67890'));
        expect(context.spanId, equals('b1c2d3e4f5678901'));
        expect(context.traceFlags, equals(1));
      });

      test('should handle lowercase header names', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        final context = OtelContextPropagator.extract(headers);

        expect(context, isNotNull);
        expect(context!.traceId, equals('a1b2c3d4e5f67890a1b2c3d4e5f67890'));
      });

      test('should extract tracestate when present', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
          'tracestate': 'vendor1=value1',
        };

        final context = OtelContextPropagator.extract(headers);

        expect(context, isNotNull);
        expect(context!.traceState, equals('vendor1=value1'));
      });

      test('should return null for missing traceparent', () {
        final headers = <String, String>{
          'Authorization': 'Bearer token',
        };

        final context = OtelContextPropagator.extract(headers);

        expect(context, isNull);
      });

      test('should return null for empty traceparent', () {
        final headers = {
          'traceparent': '',
        };

        final context = OtelContextPropagator.extract(headers);

        expect(context, isNull);
      });

      test('should return null for invalid traceparent format', () {
        final headers = {
          'traceparent': 'invalid-format',
        };

        final context = OtelContextPropagator.extract(headers);

        expect(context, isNull);
      });
    });

    group('extractIds helper', () {
      test('should extract trace and span IDs', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        final ids = OtelContextPropagator.extractIds(headers);

        expect(ids.traceId, equals('a1b2c3d4e5f67890a1b2c3d4e5f67890'));
        expect(ids.spanId, equals('b1c2d3e4f5678901'));
      });

      test('should return null IDs when no trace context', () {
        final headers = <String, String>{};

        final ids = OtelContextPropagator.extractIds(headers);

        expect(ids.traceId, isNull);
        expect(ids.spanId, isNull);
      });
    });

    group('hasTraceContext helper', () {
      test('should return true when valid traceparent present', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        expect(OtelContextPropagator.hasTraceContext(headers), isTrue);
      });

      test('should return false when traceparent missing', () {
        final headers = <String, String>{};

        expect(OtelContextPropagator.hasTraceContext(headers), isFalse);
      });

      test('should return false for invalid traceparent', () {
        final headers = {
          'traceparent': 'invalid',
        };

        expect(OtelContextPropagator.hasTraceContext(headers), isFalse);
      });
    });

    group('createChildContext', () {
      test('should create child context from valid parent headers', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        final childContext = OtelContextPropagator.createChildContext(headers);

        expect(childContext, isNotNull);
        expect(
          childContext!.traceId,
          equals('a1b2c3d4e5f67890a1b2c3d4e5f67890'),
        );
      });

      test('should return null when no trace context in headers', () {
        final headers = <String, String>{};

        final childContext = OtelContextPropagator.createChildContext(headers);

        expect(childContext, isNull);
      });
    });

    group('traceparent format validation', () {
      test('should accept valid version 00', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        final context = OtelContextPropagator.extract(headers);
        expect(context, isNotNull);
      });

      test('should extract trace flags 00 (not sampled)', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-00',
        };

        final context = OtelContextPropagator.extract(headers);
        expect(context!.traceFlags, equals(0));
      });

      test('should extract trace flags 01 (sampled)', () {
        final headers = {
          'traceparent': '00-a1b2c3d4e5f67890a1b2c3d4e5f67890-b1c2d3e4f5678901-01',
        };

        final context = OtelContextPropagator.extract(headers);
        expect(context!.traceFlags, equals(1));
      });
    });

    group('round-trip propagation', () {
      test('should preserve context through inject and extract', () {
        final originalSpan = SpanFactory.create(
          name: 'round-trip-test',
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
          spanId: 'b1c2d3e4f5678901',
        );
        originalSpan.end();

        // Inject into headers
        final headers = OtelContextPropagator.inject(originalSpan);

        // Extract from headers
        final extractedContext = OtelContextPropagator.extract(headers);

        expect(extractedContext, isNotNull);
        expect(extractedContext!.traceId, equals(originalSpan.traceId));
        expect(extractedContext.spanId, equals(originalSpan.spanId));
      });

      test('should preserve tracestate through round-trip', () {
        final context = SpanContext(
          traceId: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
          spanId: 'b1c2d3e4f5678901',
          traceFlags: 1,
          traceState: 'vendorA=valueA,vendorB=valueB',
        );

        // Inject into headers
        final headers = OtelContextPropagator.injectContext(context);

        // Extract from headers
        final extractedContext = OtelContextPropagator.extract(headers);

        expect(extractedContext, isNotNull);
        expect(
          extractedContext!.traceState,
          equals('vendorA=valueA,vendorB=valueB'),
        );
      });
    });
  });
}
