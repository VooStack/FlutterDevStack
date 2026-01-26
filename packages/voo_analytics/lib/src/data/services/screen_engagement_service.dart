import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

/// Engagement metrics for a single screen.
@immutable
class ScreenEngagement {
  /// Name of the screen.
  final String screenName;

  /// When the user entered the screen.
  final DateTime enterTime;

  /// Time spent on the screen.
  final Duration timeOnScreen;

  /// Scroll depth (0.0 - 1.0). Null if not applicable.
  final double? scrollDepth;

  /// Number of interactions on this screen.
  final int interactionCount;

  /// How the user left the screen.
  final String? exitTrigger;

  const ScreenEngagement({
    required this.screenName,
    required this.enterTime,
    required this.timeOnScreen,
    this.scrollDepth,
    required this.interactionCount,
    this.exitTrigger,
  });

  Map<String, dynamic> toJson() {
    return {
      'screen_name': screenName,
      'enter_time': enterTime.toIso8601String(),
      'time_on_screen_ms': timeOnScreen.inMilliseconds,
      if (scrollDepth != null) 'scroll_depth': scrollDepth,
      'interaction_count': interactionCount,
      if (exitTrigger != null) 'exit_trigger': exitTrigger,
    };
  }

  @override
  String toString() {
    return 'ScreenEngagement($screenName: ${timeOnScreen.inSeconds}s, '
        'interactions: $interactionCount, exit: $exitTrigger)';
  }
}

/// Service for tracking screen engagement metrics.
///
/// Tracks time spent on each screen, interactions, and scroll depth.
///
/// ## Usage
///
/// ```dart
/// // Start tracking when screen is entered
/// ScreenEngagementService.startTracking('HomeScreen');
///
/// // Record an interaction
/// ScreenEngagementService.recordInteraction('tap', elementId: 'buy_button');
///
/// // Update scroll depth
/// ScreenEngagementService.updateScrollDepth(0.5);
///
/// // Stop tracking when screen is exited
/// final engagement = ScreenEngagementService.stopTracking('navigation');
/// print('User spent ${engagement?.timeOnScreen.inSeconds}s on screen');
/// ```
class ScreenEngagementService {
  static ScreenEngagementService? _instance;
  static bool _initialized = false;

  /// Current screen being tracked.
  String? _currentScreen;

  /// When tracking started for the current screen.
  DateTime? _screenEnterTime;

  /// Interaction count for the current screen.
  int _interactionCount = 0;

  /// Current scroll depth for the current screen.
  double? _scrollDepth;

  /// History of completed screen engagements.
  final List<ScreenEngagement> _history = [];

  /// Maximum history size.
  static const int _maxHistorySize = 50;

  /// Stream controller for engagement events.
  final StreamController<ScreenEngagement> _engagementController =
      StreamController<ScreenEngagement>.broadcast();

  ScreenEngagementService._();

  /// Get the singleton instance.
  static ScreenEngagementService get instance {
    _instance ??= ScreenEngagementService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Stream of completed screen engagements.
  static Stream<ScreenEngagement> get engagementStream =>
      instance._engagementController.stream;

  /// Current screen being tracked.
  static String? get currentScreen => instance._currentScreen;

  /// Current interaction count on the active screen.
  static int get currentInteractionCount => instance._interactionCount;

  /// Initialize the service.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
  }

  /// Start tracking engagement for a new screen.
  static void startTracking(String screenName) {
    if (!_initialized) initialize();
    // Check project-level feature toggle
    if (!Voo.featureConfig.isEnabled(VooFeature.screenEngagement)) return;

    // If there's an active screen, stop tracking it first
    if (instance._currentScreen != null) {
      stopTracking('navigation');
    }

    instance._currentScreen = screenName;
    instance._screenEnterTime = DateTime.now();
    instance._interactionCount = 0;
    instance._scrollDepth = null;
  }

  /// Stop tracking and return the engagement metrics.
  static ScreenEngagement? stopTracking([String? exitTrigger]) {
    if (instance._currentScreen == null || instance._screenEnterTime == null) {
      return null;
    }

    final engagement = ScreenEngagement(
      screenName: instance._currentScreen!,
      enterTime: instance._screenEnterTime!,
      timeOnScreen: DateTime.now().difference(instance._screenEnterTime!),
      scrollDepth: instance._scrollDepth,
      interactionCount: instance._interactionCount,
      exitTrigger: exitTrigger,
    );

    // Add to history
    instance._history.add(engagement);
    while (instance._history.length > _maxHistorySize) {
      instance._history.removeAt(0);
    }

    // Update user context with engagement metrics
    _updateUserContext(engagement);

    // Notify listeners
    instance._engagementController.add(engagement);

    // Reset tracking state
    instance._currentScreen = null;
    instance._screenEnterTime = null;
    instance._interactionCount = 0;
    instance._scrollDepth = null;

    return engagement;
  }

  /// Record an interaction on the current screen.
  static void recordInteraction(
    String type, {
    String? elementId,
    String? elementType,
    Map<String, dynamic>? data,
  }) {
    if (instance._currentScreen == null) return;

    instance._interactionCount++;
  }

  /// Update the scroll depth for the current screen.
  ///
  /// [depth] should be between 0.0 (top) and 1.0 (bottom).
  static void updateScrollDepth(double depth) {
    if (instance._currentScreen == null) return;

    // Only update if the user scrolled further down
    if (instance._scrollDepth == null || depth > instance._scrollDepth!) {
      instance._scrollDepth = depth.clamp(0.0, 1.0);
    }
  }

  /// Get the engagement history.
  static List<ScreenEngagement> getHistory() {
    return List.unmodifiable(instance._history);
  }

  /// Get total engagement time across all tracked screens.
  static Duration getTotalEngagementTime() {
    var total = Duration.zero;
    for (final engagement in instance._history) {
      total += engagement.timeOnScreen;
    }
    return total;
  }

  /// Get total screen views.
  static int getTotalScreenViews() {
    return instance._history.length;
  }

  /// Get total interactions across all screens.
  static int getTotalInteractions() {
    return instance._history.fold(
      0,
      (sum, e) => sum + e.interactionCount,
    );
  }

  /// Update the central user context with engagement metrics.
  static void _updateUserContext(ScreenEngagement engagement) {
    try {
      // Track cumulative engagement in user context
      final currentTime = Voo.userContext?.userProperties['totalEngagementMs'] ?? 0;
      final currentViews = Voo.userContext?.userProperties['screenViewCount'] ?? 0;
      final currentInteractions = Voo.userContext?.userProperties['interactionCount'] ?? 0;

      Voo.setUserProperties({
        'totalEngagementMs': (currentTime as int) + engagement.timeOnScreen.inMilliseconds,
        'screenViewCount': (currentViews as int) + 1,
        'interactionCount': (currentInteractions as int) + engagement.interactionCount,
        'lastScreen': engagement.screenName,
      });
    } catch (_) {
      // ignore
    }
  }

  /// Dispose resources.
  static Future<void> dispose() async {
    // Stop tracking if active
    if (instance._currentScreen != null) {
      stopTracking('app_close');
    }

    await instance._engagementController.close();
    instance._history.clear();
    _initialized = false;
    _instance = null;
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    instance._currentScreen = null;
    instance._screenEnterTime = null;
    instance._interactionCount = 0;
    instance._scrollDepth = null;
    instance._history.clear();
    _initialized = false;
    _instance = null;
  }
}
