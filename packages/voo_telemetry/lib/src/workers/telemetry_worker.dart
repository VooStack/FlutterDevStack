import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:voo_telemetry/src/core/telemetry_config.dart';
import 'package:voo_telemetry/src/workers/serializable_models.dart';

/// Background worker for telemetry processing.
///
/// This isolate handles:
/// - Batch accumulation
/// - OTLP payload encoding
/// - HTTP export
/// - Retry logic
///
/// All heavy processing happens off the main thread.
class TelemetryWorker {
  static TelemetryWorker? _instance;

  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  final Map<String, Completer<TelemetryWorkerResponse>> _pendingRequests = {};
  int _requestCounter = 0;
  bool _initialized = false;

  TelemetryWorker._();

  /// Get the singleton instance.
  static TelemetryWorker get instance {
    _instance ??= TelemetryWorker._();
    return _instance!;
  }

  /// Whether the worker is initialized and ready.
  bool get isInitialized => _initialized;

  /// Initialize the telemetry worker.
  ///
  /// On web, this is a no-op as web workers require different setup.
  Future<void> initialize({required String endpoint, String? apiKey, required TelemetryConfig config, required Map<String, dynamic> resourceAttributes}) async {
    if (_initialized) return;

    if (kIsWeb) {
      // Web doesn't support traditional isolates
      _initialized = true;
      if (kDebugMode) {
        debugPrint('TelemetryWorker: Web platform - using fallback mode');
      }
      return;
    }

    _mainReceivePort = ReceivePort();

    try {
      _isolate = await Isolate.spawn(
        _workerEntryPoint,
        _WorkerInitMessage(
          mainSendPort: _mainReceivePort!.sendPort,
          endpoint: endpoint,
          apiKey: apiKey,
          batchSize: config.maxBatchSize,
          batchIntervalMs: config.batchInterval.inMilliseconds,
          timeoutMs: config.timeout.inMilliseconds,
          maxRetries: config.maxRetries,
          retryDelayMs: config.retryDelay.inMilliseconds,
          enableCompression: config.enableCompression,
          compressionThreshold: config.compressionThreshold,
          resourceAttributes: resourceAttributes,
          debug: config.debug,
        ),
      );

      final completer = Completer<void>();
      _mainReceivePort!.listen((message) {
        if (message is SendPort) {
          _workerSendPort = message;
          completer.complete();
        } else if (message is Map<String, dynamic>) {
          _handleWorkerResponse(TelemetryWorkerResponse.fromMap(message));
        }
      });

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('TelemetryWorker initialization timed out');
        },
      );

      _initialized = true;

      if (kDebugMode) {
        debugPrint('TelemetryWorker: Initialized with isolate');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TelemetryWorker: Failed to initialize: $e');
      }
      _isolate?.kill();
      _isolate = null;
      _mainReceivePort?.close();
      _mainReceivePort = null;
      // Fall back to synchronous mode
      _initialized = true;
    }
  }

  /// Add log records to the export queue.
  Future<void> addLogs(List<SerializedLogRecord> logs, {int priority = TelemetryPriority.normal}) async {
    if (!_initialized) return;

    final message = TelemetryWorkerMessage(
      id: _generateRequestId(),
      type: TelemetryMessageType.addLogs,
      data: logs.map((l) => l.toMap()).toList(),
      priority: priority,
    );

    await _sendMessage(message);
  }

  /// Add spans to the export queue.
  Future<void> addSpans(List<SerializedSpan> spans, {int priority = TelemetryPriority.normal}) async {
    if (!_initialized) return;

    final message = TelemetryWorkerMessage(
      id: _generateRequestId(),
      type: TelemetryMessageType.addSpans,
      data: spans.map((s) => s.toMap()).toList(),
      priority: priority,
    );

    await _sendMessage(message);
  }

  /// Add metrics to the export queue.
  Future<void> addMetrics(List<SerializedMetric> metrics, {int priority = TelemetryPriority.normal}) async {
    if (!_initialized) return;

    final message = TelemetryWorkerMessage(
      id: _generateRequestId(),
      type: TelemetryMessageType.addMetrics,
      data: metrics.map((m) => m.toMap()).toList(),
      priority: priority,
    );

    await _sendMessage(message);
  }

  /// Flush all pending telemetry.
  Future<bool> flush() async {
    if (!_initialized) return false;

    final message = TelemetryWorkerMessage(id: _generateRequestId(), type: TelemetryMessageType.flush);

    final response = await _sendMessageAndWait(message);
    return response?.success ?? false;
  }

  /// Shutdown the worker gracefully.
  Future<void> shutdown() async {
    if (!_initialized) return;

    // Send shutdown message and wait for flush
    final message = TelemetryWorkerMessage(id: _generateRequestId(), type: TelemetryMessageType.shutdown);

    await _sendMessageAndWait(message, timeout: const Duration(seconds: 10));

    _isolate?.kill();
    _isolate = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerSendPort = null;
    _pendingRequests.clear();
    _initialized = false;
  }

  String _generateRequestId() {
    _requestCounter++;
    return 'telemetry_${DateTime.now().millisecondsSinceEpoch}_$_requestCounter';
  }

  Future<void> _sendMessage(TelemetryWorkerMessage message) async {
    if (_workerSendPort != null) {
      _workerSendPort!.send(message.toMap());
    }
  }

  Future<TelemetryWorkerResponse?> _sendMessageAndWait(TelemetryWorkerMessage message, {Duration timeout = const Duration(seconds: 30)}) async {
    if (_workerSendPort == null) return null;

    final completer = Completer<TelemetryWorkerResponse>();
    _pendingRequests[message.id] = completer;
    _workerSendPort!.send(message.toMap());

    try {
      return await completer.future.timeout(timeout);
    } catch (e) {
      _pendingRequests.remove(message.id);
      return null;
    }
  }

  void _handleWorkerResponse(TelemetryWorkerResponse response) {
    final completer = _pendingRequests.remove(response.requestId);
    completer?.complete(response);
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _instance?.shutdown();
    _instance = null;
  }
}

