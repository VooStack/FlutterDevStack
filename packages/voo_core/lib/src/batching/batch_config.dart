import 'package:flutter/foundation.dart';

/// Configuration for network-aware batching.
///
/// Adjusts batch size and intervals based on network conditions
/// to optimize battery usage and data transmission.
@immutable
class BatchConfig {
  /// Maximum items per batch.
  final int batchSize;

  /// Interval between automatic flushes.
  final Duration batchInterval;

  /// Interval for high-priority items (errors, exceptions).
  final Duration priorityFlushInterval;

  /// Enable compression for payloads over threshold.
  final bool enableCompression;

  /// Minimum payload size (bytes) to trigger compression.
  final int compressionThreshold;

  /// Maximum items in the persistent queue.
  final int maxQueueSize;

  /// Maximum retention period for queued items.
  final Duration maxRetention;

  /// Enable network-aware batching adjustments.
  final bool enableNetworkAwareBatching;

  const BatchConfig({
    this.batchSize = 100,
    this.batchInterval = const Duration(seconds: 30),
    this.priorityFlushInterval = const Duration(seconds: 5),
    this.enableCompression = true,
    this.compressionThreshold = 1024,
    this.maxQueueSize = 5000,
    this.maxRetention = const Duration(days: 7),
    this.enableNetworkAwareBatching = true,
  });

  /// Configuration optimized for WiFi connections.
  ///
  /// Larger batches, shorter intervals, less compression.
  factory BatchConfig.wifi() => const BatchConfig(
        batchSize: 100,
        batchInterval: Duration(seconds: 30),
        priorityFlushInterval: Duration(seconds: 5),
        enableCompression: true,
        compressionThreshold: 1024, // Only compress >1KB
      );

  /// Configuration optimized for cellular connections.
  ///
  /// Smaller batches, longer intervals, more compression.
  factory BatchConfig.cellular() => const BatchConfig(
        batchSize: 25,
        batchInterval: Duration(seconds: 120),
        priorityFlushInterval: Duration(seconds: 15),
        enableCompression: true,
        compressionThreshold: 512, // Compress >512B
      );

  /// Configuration for offline/airplane mode.
  ///
  /// Queue everything, don't attempt to send.
  factory BatchConfig.offline() => const BatchConfig(
        batchSize: 50,
        batchInterval: Duration(minutes: 5), // Check periodically
        priorityFlushInterval: Duration(minutes: 1),
        enableCompression: true,
        compressionThreshold: 512,
      );

  /// Configuration for development/debug.
  ///
  /// Smaller batches, shorter intervals for quick feedback.
  factory BatchConfig.debug() => const BatchConfig(
        batchSize: 10,
        batchInterval: Duration(seconds: 10),
        priorityFlushInterval: Duration(seconds: 2),
        enableCompression: false,
        compressionThreshold: 0,
      );

  /// Create a copy with modifications.
  BatchConfig copyWith({
    int? batchSize,
    Duration? batchInterval,
    Duration? priorityFlushInterval,
    bool? enableCompression,
    int? compressionThreshold,
    int? maxQueueSize,
    Duration? maxRetention,
    bool? enableNetworkAwareBatching,
  }) =>
      BatchConfig(
        batchSize: batchSize ?? this.batchSize,
        batchInterval: batchInterval ?? this.batchInterval,
        priorityFlushInterval:
            priorityFlushInterval ?? this.priorityFlushInterval,
        enableCompression: enableCompression ?? this.enableCompression,
        compressionThreshold: compressionThreshold ?? this.compressionThreshold,
        maxQueueSize: maxQueueSize ?? this.maxQueueSize,
        maxRetention: maxRetention ?? this.maxRetention,
        enableNetworkAwareBatching:
            enableNetworkAwareBatching ?? this.enableNetworkAwareBatching,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchConfig &&
          runtimeType == other.runtimeType &&
          batchSize == other.batchSize &&
          batchInterval == other.batchInterval &&
          priorityFlushInterval == other.priorityFlushInterval &&
          enableCompression == other.enableCompression &&
          compressionThreshold == other.compressionThreshold &&
          maxQueueSize == other.maxQueueSize &&
          maxRetention == other.maxRetention &&
          enableNetworkAwareBatching == other.enableNetworkAwareBatching;

  @override
  int get hashCode =>
      batchSize.hashCode ^
      batchInterval.hashCode ^
      priorityFlushInterval.hashCode ^
      enableCompression.hashCode ^
      compressionThreshold.hashCode ^
      maxQueueSize.hashCode ^
      maxRetention.hashCode ^
      enableNetworkAwareBatching.hashCode;
}

/// Network connection types.
enum NetworkType {
  /// WiFi connection.
  wifi,

  /// Cellular/mobile data connection.
  cellular,

  /// Ethernet connection.
  ethernet,

  /// No network connection.
  none,

  /// Unknown connection type.
  unknown,
}

/// Priority levels for batch items.
enum BatchPriority {
  /// High priority (errors, exceptions) - flush quickly.
  high(0),

  /// Normal priority (info logs, traces) - standard batching.
  normal(1),

  /// Low priority (debug, verbose) - can be batched longer, first dropped.
  low(2);

  final int value;
  const BatchPriority(this.value);

  /// Whether this priority should trigger immediate flush.
  bool get shouldFlushImmediately => this == BatchPriority.high;
}
