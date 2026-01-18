import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// A message sent to the worker isolate.
class VooIsolateMessage {
  final String id;
  final String type;
  final dynamic data;

  VooIsolateMessage({
    required this.id,
    required this.type,
    this.data,
  });
}

/// Result from a worker isolate operation.
class VooIsolateResult {
  final String id;
  final bool success;
  final dynamic data;
  final String? error;

  VooIsolateResult({
    required this.id,
    required this.success,
    this.data,
    this.error,
  });
}

/// Manages background processing for Voo SDK.
///
/// This service provides utilities for running computationally expensive
/// operations off the main UI thread using Dart isolates.
///
/// ## Usage
///
/// ```dart
/// // Initialize during app startup
/// await VooIsolateManager.initialize();
///
/// // Run a simple computation in the background
/// final result = await VooIsolateManager.compute(
///   (data) => expensiveCalculation(data),
///   inputData,
/// );
///
/// // Run an async operation in the background
/// final result = await VooIsolateManager.runInBackground(
///   () async => await networkRequest(),
/// );
/// ```
///
/// Note: On web platforms, operations run on the main thread since
/// web workers have limitations with Dart isolates.
class VooIsolateManager {
  static VooIsolateManager? _instance;
  static bool _initialized = false;

  // Worker isolate for long-running tasks
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  final Map<String, Completer<VooIsolateResult>> _pendingRequests = {};
  int _requestCounter = 0;

  VooIsolateManager._();

  /// Get the singleton instance.
  static VooIsolateManager get instance {
    _instance ??= VooIsolateManager._();
    return _instance!;
  }

  /// Whether the isolate manager is initialized.
  static bool get isInitialized => _initialized;

  /// Initialize the isolate manager.
  ///
  /// This sets up the infrastructure for background processing.
  /// On web, this is a no-op as isolates work differently.
  static Future<void> initialize() async {
    if (_initialized) return;

    // On web, we can't use traditional isolates
    if (kIsWeb) {
      _initialized = true;
      if (kDebugMode) {
        debugPrint('VooIsolateManager: Web platform - using main thread');
      }
      return;
    }

    await instance._initializeWorker();
    _initialized = true;

    if (kDebugMode) {
      debugPrint('VooIsolateManager: Initialized with worker isolate');
    }
  }

  /// Run a synchronous function in an isolate.
  ///
  /// This is a wrapper around Flutter's `compute()` function.
  /// Use this for CPU-intensive synchronous operations.
  ///
  /// Example:
  /// ```dart
  /// final result = await VooIsolateManager.compute(
  ///   (data) => jsonDecode(data),
  ///   largeJsonString,
  /// );
  /// ```
  static Future<R> computeSync<Q, R>(
    R Function(Q message) callback,
    Q message, {
    String? debugLabel,
  }) async {
    // On web or if not initialized, run on main thread
    if (kIsWeb) {
      return callback(message);
    }

    return await compute(callback, message, debugLabel: debugLabel);
  }

  /// Run an async function in the background.
  ///
  /// This creates a new isolate for the operation and handles
  /// the result transfer back to the main thread.
  ///
  /// Note: The callback function must be a top-level or static function
  /// and all parameters must be serializable across isolate boundaries.
  ///
  /// Example:
  /// ```dart
  /// final result = await VooIsolateManager.runInBackground(
  ///   _fetchAndProcessData,
  ///   url,
  /// );
  ///
  /// // Top-level function
  /// Future<List<Data>> _fetchAndProcessData(String url) async {
  ///   final response = await http.get(Uri.parse(url));
  ///   return parseData(response.body);
  /// }
  /// ```
  static Future<R> runInBackground<Q, R>(
    Future<R> Function(Q message) callback,
    Q message, {
    String? debugLabel,
  }) async {
    // On web, run on main thread
    if (kIsWeb) {
      return await callback(message);
    }

    // Use Isolate.run for simple async operations
    try {
      return await Isolate.run<R>(() => callback(message));
    } catch (e) {
      // Fallback to main thread if isolate fails
      if (kDebugMode) {
        debugPrint(
            'VooIsolateManager: Isolate failed, running on main thread: $e');
      }
      return await callback(message);
    }
  }

