import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:voo_telemetry/src/core/telemetry_config.dart';
import 'package:voo_telemetry/src/workers/serializable_models.dart';

/// Web-compatible telemetry processor.
///
/// Since web doesn't support traditional isolates, this uses
/// scheduleMicrotask for chunked processing to prevent UI jank.
class TelemetryWorkerWeb {
  static TelemetryWorkerWeb? _instance;

  String? _endpoint;
  String? _apiKey;
  int _batchSize = 100;
  int _batchIntervalMs = 30000;
  int _timeoutMs = 10000;
  int _maxRetries = 3;
  int _retryDelayMs = 1000;
  // Note: Compression is not supported on web (dart:io not available)
  Map<String, dynamic> _resourceAttributes = {};

  final http.Client _httpClient = http.Client();

  // Batches for different telemetry types
  final Queue<SerializedLogRecord> _logQueue = Queue();
  final Queue<SerializedSpan> _spanQueue = Queue();
  final Queue<SerializedMetric> _metricQueue = Queue();

  // Priority queues
  final Queue<SerializedLogRecord> _priorityLogQueue = Queue();
  final Queue<SerializedSpan> _prioritySpanQueue = Queue();

  Timer? _flushTimer;
  bool _initialized = false;
  bool _processing = false;

  TelemetryWorkerWeb._();

  /// Get the singleton instance.
  static TelemetryWorkerWeb get instance {
    _instance ??= TelemetryWorkerWeb._();
    return _instance!;
  }

  /// Whether the worker is initialized.
  bool get isInitialized => _initialized;

  /// Initialize the web telemetry processor.
  Future<void> initialize({
    required String endpoint,
    String? apiKey,
    required TelemetryConfig config,
    required Map<String, dynamic> resourceAttributes,
  }) async {
    if (_initialized) return;

    _endpoint = endpoint;
    _apiKey = apiKey;
    _batchSize = config.maxBatchSize;
    _batchIntervalMs = config.batchInterval.inMilliseconds;
    _timeoutMs = config.timeout.inMilliseconds;
    _maxRetries = config.maxRetries;
    _retryDelayMs = config.retryDelay.inMilliseconds;
    // Note: config.enableCompression is ignored on web (dart:io not available)
    _resourceAttributes = resourceAttributes;

    // Start the flush timer
    _flushTimer = Timer.periodic(
      Duration(milliseconds: _batchIntervalMs),
      (_) => _scheduleFlush(),
    );

    _initialized = true;
  }

  /// Add log records to the export queue.
  Future<void> addLogs(
    List<SerializedLogRecord> logs, {
    int priority = TelemetryPriority.normal,
  }) async {
    if (!_initialized) return;

    for (final log in logs) {
      if (priority == TelemetryPriority.high) {
        _priorityLogQueue.add(log);
      } else {
        _logQueue.add(log);
      }
    }

    // Check if we should flush
    if (_priorityLogQueue.isNotEmpty || _logQueue.length >= _batchSize) {
      _scheduleFlush();
    }
  }

  /// Add spans to the export queue.
  Future<void> addSpans(
    List<SerializedSpan> spans, {
    int priority = TelemetryPriority.normal,
  }) async {
    if (!_initialized) return;

    for (final span in spans) {
      if (priority == TelemetryPriority.high) {
        _prioritySpanQueue.add(span);
      } else {
        _spanQueue.add(span);
      }
    }

    if (_prioritySpanQueue.isNotEmpty || _spanQueue.length >= _batchSize) {
      _scheduleFlush();
    }
  }

  /// Add metrics to the export queue.
  Future<void> addMetrics(
    List<SerializedMetric> metrics, {
    int priority = TelemetryPriority.normal,
  }) async {
    if (!_initialized) return;

    _metricQueue.addAll(metrics);

    if (_metricQueue.length >= _batchSize) {
      _scheduleFlush();
    }
  }

  /// Flush all pending telemetry.
  Future<bool> flush() async {
    if (!_initialized) return false;
    return _flushAll();
  }

  /// Shutdown the processor.
  Future<void> shutdown() async {
    _flushTimer?.cancel();
    await _flushAll();
    _httpClient.close();
    _initialized = false;
  }

  /// Schedule a flush using microtasks to avoid UI jank.
  void _scheduleFlush() {
    if (_processing) return;

    scheduleMicrotask(() async {
      await _flushAll();
    });
  }

  Future<bool> _flushAll() async {
    if (_processing) return true;
    _processing = true;

    try {
      final results = await Future.wait([
        _flushLogs(),
        _flushSpans(),
        _flushMetrics(),
      ]);

      return results.every((r) => r);
    } finally {
      _processing = false;
    }
  }

