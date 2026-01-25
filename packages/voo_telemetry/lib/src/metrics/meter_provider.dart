import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:voo_telemetry/src/core/telemetry_config.dart';
import 'package:voo_telemetry/src/core/telemetry_resource.dart';
import 'package:voo_telemetry/src/exporters/otlp_http_exporter.dart';
import 'package:voo_telemetry/src/metrics/meter.dart';
import 'package:voo_telemetry/src/metrics/metric.dart';

/// Provider for metrics telemetry
class MeterProvider {
  final TelemetryResource resource;
  final OTLPHttpExporter exporter;
  final TelemetryConfig config;
  final Map<String, Meter> _meters = {};
  final List<Metric> _pendingMetrics = [];
  final _lock = Lock();

  MeterProvider({required this.resource, required this.exporter, required this.config});

  /// Initialize the meter provider
  Future<void> initialize() async {
    // Any initialization logic
  }

  /// Get or create a meter
  Meter getMeter(String name) => _meters.putIfAbsent(name, () => Meter(name: name, provider: this));

  /// Add a metric to be exported
  void addMetric(Metric metric) {
    unawaited(_addMetricAsync(metric));
  }

  Future<void> _addMetricAsync(Metric metric) async {
    List<Metric>? itemsToExport;

    await _lock.synchronized(() {
      _pendingMetrics.add(metric);

      if (_pendingMetrics.length >= config.maxBatchSize) {
        // Extract items inside lock, export outside
        itemsToExport = List<Metric>.from(_pendingMetrics);
        _pendingMetrics.clear();
      }
    });

    // Export outside the lock to prevent deadlock
    if (itemsToExport != null) {
      await _exportBatch(itemsToExport!);
    }
  }

  Future<void> _exportBatch(List<Metric> metrics) async {
    if (metrics.isEmpty) return;
    final otlpMetrics = metrics.map((m) => m.toOtlp()).toList();
    await exporter.exportMetrics(otlpMetrics, resource);
  }

  /// Collect pending metrics for combined export.
  ///
  /// Returns the OTLP-formatted metrics and clears the pending list.
  /// Use this when exporting via the combined telemetry endpoint.
  Future<List<Map<String, dynamic>>> collectPendingOtlp() async {
    // First, flush all meter instruments (especially histograms with pending values)
    for (final meter in _meters.values) {
      meter.flush();
    }

    // Now collect all pending metrics
    final metricsToExport = await _lock.synchronized(() {
      final metrics = List<Metric>.from(_pendingMetrics);
      _pendingMetrics.clear();
      return metrics;
    });

    if (metricsToExport.isEmpty) return [];

    return metricsToExport.map((m) => m.toOtlp()).toList();
  }

  /// Flush pending metrics
  Future<void> flush() async {
    final otlpMetrics = await collectPendingOtlp();
    if (otlpMetrics.isEmpty) return;
    await exporter.exportMetrics(otlpMetrics, resource);
  }

  /// Shutdown the provider
  Future<void> shutdown() async {
    await flush();
    _meters.clear();
  }
}
