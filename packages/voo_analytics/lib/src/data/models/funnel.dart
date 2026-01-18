import 'package:flutter/foundation.dart';

/// Definition of a conversion funnel.
///
/// A funnel represents a series of steps that users should complete
/// to achieve a goal (e.g., signup, purchase, onboarding).
@immutable
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

/// A single step within a funnel.
@immutable
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

/// Progress through a funnel for a single user session.
@immutable
class VooFunnelProgress {
  /// The funnel being tracked.
  final String funnelId;

  /// Session ID for this progress.
  final String sessionId;

  /// User ID if available.
  final String? userId;

  /// Steps that have been completed.
  final List<VooFunnelStepCompletion> completedSteps;

  /// When the user started this funnel.
  final DateTime startTime;

  /// When the user completed or abandoned the funnel.
  final DateTime? endTime;

  /// Whether all required steps are complete.
  final bool isComplete;

  /// Whether the user abandoned the funnel.
  final bool isAbandoned;

  /// Current step index (next step to complete).
  final int currentStepIndex;

  const VooFunnelProgress({
    required this.funnelId,
    required this.sessionId,
    this.userId,
    required this.completedSteps,
    required this.startTime,
    this.endTime,
    required this.isComplete,
    required this.isAbandoned,
    required this.currentStepIndex,
  });

  /// Duration from start to completion/abandonment.
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Completion rate as a percentage (0.0 - 1.0).
  double completionRate(int totalSteps) {
    if (totalSteps == 0) return 0.0;
    return completedSteps.length / totalSteps;
  }

  /// Creates a new progress with an additional completed step.
  VooFunnelProgress withStepCompleted(VooFunnelStepCompletion completion) {
    return VooFunnelProgress(
      funnelId: funnelId,
      sessionId: sessionId,
      userId: userId,
      completedSteps: [...completedSteps, completion],
      startTime: startTime,
      endTime: endTime,
      isComplete: isComplete,
      isAbandoned: isAbandoned,
      currentStepIndex: currentStepIndex + 1,
    );
  }

  /// Marks the progress as complete.
  VooFunnelProgress markComplete() {
    return VooFunnelProgress(
      funnelId: funnelId,
      sessionId: sessionId,
      userId: userId,
      completedSteps: completedSteps,
      startTime: startTime,
      endTime: DateTime.now(),
      isComplete: true,
      isAbandoned: false,
      currentStepIndex: currentStepIndex,
    );
  }

  /// Marks the progress as abandoned.
  VooFunnelProgress markAbandoned() {
    return VooFunnelProgress(
      funnelId: funnelId,
      sessionId: sessionId,
      userId: userId,
      completedSteps: completedSteps,
      startTime: startTime,
      endTime: DateTime.now(),
      isComplete: false,
      isAbandoned: true,
      currentStepIndex: currentStepIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'funnel_id': funnelId,
      'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      'completed_steps': completedSteps.map((s) => s.toJson()).toList(),
      'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      'is_complete': isComplete,
      'is_abandoned': isAbandoned,
      'current_step_index': currentStepIndex,
      if (duration != null) 'duration_ms': duration!.inMilliseconds,
    };
  }

  factory VooFunnelProgress.fromJson(Map<String, dynamic> json) {
    return VooFunnelProgress(
      funnelId: json['funnel_id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String?,
      completedSteps: (json['completed_steps'] as List)
          .map((s) => VooFunnelStepCompletion.fromJson(s as Map<String, dynamic>))
          .toList(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      isComplete: json['is_complete'] as bool,
      isAbandoned: json['is_abandoned'] as bool,
      currentStepIndex: json['current_step_index'] as int,
    );
  }
}

/// Record of a completed funnel step.
@immutable
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
