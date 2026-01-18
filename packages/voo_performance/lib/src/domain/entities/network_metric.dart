import 'package:equatable/equatable.dart';
import 'package:voo_performance/src/domain/entities/network_timing.dart';

class NetworkMetric extends Equatable {
  final String id;
  final String url;
  final String method;
  final int statusCode;
  final Duration duration;
  final DateTime timestamp;
  final int? requestSize;
  final int? responseSize;
  final Map<String, dynamic>? metadata;

  /// Detailed timing breakdown for the request.
  ///
  /// Contains granular timing info like DNS lookup, TCP connect,
  /// TLS handshake, time to first byte, and content download.
  final NetworkTiming? timing;

  /// Whether this request was served from cache.
  final bool fromCache;

  /// Request priority (low, medium, high).
  final String? priority;

  /// Initiator of the request (navigation, script, user, etc.).
  final String? initiator;

  const NetworkMetric({
    required this.id,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.duration,
    required this.timestamp,
    this.requestSize,
    this.responseSize,
    this.metadata,
    this.timing,
    this.fromCache = false,
    this.priority,
    this.initiator,
  });

  bool get isError => statusCode >= 400;
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Bandwidth in KB/s based on response size and download time.
  double? get bandwidthKBps {
    if (timing != null && responseSize != null) {
      return timing!.calculateBandwidth(responseSize!);
    }
    return null;
  }

  /// Time to first byte from timing breakdown.
  int? get timeToFirstByteMs => timing?.timeToFirstByteMs;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'method': method,
      'status_code': statusCode,
      'duration_ms': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      if (requestSize != null) 'request_size': requestSize,
      if (responseSize != null) 'response_size': responseSize,
      if (metadata != null) 'metadata': metadata,
      if (timing != null) 'timing': timing!.toJson(),
      'from_cache': fromCache,
      if (priority != null) 'priority': priority,
      if (initiator != null) 'initiator': initiator,
    };
  }

  factory NetworkMetric.fromMap(Map<String, dynamic> map) {
    return NetworkMetric(
      id: map['id'] as String,
      url: map['url'] as String,
      method: map['method'] as String,
      statusCode: map['status_code'] as int,
      duration: Duration(milliseconds: map['duration_ms'] as int),
      timestamp: DateTime.parse(map['timestamp'] as String),
      requestSize: map['request_size'] as int?,
      responseSize: map['response_size'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      timing: map['timing'] != null
          ? NetworkTiming.fromJson(map['timing'] as Map<String, dynamic>)
          : null,
      fromCache: map['from_cache'] as bool? ?? false,
      priority: map['priority'] as String?,
      initiator: map['initiator'] as String?,
    );
  }

  NetworkMetric copyWith({
    String? id,
    String? url,
    String? method,
    int? statusCode,
    Duration? duration,
    DateTime? timestamp,
    int? requestSize,
    int? responseSize,
    Map<String, dynamic>? metadata,
    NetworkTiming? timing,
    bool? fromCache,
    String? priority,
    String? initiator,
  }) =>
      NetworkMetric(
        id: id ?? this.id,
        url: url ?? this.url,
        method: method ?? this.method,
        statusCode: statusCode ?? this.statusCode,
        duration: duration ?? this.duration,
        timestamp: timestamp ?? this.timestamp,
        requestSize: requestSize ?? this.requestSize,
        responseSize: responseSize ?? this.responseSize,
        metadata: metadata ?? this.metadata,
        timing: timing ?? this.timing,
        fromCache: fromCache ?? this.fromCache,
        priority: priority ?? this.priority,
        initiator: initiator ?? this.initiator,
      );

  @override
  List<Object?> get props => [
        id,
        url,
        method,
        statusCode,
        duration,
        timestamp,
        requestSize,
        responseSize,
        metadata,
        timing,
        fromCache,
        priority,
        initiator,
      ];
}
