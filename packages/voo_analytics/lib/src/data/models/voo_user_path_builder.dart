import 'package:voo_analytics/src/data/models/user_path.dart';

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

  VooUserPathBuilder({required this.sessionId, this.userId, DateTime? startTime, this.attribution}) : startTime = startTime ?? DateTime.now();

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

    _nodes.add(
      VooPathNode(
        screenName: _currentScreen!,
        enterTime: _currentEnterTime!,
        duration: DateTime.now().difference(_currentEnterTime!),
        interactionCount: _currentInteractions,
        nextScreen: nextScreen,
        exitType: exitType,
        scrollDepth: _currentScrollDepth,
        routeParams: _currentRouteParams,
        events: _currentEvents.isNotEmpty ? List.from(_currentEvents) : null,
      ),
    );
  }

  /// Build the final user path.
  VooUserPath build({bool endedWithConversion = false, String? conversionEvent}) {
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
