/// A single node (screen) in a user path.
class VooPathNode {
  /// Name of the screen.
  final String screenName;

  /// When the user entered this screen.
  final DateTime enterTime;

  /// How long the user spent on this screen.
  final Duration duration;

  /// Number of interactions on this screen.
  final int interactionCount;

  /// Next screen the user navigated to (null if last screen).
  final String? nextScreen;

  /// How the user left this screen.
  final String exitType;

  /// Scroll depth reached on this screen (0.0 - 1.0).
  final double? scrollDepth;

  /// Route parameters for this screen.
  final Map<String, dynamic>? routeParams;

  /// Events that occurred on this screen.
  final List<String>? events;

  const VooPathNode({
    required this.screenName,
    required this.enterTime,
    required this.duration,
    required this.interactionCount,
    this.nextScreen,
    required this.exitType,
    this.scrollDepth,
    this.routeParams,
    this.events,
  });

  /// Whether user engaged with this screen (interactions or scroll).
  bool get wasEngaged =>
      interactionCount > 0 || (scrollDepth != null && scrollDepth! > 0.1);

  /// Time in seconds for display.
  int get durationSeconds => duration.inSeconds;

  Map<String, dynamic> toJson() {
    return {
      'screen_name': screenName,
      'enter_time': enterTime.toIso8601String(),
      'duration_ms': duration.inMilliseconds,
      'interaction_count': interactionCount,
      if (nextScreen != null) 'next_screen': nextScreen,
      'exit_type': exitType,
      if (scrollDepth != null) 'scroll_depth': scrollDepth,
      if (routeParams != null) 'route_params': routeParams,
      if (events != null) 'events': events,
    };
  }

  factory VooPathNode.fromJson(Map<String, dynamic> json) {
    return VooPathNode(
      screenName: json['screen_name'] as String,
      enterTime: DateTime.parse(json['enter_time'] as String),
      duration: Duration(milliseconds: json['duration_ms'] as int),
      interactionCount: json['interaction_count'] as int,
      nextScreen: json['next_screen'] as String?,
      exitType: json['exit_type'] as String,
      scrollDepth: (json['scroll_depth'] as num?)?.toDouble(),
      routeParams: json['route_params'] as Map<String, dynamic>?,
      events: (json['events'] as List?)?.cast<String>(),
    );
  }
}
