import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Runtime metrics that can change during app execution.
///
/// Unlike [VooDeviceInfo] which captures static device properties at startup,
/// [VooRuntimeMetrics] captures dynamic metrics that can change during runtime.
@immutable
class VooRuntimeMetrics {
  /// Network connection type (wifi, mobile, none, other)
  final String networkType;

  /// Whether the device is connected to the internet.
  final bool isConnected;

  /// Battery level as percentage (0-100). Null if unavailable.
  final int? batteryLevel;

  /// Battery state (charging, discharging, full, unknown).
  final String batteryState;

  /// Current device orientation (portrait, landscape).
  final String orientation;

  /// Timestamp when these metrics were collected.
  final DateTime collectedAt;

  const VooRuntimeMetrics({
    required this.networkType,
    required this.isConnected,
    this.batteryLevel,
    required this.batteryState,
    required this.orientation,
    required this.collectedAt,
  });

  /// Creates a copy with updated fields.
  VooRuntimeMetrics copyWith({
    String? networkType,
    bool? isConnected,
    int? batteryLevel,
    String? batteryState,
    String? orientation,
    DateTime? collectedAt,
  }) {
    return VooRuntimeMetrics(
      networkType: networkType ?? this.networkType,
      isConnected: isConnected ?? this.isConnected,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryState: batteryState ?? this.batteryState,
      orientation: orientation ?? this.orientation,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }

  /// Converts to a map for sync payloads.
  Map<String, dynamic> toJson() {
    return {
      'networkType': networkType,
      'isConnected': isConnected,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      'batteryState': batteryState,
      'orientation': orientation,
      'collectedAt': collectedAt.toIso8601String(),
    };
  }

  /// Converts to analytics tags format.
  Map<String, String> toAnalyticsTags() {
    return {
      'network_type': networkType,
      'is_connected': isConnected.toString(),
      if (batteryLevel != null) 'battery_level': batteryLevel.toString(),
      'battery_state': batteryState,
      'orientation': orientation,
    };
  }

  @override
  String toString() {
    return 'VooRuntimeMetrics(network: $networkType, connected: $isConnected, '
        'battery: $batteryLevel% $batteryState, orientation: $orientation)';
  }
}

/// Service for collecting and monitoring runtime device metrics.
///
/// This service tracks metrics that can change during app execution:
/// - Network connectivity and type
/// - Battery level and charging state
/// - Device orientation
///
/// ## Usage
///
/// ```dart
/// // Initialize during app startup
/// await VooRuntimeMetricsService.initialize();
///
/// // Get current metrics
/// final metrics = VooRuntimeMetricsService.currentMetrics;
/// print('Battery: ${metrics?.batteryLevel}%');
///
/// // Listen to changes
/// VooRuntimeMetricsService.metricsStream.listen((metrics) {
///   print('Network changed: ${metrics.networkType}');
/// });
/// ```
class VooRuntimeMetricsService {
  static VooRuntimeMetricsService? _instance;
  static VooRuntimeMetrics? _currentMetrics;
  static bool _initialized = false;

  // Plugins
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  // Subscriptions
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controller for metrics changes
  final StreamController<VooRuntimeMetrics> _metricsController =
      StreamController<VooRuntimeMetrics>.broadcast();

  VooRuntimeMetricsService._();

  /// Get the singleton instance.
  static VooRuntimeMetricsService get instance {
    _instance ??= VooRuntimeMetricsService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Current runtime metrics. Null if not initialized.
  static VooRuntimeMetrics? get currentMetrics => _currentMetrics;

  /// Stream of runtime metrics changes.
  static Stream<VooRuntimeMetrics> get metricsStream =>
      instance._metricsController.stream;

  /// Initialize the runtime metrics service.
  ///
  /// Collects initial metrics and starts monitoring for changes.
  static Future<VooRuntimeMetrics> initialize() async {
    if (_initialized && _currentMetrics != null) {
      return _currentMetrics!;
    }

    try {
      _currentMetrics = await instance._collectMetrics();
      await instance._startMonitoring();
      _initialized = true;

      if (kDebugMode) {
        debugPrint('VooRuntimeMetricsService: Initialized - $_currentMetrics');
      }

      return _currentMetrics!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooRuntimeMetricsService: Initialization failed: $e');
      }
      _currentMetrics = _fallbackMetrics();
      return _currentMetrics!;
    }
  }

