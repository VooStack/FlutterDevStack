import 'package:flutter/foundation.dart';

/// Detailed timing breakdown for a network request.
///
/// This model captures granular timing information similar to
/// the Resource Timing API in browsers. In Flutter, some of these
/// metrics may not be directly available and will be null.
///
/// ## Timing Flow
///
/// ```
/// [Request Start]
///     |
///     +-- DNS Lookup (dnsLookupMs)
///     |
///     +-- TCP Connect (tcpConnectMs)
///     |
///     +-- TLS Handshake (tlsHandshakeMs) - HTTPS only
///     |
///     +-- Request Sent -> Time to First Byte (timeToFirstByteMs)
///     |
///     +-- Content Download (contentDownloadMs)
///     |
/// [Request Complete]
/// ```
@immutable
class NetworkTiming {
  /// Time spent looking up the DNS name.
  ///
  /// This is the time from when the lookup starts until the
  /// IP address is resolved. Null if using cached DNS or unavailable.
  final int? dnsLookupMs;

  /// Time spent establishing the TCP connection.
  ///
  /// This includes the TCP 3-way handshake time.
  /// Null if connection was reused or unavailable.
  final int? tcpConnectMs;

  /// Time spent on TLS/SSL handshake.
  ///
  /// Only applicable for HTTPS requests.
  /// Null for HTTP requests or if unavailable.
  final int? tlsHandshakeMs;

  /// Time from request sent to first byte received.
  ///
  /// This is often called TTFB (Time to First Byte) and represents
  /// the server processing time plus network latency.
  final int? timeToFirstByteMs;

  /// Time spent downloading the response content.
  ///
  /// From first byte received to last byte received.
  final int? contentDownloadMs;

  /// Time from connection ready to request sent.
  ///
  /// This includes time spent waiting for the connection
  /// to be available (connection pooling, etc.)
  final int? requestQueueMs;

  /// Time spent reading/parsing the response.
  ///
  /// This is after all bytes are received.
  final int? responseParsingMs;

  /// Whether this request reused an existing connection.
  final bool connectionReused;

  /// Whether HTTP/2 multiplexing was used.
  final bool http2Multiplexed;

  /// HTTP protocol version (1.0, 1.1, 2, 3).
  final String? httpVersion;

  /// Remote IP address of the server.
  final String? remoteIp;

  /// Remote port of the server.
  final int? remotePort;

  /// Number of redirects followed.
  final int redirectCount;

  /// Total time for all redirects.
  final int? redirectTimeMs;

  const NetworkTiming({
    this.dnsLookupMs,
    this.tcpConnectMs,
    this.tlsHandshakeMs,
    this.timeToFirstByteMs,
    this.contentDownloadMs,
    this.requestQueueMs,
    this.responseParsingMs,
    this.connectionReused = false,
    this.http2Multiplexed = false,
    this.httpVersion,
    this.remoteIp,
    this.remotePort,
    this.redirectCount = 0,
    this.redirectTimeMs,
  });

  /// Total connection setup time (DNS + TCP + TLS).
  int? get connectionSetupMs {
    final dns = dnsLookupMs ?? 0;
    final tcp = tcpConnectMs ?? 0;
    final tls = tlsHandshakeMs ?? 0;

    // If all are null, return null
    if (dnsLookupMs == null && tcpConnectMs == null && tlsHandshakeMs == null) {
      return null;
    }

    return dns + tcp + tls;
  }

  /// Total request-response time excluding connection setup.
  int? get requestResponseMs {
    final ttfb = timeToFirstByteMs ?? 0;
    final download = contentDownloadMs ?? 0;

    if (timeToFirstByteMs == null && contentDownloadMs == null) {
      return null;
    }

    return ttfb + download;
  }

  /// Calculated total time from all phases.
  int? get calculatedTotalMs {
    final setup = connectionSetupMs ?? 0;
    final queue = requestQueueMs ?? 0;
    final reqRes = requestResponseMs ?? 0;
    final parse = responseParsingMs ?? 0;
    final redirect = redirectTimeMs ?? 0;

    // If no timing data available, return null
    if (connectionSetupMs == null &&
        requestQueueMs == null &&
        requestResponseMs == null) {
      return null;
    }

    return setup + queue + reqRes + parse + redirect;
  }

