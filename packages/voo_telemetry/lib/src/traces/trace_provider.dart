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
    _lock.synchronized(() {
      _pendingSpans.add(span);

      if (_pendingSpans.length >= config.maxBatchSize) {
        flush();
      }
    });
  }

  /// Flush pending spans
  Future<void> flush() async {
    final spansToExport = await _lock.synchronized(() {
      final spans = List<Span>.from(_pendingSpans);
      _pendingSpans.clear();
      return spans;
    });

    if (spansToExport.isEmpty) return;

    final otlpSpans = spansToExport.map((s) => s.toOtlp()).toList();
    await exporter.exportTraces(otlpSpans, resource);
  }

  /// Shutdown the provider
  Future<void> shutdown() async {
    await flush();
    _tracers.clear();
    _spanStack.clear();
  }
}
