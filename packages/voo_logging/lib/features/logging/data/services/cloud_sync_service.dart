import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_logging/features/logging/domain/entities/cloud_sync_config.dart';
import 'package:voo_logging/features/logging/domain/entities/log_entry.dart';

/// Service for syncing logs to a cloud backend.
///
/// Features:
/// - Automatic batching with configurable size and interval
/// - Retry logic with exponential backoff
/// - Priority queue for error logs
/// - Offline queue management
/// - Thread-safe operations
class CloudSyncService {
  final CloudSyncConfig config;
  final http.Client _client;

  final Queue<LogEntry> _pendingLogs = Queue();
  final Queue<LogEntry> _priorityLogs = Queue();
  Timer? _batchTimer;
  bool _isSyncing = false;
  int _consecutiveFailures = 0;

  /// Callback for sync status changes.
  void Function(CloudSyncStatus)? onStatusChanged;

  /// Callback for sync errors.
  void Function(String error, int retryCount)? onError;

  CloudSyncService({required this.config, http.Client? client}) : _client = client ?? http.Client();

  /// Initialize the sync service and start the batch timer.
  void initialize() {
    if (!config.isValid) {
      debugPrint('CloudSyncService: Invalid configuration, sync disabled');
      return;
    }

    _startBatchTimer();
    debugPrint('CloudSyncService: Initialized with endpoint ${config.logEndpoint}');
  }

  /// Queue a log entry for syncing.
  void queueLog(LogEntry log) {
    if (!config.enabled || !config.isValid) return;

    // Check minimum level filter
    if (config.syncMinimumLevel != null) {
      final levelOrder = ['verbose', 'debug', 'info', 'warning', 'error', 'fatal'];
      final minIndex = levelOrder.indexOf(config.syncMinimumLevel!.toLowerCase());
      final logIndex = levelOrder.indexOf(log.level.name.toLowerCase());
      if (logIndex < minIndex) return;
    }

    // Priority queue for errors
    final isError = log.level.name.toLowerCase() == 'error' || log.level.name.toLowerCase() == 'fatal';

    if (isError && config.prioritizeErrors) {
      _priorityLogs.add(log);
      // Trigger immediate sync for errors
      _flushNow();
    } else {
      _pendingLogs.add(log);

      // Enforce max queue size
      while (_pendingLogs.length > config.maxQueueSize) {
        _pendingLogs.removeFirst();
      }
    }

    // Check if batch threshold reached
    if (_pendingLogs.length >= config.batchSize) {
      _flushNow();
    }
  }

  /// Manually trigger a sync of all pending logs.
  Future<bool> flush() async => _flushNow();

  /// Get the current queue size.
  int get pendingCount => _pendingLogs.length + _priorityLogs.length;

  /// Get the current sync status.
  CloudSyncStatus get status {
    if (!config.enabled || !config.isValid) return CloudSyncStatus.disabled;
    if (_isSyncing) return CloudSyncStatus.syncing;
    if (_consecutiveFailures > 0) return CloudSyncStatus.error;
    return CloudSyncStatus.idle;
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(config.batchInterval, (_) {
      _flushNow();
    });
  }

  Future<bool> _flushNow() async {
    if (_isSyncing || !config.isValid) return false;

    // Combine priority and regular logs
    final logsToSync = <LogEntry>[];

    // Add all priority logs first
    while (_priorityLogs.isNotEmpty) {
      logsToSync.add(_priorityLogs.removeFirst());
    }

    // Add regular logs up to batch size
    final regularCount = config.batchSize - logsToSync.length;
    for (var i = 0; i < regularCount && _pendingLogs.isNotEmpty; i++) {
      logsToSync.add(_pendingLogs.removeFirst());
    }

    if (logsToSync.isEmpty) return true;

    _isSyncing = true;
    onStatusChanged?.call(CloudSyncStatus.syncing);

    try {
      final success = await _sendBatch(logsToSync);

      if (success) {
        _consecutiveFailures = 0;
        onStatusChanged?.call(CloudSyncStatus.idle);
        return true;
      } else {
        // Re-queue failed logs
        for (final log in logsToSync.reversed) {
          _pendingLogs.addFirst(log);
        }
        _consecutiveFailures++;
        onStatusChanged?.call(CloudSyncStatus.error);
        return false;
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _sendBatch(List<LogEntry> logs) async {
    final endpoint = config.logEndpoint;
    if (endpoint == null) return false;

    final payload = _formatPayload(logs);

    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        final response = await _client.post(Uri.parse(endpoint), headers: _buildHeaders(), body: jsonEncode(payload)).timeout(config.timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint('CloudSyncService: Synced ${logs.length} logs successfully');
          }
          return true;
        }

        if (kDebugMode) {
          debugPrint('CloudSyncService: Failed with status ${response.statusCode}: ${response.body}');
        }

        onError?.call('HTTP ${response.statusCode}: ${response.body}', attempt);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CloudSyncService: Error on attempt $attempt: $e');
        }
        onError?.call(e.toString(), attempt);
      }

      // Wait before retry (exponential backoff)
      if (attempt < config.maxRetries) {
        final delay = config.retryDelay * (1 << attempt);
        await Future.delayed(delay);
      }
    }

    return false;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (config.apiKey != null) {
      headers['X-API-Key'] = config.apiKey!;
    }

    if (config.headers != null) {
      headers.addAll(config.headers!);
    }

    return headers;
  }

  Map<String, dynamic> _formatPayload(List<LogEntry> logs) {
    // Get common fields from first log entry
    final firstLog = logs.isNotEmpty ? logs.first : null;
    return {
      'logs': logs.map(_formatLogEntry).toList(),
      'sessionId': firstLog?.sessionId ?? '',
      'deviceId': firstLog?.deviceId ?? '',
      'platform': _getPlatform(),
      'appVersion': firstLog?.appVersion ?? '',
    };
  }

  Map<String, dynamic> _formatLogEntry(LogEntry log) => {
    'level': log.level.name.toLowerCase(),
    'message': log.message,
    'category': log.category ?? '',
    'context': log.metadata ?? {},
    'stackTrace': log.stackTrace,
    'timestamp': log.timestamp.toIso8601String(),
  };

  String _getPlatform() {
    if (kIsWeb) return 'web';
    // Platform detection would go here for native platforms
    return 'flutter';
  }

  /// Dispose resources.
  void dispose() {
    _batchTimer?.cancel();
    _client.close();
  }
}

/// Status of the cloud sync service.
enum CloudSyncStatus {
  /// Sync is disabled or not configured.
  disabled,

  /// Service is idle, ready to sync.
  idle,

  /// Currently syncing logs.
  syncing,

  /// Recent sync failed.
  error,
}
