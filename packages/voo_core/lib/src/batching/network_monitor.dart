import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:voo_core/src/batching/batch_config.dart';

/// Monitors network connectivity and provides optimal batch configuration.
///
/// Automatically adjusts batching parameters based on network conditions
/// to optimize battery usage and data transmission.
class NetworkMonitor {
  static NetworkMonitor? _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkType _currentNetworkType = NetworkType.unknown;
  BatchConfig _currentConfig = const BatchConfig();
  bool _initialized = false;

  final _networkTypeController = StreamController<NetworkType>.broadcast();
  final _configController = StreamController<BatchConfig>.broadcast();

  NetworkMonitor._();

  /// Get the singleton instance.
  static NetworkMonitor get instance {
    _instance ??= NetworkMonitor._();
    return _instance!;
  }

  /// Whether the monitor is initialized.
  bool get isInitialized => _initialized;

  /// Current network type.
  NetworkType get currentNetworkType => _currentNetworkType;

  /// Current batch configuration based on network.
  BatchConfig get currentConfig => _currentConfig;

  /// Whether device is currently online.
  bool get isOnline => _currentNetworkType != NetworkType.none;

  /// Whether device is on WiFi.
  bool get isWifi => _currentNetworkType == NetworkType.wifi;

  /// Whether device is on cellular.
  bool get isCellular => _currentNetworkType == NetworkType.cellular;

  /// Stream of network type changes.
  Stream<NetworkType> get networkTypeStream => _networkTypeController.stream;

  /// Stream of config changes based on network.
  Stream<BatchConfig> get configStream => _configController.stream;

  /// Initialize the network monitor.
  Future<void> initialize() async {
    if (_initialized) return;

    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _updateNetworkType(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateNetworkType);

    _initialized = true;

    if (kDebugMode) {
      debugPrint('NetworkMonitor: Initialized with $_currentNetworkType');
    }
  }

  void _updateNetworkType(List<ConnectivityResult> results) {
    final newType = _mapConnectivityResult(results);
    if (newType != _currentNetworkType) {
      _currentNetworkType = newType;
      _currentConfig = _getConfigForNetwork(newType);

      _networkTypeController.add(newType);
      _configController.add(_currentConfig);

      if (kDebugMode) {
        debugPrint('NetworkMonitor: Network changed to $_currentNetworkType');
      }
    }
  }

  NetworkType _mapConnectivityResult(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkType.none;
    }

    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkType.wifi;
    }

    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkType.ethernet;
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkType.cellular;
    }

    return NetworkType.unknown;
  }

  BatchConfig _getConfigForNetwork(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
      case NetworkType.ethernet:
        return BatchConfig.wifi();
      case NetworkType.cellular:
        return BatchConfig.cellular();
      case NetworkType.none:
        return BatchConfig.offline();
      case NetworkType.unknown:
        return const BatchConfig();
    }
  }

  /// Get optimal batch configuration for current network.
  ///
  /// Optionally provide a base config to merge with network-specific settings.
  BatchConfig getOptimalConfig([BatchConfig? baseConfig]) {
    if (baseConfig == null || !baseConfig.enableNetworkAwareBatching) {
      return baseConfig ?? _currentConfig;
    }

    return baseConfig.copyWith(
      batchSize: _currentConfig.batchSize,
      batchInterval: _currentConfig.batchInterval,
      priorityFlushInterval: _currentConfig.priorityFlushInterval,
      compressionThreshold: _currentConfig.compressionThreshold,
    );
  }

  /// Dispose the network monitor.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _networkTypeController.close();
    await _configController.close();
    _initialized = false;
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
