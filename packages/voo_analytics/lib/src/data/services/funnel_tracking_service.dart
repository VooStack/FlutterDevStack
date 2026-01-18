import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

import '../models/funnel.dart';
import '../../voo_analytics_plugin.dart';

/// Service for tracking user progress through conversion funnels.
///
/// ## Usage
///
/// ```dart
/// // Define a signup funnel
/// FunnelTrackingService.registerFunnel(VooFunnel.simple(
///   id: 'signup',
///   name: 'User Signup',
///   eventNames: ['view_signup', 'enter_email', 'verify_email', 'complete_profile'],
/// ));
///
/// // Events are automatically matched to funnels
/// VooAnalytics.logEvent('view_signup');  // Starts funnel progress
/// VooAnalytics.logEvent('enter_email');  // Completes step 2
///
/// // Check funnel progress
/// final progress = FunnelTrackingService.getProgress('signup');
/// print('Completed ${progress?.completedSteps.length} steps');
///
/// // Get funnel analytics
/// final stats = FunnelTrackingService.getFunnelStats('signup');
/// print('Conversion rate: ${stats.conversionRate}%');
/// ```
class FunnelTrackingService {
  static FunnelTrackingService? _instance;
  static bool _initialized = false;

  /// Registered funnels by ID.
  final Map<String, VooFunnel> _funnels = {};

  /// Active funnel progress by funnel ID.
  final Map<String, VooFunnelProgress> _activeProgress = {};

  /// Completed/abandoned funnel progress history.
  final List<VooFunnelProgress> _history = [];

  /// Maximum history size.
  static const int _maxHistorySize = 100;

  /// Event name to funnel step mapping for fast lookup.
  final Map<String, List<_FunnelStepRef>> _eventToSteps = {};

  /// Stream controller for funnel events.
  final StreamController<FunnelEvent> _eventController =
      StreamController<FunnelEvent>.broadcast();

  FunnelTrackingService._();