/// Initialization message for the worker.
class _WorkerInitMessage {
  final SendPort mainSendPort;
  final String endpoint;
  final String? apiKey;
  final int batchSize;
  final int batchIntervalMs;
  final int timeoutMs;
  final int maxRetries;
  final int retryDelayMs;
  final bool enableCompression;
  final int compressionThreshold;
  final Map<String, dynamic> resourceAttributes;
  final bool debug;

  const _WorkerInitMessage({
    required this.mainSendPort,
    required this.endpoint,
    this.apiKey,
    required this.batchSize,
    required this.batchIntervalMs,
    required this.timeoutMs,
    required this.maxRetries,
    required this.retryDelayMs,
    required this.enableCompression,
    required this.compressionThreshold,
    required this.resourceAttributes,
    required this.debug,
  });
}

/// Worker isolate entry point.
void _workerEntryPoint(_WorkerInitMessage init) {
  final worker = _TelemetryWorkerIsolate(init);
  worker.run();
}

/// The actual worker running in the isolate.
class _TelemetryWorkerIsolate {
  final _WorkerInitMessage _init;
  final ReceivePort _receivePort = ReceivePort();
  final http.Client _httpClient = http.Client();

  // Batches for different telemetry types
  final Queue<SerializedLogRecord> _logQueue = Queue();
  final Queue<SerializedSpan> _spanQueue = Queue();
  final Queue<SerializedMetric> _metricQueue = Queue();

  // Priority queues (high priority items)
  final Queue<SerializedLogRecord> _priorityLogQueue = Queue();
  final Queue<SerializedSpan> _prioritySpanQueue = Queue();

  Timer? _flushTimer;
  bool _shuttingDown = false;

  _TelemetryWorkerIsolate(this._init);

