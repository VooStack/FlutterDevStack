import 'package:voo_telemetry/voo_telemetry.dart';

/// W3C Trace Context propagation for distributed tracing.
///
/// Implements the W3C Trace Context standard for propagating trace
/// information across service boundaries via HTTP headers.
///
/// See: https://www.w3.org/TR/trace-context/
class OtelContextPropagator {
  /// Standard W3C traceparent header name.
  static const String traceparentHeader = 'traceparent';

  /// Standard W3C tracestate header name.
  static const String tracestateHeader = 'tracestate';

  /// Baggage header for propagating key-value pairs.
  static const String baggageHeader = 'baggage';

  /// Inject trace context into outgoing HTTP headers.
  ///
  /// [span] The span whose context should be propagated.
  /// [headers] Optional existing headers to add to.
  /// Returns a new map with trace context headers added.
  static Map<String, String> inject(Span span, [Map<String, String>? headers]) {
    final result = Map<String, String>.from(headers ?? {});
    result[traceparentHeader] = span.context.toTraceparent();
    if (span.context.traceState != null && span.context.traceState!.isNotEmpty) {
      result[tracestateHeader] = span.context.traceState!;
    }
    return result;
  }

  /// Inject trace context from a SpanContext into headers.
  ///
  /// [context] The span context to propagate.
  /// [headers] Optional existing headers to add to.
  static Map<String, String> injectContext(SpanContext context, [Map<String, String>? headers]) {
    final result = Map<String, String>.from(headers ?? {});
    result[traceparentHeader] = context.toTraceparent();
    if (context.traceState != null && context.traceState!.isNotEmpty) {
      result[tracestateHeader] = context.traceState!;
    }
    return result;
  }

  /// Extract trace context from incoming HTTP headers.
  ///
  /// [headers] The HTTP headers to extract from.
  /// Returns a SpanContext if valid traceparent found, null otherwise.
  static SpanContext? extract(Map<String, String> headers) {
    // Try both original case and lowercase
    final traceparent = headers[traceparentHeader] ?? headers[traceparentHeader.toLowerCase()];

    if (traceparent == null || traceparent.isEmpty) {
      return null;
    }

    try {
      final context = SpanContext.fromTraceparent(traceparent);

      // Also extract tracestate if present
      final tracestate = headers[tracestateHeader] ?? headers[tracestateHeader.toLowerCase()];

      if (tracestate != null && tracestate.isNotEmpty) {
        return SpanContext(
          traceId: context.traceId,
          spanId: context.spanId,
          traceFlags: context.traceFlags,
          traceState: tracestate,
        );
      }

      return context;
    } catch (e) {
      // Invalid traceparent format
      return null;
    }
  }

  /// Extract parent trace and span IDs from headers.
  ///
  /// Useful when you need just the IDs without full context.
  static ({String? traceId, String? spanId}) extractIds(Map<String, String> headers) {
    final context = extract(headers);
    if (context == null) {
      return (traceId: null, spanId: null);
    }
    return (traceId: context.traceId, spanId: context.spanId);
  }

  /// Check if headers contain valid trace context.
  static bool hasTraceContext(Map<String, String> headers) {
    return extract(headers) != null;
  }

  /// Create a child span context from parent headers.
  ///
  /// Used when creating a new span that should be a child of
  /// the span represented in the incoming headers.
  static SpanContext? createChildContext(Map<String, String> headers) {
    final parentContext = extract(headers);
    if (parentContext == null) return null;

    // The parent's spanId becomes the parentSpanId for the new span
    // A new spanId will be generated when the span is created
    return parentContext;
  }
}
