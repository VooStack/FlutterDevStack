import 'package:voo_analytics/src/data/models/voo_funnel_step.dart';

export 'voo_funnel_step.dart';
export 'voo_funnel_step_completion.dart';
export 'voo_funnel_progress.dart';

/// Definition of a conversion funnel.
///
/// A funnel represents a series of steps that users should complete
/// to achieve a goal (e.g., signup, purchase, onboarding).
class VooFunnel {
  /// Unique identifier for this funnel.
  final String id;

  /// Human-readable name for the funnel.
  final String name;

  /// Description of what this funnel tracks.
  final String? description;

  /// Ordered list of steps in the funnel.
  final List<VooFunnelStep> steps;

  /// Maximum time allowed to complete the entire funnel.
  final Duration? maxCompletionTime;

  /// Whether this funnel is currently active.
  final bool isActive;

  const VooFunnel({
    required this.id,
    required this.name,
    this.description,
    required this.steps,
    this.maxCompletionTime,
    this.isActive = true,
  });

  /// Creates a simple funnel from event names.
  factory VooFunnel.simple({
    required String id,
    required String name,
    required List<String> eventNames,
    String? description,
    Duration? maxCompletionTime,
  }) {
    return VooFunnel(
      id: id,
      name: name,
      description: description,
      maxCompletionTime: maxCompletionTime,
      steps: eventNames
          .asMap()
          .entries
          .map((e) => VooFunnelStep(
                id: '${id}_step_${e.key}',
                name: e.value,
                eventName: e.value,
                order: e.key,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'steps': steps.map((s) => s.toJson()).toList(),
      if (maxCompletionTime != null)
        'max_completion_time_ms': maxCompletionTime!.inMilliseconds,
      'is_active': isActive,
    };
  }

  factory VooFunnel.fromJson(Map<String, dynamic> json) {
    return VooFunnel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      steps: (json['steps'] as List)
          .map((s) => VooFunnelStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      maxCompletionTime: json['max_completion_time_ms'] != null
          ? Duration(milliseconds: json['max_completion_time_ms'] as int)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
