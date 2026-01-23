import 'package:voo_telemetry/src/logs/log_record.dart';
import 'package:voo_telemetry/src/traces/span.dart';

/// Serializable log record for isolate communication.
///
/// This is a lightweight representation of [LogRecord] that can be
/// efficiently serialized across isolate boundaries.
class SerializedLogRecord {
  final int timestampMicros;
  final int? observedTimestampMicros;
  final int severityNumber;
  final String severityText;
  final String body;
  final Map<String, dynamic> attributes;
  final String? traceId;
  final String? spanId;
  final int traceFlags;

  const SerializedLogRecord({
    required this.timestampMicros,
    this.observedTimestampMicros,
    required this.severityNumber,
    required this.severityText,
    required this.body,
    required this.attributes,
    this.traceId,
    this.spanId,
    this.traceFlags = 0,
  });

  /// Create from a LogRecord.
  factory SerializedLogRecord.fromLogRecord(LogRecord record) {
    return SerializedLogRecord(
      timestampMicros: record.timestamp.microsecondsSinceEpoch,
      observedTimestampMicros: record.observedTimestamp?.microsecondsSinceEpoch,
      severityNumber: record.severityNumber.value,
      severityText: record.severityText,
      body: record.body,
      attributes: Map<String, dynamic>.from(record.attributes),
      traceId: record.traceId,
      spanId: record.spanId,
      traceFlags: record.traceFlags,
    );
  }

  /// Convert to OTLP format (runs in worker isolate).
  Map<String, dynamic> toOtlp() => {
        'timeUnixNano': timestampMicros * 1000,
        if (observedTimestampMicros != null)
          'observedTimeUnixNano': observedTimestampMicros! * 1000,
        'severityNumber': severityNumber,
        'severityText': severityText,
        'body': {'stringValue': body},
        'attributes': attributes.entries
            .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
            .toList(),
        // Keep traceId/spanId as hex strings - backend expects strings, not byte arrays
        if (traceId != null) 'traceId': traceId,
        if (spanId != null) 'spanId': spanId,
        'flags': traceFlags,
      };

  /// Convert to a Map for isolate serialization.
  Map<String, dynamic> toMap() => {
        'timestampMicros': timestampMicros,
        'observedTimestampMicros': observedTimestampMicros,
        'severityNumber': severityNumber,
        'severityText': severityText,
        'body': body,
        'attributes': attributes,
        'traceId': traceId,
        'spanId': spanId,
        'traceFlags': traceFlags,
      };

  /// Create from a Map (deserialization in worker).
  factory SerializedLogRecord.fromMap(Map<String, dynamic> map) {
    return SerializedLogRecord(
      timestampMicros: map['timestampMicros'] as int,
      observedTimestampMicros: map['observedTimestampMicros'] as int?,
      severityNumber: map['severityNumber'] as int,
      severityText: map['severityText'] as String,
      body: map['body'] as String,
      attributes: Map<String, dynamic>.from(map['attributes'] as Map),
      traceId: map['traceId'] as String?,
      spanId: map['spanId'] as String?,
      traceFlags: map['traceFlags'] as int? ?? 0,
    );
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return bytes;
  }

  Map<String, dynamic> _convertValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    } else if (value is bool) {
      return {'boolValue': value};
    } else if (value is int) {
      return {'intValue': value};
    } else if (value is double) {
      return {'doubleValue': value};
    } else if (value is List) {
      return {
        'arrayValue': {'values': value.map(_convertValue).toList()},
      };
    } else if (value is Map) {
      return {
        'kvlistValue': {
          'values': value.entries
              .map((e) =>
                  {'key': e.key.toString(), 'value': _convertValue(e.value)})
              .toList(),
        },
      };
    } else {
      return {'stringValue': value.toString()};
    }
  }
}

/// Serializable span for isolate communication.
class SerializedSpan {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String name;
  final int kind;
  final int startTimeMicros;
  final int? endTimeMicros;
  final Map<String, dynamic> attributes;
  final List<SerializedSpanEvent> events;
  final List<SerializedSpanLink> links;
  final int statusCode;
  final String? statusMessage;

  const SerializedSpan({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.name,
    required this.kind,
    required this.startTimeMicros,
    this.endTimeMicros,
    required this.attributes,
    required this.events,
    required this.links,
    required this.statusCode,
    this.statusMessage,
  });

