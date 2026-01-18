import 'package:flutter/foundation.dart';

/// Comprehensive device information collected automatically by voo_core.
///
/// This immutable class contains all device, app, and platform information
/// needed for telemetry and analytics. It is auto-populated during
/// [Voo.initializeApp] using [VooDeviceInfoService].
@immutable
class VooDeviceInfo {
  /// Unique identifier for this device.
  final String deviceId;

  /// Device model name (e.g., "iPhone 14 Pro", "Pixel 7").
  final String deviceModel;

  /// Device manufacturer (e.g., "Apple", "Samsung").
  final String manufacturer;

  /// Operating system name (e.g., "iOS", "Android", "macOS", "Web").
  final String osName;

  /// Operating system version.
  final String osVersion;

  /// Screen width in pixels (optional).
  final String? screenWidth;

  /// Screen height in pixels (optional).
  final String? screenHeight;

  /// Display density/scale factor (optional).
  final String? displayDensity;

  /// Device locale (e.g., "en_US").
  final String locale;

  /// Device timezone (e.g., "America/New_York").
  final String timezone;

  /// App version string (e.g., "1.0.0").
  final String appVersion;

  /// App build number (e.g., "42").
  final String buildNumber;

  /// App package name (e.g., "com.example.app").
  final String packageName;

  /// Browser user agent string (web only).
  final String? userAgent;

  /// Browser name (web only, e.g., "Chrome", "Safari").
  final String? browserName;

  /// Browser version (web only).
  final String? browserVersion;

  /// Whether running on a physical device (vs simulator/emulator).
  final bool isPhysicalDevice;

  /// Additional platform-specific information.
  final Map<String, dynamic> additionalInfo;

  const VooDeviceInfo({
    required this.deviceId,
    required this.deviceModel,
    required this.manufacturer,
    required this.osName,
    required this.osVersion,
    this.screenWidth,
    this.screenHeight,
    this.displayDensity,
    required this.locale,
    required this.timezone,
    required this.appVersion,
    required this.buildNumber,
    required this.packageName,
    this.userAgent,
    this.browserName,
    this.browserVersion,
    required this.isPhysicalDevice,
    this.additionalInfo = const {},
  });

  /// Creates a copy with the given fields replaced.
  VooDeviceInfo copyWith({
    String? deviceId,
    String? deviceModel,
    String? manufacturer,
    String? osName,
    String? osVersion,
    String? screenWidth,
    String? screenHeight,
    String? displayDensity,
    String? locale,
    String? timezone,
    String? appVersion,
    String? buildNumber,
    String? packageName,
    String? userAgent,
    String? browserName,
    String? browserVersion,
    bool? isPhysicalDevice,
    Map<String, dynamic>? additionalInfo,
  }) {
    return VooDeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      manufacturer: manufacturer ?? this.manufacturer,
      osName: osName ?? this.osName,
      osVersion: osVersion ?? this.osVersion,
      screenWidth: screenWidth ?? this.screenWidth,
      screenHeight: screenHeight ?? this.screenHeight,
      displayDensity: displayDensity ?? this.displayDensity,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      packageName: packageName ?? this.packageName,
      userAgent: userAgent ?? this.userAgent,
      browserName: browserName ?? this.browserName,
      browserVersion: browserVersion ?? this.browserVersion,
      isPhysicalDevice: isPhysicalDevice ?? this.isPhysicalDevice,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'manufacturer': manufacturer,
        'osName': osName,
        'osVersion': osVersion,
        if (screenWidth != null) 'screenWidth': screenWidth,
        if (screenHeight != null) 'screenHeight': screenHeight,
        if (displayDensity != null) 'displayDensity': displayDensity,
        'locale': locale,
        'timezone': timezone,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'packageName': packageName,
        if (userAgent != null) 'userAgent': userAgent,
        if (browserName != null) 'browserName': browserName,
        if (browserVersion != null) 'browserVersion': browserVersion,
        'isPhysicalDevice': isPhysicalDevice,
        ...additionalInfo,
      };

  /// Returns the essential fields needed for sync payloads.
  ///
  /// Used by [VooContext.toSyncPayload] to include device info
  /// in telemetry requests.
  Map<String, dynamic> toSyncPayload() => {
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'platform': osName,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'locale': locale,
        'timezone': timezone,
        'isPhysicalDevice': isPhysicalDevice,
      };

  /// Returns a flattened map suitable for analytics tags.
  ///
  /// Keys are in snake_case format for analytics platforms.
  Map<String, String> toAnalyticsTags() => {
        'device_id': deviceId,
        'device_model': deviceModel,
        'manufacturer': manufacturer,
        'os_name': osName,
        'os_version': osVersion,
        'locale': locale,
        'timezone': timezone,
        'app_version': appVersion,
        'build_number': buildNumber,
        'is_physical_device': isPhysicalDevice.toString(),
      };

  /// Creates a VooDeviceInfo from a JSON map.
  factory VooDeviceInfo.fromJson(Map<String, dynamic> json) {
    return VooDeviceInfo(
      deviceId: json['deviceId'] as String? ?? 'unknown',
      deviceModel: json['deviceModel'] as String? ?? 'unknown',
      manufacturer: json['manufacturer'] as String? ?? 'unknown',
      osName: json['osName'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String? ?? 'unknown',
      screenWidth: json['screenWidth'] as String?,
      screenHeight: json['screenHeight'] as String?,
      displayDensity: json['displayDensity'] as String?,
      locale: json['locale'] as String? ?? 'en',
      timezone: json['timezone'] as String? ?? 'UTC',
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      buildNumber: json['buildNumber'] as String? ?? '1',
      packageName: json['packageName'] as String? ?? 'unknown',
      userAgent: json['userAgent'] as String?,
      browserName: json['browserName'] as String?,
      browserVersion: json['browserVersion'] as String?,
      isPhysicalDevice: json['isPhysicalDevice'] as bool? ?? true,
      additionalInfo: Map<String, dynamic>.from(
        json['additionalInfo'] as Map? ?? {},
      ),
    );
  }

  @override
  String toString() {
    return 'VooDeviceInfo(deviceId: $deviceId, deviceModel: $deviceModel, '
        'osName: $osName, osVersion: $osVersion, appVersion: $appVersion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VooDeviceInfo &&
        other.deviceId == deviceId &&
        other.deviceModel == deviceModel &&
        other.manufacturer == manufacturer &&
        other.osName == osName &&
        other.osVersion == osVersion &&
        other.locale == locale &&
        other.timezone == timezone &&
        other.appVersion == appVersion &&
        other.buildNumber == buildNumber &&
        other.packageName == packageName &&
        other.isPhysicalDevice == isPhysicalDevice;
  }

  @override
  int get hashCode {
    return Object.hash(
      deviceId,
      deviceModel,
      manufacturer,
      osName,
      osVersion,
      locale,
      timezone,
      appVersion,
      buildNumber,
      packageName,
      isPhysicalDevice,
    );
  }
}