  /// Bandwidth utilization estimate in KB/s.
  ///
  /// Calculated from content download time if available.
  double? calculateBandwidth(int contentSizeBytes) {
    if (contentDownloadMs == null || contentDownloadMs! <= 0) return null;
    if (contentSizeBytes <= 0) return null;

    // KB per second
    return (contentSizeBytes / 1024) / (contentDownloadMs! / 1000);
  }

  /// Network latency estimate (round-trip time).
  ///
  /// Uses TCP connect time as a proxy for latency.
  int? get estimatedLatencyMs => tcpConnectMs;

  /// Whether this was a cache hit (no network activity).
  bool get isCacheHit =>
      connectionSetupMs == 0 &&
      timeToFirstByteMs != null &&
      timeToFirstByteMs! < 5;

  /// Create a timing from simple start/end markers.
  factory NetworkTiming.fromTotalTime(int totalMs, {bool isHttps = true}) {
    // Estimate breakdown based on typical distributions
    // These are rough estimates when detailed timing isn't available
    if (totalMs <= 0) {
      return const NetworkTiming();
    }

    final connectionOverhead = isHttps ? 0.25 : 0.15; // TLS adds overhead
    final ttfbRatio = 0.35;
    final downloadRatio = 1.0 - connectionOverhead - ttfbRatio;

    return NetworkTiming(
      timeToFirstByteMs: (totalMs * ttfbRatio).round(),
      contentDownloadMs: (totalMs * downloadRatio).round(),
    );
  }

  /// Create timing for a connection-reuse scenario.
  factory NetworkTiming.reusedConnection({
    required int timeToFirstByteMs,
    required int contentDownloadMs,
  }) =>
      NetworkTiming(
        timeToFirstByteMs: timeToFirstByteMs,
        contentDownloadMs: contentDownloadMs,
        connectionReused: true,
      );

  Map<String, dynamic> toJson() => {
        if (dnsLookupMs != null) 'dns_lookup_ms': dnsLookupMs,
        if (tcpConnectMs != null) 'tcp_connect_ms': tcpConnectMs,
        if (tlsHandshakeMs != null) 'tls_handshake_ms': tlsHandshakeMs,
        if (timeToFirstByteMs != null) 'time_to_first_byte_ms': timeToFirstByteMs,
        if (contentDownloadMs != null) 'content_download_ms': contentDownloadMs,
        if (requestQueueMs != null) 'request_queue_ms': requestQueueMs,
        if (responseParsingMs != null) 'response_parsing_ms': responseParsingMs,
        'connection_reused': connectionReused,
        'http2_multiplexed': http2Multiplexed,
        if (httpVersion != null) 'http_version': httpVersion,
        if (remoteIp != null) 'remote_ip': remoteIp,
        if (remotePort != null) 'remote_port': remotePort,
        if (redirectCount > 0) 'redirect_count': redirectCount,
        if (redirectTimeMs != null) 'redirect_time_ms': redirectTimeMs,
        if (connectionSetupMs != null) 'connection_setup_ms': connectionSetupMs,
        if (requestResponseMs != null) 'request_response_ms': requestResponseMs,
        if (calculatedTotalMs != null) 'calculated_total_ms': calculatedTotalMs,
      };

  factory NetworkTiming.fromJson(Map<String, dynamic> json) => NetworkTiming(
        dnsLookupMs: json['dns_lookup_ms'] as int?,
        tcpConnectMs: json['tcp_connect_ms'] as int?,
        tlsHandshakeMs: json['tls_handshake_ms'] as int?,
        timeToFirstByteMs: json['time_to_first_byte_ms'] as int?,
        contentDownloadMs: json['content_download_ms'] as int?,
        requestQueueMs: json['request_queue_ms'] as int?,
        responseParsingMs: json['response_parsing_ms'] as int?,
        connectionReused: json['connection_reused'] as bool? ?? false,
        http2Multiplexed: json['http2_multiplexed'] as bool? ?? false,
        httpVersion: json['http_version'] as String?,
        remoteIp: json['remote_ip'] as String?,
        remotePort: json['remote_port'] as int?,
        redirectCount: json['redirect_count'] as int? ?? 0,
        redirectTimeMs: json['redirect_time_ms'] as int?,
      );

