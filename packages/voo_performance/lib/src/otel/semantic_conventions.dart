import '../domain/entities/network_metric.dart';
import '../domain/entities/network_timing.dart';

/// OpenTelemetry semantic conventions for HTTP and network attributes.
///
/// Based on OTEL semantic conventions:
/// - https://opentelemetry.io/docs/specs/semconv/http/
/// - https://opentelemetry.io/docs/specs/semconv/general/attributes/
class HttpSemanticConventions {
  // HTTP Request Attributes
  static const String httpRequestMethod = 'http.request.method';
  static const String httpRequestBodySize = 'http.request.body.size';

  // HTTP Response Attributes
  static const String httpResponseStatusCode = 'http.response.status_code';
  static const String httpResponseBodySize = 'http.response.body.size';

  // HTTP Client Metrics (OTEL semantic conventions)
  static const String httpClientRequestDuration = 'http.client.request.duration';

  // URL Attributes
  static const String urlFull = 'url.full';
  static const String urlPath = 'url.path';
  static const String urlScheme = 'url.scheme';
  static const String urlQuery = 'url.query';

  // Server Attributes
  static const String serverAddress = 'server.address';
  static const String serverPort = 'server.port';

  // Network Attributes
  static const String networkProtocolVersion = 'network.protocol.version';
  static const String networkTransport = 'network.transport';

  // User Agent
  static const String userAgentOriginal = 'user_agent.original';

  // Custom timing attributes (following OTEL naming conventions)
  static const String httpTimeDnsMs = 'http.time.dns_lookup_ms';
  static const String httpTimeTcpMs = 'http.time.tcp_connect_ms';
  static const String httpTimeTlsMs = 'http.time.tls_handshake_ms';
  static const String httpTimeTtfbMs = 'http.time.ttfb_ms';
  static const String httpTimeDownloadMs = 'http.time.content_download_ms';
  static const String httpTimeRequestQueueMs = 'http.time.request_queue_ms';
  static const String httpTimeResponseParseMs = 'http.time.response_parse_ms';
  static const String httpConnectionReused = 'http.connection.reused';

  // Error attributes
  static const String errorType = 'error.type';
  static const String exceptionType = 'exception.type';
  static const String exceptionMessage = 'exception.message';
  static const String exceptionStacktrace = 'exception.stacktrace';

  /// Convert NetworkMetric to OTEL span attributes.
  static Map<String, dynamic> fromNetworkMetric(NetworkMetric metric) {
    final uri = Uri.tryParse(metric.url);

    final attributes = <String, dynamic>{
      httpRequestMethod: metric.method,
      httpResponseStatusCode: metric.statusCode,
      urlFull: metric.url,
      'http.duration_ms': metric.duration.inMilliseconds,
    };

    // URL components
    if (uri != null) {
      attributes[urlPath] = uri.path;
      attributes[urlScheme] = uri.scheme;
      attributes[serverAddress] = uri.host;
      if (uri.hasPort) {
        attributes[serverPort] = uri.port;
      }
      if (uri.hasQuery) {
        attributes[urlQuery] = uri.query;
      }
    }

    // Request/response sizes
    if (metric.requestSize != null) {
      attributes[httpRequestBodySize] = metric.requestSize;
    }
    if (metric.responseSize != null) {
      attributes[httpResponseBodySize] = metric.responseSize;
    }

    // Cache
    if (metric.fromCache) {
      attributes['http.cache.hit'] = true;
    }

    // Priority and initiator
    if (metric.priority != null) {
      attributes['http.priority'] = metric.priority;
    }
    if (metric.initiator != null) {
      attributes['http.initiator'] = metric.initiator;
    }

    // Timing breakdown
    final timingAttrs = _timingAttributes(metric.timing);
    if (timingAttrs != null) {
      attributes.addAll(timingAttrs);
    }

    // Error info from metadata
    if (metric.metadata != null) {
      final error = metric.metadata!['error'];
      if (error != null) {
        attributes[errorType] = error.toString();
      }
    }

    return attributes;
  }

