/// Record of a completed funnel step.
class VooFunnelStepCompletion {
  /// The step that was completed.
  final String stepId;

  /// When the step was completed.
  final DateTime completedAt;

  /// Time since the previous step (null for first step).
  final Duration? timeSincePrevious;

  /// Event parameters that triggered the completion.
  final Map<String, dynamic>? eventParams;

  const VooFunnelStepCompletion({
    required this.stepId,
    required this.completedAt,
    this.timeSincePrevious,
    this.eventParams,
  });

  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'completed_at': completedAt.toIso8601String(),
      if (timeSincePrevious != null)
        'time_since_previous_ms': timeSincePrevious!.inMilliseconds,
      if (eventParams != null) 'event_params': eventParams,
    };
  }

  factory VooFunnelStepCompletion.fromJson(Map<String, dynamic> json) {
    return VooFunnelStepCompletion(
      stepId: json['step_id'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      timeSincePrevious: json['time_since_previous_ms'] != null
          ? Duration(milliseconds: json['time_since_previous_ms'] as int)
          : null,
      eventParams: json['event_params'] as Map<String, dynamic>?,
    );
  }
}