  Future<bool> _flushLogs() async {
    final allLogs = <SerializedLogRecord>[];

    // Process in chunks to avoid blocking
    while (_priorityLogQueue.isNotEmpty && allLogs.length < _batchSize) {
      allLogs.add(_priorityLogQueue.removeFirst());
      if (allLogs.length % 10 == 0) {
        // Yield control periodically
        await Future<void>.delayed(Duration.zero);
      }
    }
    while (_logQueue.isNotEmpty && allLogs.length < _batchSize) {
      allLogs.add(_logQueue.removeFirst());
      if (allLogs.length % 10 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (allLogs.isEmpty) return true;

    final payload = _buildLogsPayload(allLogs);
    final success = await _sendToEndpoint('$_endpoint/v1/logs', payload);

    if (!success) {
      for (final log in allLogs.reversed) {
        _logQueue.addFirst(log);
      }
    }

    return success;
  }

  Future<bool> _flushSpans() async {
    final allSpans = <SerializedSpan>[];

    while (_prioritySpanQueue.isNotEmpty && allSpans.length < _batchSize) {
      allSpans.add(_prioritySpanQueue.removeFirst());
      if (allSpans.length % 10 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    while (_spanQueue.isNotEmpty && allSpans.length < _batchSize) {
      allSpans.add(_spanQueue.removeFirst());
      if (allSpans.length % 10 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (allSpans.isEmpty) return true;

    final payload = _buildSpansPayload(allSpans);
    final success = await _sendToEndpoint('$_endpoint/v1/traces', payload);

    if (!success) {
      for (final span in allSpans.reversed) {
        _spanQueue.addFirst(span);
      }
    }

    return success;
  }

  Future<bool> _flushMetrics() async {
    final allMetrics = <SerializedMetric>[];

    while (_metricQueue.isNotEmpty && allMetrics.length < _batchSize) {
      allMetrics.add(_metricQueue.removeFirst());
      if (allMetrics.length % 10 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (allMetrics.isEmpty) return true;

    final payload = _buildMetricsPayload(allMetrics);
    final success = await _sendToEndpoint('$_endpoint/v1/metrics', payload);

    if (!success) {
      for (final metric in allMetrics.reversed) {
        _metricQueue.addFirst(metric);
      }
    }

    return success;
  }

  Map<String, dynamic> _buildLogsPayload(List<SerializedLogRecord> logs) => {
        'resourceLogs': [
          {
            'resource': {
              'attributes': _resourceAttributes.entries
                  .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
                  .toList(),
            },
            'scopeLogs': [
              {
                'scope': {'name': 'voo-telemetry', 'version': '2.0.0'},
                'logRecords': logs.map((l) => l.toOtlp()).toList(),
              },
            ],
          },
        ],
      };

  Map<String, dynamic> _buildSpansPayload(List<SerializedSpan> spans) => {
        'resourceSpans': [
          {
            'resource': {
              'attributes': _resourceAttributes.entries
                  .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
                  .toList(),
            },
            'scopeSpans': [
              {
                'scope': {'name': 'voo-telemetry', 'version': '2.0.0'},
                'spans': spans.map((s) => s.toOtlp()).toList(),
              },
            ],
          },
        ],
      };

  Map<String, dynamic> _buildMetricsPayload(List<SerializedMetric> metrics) => {
        'resourceMetrics': [
          {
            'resource': {
              'attributes': _resourceAttributes.entries
                  .map((e) => {'key': e.key, 'value': _convertValue(e.value)})
                  .toList(),
            },
            'scopeMetrics': [
              {
                'scope': {'name': 'voo-telemetry', 'version': '2.0.0'},
                'metrics': metrics.map((m) => m.toOtlp()).toList(),
              },
            ],
          },
        ],
      };

  Future<bool> _sendToEndpoint(String url, Map<String, dynamic> payload) async {
    int retries = 0;
    while (retries < _maxRetries) {
      try {
        final body = jsonEncode(payload);
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (_apiKey != null) 'X-API-Key': _apiKey!,
        };

        final response = await _httpClient
            .post(Uri.parse(url), headers: headers, body: body)
            .timeout(Duration(milliseconds: _timeoutMs));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {
        // Retry on failure
      }

      retries++;
      if (retries < _maxRetries) {
        await Future<void>.delayed(Duration(milliseconds: _retryDelayMs * retries));
      }
    }

    return false;
  }

  Map<String, dynamic> _convertValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'boolValue': value};
    if (value is int) return {'intValue': value};
    if (value is double) return {'doubleValue': value};
    return {'stringValue': value.toString()};
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _instance?.shutdown();
    _instance = null;
  }
}
