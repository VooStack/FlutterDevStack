import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:voo_core/src/models/voo_device_info.dart';

/// Service for automatically collecting comprehensive device information.
///
/// This service is called internally during [Voo.initializeApp] to populate
/// [VooDeviceInfo]. It handles all platform-specific device info collection.
///
/// The collected information is cached and can be accessed via [deviceInfo]
/// after initialization.
class VooDeviceInfoService {
  static VooDeviceInfoService? _instance;
  static VooDeviceInfo? _cachedInfo;

  VooDeviceInfoService._();

  static VooDeviceInfoService get instance {
    _instance ??= VooDeviceInfoService._();
    return _instance!;
  }

  /// Initialize and cache device info.
  ///
  /// This is called automatically during [Voo.initializeApp].
  /// Returns the collected [VooDeviceInfo].
  static Future<VooDeviceInfo> initialize() async {
    try {
      _cachedInfo = await instance._collectDeviceInfo();
      return _cachedInfo!;
    } catch (e) {
      // Return a fallback device info on error
      _cachedInfo = _fallbackDeviceInfo();
      return _cachedInfo!;
    }
  }

  /// Get cached device info (must call [initialize] first).
  static VooDeviceInfo? get deviceInfo => _cachedInfo;

  /// Get device info, collecting it if not cached.
  Future<VooDeviceInfo> getDeviceInfo() async {
    _cachedInfo ??= await _collectDeviceInfo();
    return _cachedInfo!;
  }

  /// Reset cached info (mainly for testing).
  static void reset() {
    _cachedInfo = null;
    _instance = null;
  }

  Future<VooDeviceInfo> _collectDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    if (kIsWeb) {
      return _collectWebInfo(deviceInfoPlugin, packageInfo);
    }

    if (Platform.isAndroid) {
      return _collectAndroidInfo(deviceInfoPlugin, packageInfo);
    }

    if (Platform.isIOS) {
      return _collectIOSInfo(deviceInfoPlugin, packageInfo);
    }

    if (Platform.isMacOS) {
      return _collectMacOSInfo(deviceInfoPlugin, packageInfo);
    }

    if (Platform.isWindows) {
      return _collectWindowsInfo(deviceInfoPlugin, packageInfo);
    }

    if (Platform.isLinux) {
      return _collectLinuxInfo(deviceInfoPlugin, packageInfo);
    }

