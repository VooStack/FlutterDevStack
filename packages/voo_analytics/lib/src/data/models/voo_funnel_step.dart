/// A single step within a funnel.
class VooFunnelStep {
  /// Unique identifier for this step.
  final String id;

  /// Human-readable name for the step.
  final String name;

  /// The event name that completes this step.
  final String eventName;

  /// Order of this step in the funnel (0-indexed).
  final int order;

  /// Required parameters that must be present in the event.
  final Map<String, dynamic>? requiredParams;

  /// Maximum time allowed since the previous step.
  final Duration? maxTimeSincePrevious;

  /// Whether this step is optional (can be skipped).
  final bool isOptional;

  const VooFunnelStep({
    required this.id,
    required this.name,
    required this.eventName,
    required this.order,
    this.requiredParams,
    this.maxTimeSincePrevious,
    this.isOptional = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'event_name': eventName,
      'order': order,
      if (requiredParams != null) 'required_params': requiredParams,
      if (maxTimeSincePrevious != null)
        'max_time_since_previous_ms': maxTimeSincePrevious!.inMilliseconds,
      'is_optional': isOptional,
    };
  }

  factory VooFunnelStep.fromJson(Map<String, dynamic> json) {
    return VooFunnelStep(
      id: json['id'] as String,
      name: json['name'] as String,
      eventName: json['event_name'] as String,
      order: json['order'] as int,
      requiredParams: json['required_params'] as Map<String, dynamic>?,
      maxTimeSincePrevious: json['max_time_since_previous_ms'] != null
          ? Duration(milliseconds: json['max_time_since_previous_ms'] as int)
          : null,
      isOptional: json['is_optional'] as bool? ?? false,
    );
  }
}
