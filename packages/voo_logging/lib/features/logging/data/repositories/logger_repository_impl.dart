import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';
import 'package:voo_logging/features/logging/data/datasources/local_log_storage.dart';
import 'package:voo_logging/features/logging/domain/utils/pretty_log_formatter.dart';
import 'package:voo_logging/voo_logging.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

/// Callback for external error capture (e.g., replay capture).
typedef ErrorCaptureCallback = void Function({
  required String message,
  String? errorType,
  String? stackTrace,
});

class LoggerRepositoryImpl extends LoggerRepository {
  LocalLogStorage? _storage;
  String? _currentUserId;
  String? _currentSessionId;
  LogLevel _minimumLevel = LogLevel.debug;
  bool _enabled = true;
  String? _appName;
  String? _appVersion;
  int _logCounter = 0;
  LoggingConfig _config = const LoggingConfig();
  late PrettyLogFormatter _formatter;

  /// Whether OTEL export is enabled (via VooTelemetry).
  bool _otelEnabled = false;

  /// Optional callback for external error capture (e.g., session replay).
  /// Set this to forward error logs to replay capture service.
  ErrorCaptureCallback? onErrorCaptured;

  final _random = Random();

  /// Get the number of pending logs in the OTEL export queue.
  /// Returns 0 as logs are now managed by VooTelemetry's LoggerProvider.
  int get pendingExportCount => 0;

  final StreamController<LogEntry> _logStreamController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry>? _cachedStream;

  @override
  Stream<LogEntry> get stream {
    // Return cached stream if it exists
    _cachedStream ??= _createStream();
    return _cachedStream!;
  }

  // ignore: prefer_expression_function_bodies
  Stream<LogEntry> _createStream() {
    // Return the broadcast stream directly, without any initial messages
    // This ensures all subscribers get all logs after subscription
    return _logStreamController.stream.handleError((Object error, StackTrace stackTrace) {
      // Log the error internally if possible
      developer.log(
        'VooLogger stream error: $error',
        name: 'VooLogger',
        error: error,
        stackTrace: stackTrace,
        level: 800, // Warning level
      );

      // Create an error log entry
      return LogEntry(
        id: 'stream_error_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        message: 'Stream error occurred: ${error.toString()}',
        level: LogLevel.error,
        category: 'System',
        tag: 'StreamError',
        error: error,
        stackTrace: stackTrace.toString(),
      );
    });
  }

  @override
  Future<void> initialize({
    LogLevel minimumLevel = LogLevel.debug,
    String? userId,
    String? sessionId,
    String? appName,
    String? appVersion,
    bool enabled = true,
    LoggingConfig? config,
  }) async {
    _config = config ?? LoggingConfig(minimumLevel: minimumLevel);
    _formatter = _config.formatter;
    _minimumLevel = _config.minimumLevel;
    _currentUserId = userId;
    _currentSessionId = sessionId ?? _generateSessionId();
    _appName = appName;
    _appVersion = appVersion;
    _enabled = _config.enabled;

    _storage = LocalLogStorage();

    // Perform automatic cleanup if enabled
    int cleanedLogs = 0;
    if (_config.autoCleanup && (_config.maxLogs != null || _config.retentionDays != null)) {
      cleanedLogs = await _storage!.performCleanup(maxLogs: _config.maxLogs, retentionDays: _config.retentionDays);
    }

    // CloudSync is deprecated - skip initialization even if configured
    // All telemetry should go through VooTelemetry OTLP endpoints
    if (_config.cloudSync != null) {
      developer.log(
        'CloudSync is deprecated and will be ignored. Use VooTelemetry instead.',
        name: 'VooLogger',
        level: 800, // Warning
      );
    }

    // OtelLoggingConfig is deprecated - logs now route through VooTelemetry
    if (_config.otelConfig != null) {
      developer.log(
        'OtelLoggingConfig is deprecated. Logs are now routed through VooTelemetry automatically.',
        name: 'VooLogger',
        level: 800, // Warning
      );
    }

    // Auto-enable OTEL export when VooTelemetry is initialized
    // This provides seamless telemetry without manual configuration
    _otelEnabled = VooTelemetry.isInitialized;

    if (_otelEnabled && kDebugMode) {
      developer.log(
        'VooLogger: OTEL export enabled via VooTelemetry',
        name: 'VooLogger',
        level: 500, // Info
      );
    }

    await _logInternal(
      'VooLogger initialized',
      category: 'System',
      tag: 'Init',
      metadata: {
        'minimumLevel': _config.minimumLevel.name,
        'userId': userId,
        'sessionId': _currentSessionId,
        'appName': appName,
        'appVersion': appVersion,
        'prettyLogs': _config.enablePrettyLogs,
        'maxLogs': _config.maxLogs,
        'retentionDays': _config.retentionDays,
        'autoCleanup': _config.autoCleanup,
        'otelEnabled': _otelEnabled,
        'otelViaVooTelemetry': _otelEnabled,
        if (cleanedLogs > 0) 'cleanedLogs': cleanedLogs,
      },
    );
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random.nextInt(1000);
    return '${timestamp}_$randomPart';
  }

