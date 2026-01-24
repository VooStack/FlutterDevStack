import 'package:voo_telemetry/voo_telemetry.dart';

/// Pre-built telemetry fixtures for testing.
class TelemetryFixtures {
  /// Creates a list of test spans for batch testing.
  static List<Span> createSpanBatch({int count = 5}) {
    return List.generate(
      count,
      (i) => Span(
        name: 'test-span-$i',
        startTime: DateTime.now().subtract(Duration(seconds: count - i)),
      ),
    );
  }

  /// Creates a list of test log records for batch testing.
  static List<LogRecord> createLogBatch({int count = 5}) {
    return List.generate(
      count,
      (i) => LogRecord(
        body: 'Test log message $i',
        severityNumber: SeverityNumber.info,
        severityText: 'INFO',
        timestamp: DateTime.now().subtract(Duration(seconds: count - i)),
      ),
    );
  }

  /// Creates a parent-child span relationship for testing.
  static (Span parent, Span child) createParentChildSpans() {
    final parent = Span(name: 'parent-span', startTime: DateTime.now());
    final child = Span(
      name: 'child-span',
      traceId: parent.traceId,
      parentSpanId: parent.spanId,
      startTime: DateTime.now(),
    );
    return (parent, child);
  }

  /// Creates a completed span for testing.
  static Span createCompletedSpan({
    String name = 'completed-span',
    Duration duration = const Duration(milliseconds: 100),
  }) {
    final startTime = DateTime.now().subtract(duration);
    final span = Span(name: name, startTime: startTime);
    span.end(DateTime.now());
    return span;
  }

  /// Creates a span with an error status for testing.
  static Span createErrorSpan({
    String name = 'error-span',
    String errorMessage = 'Test error occurred',
  }) {
    final span = Span(name: name, startTime: DateTime.now());
    span.recordException(Exception(errorMessage), StackTrace.current);
    span.end();
    return span;
  }

  /// Creates a span with events for testing.
  static Span createSpanWithEvents({int eventCount = 3}) {
    final span = Span(name: 'span-with-events', startTime: DateTime.now());
    for (int i = 0; i < eventCount; i++) {
      span.addEvent('event-$i', attributes: {'index': i});
    }
    return span;
  }

  /// A sample OTLP resource for testing.
  static Map<String, dynamic> sampleOtlpResource() {
    return {
      'attributes': [
        {'key': 'service.name', 'value': {'stringValue': 'test-service'}},
        {'key': 'service.version', 'value': {'stringValue': '1.0.0'}},
        {'key': 'telemetry.sdk.name', 'value': {'stringValue': 'voo_telemetry'}},
        {'key': 'telemetry.sdk.language', 'value': {'stringValue': 'dart'}},
      ],
    };
  }

  /// A sample OTLP scope for testing.
  static Map<String, dynamic> sampleOtlpScope() {
    return {
      'name': 'test-instrumentation',
      'version': '1.0.0',
    };
  }
}