  /// Extract timing attributes from NetworkTiming.
  static Map<String, dynamic>? _timingAttributes(NetworkTiming? timing) {
    if (timing == null) return null;

    final attributes = <String, dynamic>{};

    if (timing.dnsLookupMs != null) {
      attributes[httpTimeDnsMs] = timing.dnsLookupMs;
    }
    if (timing.tcpConnectMs != null) {
      attributes[httpTimeTcpMs] = timing.tcpConnectMs;
    }
    if (timing.tlsHandshakeMs != null) {
      attributes[httpTimeTlsMs] = timing.tlsHandshakeMs;
    }
    if (timing.timeToFirstByteMs != null) {
      attributes[httpTimeTtfbMs] = timing.timeToFirstByteMs;
    }
    if (timing.contentDownloadMs != null) {
      attributes[httpTimeDownloadMs] = timing.contentDownloadMs;
    }
    if (timing.requestQueueMs != null) {
      attributes[httpTimeRequestQueueMs] = timing.requestQueueMs;
    }
    // responseParseMs not currently available in NetworkTiming

    attributes[httpConnectionReused] = timing.connectionReused;

    if (timing.httpVersion != null) {
      attributes[networkProtocolVersion] = timing.httpVersion;
    }
    if (timing.remoteIp != null) {
      attributes['server.socket.address'] = timing.remoteIp;
    }
    if (timing.remotePort != null) {
      attributes['server.socket.port'] = timing.remotePort;
    }

    return attributes.isEmpty ? null : attributes;
  }

  /// Get standard HTTP span name following OTEL conventions.
  ///
  /// Format: "HTTP {method}" for client spans.
  static String getHttpSpanName(String method) => 'HTTP $method';

  /// Determine if status code indicates an error.
  static bool isErrorStatus(int statusCode) => statusCode >= 400;

  /// Get error description from status code.
  static String? getErrorDescription(int statusCode) {
    if (statusCode >= 400 && statusCode < 500) {
      return 'HTTP client error $statusCode';
    } else if (statusCode >= 500) {
      return 'HTTP server error $statusCode';
    }
    return null;
  }
}

/// App-specific semantic conventions for performance monitoring.
class AppSemanticConventions {
  // App lifecycle
  static const String appLaunchType = 'app.launch.type';
  static const String appLaunchDurationMs = 'app.launch.duration_ms';
  static const String appLaunchTtffMs = 'app.launch.time_to_first_frame_ms';
  static const String appLaunchTtiMs = 'app.launch.time_to_interactive_ms';
  static const String appLaunchIsSuccessful = 'app.launch.is_successful';
  static const String appLaunchIsSlow = 'app.launch.is_slow';

  // Rendering
  static const String appRenderFps = 'app.render.fps';
  static const String appRenderJankCount = 'app.render.jank_count';
  static const String appRenderFrameDurationMs = 'app.render.frame_duration_ms';
  static const String appRenderIsJanky = 'app.render.is_janky';

  // Memory
  static const String processRuntimeDartHeapUsage = 'process.runtime.dart.heap_usage';
  static const String processRuntimeDartExternalUsage = 'process.runtime.dart.external_usage';
  static const String processRuntimeDartHeapCapacity = 'process.runtime.dart.heap_capacity';
  static const String memoryPressureLevel = 'memory.pressure_level';
  static const String memoryIsUnderPressure = 'memory.is_under_pressure';

  // Custom trace
  static const String traceCategory = 'trace.category';
  static const String traceDomain = 'trace.domain';
  static const String traceOperation = 'trace.operation';
}

/// Resource attributes for service identification.
class ResourceSemanticConventions {
  static const String serviceName = 'service.name';
  static const String serviceVersion = 'service.version';
  static const String serviceNamespace = 'service.namespace';
  static const String serviceInstanceId = 'service.instance.id';

  static const String telemetrySdkName = 'telemetry.sdk.name';
  static const String telemetrySdkVersion = 'telemetry.sdk.version';
  static const String telemetrySdkLanguage = 'telemetry.sdk.language';

  static const String deploymentEnvironment = 'deployment.environment';

  static const String deviceId = 'device.id';
  static const String deviceModelName = 'device.model.name';
  static const String osType = 'os.type';
  static const String osVersion = 'os.version';
}