    // Fallback for unknown platform
    return VooDeviceInfo(
      deviceId: 'unknown',
      deviceModel: 'unknown',
      manufacturer: 'unknown',
      osName: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      isPhysicalDevice: true,
    );
  }

  Future<VooDeviceInfo> _collectAndroidInfo(
    DeviceInfoPlugin plugin,
    PackageInfo packageInfo,
  ) async {
    final info = await plugin.androidInfo;

    return VooDeviceInfo(
      deviceId: info.id,
      deviceModel: info.model,
      manufacturer: info.manufacturer,
      osName: 'Android',
      osVersion: info.version.release,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      isPhysicalDevice: info.isPhysicalDevice,
      additionalInfo: {
        'androidSdkInt': info.version.sdkInt,
        'androidBrand': info.brand,
        'androidDevice': info.device,
        'androidBoard': info.board,
        'androidHardware': info.hardware,
        'androidProduct': info.product,
        'androidSecurityPatch': info.version.securityPatch,
        'androidFingerprint': info.fingerprint,
        'androidDisplay': info.display,
        'supportedAbis': info.supportedAbis.join(','),
      },
    );
  }

  Future<VooDeviceInfo> _collectIOSInfo(
    DeviceInfoPlugin plugin,
    PackageInfo packageInfo,
  ) async {
    final info = await plugin.iosInfo;

    return VooDeviceInfo(
      deviceId: info.identifierForVendor ?? 'unknown',
      deviceModel: info.model,
      manufacturer: 'Apple',
      osName: info.systemName,
      osVersion: info.systemVersion,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      isPhysicalDevice: info.isPhysicalDevice,
      additionalInfo: {
        'iosName': info.name,
        'iosLocalizedModel': info.localizedModel,
        'iosUtsname': {
          'sysname': info.utsname.sysname,
          'nodename': info.utsname.nodename,
          'release': info.utsname.release,
          'version': info.utsname.version,
          'machine': info.utsname.machine,
        },
      },
    );
  }

  Future<VooDeviceInfo> _collectMacOSInfo(
    DeviceInfoPlugin plugin,
    PackageInfo packageInfo,
  ) async {
    final info = await plugin.macOsInfo;

    return VooDeviceInfo(
      deviceId: info.systemGUID ?? 'unknown',
      deviceModel: info.model,
      manufacturer: 'Apple',
      osName: 'macOS',
      osVersion:
          '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      isPhysicalDevice: true,
      additionalInfo: {
        'macOSComputerName': info.computerName,
        'macOSHostName': info.hostName,
        'macOSArch': info.arch,
        'macOSKernelVersion': info.kernelVersion,
        'macOSMemorySize': info.memorySize,
        'macOSCpuFrequency': info.cpuFrequency,
        'macOSActiveCPUs': info.activeCPUs,
      },
    );
  }

  Future<VooDeviceInfo> _collectWindowsInfo(
    DeviceInfoPlugin plugin,
    PackageInfo packageInfo,
  ) async {
    final info = await plugin.windowsInfo;

    return VooDeviceInfo(
      deviceId: info.deviceId,
      deviceModel: info.productName,
      manufacturer: info.registeredOwner,
      osName: 'Windows',
      osVersion:
          '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      isPhysicalDevice: true,
      additionalInfo: {
        'windowsComputerName': info.computerName,
        'windowsEditionId': info.editionId,
        'windowsDisplayVersion': info.displayVersion,
        'windowsCsdVersion': info.csdVersion,
        'windowsProductId': info.productId,
        'windowsNumberOfCores': info.numberOfCores,
        'windowsSystemMemoryInMegabytes': info.systemMemoryInMegabytes,
        'windowsUserName': info.userName,
      },
    );
  }

  Future<VooDeviceInfo> _collectLinuxInfo(
    DeviceInfoPlugin plugin,
    PackageInfo packageInfo,
  ) async {
    final info = await plugin.linuxInfo;

    return VooDeviceInfo(
      deviceId: info.machineId ?? 'unknown',
      deviceModel: info.prettyName,
      manufacturer: info.name,
      osName: 'Linux',
      osVersion: info.version ?? 'unknown',
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      isPhysicalDevice: true,
      additionalInfo: {
        'linuxId': info.id,
        'linuxIdLike': info.idLike?.join(','),
        'linuxVersionCodename': info.versionCodename,
        'linuxVersionId': info.versionId,
        'linuxBuildId': info.buildId,
        'linuxVariant': info.variant,
        'linuxVariantId': info.variantId,
      },
    );
  }

  Future<VooDeviceInfo> _collectWebInfo(
    DeviceInfoPlugin plugin,
    PackageInfo packageInfo,
  ) async {
    final info = await plugin.webBrowserInfo;

    return VooDeviceInfo(
      deviceId:
          'web-${info.vendor ?? 'unknown'}-${info.hardwareConcurrency ?? 0}',
      deviceModel: info.platform ?? 'unknown',
      manufacturer: info.vendor ?? 'unknown',
      osName: 'Web',
      osVersion: info.appVersion ?? 'unknown',
      locale: info.language ?? 'unknown',
      timezone: DateTime.now().timeZoneName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      userAgent: info.userAgent,
      browserName: info.browserName.name,
      browserVersion: info.appVersion,
      isPhysicalDevice: true,
      additionalInfo: {
        'webProduct': info.product,
        'webProductSub': info.productSub,
        'webVendorSub': info.vendorSub,
        'webMaxTouchPoints': info.maxTouchPoints,
        'webHardwareConcurrency': info.hardwareConcurrency,
        'webDeviceMemory': info.deviceMemory,
        'webLanguages': info.languages?.join(','),
      },
    );
  }

  static VooDeviceInfo _fallbackDeviceInfo() {
    return VooDeviceInfo(
      deviceId: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
      deviceModel: 'unknown',
      manufacturer: 'unknown',
      osName: kIsWeb ? 'Web' : 'unknown',
      osVersion: 'unknown',
      locale: 'en',
      timezone: DateTime.now().timeZoneName,
      appVersion: '1.0.0',
      buildNumber: '1',
      packageName: 'unknown',
      isPhysicalDevice: true,
    );
  }
}
