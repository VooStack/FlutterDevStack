import 'package:voo_analytics/src/data/models/voo_path_node.dart';

export 'voo_path_node.dart';
export 'voo_user_path_builder.dart';

/// Represents a user's navigation path through the app.
///
/// Captures the sequence of screens visited, time spent on each,
/// and how the user transitioned between them.
class VooUserPath {
  /// Session ID for this path.
  final String sessionId;

  /// User ID if available.
  final String? userId;

  /// Ordered list of nodes (screens) in the path.
  final List<VooPathNode> nodes;

  /// Total duration of this path.
  final Duration totalDuration;

  /// Whether the path ended with a conversion event.
  final bool endedWithConversion;

  /// The conversion event name if applicable.
  final String? conversionEvent;

  /// When this path started.
  final DateTime startTime;

  /// When this path ended.
  final DateTime? endTime;

  /// Attribution data for this path.
  final Map<String, dynamic>? attribution;

  const VooUserPath({
    required this.sessionId,
    this.userId,
    required this.nodes,
    required this.totalDuration,
    this.endedWithConversion = false,
    this.conversionEvent,
    required this.startTime,
    this.endTime,
    this.attribution,
  });

  /// Number of screens visited.
  int get screenCount => nodes.length;

  /// Total interactions across all screens.
  int get totalInteractions =>
      nodes.fold(0, (sum, node) => sum + node.interactionCount);

  /// Average time per screen.
  Duration get averageTimePerScreen {
    if (nodes.isEmpty) return Duration.zero;
    return Duration(
        milliseconds: totalDuration.inMilliseconds ~/ nodes.length);
  }

  /// First screen in the path.
  String? get entryScreen => nodes.isNotEmpty ? nodes.first.screenName : null;

  /// Last screen in the path.
  String? get exitScreen => nodes.isNotEmpty ? nodes.last.screenName : null;

  /// Gets unique screens visited.
  Set<String> get uniqueScreens =>
      nodes.map((n) => n.screenName).toSet();

  /// Bounce rate (single screen visits).
  bool get isBounce => nodes.length == 1;

  /// Creates a path summary for display.
  String get pathSummary {
    if (nodes.isEmpty) return '';
    if (nodes.length <= 3) {
      return nodes.map((n) => n.screenName).join(' → ');
    }
    return '${nodes.first.screenName} → ... → ${nodes.last.screenName}';
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'total_duration_ms': totalDuration.inMilliseconds,
      'ended_with_conversion': endedWithConversion,
      if (conversionEvent != null) 'conversion_event': conversionEvent,
      'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      if (attribution != null) 'attribution': attribution,
      'screen_count': screenCount,
      'total_interactions': totalInteractions,
      'unique_screens': uniqueScreens.toList(),
      'is_bounce': isBounce,
    };
  }

  factory VooUserPath.fromJson(Map<String, dynamic> json) {
    return VooUserPath(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String?,
      nodes: (json['nodes'] as List)
          .map((n) => VooPathNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      totalDuration:
          Duration(milliseconds: json['total_duration_ms'] as int),
      endedWithConversion: json['ended_with_conversion'] as bool? ?? false,
      conversionEvent: json['conversion_event'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      attribution: json['attribution'] as Map<String, dynamic>?,
    );
  }
}
