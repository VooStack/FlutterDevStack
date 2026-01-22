import 'package:voo_telemetry/voo_telemetry.dart';

/// Funnel step definition.
class FunnelStep {
  final String id;
  final String name;
  final String eventName;
  final int order;

  const FunnelStep({
    required this.id,
    required this.name,
    required this.eventName,
    required this.order,
  });
}

/// Funnel definition.
class Funnel {
  final String id;
  final String name;
  final List<FunnelStep> steps;
  final Duration? maxCompletionTime;

  const Funnel({
    required this.id,
    required this.name,
    required this.steps,
    this.maxCompletionTime,
  });
}

/// Tracks funnel progression as OTEL span chains.
///
/// Each funnel becomes a parent span with individual steps as child spans,
/// linked together for conversion analysis.
class FunnelSpanTracker {
  final Tracer _tracer;
  final Map<String, Span> _activeFunnelSpans = {};
  final Map<String, List<SpanLink>> _funnelLinks = {};
  final Map<String, DateTime> _funnelStartTimes = {};
  final Map<String, int> _completedStepCounts = {};

  /// Session ID for correlation.
  String? sessionId;

  FunnelSpanTracker(this._tracer);

  /// Start a funnel as a parent span.
  ///
  /// Returns the funnel span for additional attribute setting.
  Span startFunnel(Funnel funnel) {
    // End any existing funnel with the same ID
    if (_activeFunnelSpans.containsKey(funnel.id)) {
      abandonFunnel(funnel.id, reason: 'Restarted');
    }

    final funnelSpan = _tracer.startSpan(
      'funnel.${funnel.id}',
      kind: SpanKind.internal,
      attributes: {
        'funnel.id': funnel.id,
        'funnel.name': funnel.name,
        'funnel.total_steps': funnel.steps.length,
        if (sessionId != null) 'session.id': sessionId,
        if (funnel.maxCompletionTime != null)
          'funnel.max_completion_time_ms': funnel.maxCompletionTime!.inMilliseconds,
      },
    );

    _activeFunnelSpans[funnel.id] = funnelSpan;
    _funnelLinks[funnel.id] = [];
    _funnelStartTimes[funnel.id] = DateTime.now();
    _completedStepCounts[funnel.id] = 0;

    return funnelSpan;
  }

  /// Record a funnel step completion.
  ///
  /// Creates a child span for the step and links it to the funnel.
  void recordStep({
    required String funnelId,
    required FunnelStep step,
    Duration? timeSincePrevious,
    Map<String, dynamic>? additionalAttributes,
  }) {
    final parentSpan = _activeFunnelSpans[funnelId];
    if (parentSpan == null) return;

    // Create step span
    final stepSpan = _tracer.startSpan(
      'funnel.step.${step.id}',
      kind: SpanKind.internal,
      attributes: {
        'funnel.id': funnelId,
        'funnel.step.id': step.id,
        'funnel.step.name': step.name,
        'funnel.step.order': step.order,
        'funnel.step.event_name': step.eventName,
        if (timeSincePrevious != null)
          'funnel.step.time_since_previous_ms': timeSincePrevious.inMilliseconds,
        ...?additionalAttributes,
      },
    );

    // Add link to parent funnel
    stepSpan.links.add(SpanLink(
      traceId: parentSpan.traceId,
      spanId: parentSpan.spanId,
      attributes: {'link.type': 'funnel_parent'},
    ));

    stepSpan.status = SpanStatus.ok();
    stepSpan.end();

    // Track link for funnel completion
    _funnelLinks[funnelId]!.add(SpanLink(
      traceId: stepSpan.traceId,
      spanId: stepSpan.spanId,
      attributes: {'step.order': step.order},
    ));

    // Update completed step count
    _completedStepCounts[funnelId] = (_completedStepCounts[funnelId] ?? 0) + 1;

    // Add event to parent span
    parentSpan.addEvent('step_completed', attributes: {
      'step.id': step.id,
      'step.name': step.name,
      'step.order': step.order,
    });
  }

  /// Complete a funnel successfully.
  void completeFunnel(String funnelId, {Map<String, dynamic>? additionalAttributes}) {
    final span = _activeFunnelSpans.remove(funnelId);
    if (span == null) return;

    final startTime = _funnelStartTimes.remove(funnelId);
    final completedSteps = _completedStepCounts.remove(funnelId) ?? 0;

    Duration? duration;
    if (startTime != null) {
      duration = DateTime.now().difference(startTime);
    }

    span.setAttributes({
      'funnel.completed': true,
      'funnel.abandoned': false,
      'funnel.steps_completed': completedSteps,
      if (duration != null) 'funnel.duration_ms': duration.inMilliseconds,
      ...?additionalAttributes,
    });

    // Add links to all steps
    final links = _funnelLinks.remove(funnelId) ?? [];
    span.links.addAll(links);

    span.status = SpanStatus.ok();
    span.end();
  }

  /// Abandon a funnel.
  void abandonFunnel(String funnelId, {String? reason, Map<String, dynamic>? additionalAttributes}) {
    final span = _activeFunnelSpans.remove(funnelId);
    if (span == null) return;

    final startTime = _funnelStartTimes.remove(funnelId);
    final completedSteps = _completedStepCounts.remove(funnelId) ?? 0;

    Duration? duration;
    if (startTime != null) {
      duration = DateTime.now().difference(startTime);
    }

    span.setAttributes({
      'funnel.completed': false,
      'funnel.abandoned': true,
      'funnel.steps_completed': completedSteps,
      if (duration != null) 'funnel.duration_ms': duration.inMilliseconds,
      if (reason != null) 'funnel.abandon_reason': reason,
      ...?additionalAttributes,
    });

    // Add links to completed steps
    final links = _funnelLinks.remove(funnelId) ?? [];
    span.links.addAll(links);

    span.status = SpanStatus.error(description: 'Funnel abandoned${reason != null ? ": $reason" : ""}');
    span.end();
  }

  /// Check if a funnel is active.
  bool isFunnelActive(String funnelId) => _activeFunnelSpans.containsKey(funnelId);

  /// Get the number of completed steps for a funnel.
  int getCompletedStepCount(String funnelId) => _completedStepCounts[funnelId] ?? 0;

  /// Get all active funnel IDs.
  Set<String> get activeFunnelIds => _activeFunnelSpans.keys.toSet();

  /// Dispose and abandon all active funnels.
  void dispose() {
    for (final funnelId in _activeFunnelSpans.keys.toList()) {
      abandonFunnel(funnelId, reason: 'Session ended');
    }
  }
}
