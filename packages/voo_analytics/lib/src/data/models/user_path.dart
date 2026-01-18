import 'package:flutter/foundation.dart';

/// Represents a user's navigation path through the app.
///
/// Captures the sequence of screens visited, time spent on each,
/// and how the user transitioned between them.
@immutable
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

/// A single node (screen) in a user path.
@immutable
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

/// Builder for constructing user paths from navigation events.
class VooUserPathBuilder {
  final String sessionId;
  final String? userId;
  final DateTime startTime;
  final List<VooPathNode> _nodes = [];
  final Map<String, dynamic>? attribution;

  String? _currentScreen;
  DateTime? _currentEnterTime;
  int _currentInteractions = 0;
  double? _currentScrollDepth;
  Map<String, dynamic>? _currentRouteParams;
  final List<String> _currentEvents = [];

  VooUserPathBuilder({
    required this.sessionId,
    this.userId,
    DateTime? startTime,
    this.attribution,
  }) : startTime = startTime ?? DateTime.now();

  /// Call when entering a new screen.
  void enterScreen(String screenName, {Map<String, dynamic>? routeParams}) {
    // Complete previous screen if any
    if (_currentScreen != null) {
      _completeCurrentScreen(nextScreen: screenName, exitType: 'navigate');
    }

    _currentScreen = screenName;
    _currentEnterTime = DateTime.now();
    _currentInteractions = 0;
    _currentScrollDepth = null;
    _currentRouteParams = routeParams;
    _currentEvents.clear();
  }

  /// Call when an interaction occurs on the current screen.
  void recordInteraction() {
    _currentInteractions++;
  }

  /// Call to update scroll depth.
  void updateScrollDepth(double depth) {
    if (_currentScrollDepth == null || depth > _currentScrollDepth!) {
      _currentScrollDepth = depth.clamp(0.0, 1.0);
    }
  }

  /// Call when an event occurs on the current screen.
  void recordEvent(String eventName) {
    _currentEvents.add(eventName);
  }

  /// Call when leaving the current screen.
  void exitScreen({String exitType = 'navigate', String? nextScreen}) {
    _completeCurrentScreen(nextScreen: nextScreen, exitType: exitType);
    _currentScreen = null;
  }

  void _completeCurrentScreen({String? nextScreen, required String exitType}) {
    if (_currentScreen == null || _currentEnterTime == null) return;

    _nodes.add(VooPathNode(
      screenName: _currentScreen!,
      enterTime: _currentEnterTime!,
      duration: DateTime.now().difference(_currentEnterTime!),
      interactionCount: _currentInteractions,
      nextScreen: nextScreen,
      exitType: exitType,
      scrollDepth: _currentScrollDepth,
      routeParams: _currentRouteParams,
      events: _currentEvents.isNotEmpty ? List.from(_currentEvents) : null,
    ));
  }

  /// Build the final user path.
  VooUserPath build({
    bool endedWithConversion = false,
    String? conversionEvent,
  }) {
    // Complete current screen if still active
    if (_currentScreen != null) {
      _completeCurrentScreen(exitType: 'session_end');
    }

    final endTime = DateTime.now();
    return VooUserPath(
      sessionId: sessionId,
      userId: userId,
      nodes: List.unmodifiable(_nodes),
      totalDuration: endTime.difference(startTime),
      endedWithConversion: endedWithConversion,
      conversionEvent: conversionEvent,
      startTime: startTime,
      endTime: endTime,
      attribution: attribution,
    );
  }
}