  NetworkTiming copyWith({
    int? dnsLookupMs,
    int? tcpConnectMs,
    int? tlsHandshakeMs,
    int? timeToFirstByteMs,
    int? contentDownloadMs,
    int? requestQueueMs,
    int? responseParsingMs,
    bool? connectionReused,
    bool? http2Multiplexed,
    String? httpVersion,
    String? remoteIp,
    int? remotePort,
    int? redirectCount,
    int? redirectTimeMs,
  }) =>
      NetworkTiming(
        dnsLookupMs: dnsLookupMs ?? this.dnsLookupMs,
        tcpConnectMs: tcpConnectMs ?? this.tcpConnectMs,
        tlsHandshakeMs: tlsHandshakeMs ?? this.tlsHandshakeMs,
        timeToFirstByteMs: timeToFirstByteMs ?? this.timeToFirstByteMs,
        contentDownloadMs: contentDownloadMs ?? this.contentDownloadMs,
        requestQueueMs: requestQueueMs ?? this.requestQueueMs,
        responseParsingMs: responseParsingMs ?? this.responseParsingMs,
        connectionReused: connectionReused ?? this.connectionReused,
        http2Multiplexed: http2Multiplexed ?? this.http2Multiplexed,
        httpVersion: httpVersion ?? this.httpVersion,
        remoteIp: remoteIp ?? this.remoteIp,
        remotePort: remotePort ?? this.remotePort,
        redirectCount: redirectCount ?? this.redirectCount,
        redirectTimeMs: redirectTimeMs ?? this.redirectTimeMs,
      );

  @override
  String toString() => 'NetworkTiming('
      'ttfb: ${timeToFirstByteMs}ms, '
      'download: ${contentDownloadMs}ms, '
      'reused: $connectionReused'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkTiming &&
          runtimeType == other.runtimeType &&
          dnsLookupMs == other.dnsLookupMs &&
          tcpConnectMs == other.tcpConnectMs &&
          tlsHandshakeMs == other.tlsHandshakeMs &&
          timeToFirstByteMs == other.timeToFirstByteMs &&
          contentDownloadMs == other.contentDownloadMs &&
          connectionReused == other.connectionReused;

  @override
  int get hashCode => Object.hash(
        dnsLookupMs,
        tcpConnectMs,
        tlsHandshakeMs,
        timeToFirstByteMs,
        contentDownloadMs,
        connectionReused,
      );
}

/// Builder for constructing NetworkTiming with incremental timestamps.
///
/// Use this when you have access to timing events as they occur.
///
/// ```dart
/// final builder = NetworkTimingBuilder()
///   ..markDnsStart()
///   ..markDnsEnd()
///   ..markTcpConnectStart()
///   ..markTcpConnectEnd()
///   ..markRequestSent()
///   ..markFirstByte()
///   ..markComplete();
///
/// final timing = builder.build();
/// ```
class NetworkTimingBuilder {
  DateTime? _dnsStart;
  DateTime? _dnsEnd;
  DateTime? _tcpStart;
  DateTime? _tcpEnd;
  DateTime? _tlsStart;
  DateTime? _tlsEnd;
  DateTime? _requestSent;
  DateTime? _firstByte;
  DateTime? _complete;
  DateTime? _queueStart;
  DateTime? _queueEnd;

  bool _connectionReused = false;
  bool _http2Multiplexed = false;
  String? _httpVersion;
  String? _remoteIp;
  int? _remotePort;
  int _redirectCount = 0;
  int? _redirectTimeMs;

  /// Mark DNS lookup start.
  void markDnsStart() => _dnsStart = DateTime.now();

