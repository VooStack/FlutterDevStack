import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:voo_core/src/batching/batch_config.dart';
import 'package:voo_core/src/batching/compression_utils.dart';
import 'package:voo_core/src/batching/network_monitor.dart';
import 'package:voo_core/src/batching/persistent_queue.dart';
import 'package:voo_core/src/batching/retry_policy.dart';

/// A manager for adaptive batching with network awareness.
///
/// Features:
/// - Network-aware batch sizing
/// - Priority queuing
/// - Persistent storage
/// - Compression
/// - Retry with circuit breaker
class AdaptiveBatchManager<T> {
  final String name;
  final BatchConfig config;
  final RetryPolicy retryPolicy;
  final Future<bool> Function(List<T> items, CompressedPayload? payload) onFlush;
  final Map<String, dynamic> Function(T) itemToJson;
  final T Function(Map<String, dynamic>) itemFromJson;

  late final PersistentQueue<T> _queue;
  late final CircuitBreaker _circuitBreaker;

  Timer? _flushTimer;
  Timer? _priorityFlushTimer;
  StreamSubscription<BatchConfig>? _networkSubscription;

  BatchConfig _currentConfig;
  bool _initialized = false;
  bool _flushing = false;

  AdaptiveBatchManager({
    required this.name,
    required this.config,
    required this.onFlush,
    required this.itemToJson,
    required this.itemFromJson,
    RetryPolicy? retryPolicy,
  })  : retryPolicy = retryPolicy ?? const RetryPolicy(),
        _currentConfig = config;

  /// Whether the manager is initialized.
  bool get isInitialized => _initialized;

  /// Current batch configuration.
  BatchConfig get currentConfig => _currentConfig;

  /// Number of items pending in the queue.
  Future<int> get pendingCount => _queue.length;

  /// Initialize the batch manager.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize persistent queue
    _queue = PersistentQueue<T>(
      name: name,
      fromJson: itemFromJson,
      toJson: itemToJson,
      maxSize: config.maxQueueSize,
      maxRetention: config.maxRetention,
    );
    await _queue.initialize();

    // Initialize circuit breaker
    _circuitBreaker = CircuitBreaker(
      threshold: retryPolicy.circuitBreakerThreshold,
      cooldown: retryPolicy.circuitBreakerCooldown,
    );

    // Subscribe to network changes if enabled
    if (config.enableNetworkAwareBatching) {
      await NetworkMonitor.instance.initialize();
      _currentConfig = NetworkMonitor.instance.getOptimalConfig(config);

      _networkSubscription =
          NetworkMonitor.instance.configStream.listen((networkConfig) {
        _currentConfig = config.copyWith(
          batchSize: networkConfig.batchSize,
          batchInterval: networkConfig.batchInterval,
          priorityFlushInterval: networkConfig.priorityFlushInterval,
          compressionThreshold: networkConfig.compressionThreshold,
        );
        _restartTimers();
      });
    }

    // Start flush timers
    _startTimers();

    _initialized = true;

    // Process any items that were persisted
    final pending = await _queue.length;
    if (pending > 0 && kDebugMode) {
      debugPrint('AdaptiveBatchManager[$name]: Restored $pending items');
    }
  }

  /// Add an item to the batch queue.
  Future<void> add(T item, {BatchPriority priority = BatchPriority.normal}) async {
    if (!_initialized) return;

    await _queue.add(item, priority: priority);

    // Check if we should flush immediately
    if (priority == BatchPriority.high) {
      _schedulePriorityFlush();
    } else {
      final count = await _queue.length;
      if (count >= _currentConfig.batchSize) {
        _scheduleFlush();
      }
    }
  }

  /// Add multiple items to the batch queue.
  Future<void> addAll(
    List<T> items, {
    BatchPriority priority = BatchPriority.normal,
  }) async {
    if (!_initialized) return;

    await _queue.addAll(items, priority: priority);

    if (priority == BatchPriority.high) {
      _schedulePriorityFlush();
    } else {
      final count = await _queue.length;
      if (count >= _currentConfig.batchSize) {
        _scheduleFlush();
      }
    }
  }

  /// Flush all pending items.
  Future<bool> flush() async {
    if (!_initialized || _flushing) return true;
    if (!_circuitBreaker.allowRequest) {
      if (kDebugMode) {
        debugPrint('AdaptiveBatchManager[$name]: Circuit breaker open, skipping flush');
      }
      return false;
    }

    _flushing = true;

    try {
      while (true) {
        final items = await _queue.take(_currentConfig.batchSize);
        if (items.isEmpty) break;

        // Compress if enabled
        CompressedPayload? payload;
        if (_currentConfig.enableCompression) {
          final jsonData = items.map(itemToJson).toList();
          payload = CompressionUtils.compressJson(
            {'items': jsonData},
            threshold: _currentConfig.compressionThreshold,
            enabled: _currentConfig.enableCompression,
          );
        }

        // Attempt to send with retry
        try {
          final success = await retryWithBackoff(
            () => onFlush(items, payload),
            policy: retryPolicy,
            circuitBreaker: _circuitBreaker,
          );

          if (!success) {
            // Requeue items
            await _queue.requeue(items);
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('AdaptiveBatchManager[$name]: Flush failed: $e');
          }
          // Requeue items
          await _queue.requeue(items);
          return false;
        }
      }

      return true;
    } finally {
      _flushing = false;
    }
  }

  void _startTimers() {
    _flushTimer = Timer.periodic(_currentConfig.batchInterval, (_) {
      _scheduleFlush();
    });

    _priorityFlushTimer = Timer.periodic(
      _currentConfig.priorityFlushInterval,
      (_) {
        _schedulePriorityFlush();
      },
    );
  }

  void _restartTimers() {
    _flushTimer?.cancel();
    _priorityFlushTimer?.cancel();
    _startTimers();
  }

  void _scheduleFlush() {
    if (_flushing) return;
    scheduleMicrotask(() => flush());
  }

  void _schedulePriorityFlush() {
    if (_flushing) return;
    scheduleMicrotask(() => flush());
  }

  /// Shutdown the batch manager.
  Future<void> shutdown() async {
    _flushTimer?.cancel();
    _priorityFlushTimer?.cancel();
    await _networkSubscription?.cancel();

    // Final flush
    await flush();

    await _queue.close();
    _initialized = false;
  }

  /// Reset the circuit breaker.
  void resetCircuitBreaker() {
    _circuitBreaker.reset();
  }

  /// Clear all pending items.
  Future<void> clear() async {
    await _queue.clear();
  }
}