  /// Create from a Span.
  factory SerializedSpan.fromSpan(Span span) {
    return SerializedSpan(
      traceId: span.traceId,
      spanId: span.spanId,
      parentSpanId: span.parentSpanId,
      name: span.name,
      kind: span.kind.value,
      startTimeMicros: span.startTime.microsecondsSinceEpoch,
      endTimeMicros: span.endTime?.microsecondsSinceEpoch,
      attributes: Map<String, dynamic>.from(span.attributes),
      events: span.events.map(SerializedSpanEvent.fromSpanEvent).toList(),
      links: span.links.map(SerializedSpanLink.fromSpanLink).toList(),
      statusCode: span.status.code.value,
      statusMessage: span.status.description,
    );
  }

  /// Convert to OTLP format (runs in worker isolate).
  Map<String, dynamic> toOtlp() => {
        // Keep traceId/spanId as hex strings - backend expects strings, not byte arrays
        'traceId': traceId,
        'spanId': spanId,
        if (parentSpanId != null) 'parentSpanId': parentSpanId,
        'name': name,
        'kind': kind,
        'startTimeUnixNano': startTimeMicros * 1000,
        'endTimeUnixNano': (endTimeMicros ?? startTimeMicros) * 1000,
        'attributes': attributes.entries
            .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
            .toList(),
        'events': events.map((e) => e.toOtlp()).toList(),
        'links': links.map((l) => l.toOtlp()).toList(),
        'status': {
          'code': statusCode,
          if (statusMessage != null) 'message': statusMessage,
        },
      };

  /// Convert to a Map for isolate serialization.
  Map<String, dynamic> toMap() => {
        'traceId': traceId,
        'spanId': spanId,
        'parentSpanId': parentSpanId,
        'name': name,
        'kind': kind,
        'startTimeMicros': startTimeMicros,
        'endTimeMicros': endTimeMicros,
        'attributes': attributes,
        'events': events.map((e) => e.toMap()).toList(),
        'links': links.map((l) => l.toMap()).toList(),
        'statusCode': statusCode,
        'statusMessage': statusMessage,
      };

  /// Create from a Map (deserialization in worker).
  factory SerializedSpan.fromMap(Map<String, dynamic> map) {
    return SerializedSpan(
      traceId: map['traceId'] as String,
      spanId: map['spanId'] as String,
      parentSpanId: map['parentSpanId'] as String?,
      name: map['name'] as String,
      kind: map['kind'] as int,
      startTimeMicros: map['startTimeMicros'] as int,
      endTimeMicros: map['endTimeMicros'] as int?,
      attributes: Map<String, dynamic>.from(map['attributes'] as Map),
      events: (map['events'] as List)
          .map((e) => SerializedSpanEvent.fromMap(e as Map<String, dynamic>))
          .toList(),
      links: (map['links'] as List)
          .map((l) => SerializedSpanLink.fromMap(l as Map<String, dynamic>))
          .toList(),
      statusCode: map['statusCode'] as int,
      statusMessage: map['statusMessage'] as String?,
    );
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return bytes;
  }

  Map<String, dynamic> _convertValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    } else if (value is bool) {
      return {'boolValue': value};
    } else if (value is int) {
      return {'intValue': value};
    } else if (value is double) {
      return {'doubleValue': value};
    } else {
      return {'stringValue': value.toString()};
    }
  }
}

/// Serializable span event for isolate communication.
class SerializedSpanEvent {
  final String name;
  final int timestampMicros;
  final Map<String, dynamic> attributes;

  const SerializedSpanEvent({
    required this.name,
    required this.timestampMicros,
    required this.attributes,
  });

  factory SerializedSpanEvent.fromSpanEvent(SpanEvent event) {
    return SerializedSpanEvent(
      name: event.name,
      timestampMicros: event.timestamp.microsecondsSinceEpoch,
      attributes: Map<String, dynamic>.from(event.attributes),
    );
  }

  Map<String, dynamic> toOtlp() => {
        'name': name,
        'timeUnixNano': timestampMicros * 1000,
        'attributes': attributes.entries
            .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
            .toList(),
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'timestampMicros': timestampMicros,
        'attributes': attributes,
      };

  factory SerializedSpanEvent.fromMap(Map<String, dynamic> map) {
    return SerializedSpanEvent(
      name: map['name'] as String,
      timestampMicros: map['timestampMicros'] as int,
      attributes: Map<String, dynamic>.from(map['attributes'] as Map),
    );
  }

  Map<String, dynamic> _convertValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'boolValue': value};
    if (value is int) return {'intValue': value};
    if (value is double) return {'doubleValue': value};
    return {'stringValue': value.toString()};
  }
}