  /// Mark DNS lookup end.
  void markDnsEnd() => _dnsEnd = DateTime.now();

  /// Mark TCP connection start.
  void markTcpConnectStart() => _tcpStart = DateTime.now();

  /// Mark TCP connection end.
  void markTcpConnectEnd() => _tcpEnd = DateTime.now();

  /// Mark TLS handshake start.
  void markTlsStart() => _tlsStart = DateTime.now();

  /// Mark TLS handshake end.
  void markTlsEnd() => _tlsEnd = DateTime.now();

  /// Mark when the request was sent.
  void markRequestSent() => _requestSent = DateTime.now();

  /// Mark when the first byte was received.
  void markFirstByte() => _firstByte = DateTime.now();

  /// Mark when the response is complete.
  void markComplete() => _complete = DateTime.now();

  /// Mark request queue start.
  void markQueueStart() => _queueStart = DateTime.now();

  /// Mark request queue end (request started).
  void markQueueEnd() => _queueEnd = DateTime.now();

  /// Set whether connection was reused.
  set connectionReused(bool value) => _connectionReused = value;

  /// Set whether HTTP/2 multiplexing was used.
  set http2Multiplexed(bool value) => _http2Multiplexed = value;

  /// Set the HTTP version.
  set httpVersion(String? value) => _httpVersion = value;

  /// Set the remote IP.
  set remoteIp(String? value) => _remoteIp = value;

  /// Set the remote port.
  set remotePort(int? value) => _remotePort = value;

  /// Set redirect count.
  set redirectCount(int value) => _redirectCount = value;

  /// Set total redirect time.
  set redirectTimeMs(int? value) => _redirectTimeMs = value;

  /// Build the NetworkTiming from recorded timestamps.
  NetworkTiming build() {
    int? dnsMs;
    int? tcpMs;
    int? tlsMs;
    int? ttfbMs;
    int? downloadMs;
    int? queueMs;

    if (_dnsStart != null && _dnsEnd != null) {
      dnsMs = _dnsEnd!.difference(_dnsStart!).inMilliseconds;
    }

    if (_tcpStart != null && _tcpEnd != null) {
      tcpMs = _tcpEnd!.difference(_tcpStart!).inMilliseconds;
    }

    if (_tlsStart != null && _tlsEnd != null) {
      tlsMs = _tlsEnd!.difference(_tlsStart!).inMilliseconds;
    }

    if (_requestSent != null && _firstByte != null) {
      ttfbMs = _firstByte!.difference(_requestSent!).inMilliseconds;
    }

    if (_firstByte != null && _complete != null) {
      downloadMs = _complete!.difference(_firstByte!).inMilliseconds;
    }

    if (_queueStart != null && _queueEnd != null) {
      queueMs = _queueEnd!.difference(_queueStart!).inMilliseconds;
    }

    return NetworkTiming(
      dnsLookupMs: dnsMs,
      tcpConnectMs: tcpMs,
      tlsHandshakeMs: tlsMs,
      timeToFirstByteMs: ttfbMs,
      contentDownloadMs: downloadMs,
      requestQueueMs: queueMs,
      connectionReused: _connectionReused,
      http2Multiplexed: _http2Multiplexed,
      httpVersion: _httpVersion,
      remoteIp: _remoteIp,
      remotePort: _remotePort,
      redirectCount: _redirectCount,
      redirectTimeMs: _redirectTimeMs,
    );
  }

  /// Reset the builder for reuse.
  void reset() {
    _dnsStart = null;
    _dnsEnd = null;
    _tcpStart = null;
    _tcpEnd = null;
    _tlsStart = null;
    _tlsEnd = null;
    _requestSent = null;
    _firstByte = null;
    _complete = null;
    _queueStart = null;
    _queueEnd = null;
    _connectionReused = false;
    _http2Multiplexed = false;
    _httpVersion = null;
    _remoteIp = null;
    _remotePort = null;
    _redirectCount = 0;
    _redirectTimeMs = null;
  }
}
