import 'package:flutter/foundation.dart';

/// Configuration options for Voo initialization.
///
/// These options configure the local behavior of Voo packages.
/// For API and sync configuration, use [VooConfig] instead.
///
/// ## Migration from customConfig
/// Previously, device and user info was passed via [customConfig]:
/// ```dart
/// // Old way (deprecated)
/// VooOptions(customConfig: {'deviceId': '...', 'userId': '...'})
///
/// // New way
/// await Voo.initializeApp(
///   config: VooConfig(endpoint: '...', apiKey: '...', projectId: '...'),
/// );
/// // Device info is auto-collected, user set via Voo.setUserId()
/// ```
@immutable
class VooOptions {
  /// Enable debug logging for Voo packages.
  final bool enableDebugLogging;

  /// Automatically register discovered plugins.
  final bool autoRegisterPlugins;

  /// Custom configuration that can be accessed by plugins.
  ///
  /// @Deprecated('Use VooConfig for API/sync config, Voo.setUserId() for user context. '
  ///   'Device info is now auto-collected.')
  @Deprecated('Use VooConfig for API/sync config. Device info is now auto-collected.')
  final Map<String, dynamic> customConfig;

  /// Timeout for plugin initialization.
  final Duration initializationTimeout;

  /// App name for identification.
  final String? appName;

  /// App version for tracking.
  final String? appVersion;

  /// Environment (development, staging, production).
  final String environment;

  /// Enable local persistence for data.
  final bool enableLocalPersistence;

  /// Maximum local storage size in MB.
  final int maxLocalStorageMB;

  /// Whether to automatically collect device information.
  ///
  /// When true (default), device info is collected during [Voo.initializeApp]
  /// and accessible via [Voo.deviceInfo].
  final bool autoCollectDeviceInfo;

  const VooOptions({
    this.enableDebugLogging = kDebugMode,
    this.autoRegisterPlugins = true,
    @Deprecated('Use VooConfig for API/sync config. Device info is now auto-collected.') this.customConfig = const {},
    this.initializationTimeout = const Duration(seconds: 10),
    this.appName,
    this.appVersion,
    this.environment = 'development',
    this.enableLocalPersistence = true,
    this.maxLocalStorageMB = 100,
    this.autoCollectDeviceInfo = true,
  });

  VooOptions copyWith({
    bool? enableDebugLogging,
    bool? autoRegisterPlugins,
    @Deprecated('Use VooConfig instead') Map<String, dynamic>? customConfig,
    Duration? initializationTimeout,
    String? appName,
    String? appVersion,
    String? environment,
    bool? enableLocalPersistence,
    int? maxLocalStorageMB,
    bool? autoCollectDeviceInfo,
  }) {
    return VooOptions(
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      autoRegisterPlugins: autoRegisterPlugins ?? this.autoRegisterPlugins,
      // ignore: deprecated_member_use_from_same_package
      customConfig: customConfig ?? this.customConfig,
      initializationTimeout: initializationTimeout ?? this.initializationTimeout,
      appName: appName ?? this.appName,
      appVersion: appVersion ?? this.appVersion,
      environment: environment ?? this.environment,
      enableLocalPersistence: enableLocalPersistence ?? this.enableLocalPersistence,
      maxLocalStorageMB: maxLocalStorageMB ?? this.maxLocalStorageMB,
      autoCollectDeviceInfo: autoCollectDeviceInfo ?? this.autoCollectDeviceInfo,
    );
  }

  /// Create options for production environment.
  factory VooOptions.production({String? appName, String? appVersion, bool autoCollectDeviceInfo = true}) {
    return VooOptions(enableDebugLogging: false, environment: 'production', appName: appName, appVersion: appVersion, autoCollectDeviceInfo: autoCollectDeviceInfo);
  }

  /// Create options for development environment.
  factory VooOptions.development({String? appName, String? appVersion, bool autoCollectDeviceInfo = true}) {
    return VooOptions(enableDebugLogging: true, environment: 'development', appName: appName, appVersion: appVersion, autoCollectDeviceInfo: autoCollectDeviceInfo);
  }

  @override
  String toString() {
    return 'VooOptions(enableDebugLogging: $enableDebugLogging, '
        'autoRegisterPlugins: $autoRegisterPlugins, environment: $environment, '
        'appName: $appName, appVersion: $appVersion, '
        'autoCollectDeviceInfo: $autoCollectDeviceInfo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VooOptions &&
        other.enableDebugLogging == enableDebugLogging &&
        other.autoRegisterPlugins == autoRegisterPlugins &&
        // ignore: deprecated_member_use_from_same_package
        mapEquals(other.customConfig, customConfig) &&
        other.initializationTimeout == initializationTimeout &&
        other.appName == appName &&
        other.appVersion == appVersion &&
        other.environment == environment &&
        other.enableLocalPersistence == enableLocalPersistence &&
        other.maxLocalStorageMB == maxLocalStorageMB &&
        other.autoCollectDeviceInfo == autoCollectDeviceInfo;
  }

  @override
  int get hashCode {
    return Object.hash(
      enableDebugLogging,
      autoRegisterPlugins,
      // ignore: deprecated_member_use_from_same_package
      customConfig,
      initializationTimeout,
      appName,
      appVersion,
      environment,
      enableLocalPersistence,
      maxLocalStorageMB,
      autoCollectDeviceInfo,
    );
  }
}