  /// Refresh metrics manually.
  static Future<VooRuntimeMetrics> refresh() async {
    try {
      _currentMetrics = await instance._collectMetrics();
      instance._metricsController.add(_currentMetrics!);
      return _currentMetrics!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooRuntimeMetricsService: Refresh failed: $e');
      }
      return _currentMetrics ?? _fallbackMetrics();
    }
  }

  /// Collect all runtime metrics.
  Future<VooRuntimeMetrics> _collectMetrics() async {
    final networkType = await _getNetworkType();
    final isConnected = await _getIsConnected();
    final batteryLevel = await _getBatteryLevel();
    final batteryState = await _getBatteryState();
    final orientation = _getOrientation();

    return VooRuntimeMetrics(
      networkType: networkType,
      isConnected: isConnected,
      batteryLevel: batteryLevel,
      batteryState: batteryState,
      orientation: orientation,
      collectedAt: DateTime.now(),
    );
  }

  /// Start monitoring for metric changes.
  Future<void> _startMonitoring() async {
    // Monitor network connectivity changes
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) async {
        final networkType = _connectivityResultsToString(results);
        final isConnected = !results.contains(ConnectivityResult.none);

        if (_currentMetrics != null &&
            (_currentMetrics!.networkType != networkType ||
                _currentMetrics!.isConnected != isConnected)) {
          _currentMetrics = _currentMetrics!.copyWith(
            networkType: networkType,
            isConnected: isConnected,
            collectedAt: DateTime.now(),
          );
          _metricsController.add(_currentMetrics!);

          if (kDebugMode) {
            debugPrint(
                'VooRuntimeMetricsService: Network changed to $networkType');
          }
        }
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('VooRuntimeMetricsService: Connectivity error: $e');
        }
      },
    );
  }

  /// Get current network type.
  Future<String> _getNetworkType() async {
    if (kIsWeb) {
      // Web doesn't have reliable network type detection
      return 'web';
    }

    try {
      final results = await _connectivity.checkConnectivity();
      return _connectivityResultsToString(results);
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if connected to the internet.
  Future<bool> _getIsConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      return true; // Assume connected on error
    }
  }

  /// Get battery level (0-100).
  Future<int?> _getBatteryLevel() async {
    if (kIsWeb) return null;

    try {
      return await _battery.batteryLevel;
    } on PlatformException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get battery state.
  Future<String> _getBatteryState() async {
    if (kIsWeb) return 'unknown';

    try {
      final state = await _battery.batteryState;
      return _batteryStateToString(state);
    } on PlatformException {
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get current device orientation.
  String _getOrientation() {
    // This is a simplified version; in production you'd use
    // MediaQuery or OrientationBuilder context
    return 'portrait';
  }

  /// Convert connectivity results to string.
  String _connectivityResultsToString(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'none';
    }

    // Return the primary connection type
    final primary = results.first;
    switch (primary) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'cellular';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.vpn:
        return 'vpn';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      case ConnectivityResult.other:
        return 'other';
      case ConnectivityResult.none:
        return 'none';
    }
  }

  /// Convert battery state to string.
  String _batteryStateToString(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return 'charging';
      case BatteryState.discharging:
        return 'discharging';
      case BatteryState.full:
        return 'full';
      case BatteryState.connectedNotCharging:
        return 'connected_not_charging';
      case BatteryState.unknown:
        return 'unknown';
    }
  }

  /// Create fallback metrics when collection fails.
  static VooRuntimeMetrics _fallbackMetrics() {
    return VooRuntimeMetrics(
      networkType: 'unknown',
      isConnected: true,
      batteryLevel: null,
      batteryState: 'unknown',
      orientation: 'portrait',
      collectedAt: DateTime.now(),
    );
  }

  /// Dispose resources and stop monitoring.
  static Future<void> dispose() async {
    await instance._connectivitySubscription?.cancel();
    await instance._metricsController.close();
    _initialized = false;
    _currentMetrics = null;
    _instance = null;

    if (kDebugMode) {
      debugPrint('VooRuntimeMetricsService: Disposed');
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _currentMetrics = null;
    _instance = null;
  }
}
