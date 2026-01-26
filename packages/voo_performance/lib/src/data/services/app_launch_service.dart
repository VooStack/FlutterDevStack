import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:voo_core/voo_core.dart';

/// Type of app launch.
enum LaunchType {
  /// App was not in memory - full cold start.
  cold,

  /// App was in background memory - warm start.
  warm,

  /// App was resumed from recent apps.
  hot,
}

/// Represents timing data for an app launch.
@immutable
class AppLaunchMetrics {
  /// Type of launch.
  final LaunchType launchType;

  /// Time from process start to first frame rendered.
  final Duration? timeToFirstFrame;

  /// Time from process start to app being interactive.
  final Duration? timeToInteractive;

  /// Time spent in native initialization (before Flutter engine).
  final Duration? nativeInitTime;

  /// Time spent in Flutter engine initialization.
  final Duration? engineInitTime;

  /// Time spent in Dart isolate initialization.
  final Duration? dartInitTime;

  /// Time spent in widget binding initialization.
  final Duration? widgetBindingInitTime;

  /// Time spent rendering the first frame.
  final Duration? firstFrameRenderTime;

  /// Timestamp when the launch completed.
  final DateTime launchTimestamp;

  /// Whether the launch was successful.
  final bool isSuccessful;

  /// Any error that occurred during launch.
  final String? errorMessage;

  const AppLaunchMetrics({
    required this.launchType,
    this.timeToFirstFrame,
    this.timeToInteractive,
    this.nativeInitTime,
    this.engineInitTime,
    this.dartInitTime,
    this.widgetBindingInitTime,
    this.firstFrameRenderTime,
    required this.launchTimestamp,
    this.isSuccessful = true,
    this.errorMessage,
  });

  /// Total launch time.
  Duration? get totalLaunchTime => timeToInteractive ?? timeToFirstFrame;

  /// Whether this was a slow launch (> 3 seconds).
  bool get isSlowLaunch => totalLaunchTime != null && totalLaunchTime!.inMilliseconds > 3000;

  Map<String, dynamic> toJson() => {
    'launch_type': launchType.name,
    if (timeToFirstFrame != null) 'time_to_first_frame_ms': timeToFirstFrame!.inMilliseconds,
    if (timeToInteractive != null) 'time_to_interactive_ms': timeToInteractive!.inMilliseconds,
    if (nativeInitTime != null) 'native_init_time_ms': nativeInitTime!.inMilliseconds,
    if (engineInitTime != null) 'engine_init_time_ms': engineInitTime!.inMilliseconds,
    if (dartInitTime != null) 'dart_init_time_ms': dartInitTime!.inMilliseconds,
    if (widgetBindingInitTime != null) 'widget_binding_init_time_ms': widgetBindingInitTime!.inMilliseconds,
    if (firstFrameRenderTime != null) 'first_frame_render_time_ms': firstFrameRenderTime!.inMilliseconds,
    'launch_timestamp': launchTimestamp.toIso8601String(),
    'is_successful': isSuccessful,
    if (errorMessage != null) 'error_message': errorMessage,
    'is_slow_launch': isSlowLaunch,
  };
}

