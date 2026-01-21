import 'package:voo_performance/src/domain/entities/network_timing.dart';

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