/// Serializable span link for isolate communication.
class SerializedSpanLink {
  final String traceId;
  final String spanId;
  final Map<String, dynamic> attributes;

  const SerializedSpanLink({
    required this.traceId,
    required this.spanId,
    required this.attributes,
  });

  factory SerializedSpanLink.fromSpanLink(SpanLink link) {
    return SerializedSpanLink(
      traceId: link.traceId,
      spanId: link.spanId,
      attributes: Map<String, dynamic>.from(link.attributes),
    );
  }

  Map<String, dynamic> toOtlp() => {
        // Keep traceId/spanId as hex strings - backend expects strings, not byte arrays
        'traceId': traceId,
        'spanId': spanId,
        'attributes': attributes.entries
            .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
            .toList(),
      };

  Map<String, dynamic> toMap() => {
        'traceId': traceId,
        'spanId': spanId,
        'attributes': attributes,
      };

  factory SerializedSpanLink.fromMap(Map<String, dynamic> map) {
    return SerializedSpanLink(
      traceId: map['traceId'] as String,
      spanId: map['spanId'] as String,
      attributes: Map<String, dynamic>.from(map['attributes'] as Map),
    );
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return bytes;
  }

  Map<String, dynamic> _convertValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'boolValue': value};
    if (value is int) return {'intValue': value};
    if (value is double) return {'doubleValue': value};
    return {'stringValue': value.toString()};
  }
}

/// Serializable metric for isolate communication.
///
/// Since Metric is an abstract class with concrete implementations
/// (CounterMetric, GaugeMetric, HistogramMetric), we store the OTLP
/// representation directly for simplicity.
class SerializedMetric {
  /// The pre-serialized OTLP format of the metric.
  final Map<String, dynamic> otlpData;

  const SerializedMetric({
    required this.otlpData,
  });

  /// Create from a metric's OTLP output.
  factory SerializedMetric.fromOtlp(Map<String, dynamic> otlp) {
    return SerializedMetric(otlpData: Map<String, dynamic>.from(otlp));
  }

  /// Convert to OTLP format (already stored).
  Map<String, dynamic> toOtlp() => otlpData;

  /// Convert to a Map for isolate serialization.
  Map<String, dynamic> toMap() => {'otlpData': otlpData};

  /// Create from a Map (deserialization in worker).
  factory SerializedMetric.fromMap(Map<String, dynamic> map) {
    return SerializedMetric(
      otlpData: Map<String, dynamic>.from(map['otlpData'] as Map),
    );
  }
}

/// Message types for worker communication.
enum TelemetryMessageType {
  /// Add logs to the batch queue.
  addLogs,

  /// Add spans to the batch queue.
  addSpans,

  /// Add metrics to the batch queue.
  addMetrics,

  /// Flush all pending telemetry immediately.
  flush,

  /// Shutdown the worker gracefully.
  shutdown,

  /// Update configuration.
  updateConfig,

  /// Response with success/failure status.
  response,
}

/// Message sent to the telemetry worker.
class TelemetryWorkerMessage {
  final String id;
  final TelemetryMessageType type;
  final dynamic data;
  final int priority;

  const TelemetryWorkerMessage({
    required this.id,
    required this.type,
    this.data,
    this.priority = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'data': data,
        'priority': priority,
      };

  factory TelemetryWorkerMessage.fromMap(Map<String, dynamic> map) {
    return TelemetryWorkerMessage(
      id: map['id'] as String,
      type: TelemetryMessageType.values[map['type'] as int],
      data: map['data'],
      priority: map['priority'] as int? ?? 1,
    );
  }
}

/// Response from the telemetry worker.
class TelemetryWorkerResponse {
  final String requestId;
  final bool success;
  final String? error;
  final dynamic data;

  const TelemetryWorkerResponse({
    required this.requestId,
    required this.success,
    this.error,
    this.data,
  });

  Map<String, dynamic> toMap() => {
        'requestId': requestId,
        'success': success,
        'error': error,
        'data': data,
      };

  factory TelemetryWorkerResponse.fromMap(Map<String, dynamic> map) {
    return TelemetryWorkerResponse(
      requestId: map['requestId'] as String,
      success: map['success'] as bool,
      error: map['error'] as String?,
      data: map['data'],
    );
  }
}

/// Priority levels for telemetry.
class TelemetryPriority {
  /// High priority (errors, exceptions) - flush quickly.
  static const int high = 0;

  /// Normal priority (info logs, traces).
  static const int normal = 1;

  /// Low priority (debug, verbose) - can be batched longer.
  static const int low = 2;
}
