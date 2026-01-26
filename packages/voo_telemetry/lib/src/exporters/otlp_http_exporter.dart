import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voo_core/voo_core.dart';
import 'package:voo_telemetry/src/core/telemetry_resource.dart';

/// OTLP HTTP exporter for sending telemetry data
class OTLPHttpExporter {
  final String endpoint;
  String? apiKey;
  final bool debug;
  final http.Client _client;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableCompression;
  final int compressionThreshold;
  final Random _random = Random();

  OTLPHttpExporter({
    required this.endpoint,
    this.apiKey,
    this.debug = false,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCompression = true,
    this.compressionThreshold = 1024,
  }) : _client = client ?? http.Client();

  /// Set the API key used for OTLP export.
  /// Call this when the user selects a different project.
  set apiKeyValue(String? newApiKey) {
    apiKey = newApiKey;
  }

  /// Export traces to OTLP endpoint
  Future<bool> exportTraces(List<Map<String, dynamic>> spans, TelemetryResource resource) async {
    if (spans.isEmpty) return true;

    final url = Uri.parse('$endpoint/v1/traces');
    final body = {
      'resourceSpans': [
        {
          'resource': resource.toOtlp(),
          'scopeSpans': [
            {
              'scope': {'name': 'voo-telemetry', 'version': '2.0.0'},
              'spans': spans,
            },
          ],
        },
      ],
    };

    return _sendRequest(url, body);
  }

  /// Export metrics to OTLP endpoint
  Future<bool> exportMetrics(List<Map<String, dynamic>> metrics, TelemetryResource resource) async {
    if (metrics.isEmpty) return true;

    final url = Uri.parse('$endpoint/v1/metrics');
    final body = {
      'resourceMetrics': [
        {
          'resource': resource.toOtlp(),
          'scopeMetrics': [
            {
              'scope': {'name': 'voo-telemetry', 'version': '2.0.0'},
              'metrics': metrics,
            },
          ],
        },
      ],
    };

    return _sendRequest(url, body);
  }

  /// Export logs to OTLP endpoint
  Future<bool> exportLogs(List<Map<String, dynamic>> logRecords, TelemetryResource resource) async {
    if (logRecords.isEmpty) return true;

    final url = Uri.parse('$endpoint/v1/logs');
    final body = {
      'resourceLogs': [
        {
          'resource': resource.toOtlp(),
          'scopeLogs': [
            {
              'scope': {'name': 'voo-telemetry', 'version': '2.0.0'},
              'logRecords': logRecords,
            },
          ],
        },
      ],
    };

    return _sendRequest(url, body);
  }

  /// Export combined telemetry (traces, metrics, logs) in a single request.
  ///
  /// This reduces the number of HTTP requests from 3 to 1 per flush cycle.
  /// Returns [CombinedExportResult] with success status for each type.
  Future<CombinedExportResult> exportCombined({
    required List<Map<String, dynamic>> spans,
    required List<Map<String, dynamic>> metrics,
    required List<Map<String, dynamic>> logRecords,
    required TelemetryResource resource,
  }) async {
    // If all are empty, return success
    if (spans.isEmpty && metrics.isEmpty && logRecords.isEmpty) {
      return const CombinedExportResult(success: true);
    }

    final url = Uri.parse('$endpoint/v1/telemetry');
    final resourceOtlp = resource.toOtlp();
    final scope = {'name': 'voo-telemetry', 'version': '2.0.0'};

    final body = <String, dynamic>{};

    // Only include non-empty data
    if (spans.isNotEmpty) {
      body['resourceSpans'] = [
        {
          'resource': resourceOtlp,
          'scopeSpans': [
            {'scope': scope, 'spans': spans},
          ],
        },
      ];
    }

    if (metrics.isNotEmpty) {
      body['resourceMetrics'] = [
        {
          'resource': resourceOtlp,
          'scopeMetrics': [
            {'scope': scope, 'metrics': metrics},
          ],
        },
      ];
    }

    if (logRecords.isNotEmpty) {
      body['resourceLogs'] = [
        {
          'resource': resourceOtlp,
          'scopeLogs': [
            {'scope': scope, 'logRecords': logRecords},
          ],
        },
      ];
    }

    final success = await _sendRequest(url, body);

    return CombinedExportResult(
      success: success,
      spansExported: spans.length,
      metricsExported: metrics.length,
      logsExported: logRecords.length,
    );
  }

  /// Check if the combined endpoint is available.
  ///
  /// Makes a test request to check if the server returns 404.
  /// Returns true if the endpoint is available.
  Future<bool> isCombinedEndpointAvailable() async {
    try {
      final url = Uri.parse('$endpoint/v1/telemetry');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (apiKey != null) 'X-API-Key': apiKey!,
      };

      // Send empty request to check availability
      final response = await _client
          .post(url, headers: headers, body: '{}')
          .timeout(const Duration(seconds: 5));

      // 404 means endpoint doesn't exist
      // 200/400/401 etc. means it exists
      return response.statusCode != 404;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendRequest(Uri url, Map<String, dynamic> body) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      try {
        // Compress payload if enabled and above threshold
        final jsonString = jsonEncode(body);
        final compressed = CompressionUtils.compressIfNeeded(
          jsonString,
          threshold: compressionThreshold,
          enabled: enableCompression,
        );

        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (apiKey != null) 'X-API-Key': apiKey!,
          if (compressed.isCompressed) 'Content-Encoding': 'gzip',
        };

        final response = await _client
            .post(url, headers: headers, body: compressed.data)
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }

        // Don't retry on 4xx client errors (except 429 rate limit)
        if (response.statusCode >= 400 && response.statusCode < 500 && response.statusCode != 429) {
          return false;
        }
      } catch (_) {
        // Retry on failure
      }

      // Apply exponential backoff with jitter before retry
      if (attempt < maxRetries) {
        final exponentialDelay = retryDelay.inMilliseconds * pow(2, attempt - 1).toInt();
        final jitter = _random.nextInt(500); // Add up to 500ms jitter
        final totalDelay = Duration(milliseconds: exponentialDelay + jitter);

        await Future<void>.delayed(totalDelay);
      }
    }

    return false;
  }

  void dispose() {
    _client.close();
  }
}

/// Result of a combined telemetry export.
@immutable
class CombinedExportResult {
  /// Whether the export was successful.
  final bool success;

  /// Number of spans exported.
  final int spansExported;

  /// Number of metrics exported.
  final int metricsExported;

  /// Number of log records exported.
  final int logsExported;

  const CombinedExportResult({
    required this.success,
    this.spansExported = 0,
    this.metricsExported = 0,
    this.logsExported = 0,
  });

  /// Total number of items exported.
  int get totalExported => spansExported + metricsExported + logsExported;

  @override
  String toString() =>
      'CombinedExportResult(success: $success, spans: $spansExported, metrics: $metricsExported, logs: $logsExported)';
}
