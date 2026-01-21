import 'package:voo_analytics/src/data/models/voo_funnel_step_completion.dart';

/// Progress through a funnel for a single user session.
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
