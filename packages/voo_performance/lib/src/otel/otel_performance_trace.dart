import 'package:voo_telemetry/voo_telemetry.dart';
import '../domain/entities/performance_trace.dart';

/// Adapter that wraps a voo_telemetry Span while maintaining
/// backward compatibility with PerformanceTrace API.
///
/// This allows existing code using PerformanceTrace to seamlessly
/// integrate with OpenTelemetry tracing infrastructure.
class OtelPerformanceTrace extends PerformanceTrace {
  final Span _otelSpan;
  final SpanKind _kind;

  OtelPerformanceTrace._({
    required super.name,
    required super.startTime,
    required Span otelSpan,
    SpanKind kind = SpanKind.internal,
  })  : _otelSpan = otelSpan,
        _kind = kind;

  /// Create a new OTEL-backed performance trace.
  ///
  /// [tracer] The OTEL Tracer to create spans with.
  /// [name] The name of the trace/span.
  /// [kind] The span kind (internal, client, server, etc.).
  /// [attributes] Initial attributes to set on the span.
  /// [parentTraceId] Optional parent trace ID for distributed tracing.
  /// [parentSpanId] Optional parent span ID for span hierarchy.
  factory OtelPerformanceTrace.create({
    required Tracer tracer,
    required String name,
    SpanKind kind = SpanKind.internal,
    Map<String, dynamic>? attributes,
    String? parentTraceId,
    String? parentSpanId,
  }) {
    final span = tracer.startSpan(
      name,
      kind: kind,
    );

    // Set initial attributes if provided
    if (attributes != null) {
      span.setAttributes(attributes);
    }

    return OtelPerformanceTrace._(
      name: name,
      startTime: span.startTime,
      otelSpan: span,
      kind: kind,
    );
  }

  /// Create from an existing OTEL Span.
  factory OtelPerformanceTrace.fromSpan(Span span) {
    return OtelPerformanceTrace._(
      name: span.name,
      startTime: span.startTime,
      otelSpan: span,
      kind: span.kind,
    );
  }

  /// Get the underlying OTEL Span.
  Span get otelSpan => _otelSpan;

  /// Get the span kind.
  SpanKind get kind => _kind;

  /// Get W3C traceparent header value for distributed tracing.
  String get traceparent => _otelSpan.context.toTraceparent();

  /// Get trace ID for correlation.
  String get traceId => _otelSpan.traceId;

  /// Get span ID for parent-child relationships.
  String get spanId => _otelSpan.spanId;

  /// Get the span context for propagation.
  SpanContext get spanContext => _otelSpan.context;

  /// Check if the trace is sampled.
  bool get isSampled => _otelSpan.context.isSampled;

  @override
  void putAttribute(String key, String value) {
    super.putAttribute(key, value);
    _otelSpan.setAttribute(key, value);
  }

  @override
  void putMetric(String key, int value) {
    super.putMetric(key, value);
    _otelSpan.setAttribute(key, value);
  }

  @override
  void incrementMetric(String key, [int value = 1]) {
    super.incrementMetric(key, value);
    _otelSpan.setAttribute(key, metrics[key] ?? value);
  }

  @override
  void stop() {
    super.stop();
    _otelSpan.end();
  }

  /// Add an event to the span.
  void addEvent(String name, {Map<String, dynamic>? attributes}) {
    _otelSpan.addEvent(name, attributes: attributes);
  }

  /// Record an exception on the span.
  void recordException(dynamic exception, StackTrace? stackTrace) {
    _otelSpan.recordException(exception, stackTrace);
  }

  /// Set the span status to OK.
  void setStatusOk() {
    _otelSpan.status = SpanStatus.ok();
  }

  /// Set the span status to error with optional description.
  void setStatusError({String? description}) {
    _otelSpan.status = SpanStatus.error(description: description);
  }

  /// Add a link to another span (for async relationships).
  void addLink(String traceId, String spanId, {Map<String, dynamic>? attributes}) {
    _otelSpan.links.add(SpanLink(
      traceId: traceId,
      spanId: spanId,
      attributes: attributes ?? {},
    ));
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'trace_id': traceId,
      'span_id': spanId,
      'traceparent': traceparent,
      'kind': _kind.name,
      'is_sampled': isSampled,
    };
  }
}
