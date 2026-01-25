import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:voo_telemetry/src/core/telemetry_config.dart';
import 'package:voo_telemetry/src/core/telemetry_resource.dart';
import 'package:voo_telemetry/src/exporters/otlp_http_exporter.dart';
import 'package:voo_telemetry/src/traces/span.dart';
import 'package:voo_telemetry/src/traces/tracer.dart';

/// Provider for trace telemetry
class TraceProvider {
  final TelemetryResource resource;
  final OTLPHttpExporter exporter;
  final TelemetryConfig config;
  final Map<String, Tracer> _tracers = {};
  final List<Span> _pendingSpans = [];
  final _lock = Lock();

  /// Stack-based span management for proper parent restoration
  final List<Span> _spanStack = [];

  /// Get the currently active span (top of stack)
  Span? get activeSpan => _spanStack.isNotEmpty ? _spanStack.last : null;

  /// Push a span onto the stack (called when starting a span)
  void pushSpan(Span span) => _spanStack.add(span);

  /// Pop a span from the stack (called when ending a span)
  Span? popSpan() => _spanStack.isNotEmpty ? _spanStack.removeLast() : null;

  TraceProvider({required this.resource, required this.exporter, required this.config});

  /// Initialize the trace provider
  Future<void> initialize() async {
    // Any initialization logic
  }

  /// Get or create a tracer
  Tracer getTracer(String name) => _tracers.putIfAbsent(name, () => Tracer(name: name, provider: this));

  /// Add a span to be exported
  void addSpan(Span span) {
    unawaited(_addSpanAsync(span));
  }

  Future<void> _addSpanAsync(Span span) async {
    List<Span>? itemsToExport;

    await _lock.synchronized(() {
      _pendingSpans.add(span);

      if (_pendingSpans.length >= config.maxBatchSize) {
        // Extract items inside lock, export outside
        itemsToExport = List<Span>.from(_pendingSpans);
        _pendingSpans.clear();
      }
    });

    // Export outside the lock to prevent deadlock
    if (itemsToExport != null) {
      await _exportBatch(itemsToExport!);
    }
  }

  Future<void> _exportBatch(List<Span> spans) async {
    if (spans.isEmpty) return;
    final otlpSpans = spans.map((s) => s.toOtlp()).toList();
    await exporter.exportTraces(otlpSpans, resource);
  }

  /// Collect pending spans for combined export.
  ///
  /// Returns the OTLP-formatted spans and clears the pending list.
  /// Use this when exporting via the combined telemetry endpoint.
  Future<List<Map<String, dynamic>>> collectPendingOtlp() async {
    final spansToExport = await _lock.synchronized(() {
      final spans = List<Span>.from(_pendingSpans);
      _pendingSpans.clear();
      return spans;
    });

    if (spansToExport.isEmpty) return [];

    return spansToExport.map((s) => s.toOtlp()).toList();
  }

  /// Flush pending spans
  Future<void> flush() async {
    final otlpSpans = await collectPendingOtlp();
    if (otlpSpans.isEmpty) return;
    await exporter.exportTraces(otlpSpans, resource);
  }

  /// Shutdown the provider
  Future<void> shutdown() async {
    await flush();
    _tracers.clear();
    _spanStack.clear();
  }
}
