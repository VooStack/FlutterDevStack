import 'package:voo_analytics/src/data/models/funnel.dart';

/// Types of funnel events.
enum FunnelEventType {
  /// A step in the funnel was completed.
  stepCompleted,

  /// The entire funnel was completed.
  completed,

  /// The funnel was abandoned.
  abandoned,
}

/// Event emitted when funnel progress changes.
class FunnelEvent {
  final FunnelEventType type;
  final String funnelId;
  final String? stepId;
  final VooFunnelProgress progress;
  final String? reason;

  const FunnelEvent({
    required this.type,
    required this.funnelId,
    this.stepId,
    required this.progress,
    this.reason,
  });
}