  /// Run a function that doesn't require a message parameter.
  ///
  /// This is a convenience wrapper for operations that don't need input.
  static Future<R> run<R>(Future<R> Function() callback) async {
    if (kIsWeb) {
      return await callback();
    }

    try {
      return await Isolate.run<R>(callback);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'VooIsolateManager: Isolate failed, running on main thread: $e');
      }
      return await callback();
    }
  }

  /// Schedule work on the persistent worker isolate.
  ///
  /// Use this for operations that benefit from a warm isolate
  /// that doesn't need to be created each time.
  Future<VooIsolateResult> scheduleWork(VooIsolateMessage message) async {
    if (kIsWeb || _workerSendPort == null) {
      return VooIsolateResult(
        id: message.id,
        success: false,
        error: 'Worker not available',
      );
    }

    final completer = Completer<VooIsolateResult>();
    _pendingRequests[message.id] = completer;
    _workerSendPort!.send(message);

    return completer.future;
  }

  /// Generate a unique request ID.
  String generateRequestId() {
    _requestCounter++;
    return 'voo_${DateTime.now().millisecondsSinceEpoch}_$_requestCounter';
  }

  /// Initialize the persistent worker isolate.
  Future<void> _initializeWorker() async {
    if (kIsWeb) return;

    _mainReceivePort = ReceivePort();

    try {
      _workerIsolate = await Isolate.spawn(
        _workerEntryPoint,
        _mainReceivePort!.sendPort,
      );

      // Wait for the worker to send its SendPort
      final completer = Completer<void>();
      _mainReceivePort!.listen((message) {
        if (message is SendPort) {
          _workerSendPort = message;
          completer.complete();
        } else if (message is VooIsolateResult) {
          final pending = _pendingRequests.remove(message.id);
          pending?.complete(message);
        }
      });

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Worker isolate initialization timed out');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooIsolateManager: Failed to initialize worker: $e');
      }
      _workerIsolate?.kill();
      _workerIsolate = null;
      _mainReceivePort?.close();
      _mainReceivePort = null;
    }
  }

  /// Worker isolate entry point.
  static void _workerEntryPoint(SendPort mainSendPort) {
    final workerReceivePort = ReceivePort();
    mainSendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen((message) async {
      if (message is VooIsolateMessage) {
        try {
          // Process the message based on type
          final result = await _processWorkerMessage(message);
          mainSendPort.send(VooIsolateResult(
            id: message.id,
            success: true,
            data: result,
          ));
        } catch (e) {
          mainSendPort.send(VooIsolateResult(
            id: message.id,
            success: false,
            error: e.toString(),
          ));
        }
      }
    });
  }

  /// Process a message in the worker isolate.
  static Future<dynamic> _processWorkerMessage(VooIsolateMessage message) async {
    // Add custom message type handlers here
    switch (message.type) {
      case 'json_encode':
        return _jsonEncode(message.data);
      case 'json_decode':
        return _jsonDecode(message.data);
      default:
        throw UnsupportedError('Unknown message type: ${message.type}');
    }
  }

  /// Helper for JSON encoding in isolate.
  static String _jsonEncode(dynamic data) {
    // Import would happen at top of file
    // This is just a placeholder for the pattern
    return data.toString();
  }

  /// Helper for JSON decoding in isolate.
  static dynamic _jsonDecode(String data) {
    // Import would happen at top of file
    return data;
  }

  /// Dispose the isolate manager and clean up resources.
  static Future<void> dispose() async {
    if (_instance != null) {
      _instance!._workerIsolate?.kill(priority: Isolate.beforeNextEvent);
      _instance!._workerIsolate = null;
      _instance!._mainReceivePort?.close();
      _instance!._mainReceivePort = null;
      _instance!._workerSendPort = null;
      _instance!._pendingRequests.clear();
    }
    _initialized = false;
    _instance = null;

    if (kDebugMode) {
      debugPrint('VooIsolateManager: Disposed');
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _instance = null;
  }
}