  /// Get the singleton instance.
  static FunnelTrackingService get instance {
    _instance ??= FunnelTrackingService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Stream of funnel events (step completed, funnel completed, etc.).
  static Stream<FunnelEvent> get eventStream => instance._eventController.stream;

  /// Initialize the service.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      debugPrint('FunnelTrackingService: Initialized');
    }
  }

  /// Register a funnel for tracking.
  static void registerFunnel(VooFunnel funnel) {
    if (!_initialized) initialize();

    instance._funnels[funnel.id] = funnel;

    // Build event to step mapping
    for (final step in funnel.steps) {
      final refs = instance._eventToSteps[step.eventName] ?? [];
      refs.add(_FunnelStepRef(funnelId: funnel.id, step: step));
      instance._eventToSteps[step.eventName] = refs;
    }

    if (kDebugMode) {
      debugPrint(
          'FunnelTrackingService: Registered funnel "${funnel.name}" with ${funnel.steps.length} steps');
    }
  }

  /// Unregister a funnel.
  static void unregisterFunnel(String funnelId) {
    final funnel = instance._funnels.remove(funnelId);
    if (funnel == null) return;

    // Remove event mappings
    for (final step in funnel.steps) {
      final refs = instance._eventToSteps[step.eventName];
      refs?.removeWhere((r) => r.funnelId == funnelId);
      if (refs?.isEmpty == true) {
        instance._eventToSteps.remove(step.eventName);
      }
    }

    // Mark any active progress as abandoned
    final progress = instance._activeProgress.remove(funnelId);
    if (progress != null) {
      instance._addToHistory(progress.markAbandoned());
    }
  }

  /// Called when an analytics event is logged.
  ///
  /// This is called automatically by VooAnalyticsPlugin.
  static void onEvent(String eventName, Map<String, dynamic>? params) {
    if (!_initialized) return;

    final refs = instance._eventToSteps[eventName];
    if (refs == null || refs.isEmpty) return;

    for (final ref in refs) {
      instance._processEvent(ref, eventName, params);
    }
  }

  void _processEvent(
    _FunnelStepRef ref,
    String eventName,
    Map<String, dynamic>? params,
  ) {
    final funnel = _funnels[ref.funnelId];
    if (funnel == null || !funnel.isActive) return;

    final step = ref.step;
    var progress = _activeProgress[ref.funnelId];

    // Check if this is the expected next step
    if (progress == null) {
      // Only start funnel on first step
      if (step.order != 0) return;

      // Start new funnel progress
      progress = VooFunnelProgress(
        funnelId: ref.funnelId,
        sessionId: Voo.sessionId ?? 'unknown',
        userId: Voo.userId,
        completedSteps: [],
        startTime: DateTime.now(),
        isComplete: false,
        isAbandoned: false,
        currentStepIndex: 0,
      );

      if (kDebugMode) {
        debugPrint(
            'FunnelTrackingService: Started funnel "${funnel.name}"');
      }
    }

    // Check if this is the expected step
    if (step.order != progress.currentStepIndex) {
      // Not the expected step
      if (step.order < progress.currentStepIndex) {
        // Already completed this step
        return;
      }
      // Skipped steps - check if intermediate steps are optional
      final skippedSteps = funnel.steps
          .where((s) =>
              s.order >= progress!.currentStepIndex && s.order < step.order)
          .toList();

      final hasRequiredSkipped = skippedSteps.any((s) => !s.isOptional);
      if (hasRequiredSkipped) {
        // Can't skip required steps
        return;
      }
    }

    // Check required params
    if (step.requiredParams != null && params != null) {
      for (final entry in step.requiredParams!.entries) {
        if (params[entry.key] != entry.value) {
          return; // Required param doesn't match
        }
      }
    }

    // Check time constraint
    if (step.maxTimeSincePrevious != null && progress.completedSteps.isNotEmpty) {
      final lastCompletion = progress.completedSteps.last;
      final timeSince = DateTime.now().difference(lastCompletion.completedAt);
      if (timeSince > step.maxTimeSincePrevious!) {
        // Too much time has passed, abandon funnel
        _activeProgress.remove(ref.funnelId);
        _addToHistory(progress.markAbandoned());

        _eventController.add(FunnelEvent(
          type: FunnelEventType.abandoned,
          funnelId: ref.funnelId,
          progress: progress,
          reason: 'Step timeout exceeded',
        ));
        return;
      }
    }

    // Complete the step
    final timeSincePrevious = progress.completedSteps.isNotEmpty
        ? DateTime.now().difference(progress.completedSteps.last.completedAt)
        : null;

    final completion = VooFunnelStepCompletion(
      stepId: step.id,
      completedAt: DateTime.now(),
      timeSincePrevious: timeSincePrevious,
      eventParams: params,
    );

    progress = progress.withStepCompleted(completion);
    _activeProgress[ref.funnelId] = progress;

    // Log step completion
    _logStepCompletion(funnel, step, progress);

    _eventController.add(FunnelEvent(
      type: FunnelEventType.stepCompleted,
      funnelId: ref.funnelId,
      stepId: step.id,
      progress: progress,
    ));

    if (kDebugMode) {
      debugPrint(
          'FunnelTrackingService: Completed step "${step.name}" in "${funnel.name}"');
    }

    // Check if funnel is complete
    final requiredSteps = funnel.steps.where((s) => !s.isOptional).length;
    final completedRequired = progress.completedSteps
        .where((c) {
          final s = funnel.steps.firstWhere((fs) => fs.id == c.stepId);
          return !s.isOptional;
        })
        .length;

    if (completedRequired >= requiredSteps) {
      // Funnel complete!
      progress = progress.markComplete();
      _activeProgress.remove(ref.funnelId);
      _addToHistory(progress);

      _logFunnelCompletion(funnel, progress);

      _eventController.add(FunnelEvent(
        type: FunnelEventType.completed,
        funnelId: ref.funnelId,
        progress: progress,
      ));

      if (kDebugMode) {
        debugPrint(
            'FunnelTrackingService: Completed funnel "${funnel.name}" in ${progress.duration?.inSeconds}s');
      }
    }
  }

  void _logStepCompletion(
    VooFunnel funnel,
    VooFunnelStep step,
    VooFunnelProgress progress,
  ) {
    try {
      VooAnalyticsPlugin.instance.logEvent(
        'funnel_step_completed',
        category: 'funnel',
        parameters: {
          'funnel_id': funnel.id,
          'funnel_name': funnel.name,
          'step_id': step.id,
          'step_name': step.name,
          'step_order': step.order,
          'steps_completed': progress.completedSteps.length,
          'total_steps': funnel.steps.length,
        },
      );
    } catch (e) {
      // Ignore logging errors
    }
  }

  void _logFunnelCompletion(VooFunnel funnel, VooFunnelProgress progress) {
    try {
      VooAnalyticsPlugin.instance.logEvent(
        'funnel_completed',
        category: 'funnel',
        parameters: {
          'funnel_id': funnel.id,
          'funnel_name': funnel.name,
          'duration_ms': progress.duration?.inMilliseconds,
          'steps_completed': progress.completedSteps.length,
        },
      );
    } catch (e) {
      // Ignore logging errors
    }
  }

  void _addToHistory(VooFunnelProgress progress) {
    _history.add(progress);
    while (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// Get current progress for a funnel.
  static VooFunnelProgress? getProgress(String funnelId) {
    return instance._activeProgress[funnelId];
  }

  /// Get all active funnel progress.
  static List<VooFunnelProgress> getActiveProgress() {
    return instance._activeProgress.values.toList();
  }

  /// Get funnel completion history.
  static List<VooFunnelProgress> getHistory({String? funnelId}) {
    if (funnelId != null) {
      return instance._history.where((p) => p.funnelId == funnelId).toList();
    }
    return List.unmodifiable(instance._history);
  }

  /// Get registered funnels.
  static List<VooFunnel> getFunnels() {
    return instance._funnels.values.toList();
  }

  /// Get a specific funnel by ID.
  static VooFunnel? getFunnel(String funnelId) {
    return instance._funnels[funnelId];
  }

  /// Mark a funnel as abandoned (e.g., on session end).
  static void markAbandoned(String funnelId, {String? reason}) {
    final progress = instance._activeProgress.remove(funnelId);
    if (progress == null) return;

    final abandoned = progress.markAbandoned();
    instance._addToHistory(abandoned);

    instance._eventController.add(FunnelEvent(
      type: FunnelEventType.abandoned,
      funnelId: funnelId,
      progress: abandoned,
      reason: reason,
    ));

    if (kDebugMode) {
      debugPrint(
          'FunnelTrackingService: Abandoned funnel "$funnelId" - $reason');
    }
  }

  /// Mark all active funnels as abandoned (e.g., on app close).
  static void markAllAbandoned({String? reason}) {
    final funnelIds = instance._activeProgress.keys.toList();
    for (final id in funnelIds) {
      markAbandoned(id, reason: reason);
    }
  }

  /// Reset a funnel's progress (start fresh).
  static void resetProgress(String funnelId) {
    instance._activeProgress.remove(funnelId);

    if (kDebugMode) {
      debugPrint('FunnelTrackingService: Reset progress for "$funnelId"');
    }
  }

  /// Dispose resources.
  static Future<void> dispose() async {
    markAllAbandoned(reason: 'app_close');
    await instance._eventController.close();
    instance._funnels.clear();
    instance._activeProgress.clear();
    instance._eventToSteps.clear();
    _initialized = false;
    _instance = null;

    if (kDebugMode) {
      debugPrint('FunnelTrackingService: Disposed');
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    instance._funnels.clear();
    instance._activeProgress.clear();
    instance._history.clear();
    instance._eventToSteps.clear();
    _initialized = false;
    _instance = null;
  }
}

/// Reference to a funnel step for event mapping.
class _FunnelStepRef {
  final String funnelId;
  final VooFunnelStep step;

  _FunnelStepRef({required this.funnelId, required this.step});
}

/// Types of funnel events.
enum FunnelEventType {
  /// A step in the funnel was completed.
  stepCompleted,

  /// The entire funnel was completed.
  completed,

  /// The funnel was abandoned.
  abandoned,
}

/// Event emitted by the funnel tracking service.
@immutable
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
