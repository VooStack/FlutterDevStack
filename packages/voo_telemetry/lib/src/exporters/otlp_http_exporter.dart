import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  final Random _random = Random();

  OTLPHttpExporter({
    required this.endpoint,
    this.apiKey,
    this.debug = false,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
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
    if (metrics.isEmpty) {
      if (kDebugMode) {
        debugPrint('[OTLPHttpExporter] No metrics to export');
      }
      return true;
    }

    if (kDebugMode) {
      debugPrint('[OTLPHttpExporter] Exporting ${metrics.length} metrics to $endpoint/v1/metrics');
    }

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

  Future<bool> _sendRequest(Uri url, Map<String, dynamic> body) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      try {
        if (debug) {
          debugPrint('Sending OTLP request to $url (attempt $attempt/$maxRetries)');
          debugPrint('Body: ${jsonEncode(body)}');
        }

        final response = await _client
            .post(url, headers: {'Content-Type': 'application/json', if (apiKey != null) 'X-API-Key': apiKey!}, body: jsonEncode(body))
            .timeout(timeout);

        if (debug) {
          debugPrint('Response status: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }

        // Don't retry on 4xx client errors (except 429 rate limit)
        if (response.statusCode >= 400 && response.statusCode < 500 && response.statusCode != 429) {
          if (debug) {
            debugPrint('Failed to export telemetry (non-retryable): ${response.statusCode} ${response.body}');
          }
          return false;
        }

        if (debug) {
          debugPrint('Failed to export telemetry: ${response.statusCode} ${response.body}');
        }
      } catch (e, stackTrace) {
        if (debug) {
          debugPrint('Error exporting telemetry (attempt $attempt): $e');
          debugPrint('Stack trace: $stackTrace');
        }
      }

      // Apply exponential backoff with jitter before retry
      if (attempt < maxRetries) {
        final exponentialDelay = retryDelay.inMilliseconds * pow(2, attempt - 1).toInt();
        final jitter = _random.nextInt(500); // Add up to 500ms jitter
        final totalDelay = Duration(milliseconds: exponentialDelay + jitter);

        if (debug) {
          debugPrint('Retrying in ${totalDelay.inMilliseconds}ms...');
        }

        await Future<void>.delayed(totalDelay);
      }
    }

    if (debug) {
      debugPrint('Failed to export telemetry after $maxRetries attempts');
    }
    return false;
  }

  void dispose() {
    _client.close();
  }
}
