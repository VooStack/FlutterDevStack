import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_logging/features/logging/domain/entities/log_entry.dart';
import 'package:voo_telemetry/voo_telemetry.dart';
import 'package:voo_logging/src/otel/otel_log_adapter.dart';
import 'package:voo_logging/src/otel/otel_logging_config.dart';
import 'package:voo_logging/src/otel/trace_context_provider.dart';

/// OTLP Log Exporter for VooLogger.
///
/// Batches log entries and exports them to an OTLP endpoint using
/// the standard OpenTelemetry log protocol.
///
/// **DEPRECATED**: This class is deprecated and will be removed in a future version.
/// Logs are now routed through [VooTelemetry] automatically when VooTelemetry is initialized.
/// This provides unified telemetry export with better batching, compression, and persistence.
///
/// To migrate:
/// 1. Remove any manual OtelLogExporter configuration from your LoggingConfig
/// 2. Ensure VooTelemetry.initialize() is called before VooLogger.initialize()
/// 3. Logs will automatically flow through VooTelemetry's unified OTLP pipeline
@Deprecated(
  'OtelLogExporter is deprecated. Logs are now routed through VooTelemetry automatically. '
  'Remove otelConfig from LoggingConfig and ensure VooTelemetry is initialized.',
)
class OtelLogExporter {
  final OtelLoggingConfig config;
  final TelemetryResource _resource;

  final Queue<LogEntry> _pendingLogs = Queue();
  Timer? _flushTimer;
  bool _disposed = false;

  /// Callback to get current trace context for log correlation.
  TraceContextProvider? traceContextProvider;

  OtelLogExporter({required this.config}) : _resource = config.buildResource();

  /// Initialize the exporter and start the flush timer.
  void initialize() {
    if (!config.isValid) {
      if (kDebugMode) {
        debugPrint('OtelLogExporter: Invalid config, skipping initialization');
      }
      return;
    }

    if (config.batchInterval.inMilliseconds > 0) {
      _flushTimer = Timer.periodic(config.batchInterval, (_) {
        flush();
      });
    }

    if (config.debug) {
      debugPrint('OtelLogExporter initialized with endpoint: ${config.endpoint}');
    }
  }

  /// Queue a log entry for export.
  ///
  /// Logs are batched and sent periodically or when batch size is reached.
  void queueLog(LogEntry log) {
    if (_disposed || !config.isValid) return;

    _pendingLogs.add(log);

    // Enforce max queue size
    while (_pendingLogs.length > config.maxQueueSize) {
      _pendingLogs.removeFirst();
    }

    // Flush immediately if batch size reached
    if (_pendingLogs.length >= config.batchSize) {
      flush();
    }

    // Flush immediately for error/fatal logs if prioritizeErrors is enabled
    if (config.prioritizeErrors && (log.level.priority >= 4)) {
      // error or fatal
      flush();
    }
  }

  /// Flush pending logs to the OTLP endpoint.
  ///
  /// Returns true if export was successful, false otherwise.
  Future<bool> flush() async {
    if (_disposed || _pendingLogs.isEmpty) return true;

    // Take logs to export
    final logsToExport = <LogEntry>[];
    final batchSize = config.batchSize;
    while (logsToExport.length < batchSize && _pendingLogs.isNotEmpty) {
      logsToExport.add(_pendingLogs.removeFirst());
    }

    if (logsToExport.isEmpty) return true;

    try {
      // Convert to OTLP format
      final logRecords = logsToExport.map((entry) => OtelLogAdapter.toLogRecordWithContext(entry, traceContextProvider: traceContextProvider)).toList();

      // Build OTLP payload
      final payload = _buildOtlpPayload(logRecords);

      // Export via HTTP
      final success = await _sendToEndpoint(payload);

      if (!success) {
        // Re-queue failed logs (at front of queue)
        for (final log in logsToExport.reversed) {
          _pendingLogs.addFirst(log);
        }

        // Trim queue if too large after re-adding
        while (_pendingLogs.length > config.maxQueueSize) {
          _pendingLogs.removeLast();
        }
      }

      return success;
    } catch (e) {
      if (config.debug) {
        debugPrint('OtelLogExporter flush error: $e');
      }

      // Re-queue logs on error
      for (final log in logsToExport.reversed) {
        _pendingLogs.addFirst(log);
      }

      return false;
    }
  }

  /// Build the OTLP log export payload.
  Map<String, dynamic> _buildOtlpPayload(List<LogRecord> logRecords) => {
    'resourceLogs': [
      {
        'resource': {
          'attributes': _resource.attributes.entries.map((e) => {'key': e.key, 'value': _convertValue(e.value)}).toList(),
        },
        'scopeLogs': [
          {
            'scope': {'name': config.instrumentationScopeName, 'version': config.instrumentationScopeVersion},
            'logRecords': logRecords.map((r) => r.toOtlp()).toList(),
          },
        ],
      },
    ],
  };

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

  /// Send payload to the OTLP endpoint.
  Future<bool> _sendToEndpoint(Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('${config.endpoint}/v1/logs');

      final headers = <String, String>{'Content-Type': 'application/json', if (config.apiKey != null) 'X-API-Key': config.apiKey!, ...?config.headers};

      // Fallback to direct HTTP (VooTelemetry integration removed)
      final response = await _httpPost(uri, headers, payload);
      return response;
    } catch (e) {
      if (config.debug) {
        debugPrint('OtelLogExporter HTTP error: $e');
      }
      return false;
    }
  }

  Future<bool> _httpPost(Uri uri, Map<String, String> headers, Map<String, dynamic> payload) async {
    try {
      final client = _getHttpClient();
      final response = await client.post(uri, headers: headers, body: _encodeJson(payload));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (config.debug) {
        debugPrint('OtelLogExporter HTTP request failed: $e');
      }
      return false;
    }
  }

  // Lazy HTTP client getter
  http.Client? _httpClient;
  http.Client _getHttpClient() {
    _httpClient ??= http.Client();
    return _httpClient!;
  }

  String _encodeJson(Map<String, dynamic> data) => _jsonEncode(data);

  String _jsonEncode(dynamic data) {
    if (data is Map) {
      final entries = data.entries.map((e) => '"${e.key}":${_jsonEncode(e.value)}');
      return '{${entries.join(',')}}';
    } else if (data is List) {
      return '[${data.map(_jsonEncode).join(',')}]';
    } else if (data is String) {
      return '"${data.replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
    } else if (data is bool || data is num) {
      return data.toString();
    } else if (data == null) {
      return 'null';
    } else {
      return '"${data.toString()}"';
    }
  }

  /// Get the number of pending logs.
  int get pendingCount => _pendingLogs.length;

  /// Check if the exporter is disposed.
  bool get isDisposed => _disposed;

  /// Dispose the exporter and flush remaining logs.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _flushTimer?.cancel();
    _flushTimer = null;

    // Final flush attempt
    await flush();

    _pendingLogs.clear();
  }
}