  void run() {
    // Send our port to the main isolate
    _init.mainSendPort.send(_receivePort.sendPort);

    // Start the flush timer
    _flushTimer = Timer.periodic(Duration(milliseconds: _init.batchIntervalMs), (_) => _flushAll());

    // Listen for messages
    _receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final workerMessage = TelemetryWorkerMessage.fromMap(message);
        await _handleMessage(workerMessage);
      }
    });
  }

  Future<void> _handleMessage(TelemetryWorkerMessage message) async {
    switch (message.type) {
      case TelemetryMessageType.addLogs:
        _addLogs(message);
        break;
      case TelemetryMessageType.addSpans:
        _addSpans(message);
        break;
      case TelemetryMessageType.addMetrics:
        _addMetrics(message);
        break;
      case TelemetryMessageType.flush:
        await _handleFlush(message);
        break;
      case TelemetryMessageType.shutdown:
        await _handleShutdown(message);
        break;
      case TelemetryMessageType.updateConfig:
        // Handle config updates if needed
        break;
      case TelemetryMessageType.response:
        // Not expected in worker
        break;
    }
  }

  void _addLogs(TelemetryWorkerMessage message) {
    final logs = (message.data as List).map((m) => SerializedLogRecord.fromMap(m as Map<String, dynamic>)).toList();

    for (final log in logs) {
      if (message.priority == TelemetryPriority.high) {
        _priorityLogQueue.add(log);
      } else {
        _logQueue.add(log);
      }
    }

    // Check if we should flush immediately
    if (_priorityLogQueue.isNotEmpty || _logQueue.length >= _init.batchSize) {
      _flushLogs();
    }
  }

  void _addSpans(TelemetryWorkerMessage message) {
    final spans = (message.data as List).map((m) => SerializedSpan.fromMap(m as Map<String, dynamic>)).toList();

    for (final span in spans) {
      if (message.priority == TelemetryPriority.high) {
        _prioritySpanQueue.add(span);
      } else {
        _spanQueue.add(span);
      }
    }

    if (_prioritySpanQueue.isNotEmpty || _spanQueue.length >= _init.batchSize) {
      _flushSpans();
    }
  }

  void _addMetrics(TelemetryWorkerMessage message) {
    final metrics = (message.data as List).map((m) => SerializedMetric.fromMap(m as Map<String, dynamic>)).toList();

    _metricQueue.addAll(metrics);

    if (_metricQueue.length >= _init.batchSize) {
      _flushMetrics();
    }
  }

  Future<void> _handleFlush(TelemetryWorkerMessage message) async {
    final success = await _flushAll();
    _sendResponse(message.id, success);
  }

  Future<void> _handleShutdown(TelemetryWorkerMessage message) async {
    _shuttingDown = true;
    _flushTimer?.cancel();

    // Final flush
    await _flushAll();

    _httpClient.close();
    _sendResponse(message.id, true);
    _receivePort.close();
  }

  Future<bool> _flushAll() async {
    if (_shuttingDown && _logQueue.isEmpty && _spanQueue.isEmpty && _metricQueue.isEmpty) {
      return true;
    }

    final results = await Future.wait([_flushLogs(), _flushSpans(), _flushMetrics()]);

    return results.every((r) => r);
  }

  Future<bool> _flushLogs() async {
    // Flush priority logs first
    final allLogs = <SerializedLogRecord>[];
    while (_priorityLogQueue.isNotEmpty && allLogs.length < _init.batchSize) {
      allLogs.add(_priorityLogQueue.removeFirst());
    }
    while (_logQueue.isNotEmpty && allLogs.length < _init.batchSize) {
      allLogs.add(_logQueue.removeFirst());
    }

    if (allLogs.isEmpty) return true;

    final payload = _buildLogsPayload(allLogs);
    final success = await _sendToEndpoint('${_init.endpoint}/v1/logs', payload);

    if (!success) {
      // Re-queue failed logs
      for (final log in allLogs.reversed) {
        _logQueue.addFirst(log);
      }
    }

    return success;
  }

  Future<bool> _flushSpans() async {
    final allSpans = <SerializedSpan>[];
    while (_prioritySpanQueue.isNotEmpty && allSpans.length < _init.batchSize) {
      allSpans.add(_prioritySpanQueue.removeFirst());
    }
    while (_spanQueue.isNotEmpty && allSpans.length < _init.batchSize) {
      allSpans.add(_spanQueue.removeFirst());
    }

    if (allSpans.isEmpty) return true;

    final payload = _buildSpansPayload(allSpans);
    final success = await _sendToEndpoint('${_init.endpoint}/v1/traces', payload);

    if (!success) {
      for (final span in allSpans.reversed) {
        _spanQueue.addFirst(span);
      }
    }

    return success;
  }

  Future<bool> _flushMetrics() async {
    final allMetrics = <SerializedMetric>[];
    while (_metricQueue.isNotEmpty && allMetrics.length < _init.batchSize) {
      allMetrics.add(_metricQueue.removeFirst());
    }

    if (allMetrics.isEmpty) return true;

    final payload = _buildMetricsPayload(allMetrics);
    final success = await _sendToEndpoint('${_init.endpoint}/v1/metrics', payload);

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
          'attributes': _init.resourceAttributes.entries.map((e) => {'key': e.key, 'value': _convertValue(e.value)}).toList(),
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
          'attributes': _init.resourceAttributes.entries.map((e) => {'key': e.key, 'value': _convertValue(e.value)}).toList(),
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
          'attributes': _init.resourceAttributes.entries.map((e) => {'key': e.key, 'value': _convertValue(e.value)}).toList(),
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
    while (retries < _init.maxRetries) {
      try {
        final body = jsonEncode(payload);
        final headers = <String, String>{'Content-Type': 'application/json', if (_init.apiKey != null) 'X-API-Key': _init.apiKey!};

        final response = await _httpClient.post(Uri.parse(url), headers: headers, body: body).timeout(Duration(milliseconds: _init.timeoutMs));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (_init.debug) {
            debugPrint('TelemetryWorker: Exported to $url');
          }
          return true;
        }

        if (_init.debug) {
          debugPrint('TelemetryWorker: Export failed ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        if (_init.debug) {
          debugPrint('TelemetryWorker: Export error: $e');
        }
      }

      retries++;
      if (retries < _init.maxRetries) {
        await Future<void>.delayed(Duration(milliseconds: _init.retryDelayMs * retries));
      }
    }

    return false;
  }

  void _sendResponse(String requestId, bool success, {String? error}) {
    _init.mainSendPort.send(TelemetryWorkerResponse(requestId: requestId, success: success, error: error).toMap());
  }

  Map<String, dynamic> _convertValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'boolValue': value};
    if (value is int) return {'intValue': value};
    if (value is double) return {'doubleValue': value};
    return {'stringValue': value.toString()};
  }
}
