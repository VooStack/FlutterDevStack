import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:voo_telemetry/src/core/telemetry_config.dart';
import 'package:voo_telemetry/src/core/telemetry_resource.dart';
import 'package:voo_telemetry/src/exporters/otlp_http_exporter.dart';
import 'package:voo_telemetry/src/logs/log_record.dart';
import 'package:voo_telemetry/src/logs/logger.dart';
import 'package:voo_telemetry/src/traces/trace_provider.dart';

/// Provider for log telemetry
class LoggerProvider {
  final TelemetryResource resource;
  final OTLPHttpExporter exporter;
  final TelemetryConfig config;
  final Map<String, Logger> _loggers = {};
  final List<LogRecord> _pendingLogs = [];
  final _lock = Lock();

  /// Reference to TraceProvider for log-trace correlation
  TraceProvider? traceProvider;

  LoggerProvider({required this.resource, required this.exporter, required this.config});

  /// Initialize the logger provider
  Future<void> initialize() async {
    // Any initialization logic
  }

  /// Get or create a logger
  Logger getLogger(String name) => _loggers.putIfAbsent(
        name,
        () => Logger(name: name, provider: this, traceProvider: traceProvider),
      );

  /// Add a log record to be exported
  void addLogRecord(LogRecord logRecord) {
    unawaited(_addLogRecordAsync(logRecord));
  }

  Future<void> _addLogRecordAsync(LogRecord logRecord) async {
    List<LogRecord>? itemsToExport;

    await _lock.synchronized(() {
      _pendingLogs.add(logRecord);

      if (_pendingLogs.length >= config.maxBatchSize) {
        // Extract items inside lock, export outside
        itemsToExport = List<LogRecord>.from(_pendingLogs);
        _pendingLogs.clear();
      }
    });

    // Export outside the lock to prevent deadlock
    if (itemsToExport != null) {
      await _exportBatch(itemsToExport!);
    }
  }

  Future<void> _exportBatch(List<LogRecord> logs) async {
    if (logs.isEmpty) return;
    final otlpLogs = logs.map((l) => l.toOtlp()).toList();
    await exporter.exportLogs(otlpLogs, resource);
  }

  /// Collect pending logs for combined export.
  ///
  /// Returns the OTLP-formatted logs and clears the pending list.
  /// Use this when exporting via the combined telemetry endpoint.
  Future<List<Map<String, dynamic>>> collectPendingOtlp() async {
    final logsToExport = await _lock.synchronized(() {
      final logs = List<LogRecord>.from(_pendingLogs);
      _pendingLogs.clear();
      return logs;
    });

    if (logsToExport.isEmpty) return [];

    return logsToExport.map((l) => l.toOtlp()).toList();
  }

  /// Flush pending logs
  Future<void> flush() async {
    final otlpLogs = await collectPendingOtlp();
    if (otlpLogs.isEmpty) return;
    await exporter.exportLogs(otlpLogs, resource);
  }

  /// Shutdown the provider
  Future<void> shutdown() async {
    await flush();
    _loggers.clear();
  }
}