  String _generateLogId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final counter = ++_logCounter;
    final randomPart = _random.nextInt(1000);
    return '${timestamp}_${counter}_$randomPart';
  }

  Future<void> _logInternal(
    String message, {
    LogLevel level = LogLevel.info,
    String? category,
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
    String? userId,
    String? sessionId,
  }) async {
    if (!_enabled) {
      return;
    }

    // Get type-specific configuration
    final logType = LoggingConfig.mapCategoryToLogType(category);
    final hasTypeConfig = _config.logTypeConfigs.containsKey(logType);

    if (hasTypeConfig) {
      // Type-specific config exists, use its minimum level
      final typeConfig = _config.logTypeConfigs[logType];
      if (level.priority < typeConfig!.minimumLevel.priority) {
        return;
      }
    } else {
      // No type-specific config, use global minimum
      if (level.priority < _minimumLevel.priority) {
        return;
      }
    }

    // Get the effective config for console/devtools/storage settings
    final typeConfig = _config.getConfigForCategory(category);

    final entry = LogEntry(
      id: _generateLogId(),
      timestamp: DateTime.now(),
      message: message,
      level: level,
      category: category,
      tag: tag,
      metadata: _enrichMetadata(metadata),
      error: error,
      stackTrace: stackTrace?.toString(),
      userId: userId ?? _currentUserId,
      sessionId: sessionId ?? _currentSessionId,
    );

    // Only log to console if enabled for this log type
    if (typeConfig.enableConsoleOutput) {
      _logToDevTools(entry);
    }

    // Only send to DevTools if enabled for this log type
    if (typeConfig.enableDevToolsOutput) {
      _sendStructuredLogToDevTools(entry);
    }

    // Safely add to stream controller with error handling
    if (!_logStreamController.isClosed) {
      try {
        _logStreamController.add(entry);
      } catch (e) {
        // If stream is closed or errored, log to developer console as fallback
        developer.log(
          'Failed to add log to stream: ${e.toString()}',
          name: 'VooLogger',
          error: e,
          level: 900, // Error level
        );
      }
    } else {
      // Stream is closed, log a warning
      developer.log(
        'VooLogger stream is closed. Log entry not added to stream.',
        name: 'VooLogger',
        level: 800, // Warning level
      );
    }

    // Only store if storage is enabled for this log type
    if (typeConfig.enableStorage) {
      await _storage?.insertLog(entry).catchError((_) => null);
    }

    // Export to OTEL via VooTelemetry if enabled
    if (_otelEnabled && VooTelemetry.isInitialized) {
      _exportToVooTelemetry(entry);
    }

    // Notify error tracking for error-level logs
    if (level == LogLevel.error || level == LogLevel.fatal) {
      // Always submit to VooErrorTrackingService if enabled (automatic)
      if (VooErrorTrackingService.instance.isEnabled) {
        VooErrorTrackingService.instance.submitError(
          message: message,
          errorType: error?.runtimeType.toString(),
          stackTrace: stackTrace?.toString(),
          severity: level == LogLevel.fatal ? 'critical' : 'high',
          isFatal: level == LogLevel.fatal,
        );
      }

      // Also notify any custom error capture callback (e.g., replay capture)
      if (onErrorCaptured != null) {
        try {
          onErrorCaptured!(
            message: message,
            errorType: error?.runtimeType.toString(),
            stackTrace: stackTrace?.toString(),
          );
        } catch (_) {
          // Silent fail - replay capture is optional
        }
      }
    }
  }

  Map<String, dynamic>? _enrichMetadata(Map<String, dynamic>? userMetadata) {
    final enriched = <String, dynamic>{};

    if (_appName != null) enriched['appName'] = _appName;
    if (_appVersion != null) enriched['appVersion'] = _appVersion;
    enriched['timestamp'] = DateTime.now().toIso8601String();

    if (userMetadata != null) {
      enriched.addAll(userMetadata);
    }

    return enriched.isEmpty ? null : enriched;
  }

  void _logToDevTools(LogEntry entry) {
    try {
      // Use pretty formatter for console output
      final formattedMessage = _formatter.format(entry);

      // Always use developer.log but with formatted output
      developer.log(
        formattedMessage,
        name: entry.category ?? 'VooLogger',
        level: entry.level.priority,
        error: _config.enablePrettyLogs ? null : entry.error, // Don't duplicate error in pretty mode
        stackTrace: _config.enablePrettyLogs ? null : (entry.stackTrace != null ? StackTrace.fromString(entry.stackTrace!) : null),
        sequenceNumber: entry.timestamp.millisecondsSinceEpoch,
        time: entry.timestamp,
        zone: Zone.current,
      );
      // ignore: empty_catches
    } catch (e) {}
  }

  void _sendStructuredLogToDevTools(LogEntry entry) {
    try {
      // Create entry data, filtering out null values for web compatibility
      final entryData = <String, dynamic>{'id': entry.id, 'timestamp': entry.timestamp.toIso8601String(), 'message': entry.message, 'level': entry.level.name};

      // Add non-null fields
      if (entry.category != null) entryData['category'] = entry.category;
      if (entry.tag != null) entryData['tag'] = entry.tag;
      if (entry.metadata != null) {
        // Filter out null values from metadata for web compatibility
        final cleanMetadata = <String, dynamic>{};
        entry.metadata!.forEach((key, value) {
          if (value != null) cleanMetadata[key] = value;
        });
        if (cleanMetadata.isNotEmpty) entryData['metadata'] = cleanMetadata;
      }
      if (entry.error != null) entryData['error'] = entry.error.toString();
      if (entry.stackTrace != null) entryData['stackTrace'] = entry.stackTrace;
      if (entry.userId != null) entryData['userId'] = entry.userId;
      if (entry.sessionId != null) entryData['sessionId'] = entry.sessionId;

      final structuredData = {'__voo_logger__': true, 'entry': entryData};

      // Only send JSON to console if explicitly enabled
      if (_config.enableDevToolsJson) {
        developer.log(jsonEncode(structuredData), name: 'VooLogger', level: entry.level.priority, time: entry.timestamp);
      }

      // Always send postEvent for DevTools integration (doesn't appear in console)
      developer.postEvent('voo_log_event', structuredData);
    } catch (_) {
      // Silent fail - logging is best effort
    }
  }

  @override
  Future<void> verbose(String message, {String? category, String? tag, Map<String, dynamic>? metadata}) async {
    await _logInternal(message, level: LogLevel.verbose, category: category, tag: tag, metadata: metadata);
  }

  @override
  Future<void> debug(String message, {String? category, String? tag, Map<String, dynamic>? metadata}) async {
    await _logInternal(message, level: LogLevel.debug, category: category, tag: tag, metadata: metadata);
  }

  @override
  Future<void> info(String message, {String? category, String? tag, Map<String, dynamic>? metadata}) async {
    await _logInternal(message, category: category, tag: tag, metadata: metadata);
  }

  @override
  Future<void> warning(String message, {String? category, String? tag, Map<String, dynamic>? metadata}) async {
    await _logInternal(message, level: LogLevel.warning, category: category, tag: tag, metadata: metadata);
  }

  @override
  Future<void> error(String message, {Object? error, StackTrace? stackTrace, String? category, String? tag, Map<String, dynamic>? metadata}) async {
    await _logInternal(message, level: LogLevel.error, category: category, tag: tag, metadata: metadata, error: error, stackTrace: stackTrace);
  }

  @override
  Future<void> fatal(String message, {Object? error, StackTrace? stackTrace, String? category, String? tag, Map<String, dynamic>? metadata}) async {
    await _logInternal(message, level: LogLevel.fatal, category: category, tag: tag, metadata: metadata, error: error, stackTrace: stackTrace);
  }

  @override
  Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    String? category,
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await _logInternal(message, level: level, category: category, tag: tag, metadata: metadata, error: error, stackTrace: stackTrace);
  }

  @override
  Future<void> setUserId(String? userId) async => _currentUserId = userId;

  @override
  void startNewSession([String? sessionId]) {
    _currentSessionId = sessionId ?? _generateSessionId();
    info('New session started', category: 'System', tag: 'Session', metadata: {'sessionId': _currentSessionId});
  }

  Future<void> setMinimumLevel(LogLevel level) async => _minimumLevel = level;

  Future<void> setEnabled(bool enabled) async => _enabled = enabled;

  Future<List<LogEntry>> queryLogs({
    List<LogLevel>? levels,
    List<String>? categories,
    List<String>? tags,
    String? messagePattern,
    DateTime? startTime,
    DateTime? endTime,
    String? userId,
    String? sessionId,
    int limit = 1000,
    int offset = 0,
    bool ascending = false,
  }) async =>
      await _storage?.queryLogs(
        levels: levels,
        categories: categories,
        tags: tags,
        messagePattern: messagePattern,
        startTime: startTime,
        endTime: endTime,
        userId: userId,
        sessionId: sessionId,
        limit: limit,
        offset: offset,
        ascending: ascending,
      ) ??
      [];

  @override
  Future<LogStatistics> getStatistics() async => await _storage?.getLogStatistics() ?? LogStatistics(totalLogs: 0, levelCounts: {}, categoryCounts: {});

  Future<List<String>> getCategories() async => await _storage?.getUniqueCategories() ?? [];

  Future<List<String>> getTags() async => await _storage?.getUniqueTags() ?? [];

  Future<List<String>> getSessions() async => await _storage?.getUniqueSessions() ?? [];

  @override
  Future<void> clearLogs({DateTime? olderThan, List<LogLevel>? levels, List<String>? categories}) async {
    await _storage?.clearLogs(olderThan: olderThan, levels: levels, categories: categories);
  }

  @override
  Future<void> networkRequest(String method, String url, {Map<String, String>? headers, dynamic body, Map<String, dynamic>? metadata}) async {
    await info(
      '$method $url',
      category: 'Network',
      tag: 'Request',
      metadata: {'method': method, 'url': url, 'headers': headers, 'hasBody': body != null, ...?metadata},
    );
  }

  @override
  Future<void> networkResponse(
    int statusCode,
    String url,
    Duration duration, {
    Map<String, String>? headers,
    int? contentLength,
    Map<String, dynamic>? metadata,
  }) async {
    final level = statusCode >= 400 ? LogLevel.error : LogLevel.info;

    await log(
      'Response $statusCode for $url (${duration.inMilliseconds}ms)',
      level: level,
      category: 'Network',
      tag: 'Response',
      metadata: {'statusCode': statusCode, 'url': url, 'duration': duration.inMilliseconds, 'headers': headers, 'contentLength': contentLength, ...?metadata},
    );
  }

  @override
  Future<void> userAction(String action, {String? screen, Map<String, dynamic>? properties}) async {
    await info(
      'User action: $action',
      category: 'Analytics',
      tag: 'UserAction',
      metadata: {'action': action, 'screen': screen, 'properties': properties, 'userId': _currentUserId},
    );
  }

  @override
  Future<List<LogEntry>> getLogs({LogFilter? filter}) async {
    if (_storage == null) return [];

    if (filter != null) {
      return _storage!.queryLogs(
        levels: filter.levels,
        categories: filter.categories,
        tags: filter.tags,
        messagePattern: filter.searchQuery,
        startTime: filter.startTime,
        endTime: filter.endTime,
        userId: filter.userId,
        sessionId: filter.sessionId,
      );
    } else {
      // Return all logs if no filter provided
      return _storage!.queryLogs();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> exportLogs() async {
    final logs = await getLogs();
    return logs
        .map(
          (LogEntry log) => {
            'id': log.id,
            'timestamp': log.timestamp.toIso8601String(),
            'level': log.level.name,
            'message': log.message,
            'category': log.category,
            'tag': log.tag,
            'userId': log.userId,
            'sessionId': log.sessionId,
            'metadata': log.metadata,
            'error': log.error?.toString(),
            'stackTrace': log.stackTrace,
          },
        )
        .toList();
  }

  /// Manually flush pending log exports.
  Future<bool> flushExports() async {
    if (_otelEnabled && VooTelemetry.isInitialized) {
      await VooTelemetry.instance.loggerProvider.flush();
      return true;
    }
    return false;
  }

  /// Export a log entry to VooTelemetry.
  void _exportToVooTelemetry(LogEntry entry) {
    try {
      // Get current trace context for correlation
      final traceContext = VooTelemetry.instance.currentTraceContext;

      // Create log record through VooTelemetry
      final logRecord = VooTelemetry.createLogRecord(
        message: entry.message,
        severity: _logLevelToSeverity(entry.level),
        timestamp: entry.timestamp,
        category: entry.category,
        tag: entry.tag,
        metadata: entry.metadata,
        error: entry.error,
        stackTrace: entry.stackTrace,
        userId: entry.userId ?? _currentUserId,
        sessionId: entry.sessionId ?? _currentSessionId,
        traceId: traceContext?.traceId,
        spanId: traceContext?.spanId,
      );

      // Add to VooTelemetry's logger provider
      VooTelemetry.instance.addLogRecord(logRecord);
    } catch (e) {
      if (kDebugMode) {
        developer.log(
          'VooLogger: Failed to export to VooTelemetry: $e',
          name: 'VooLogger',
          level: 800, // Warning
        );
      }
    }
  }

  /// Convert LogLevel to OTEL SeverityNumber.
  SeverityNumber _logLevelToSeverity(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return SeverityNumber.trace;
      case LogLevel.debug:
        return SeverityNumber.debug;
      case LogLevel.info:
        return SeverityNumber.info;
      case LogLevel.warning:
        return SeverityNumber.warn;
      case LogLevel.error:
        return SeverityNumber.error;
      case LogLevel.fatal:
        return SeverityNumber.fatal;
    }
  }

  void close() {
    try {
      // Disable OTEL export (VooTelemetry manages its own lifecycle)
      _otelEnabled = false;

      if (!_logStreamController.isClosed) {
        // Send a final log before closing
        final finalEntry = LogEntry(
          id: 'stream_close_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          message: 'VooLogger stream closing',
          level: LogLevel.info,
          category: 'System',
          tag: 'StreamClose',
        );

        _logStreamController.add(finalEntry);
        _logStreamController.close();

        developer.log(
          'VooLogger stream closed successfully',
          name: 'VooLogger',
          level: 100, // Info level
        );
      }
    } catch (e) {
      developer.log(
        'Error closing VooLogger stream: ${e.toString()}',
        name: 'VooLogger',
        error: e,
        level: 900, // Error level
      );
    }
  }
}
