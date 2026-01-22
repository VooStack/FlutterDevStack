import 'package:voo_logging/features/logging/domain/entities/log_entry.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_logging/src/otel/log_level_otel_extension.dart';
import 'package:voo_logging/src/otel/trace_context_provider.dart';

/// Adapts VooLogger LogEntry to OpenTelemetry LogRecord.
///
/// This adapter transforms the local log format to the OTEL standard
/// for export via OTLP protocol.
class OtelLogAdapter {
  /// Convert a LogEntry to an OTEL LogRecord.
  ///
  /// [entry] The VooLogger log entry to convert.
  /// [traceId] Optional trace ID for correlation with spans.
  /// [spanId] Optional span ID for correlation with spans.
  /// [traceFlags] Trace flags (default 0, set to 1 if sampled).
  static LogRecord toLogRecord(
    LogEntry entry, {
    String? traceId,
    String? spanId,
    int traceFlags = 0,
  }) {
    final observedTime = DateTime.now();

    // Build attributes from LogEntry fields
    final attributes = <String, dynamic>{
      // Log context attributes
      if (entry.category != null) 'log.category': entry.category,
      if (entry.tag != null) 'log.tag': entry.tag,
      if (entry.context != null) 'log.context': entry.context,

      // User/session attributes
      if (entry.userId != null) 'user.id': entry.userId,
      if (entry.sessionId != null) 'session.id': entry.sessionId,

      // Device/app attributes
      if (entry.appVersion != null) 'app.version': entry.appVersion,
      if (entry.deviceId != null) 'device.id': entry.deviceId,

      // Exception attributes (if error is present)
      if (entry.error != null) 'exception.type': entry.error.runtimeType.toString(),
      if (entry.error != null) 'exception.message': entry.error.toString(),
      if (entry.stackTrace != null) 'exception.stacktrace': entry.stackTrace,

      // Flatten metadata into attributes
      ...?entry.metadata,
    };

    return LogRecord(
      timestamp: entry.timestamp,
      observedTimestamp: observedTime,
      severityNumber: entry.level.otelSeverityNumber,
      severityText: entry.level.otelSeverityText,
      body: entry.message,
      attributes: attributes,
      traceId: traceId,
      spanId: spanId,
      traceFlags: traceFlags,
    );
  }

  /// Convert a LogEntry to LogRecord with automatic trace context.
  ///
  /// Uses the provided [traceContextProvider] to get current trace context
  /// for correlation with active spans.
  static LogRecord toLogRecordWithContext(
    LogEntry entry, {
    TraceContextProvider? traceContextProvider,
  }) {
    final context = traceContextProvider?.getActiveContext();

    return toLogRecord(
      entry,
      traceId: context?.traceId,
      spanId: context?.spanId,
      traceFlags: context?.traceFlags ?? 0,
    );
  }

  /// Convert a batch of LogEntries to OTLP format.
  ///
  /// Returns a list of maps ready for OTLP JSON export.
  static List<Map<String, dynamic>> toOtlpBatch(
    List<LogEntry> entries, {
    TraceContextProvider? traceContextProvider,
  }) => entries.map((entry) {
      final logRecord = toLogRecordWithContext(
        entry,
        traceContextProvider: traceContextProvider,
      );
      return logRecord.toOtlp();
    }).toList();

  /// Create a LogRecord directly (without LogEntry intermediate).
  ///
  /// Useful for direct OTEL logging without going through VooLogger.
  static LogRecord createLogRecord({
    required String message,
    required SeverityNumber severity,
    String? severityText,
    Map<String, dynamic>? attributes,
    String? traceId,
    String? spanId,
    int traceFlags = 0,
  }) => LogRecord(
      timestamp: DateTime.now(),
      observedTimestamp: DateTime.now(),
      severityNumber: severity,
      severityText: severityText ?? _getSeverityText(severity),
      body: message,
      attributes: attributes,
      traceId: traceId,
      spanId: spanId,
      traceFlags: traceFlags,
    );

  static String _getSeverityText(SeverityNumber severity) {
    final value = severity.value;
    if (value <= 4) return 'TRACE';
    if (value <= 8) return 'DEBUG';
    if (value <= 12) return 'INFO';
    if (value <= 16) return 'WARN';
    if (value <= 20) return 'ERROR';
    return 'FATAL';
  }
}
