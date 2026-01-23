import 'package:voo_telemetry/voo_telemetry.dart';

/// Interface for providing trace context to logs for correlation.
///
/// Implement this interface to provide custom trace context sources,
/// or use [VooTelemetryContextProvider] for automatic integration
/// with VooTelemetry.
abstract class TraceContextProvider {
  /// Get the currently active trace context, if any.
  ///
  /// Returns null if no active trace context is available.
  TraceContext? getActiveContext();
}

/// Trace context information for log correlation.
///
/// Contains the trace ID, span ID, and trace flags needed to
/// correlate logs with distributed traces.
class TraceContext {
  /// The trace ID (32 hex characters).
  final String traceId;

  /// The span ID (16 hex characters).
  final String spanId;

  /// Trace flags (bit field, 1 = sampled).
  final int traceFlags;

  const TraceContext({
    required this.traceId,
    required this.spanId,
    this.traceFlags = 1, // Sampled by default
  });

  /// Check if the trace is sampled.
  bool get isSampled => (traceFlags & 0x01) == 0x01;
}

/// Default implementation that integrates with VooTelemetry.
///
/// Automatically retrieves the active span context from VooTelemetry
/// when available.
class VooTelemetryContextProvider implements TraceContextProvider {
  @override
  TraceContext? getActiveContext() {
    try {
      if (!VooTelemetry.isInitialized) return null;

      final activeSpan = VooTelemetry.instance.traceProvider.activeSpan;
      if (activeSpan == null) return null;

      return TraceContext(traceId: activeSpan.traceId, spanId: activeSpan.spanId, traceFlags: activeSpan.context.traceFlags);
    } catch (_) {
      return null;
    }
  }
}

/// Manual trace context provider for custom integration.
///
/// Use this when you need to manually control the trace context,
/// such as when extracting context from incoming HTTP request headers.
class ManualTraceContextProvider implements TraceContextProvider {
  TraceContext? _currentContext;

  /// Set the current trace context.
  ///
  /// Call this to update the context (e.g., when a new request arrives).
  void setContext(TraceContext? context) {
    _currentContext = context;
  }

  /// Clear the current trace context.
  void clearContext() {
    _currentContext = null;
  }

  @override
  TraceContext? getActiveContext() => _currentContext;
}

/// Combined trace context provider that tries multiple sources.
///
/// Attempts to get context from each provider in order, returning
/// the first non-null context found.
class CompositeTraceContextProvider implements TraceContextProvider {
  final List<TraceContextProvider> providers;

  CompositeTraceContextProvider(this.providers);

  @override
  TraceContext? getActiveContext() {
    for (final provider in providers) {
      final context = provider.getActiveContext();
      if (context != null) return context;
    }
    return null;
  }
}
