import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_core/src/config/base_sync_config.dart';

/// Base class for cloud sync services.
///
/// Provides common functionality for batching, queueing, retry logic,
/// and HTTP communication. Subclasses implement the specific payload
/// formatting and endpoint logic.
///
/// ## Usage
///
/// ```dart
/// class LoggingSyncService extends BaseSyncService<LogEntry> {
///   LoggingSyncService({required LoggingConfig config})
///       : super(config: config, serviceName: 'Logging');
///
///   @override
///   String get endpoint => '${config.endpoint}/api/v1/telemetry/logs';
///
///   @override
///   Map<String, dynamic> formatPayload(List<LogEntry> items) => {
///     'projectId': config.projectId,
///     'logs': items.map((e) => e.toJson()).toList(),
///   };
/// }
/// ```
abstract class BaseSyncService<T> {
  /// Configuration for the sync service.
  final BaseSyncConfig config;

  /// Name of this service (for debug logging).
  final String serviceName;

  /// HTTP client for making requests.
  final http.Client _client;

  /// Queue of items waiting to be synced.
  final Queue<T> _pendingItems = Queue();

  /// Timer for periodic batch flushing.
  Timer? _batchTimer;

  /// Flag to prevent concurrent sync operations.
  bool _isSyncing = false;

  /// Count of consecutive sync failures.
  int _consecutiveFailures = 0;

  /// Current status of the sync service.
  SyncStatus _status = SyncStatus.idle;

  /// Callback for sync status changes.
  void Function(SyncStatus status)? onStatusChanged;

  /// Callback for sync errors.
  void Function(String error, int retryCount)? onError;

  /// Creates a new sync service with the given configuration.
  BaseSyncService({
    required this.config,
    required this.serviceName,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// The endpoint URL for syncing items.
  /// Subclasses must implement this to return the appropriate endpoint.
  String get endpoint;

  /// Formats items into a JSON payload for the API.
  /// Subclasses must implement this to format their specific item types.
  Map<String, dynamic> formatPayload(List<T> items);

  /// Optional: Filter items before adding to the queue.
  /// Return true to include the item, false to skip it.
  bool shouldQueueItem(T item) => true;

  /// Optional: Check if an item should trigger immediate flush.
  /// Return true for high-priority items (e.g., errors).
  bool shouldFlushImmediately(T item) => false;

  /// Current sync status.
  SyncStatus get status => _status;

  /// Number of items waiting to be synced.
  int get pendingCount => _pendingItems.length;

  /// Number of consecutive sync failures.
  int get consecutiveFailures => _consecutiveFailures;

  /// Initialize the sync service and start the batch timer.
  void initialize() {
    if (!config.isValid) {
      _status = SyncStatus.disabled;
      if (kDebugMode) {
        debugPrint('$serviceName: Invalid configuration, sync disabled');
      }
      return;
    }

    _startBatchTimer();
    _status = SyncStatus.idle;

    if (kDebugMode) {
      debugPrint('$serviceName: Initialized with endpoint $endpoint');
    }
  }

  /// Queue an item for syncing.
  void queueItem(T item) {
    if (!config.enabled || !config.isValid) return;

    // Apply optional filtering
    if (!shouldQueueItem(item)) return;

    _pendingItems.add(item);

    // Enforce max queue size (drop oldest)
    while (_pendingItems.length > config.maxQueueSize) {
      _pendingItems.removeFirst();
    }

    // Check for immediate flush (high-priority items)
    if (shouldFlushImmediately(item)) {
      _flushNow();
      return;
    }

    // Check if batch threshold reached
    if (_pendingItems.length >= config.batchSize) {
      _flushNow();
    }
  }

  /// Queue multiple items at once.
  void queueItems(Iterable<T> items) {
    for (final item in items) {
      queueItem(item);
    }
  }

  /// Manually trigger a sync of all pending items.
  Future<bool> flush() async => _flushNow();

  /// Start the periodic batch timer.
  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(config.batchInterval, (_) {
      _flushNow();
    });
  }

  /// Flush pending items to the server.
  Future<bool> _flushNow() async {
    if (_isSyncing || !config.isValid) return false;

    // Extract items up to batch size
    final itemsToSync = <T>[];
    final count = config.batchSize;
    for (var i = 0; i < count && _pendingItems.isNotEmpty; i++) {
      itemsToSync.add(_pendingItems.removeFirst());
    }

    if (itemsToSync.isEmpty) return true;

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      final success = await _sendBatch(itemsToSync);

      if (success) {
        _consecutiveFailures = 0;
        _updateStatus(SyncStatus.success);
        return true;
      } else {
        // Re-queue failed items at the front
        for (final item in itemsToSync.reversed) {
          _pendingItems.addFirst(item);
        }
        _consecutiveFailures++;
        _updateStatus(SyncStatus.error);
        return false;
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Send a batch of items to the server with retry logic.
  Future<bool> _sendBatch(List<T> items) async {
    final payload = formatPayload(items);

    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: _buildHeaders(),
              body: jsonEncode(payload),
            )
            .timeout(config.timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint('$serviceName: Synced ${items.length} items successfully');
          }
          return true;
        }

        if (kDebugMode) {
          debugPrint(
              '$serviceName: Failed with status ${response.statusCode}: ${response.body}');
        }

        onError?.call('HTTP ${response.statusCode}: ${response.body}', attempt);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('$serviceName: Error on attempt $attempt: $e');
        }
        onError?.call(e.toString(), attempt);
      }

      // Wait before retry (exponential backoff)
      if (attempt < config.maxRetries) {
        final delay = config.getBackoffDelay(attempt);
        await Future.delayed(delay);
      }
    }

    return false;
  }

  /// Build HTTP headers for requests.
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (config.apiKey != null) {
      headers['X-API-Key'] = config.apiKey!;
    }

    if (config.projectId != null) {
      headers['X-Project-Id'] = config.projectId!;
    }

    if (config.headers != null) {
      headers.addAll(config.headers!);
    }

    return headers;
  }

  /// Update status and notify listeners.
  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      onStatusChanged?.call(newStatus);
    }
  }

  /// Dispose resources.
  @mustCallSuper
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _client.close();
  }
}