/// Service for tracking app launch performance.
///
/// Detects cold vs warm starts and measures key timing milestones:
/// - Time to first frame
/// - Time to interactive
/// - Various initialization phases
///
/// ## Usage
///
/// ```dart
/// // Call as early as possible in main()
/// void main() {
///   AppLaunchService.markLaunchStart();
///
///   WidgetsFlutterBinding.ensureInitialized();
///   AppLaunchService.markWidgetBindingReady();
///
///   runApp(MyApp());
/// }
///
/// // In your first interactive screen
/// class HomeScreen extends StatefulWidget {
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addPostFrameCallback((_) {
///       AppLaunchService.markInteractive();
///     });
///   }
/// }
/// ```
class AppLaunchService with WidgetsBindingObserver {
  static AppLaunchService? _instance;
  static bool _initialized = false;

  /// Process start time - captured as early as possible.
  static DateTime? _processStartTime;

  /// Widget binding ready time.
  static DateTime? _widgetBindingReadyTime;

  /// First frame rendered time.
  static DateTime? _firstFrameTime;

  /// App interactive time.
  static DateTime? _interactiveTime;

  /// Current app lifecycle state.
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;

  /// Whether this is the initial launch.
  bool _isInitialLaunch = true;

  /// Last time app went to background.
  DateTime? _lastBackgroundTime;

  /// Stream controller for launch metrics.
  final StreamController<AppLaunchMetrics> _launchController = StreamController<AppLaunchMetrics>.broadcast();

  /// History of launches in this session.
  final List<AppLaunchMetrics> _launchHistory = [];

  AppLaunchService._();

  /// Get the singleton instance.
  static AppLaunchService get instance {
    _instance ??= AppLaunchService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Stream of launch metrics.
  static Stream<AppLaunchMetrics> get launchStream => instance._launchController.stream;

  /// Get launch history.
  static List<AppLaunchMetrics> get launchHistory => List.unmodifiable(instance._launchHistory);

  /// Get the initial launch metrics.
  static AppLaunchMetrics? get initialLaunch => instance._launchHistory.isNotEmpty ? instance._launchHistory.first : null;

  /// Mark the start of app launch - call this as early as possible in main().
  static void markLaunchStart() {
    _processStartTime ??= DateTime.now();
  }

  /// Mark when widget binding is ready.
  static void markWidgetBindingReady() {
    _widgetBindingReadyTime = DateTime.now();
  }

  /// Initialize the service - call after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> initialize() async {
    if (_initialized) return;

    // Ensure we have a start time
    _processStartTime ??= DateTime.now();

    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(instance);

    // Wait for first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _firstFrameTime = DateTime.now();

      // Record cold start metrics
      if (instance._isInitialLaunch) {
        instance._recordLaunch(LaunchType.cold);
      }
    });

    _initialized = true;
  }

  /// Mark when the app is fully interactive.
  /// Call this when your main screen is ready and responsive.
  static void markInteractive() {
    if (_interactiveTime != null && instance._isInitialLaunch) {
      return; // Already marked for initial launch
    }

    _interactiveTime = DateTime.now();

    // Update metrics with interactive time
    if (instance._isInitialLaunch && instance._launchHistory.isNotEmpty) {
      final lastLaunch = instance._launchHistory.last;
      instance._launchHistory[instance._launchHistory.length - 1] = AppLaunchMetrics(
        launchType: lastLaunch.launchType,
        timeToFirstFrame: lastLaunch.timeToFirstFrame,
        timeToInteractive: _interactiveTime!.difference(_processStartTime!),
        nativeInitTime: lastLaunch.nativeInitTime,
        engineInitTime: lastLaunch.engineInitTime,
        dartInitTime: lastLaunch.dartInitTime,
        widgetBindingInitTime: lastLaunch.widgetBindingInitTime,
        firstFrameRenderTime: lastLaunch.firstFrameRenderTime,
        launchTimestamp: lastLaunch.launchTimestamp,
        isSuccessful: true,
      );
    }

    instance._isInitialLaunch = false;

    // Add breadcrumb
    Voo.addBreadcrumb(
      VooBreadcrumb(
        type: VooBreadcrumbType.custom,
        category: 'app_lifecycle',
        message: 'App became interactive',
        data: {'time_to_interactive_ms': _interactiveTime!.difference(_processStartTime!).inMilliseconds},
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = _lastLifecycleState;
    _lastLifecycleState = state;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _lastBackgroundTime = DateTime.now();

      case AppLifecycleState.resumed:
        if (previousState == AppLifecycleState.paused || previousState == AppLifecycleState.inactive) {
          _handleResume();
        }

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is being destroyed or hidden
        break;
    }
  }

  void _handleResume() {
    final resumeTime = DateTime.now();
    final launchType = _determineLaunchType();

    // Reset first frame time for warm/hot start measurement
    _firstFrameTime = null;

    // Wait for first frame after resume
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _firstFrameTime = DateTime.now();
      _recordLaunch(launchType);
    });

    // Add breadcrumb
    Voo.addBreadcrumb(
      VooBreadcrumb(
        type: VooBreadcrumbType.custom,
        category: 'app_lifecycle',
        message: 'App resumed (${launchType.name} start)',
        data: {if (_lastBackgroundTime != null) 'background_duration_ms': resumeTime.difference(_lastBackgroundTime!).inMilliseconds},
      ),
    );
  }

  LaunchType _determineLaunchType() {
    if (_lastBackgroundTime == null) return LaunchType.cold;

    final backgroundDuration = DateTime.now().difference(_lastBackgroundTime!);

    // If app was in background for more than 30 minutes, consider it a warm start
    // (OS may have released some resources)
    if (backgroundDuration.inMinutes > 30) {
      return LaunchType.warm;
    }

    // Hot start - app was recently in background
    return LaunchType.hot;
  }

  void _recordLaunch(LaunchType launchType) {
    final now = DateTime.now();

    Duration? timeToFirstFrame;
    Duration? widgetBindingInitTime;

    if (_processStartTime != null && _firstFrameTime != null) {
      timeToFirstFrame = _firstFrameTime!.difference(_processStartTime!);
    }

    if (_processStartTime != null && _widgetBindingReadyTime != null) {
      widgetBindingInitTime = _widgetBindingReadyTime!.difference(_processStartTime!);
    }

    final metrics = AppLaunchMetrics(
      launchType: launchType,
      timeToFirstFrame: timeToFirstFrame,
      timeToInteractive: _interactiveTime?.difference(_processStartTime ?? now),
      widgetBindingInitTime: widgetBindingInitTime,
      launchTimestamp: now,
      isSuccessful: true,
    );

    _launchHistory.add(metrics);
    _launchController.add(metrics);

    // Log to Voo performance
    _logLaunchMetrics(metrics);

  }

  void _logLaunchMetrics(AppLaunchMetrics metrics) {
    try {
      // Add breadcrumb for launch metrics
      Voo.addBreadcrumb(
        VooBreadcrumb(
          type: VooBreadcrumbType.system,
          category: 'performance',
          message: 'App launch: ${metrics.launchType.name}',
          data: {
            'launch_type': metrics.launchType.name,
            'is_slow': metrics.isSlowLaunch,
            if (metrics.totalLaunchTime != null) 'total_launch_time_ms': metrics.totalLaunchTime!.inMilliseconds,
            if (metrics.timeToFirstFrame != null) 'time_to_first_frame_ms': metrics.timeToFirstFrame!.inMilliseconds,
            if (metrics.timeToInteractive != null) 'time_to_interactive_ms': metrics.timeToInteractive!.inMilliseconds,
          },
        ),
      );
    } catch (_) {
      // Metrics logging error ignored
    }
  }

  /// Record a launch error.
  static void recordLaunchError(String error) {
    final metrics = AppLaunchMetrics(
      launchType: instance._isInitialLaunch ? LaunchType.cold : LaunchType.warm,
      launchTimestamp: DateTime.now(),
      isSuccessful: false,
      errorMessage: error,
    );

    instance._launchHistory.add(metrics);
    instance._launchController.add(metrics);

    Voo.addBreadcrumb(VooBreadcrumb(type: VooBreadcrumbType.error, category: 'app_lifecycle', message: 'Launch error: $error', level: VooBreadcrumbLevel.error));
  }

  /// Dispose resources.
  static Future<void> dispose() async {
    if (_instance != null) {
      WidgetsBinding.instance.removeObserver(_instance!);
      await _instance!._launchController.close();
    }
    _initialized = false;
    _instance = null;
    _processStartTime = null;
    _widgetBindingReadyTime = null;
    _firstFrameTime = null;
    _interactiveTime = null;
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _instance = null;
    _processStartTime = null;
    _widgetBindingReadyTime = null;
    _firstFrameTime = null;
    _interactiveTime = null;
  }
}
