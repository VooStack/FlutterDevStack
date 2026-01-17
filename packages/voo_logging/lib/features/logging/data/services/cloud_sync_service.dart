import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_core/voo_core.dart';
import 'package:voo_logging/features/logging/domain/entities/cloud_sync_config.dart';
import 'package:voo_logging/features/logging/domain/entities/log_entry.dart';

/// Service for syncing logs to a cloud backend.
///
/// Extends [BaseSyncService] from voo_core to reuse common batching,
/// retry, and HTTP logic. Adds logging-specific features:
/// - Priority queue for error/fatal logs
/// - Minimum level filtering
/// - Immediate flush for priority items
class CloudSyncService extends BaseSyncService<LogEntry> {
  final CloudSyncConfig _loggingConfig;

  /// Priority queue for error/fatal logs (flushed first).
  final Queue<LogEntry> _priorityLogs = Queue();

  /// Legacy callback for sync status changes.
  @override
  void Function(SyncStatus)? onStatusChanged;

  CloudSyncService({
    required CloudSyncConfig config,
    http.Client? client,
  })  : _loggingConfig = config,
        super(
          config: _toBaseSyncConfig(config),
          serviceName: 'CloudSyncService',
          client: client,
        );

  /// Convert CloudSyncConfig to BaseSyncConfig.
  static BaseSyncConfig _toBaseSyncConfig(CloudSyncConfig config) {
    return BaseSyncConfig(
      enabled: config.enabled,
      endpoint: config.endpoint,
      apiKey: config.apiKey,
      projectId: config.projectId,
      batchSize: config.batchSize,
      batchInterval: config.batchInterval,
      maxRetries: config.maxRetries,
      retryDelay: config.retryDelay,
      timeout: config.timeout,
      maxQueueSize: config.maxQueueSize,
      headers: config.headers,
    );
  }

  @override
  String get endpoint => _loggingConfig.logEndpoint ?? '';

  @override
  bool shouldQueueItem(LogEntry log) {
    // Check minimum level filter
    if (_loggingConfig.syncMinimumLevel != null) {
      final levelOrder = [
        'verbose',
        'debug',
        'info',
        'warning',
        'error',
        'fatal'
      ];
      final minIndex =
          levelOrder.indexOf(_loggingConfig.syncMinimumLevel!.toLowerCase());
      final logIndex = levelOrder.indexOf(log.level.name.toLowerCase());
      if (logIndex < minIndex) return false;
    }
    return true;
  }

  @override
  bool shouldFlushImmediately(LogEntry log) {
    // Flush immediately for error/fatal logs if prioritizeErrors is enabled
    if (!_loggingConfig.prioritizeErrors) return false;

    final level = log.level.name.toLowerCase();
    return level == 'error' || level == 'fatal';
  }

  /// Queue a log entry for syncing.
  /// Maintains backwards compatibility with original API.
  void queueLog(LogEntry log) {
    if (!_loggingConfig.enabled || !_loggingConfig.isValid) return;

    // Apply level filtering
    if (!shouldQueueItem(log)) return;

    // Priority queue for errors
    final isError = shouldFlushImmediately(log);

    if (isError) {
      _priorityLogs.add(log);
      // Trigger immediate sync for errors
      flush();
    } else {
      queueItem(log);
    }
  }

  @override
  Future<bool> flush() async {
    // First, move priority logs to the front of the regular queue
    while (_priorityLogs.isNotEmpty) {
      // We need to add priority logs to the front of the base queue
      // Since we can't access the private _pendingItems, we'll process them here
      final priorityLog = _priorityLogs.removeFirst();
      super.queueItem(priorityLog);
    }

    return super.flush();
  }

  /// Get the current queue size (includes priority queue).
  @override
  int get pendingCount => super.pendingCount + _priorityLogs.length;

  /// Get the current sync status.
  /// Returns [CloudSyncStatus] for backwards compatibility.
  CloudSyncStatus get syncStatus {
    if (!_loggingConfig.enabled || !_loggingConfig.isValid) {
      return CloudSyncStatus.disabled;
    }
    switch (status) {
      case SyncStatus.disabled:
        return CloudSyncStatus.disabled;
      case SyncStatus.idle:
        return CloudSyncStatus.idle;
      case SyncStatus.syncing:
        return CloudSyncStatus.syncing;
      case SyncStatus.success:
        return CloudSyncStatus.idle;
      case SyncStatus.error:
        return CloudSyncStatus.error;
    }
  }

  @override
  Map<String, dynamic> formatPayload(List<LogEntry> logs) {
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
    return 'flutter';
  }

  @override
  void dispose() {
    _priorityLogs.clear();
    super.dispose();
  }
}

/// Status of the cloud sync service.
/// Kept for backwards compatibility.
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
