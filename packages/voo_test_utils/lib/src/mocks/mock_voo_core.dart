import 'package:voo_core/voo_core.dart';

/// Factory methods for creating test VooConfig instances.
class VooConfigFactory {
  /// Creates a valid VooConfig for testing.
  static VooConfig create({
    String endpoint = 'https://api.test.com',
    String apiKey = 'test-api-key',
    String projectId = 'test-project-id',
    String? organizationId,
    String environment = 'test',
    bool enableCloudSync = true,
    int batchSize = 10,
    Duration syncInterval = const Duration(seconds: 30),
    bool enableErrorTracking = true,
    bool enablePerformanceTracking = true,
    bool enableAnalytics = true,
    bool enableDeviceInfo = false,
  }) {
    return VooConfig(
      endpoint: endpoint,
      apiKey: apiKey,
      projectId: projectId,
      organizationId: organizationId,
      environment: environment,
      enableCloudSync: enableCloudSync,
      batchSize: batchSize,
      syncInterval: syncInterval,
      enableErrorTracking: enableErrorTracking,
      enablePerformanceTracking: enablePerformanceTracking,
      enableAnalytics: enableAnalytics,
      enableDeviceInfo: enableDeviceInfo,
    );
  }

  /// Creates a disabled (local-only) config for testing.
  static VooConfig createDisabled() {
    return VooConfig.localOnly();
  }

  /// Creates a production-like config for testing.
  static VooConfig createProduction({
    String endpoint = 'https://api.test.com',
    String apiKey = 'test-api-key',
    String projectId = 'test-project-id',
  }) {
    return VooConfig.production(
      endpoint: endpoint,
      apiKey: apiKey,
      projectId: projectId,
    );
  }

  /// Creates a development-like config for testing.
  static VooConfig createDevelopment({
    String endpoint = 'https://api.test.com',
    String apiKey = 'test-api-key',
    String projectId = 'test-project-id',
  }) {
    return VooConfig.development(
      endpoint: endpoint,
      apiKey: apiKey,
      projectId: projectId,
    );
  }
}

/// Factory methods for creating test VooDeviceInfo instances.
class VooDeviceInfoFactory {
  /// Creates a mock VooDeviceInfo for testing.
  static VooDeviceInfo create({
    String? deviceId,
    String? deviceModel,
    String? deviceManufacturer,
    String? osName,
    String? osVersion,
    String? appVersion,
    String? appBuildNumber,
    String? appPackageName,
    String? locale,
    String? timezone,
    bool? isPhysicalDevice,
  }) {
    return VooDeviceInfo(
      deviceId: deviceId ?? 'test-device-id',
      deviceModel: deviceModel ?? 'Test Model',
      deviceManufacturer: deviceManufacturer ?? 'Test Manufacturer',
      osName: osName ?? 'TestOS',
      osVersion: osVersion ?? '1.0.0',
      appVersion: appVersion ?? '1.0.0',
      appBuildNumber: appBuildNumber ?? '1',
      appPackageName: appPackageName ?? 'com.test.app',
      locale: locale ?? 'en_US',
      timezone: timezone ?? 'UTC',
      isPhysicalDevice: isPhysicalDevice ?? false,
    );
  }
}

/// Factory methods for creating test VooUserContext instances.
class VooUserContextFactory {
  /// Creates a VooUserContext for testing.
  static VooUserContext create({
    String? userId,
    String? email,
    String? displayName,
    Map<String, dynamic>? customData,
    String? sessionId,
  }) {
    return VooUserContext(
      userId: userId ?? 'test-user-id',
      email: email,
      displayName: displayName,
      customData: customData ?? {},
      sessionId: sessionId ?? 'test-session-id',
    );
  }

  /// Creates an anonymous VooUserContext for testing.
  static VooUserContext createAnonymous() {
    return VooUserContext(
      sessionId: 'anonymous-session-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}

/// Factory methods for creating test VooBreadcrumb instances.
class VooBreadcrumbFactory {
  /// Creates a navigation breadcrumb for testing.
  static VooBreadcrumb createNavigation({
    String from = 'ScreenA',
    String to = 'ScreenB',
    String action = 'push',
    Map<String, dynamic>? routeParams,
  }) {
    return VooBreadcrumb.navigation(
      from: from,
      to: to,
      action: action,
      routeParams: routeParams,
    );
  }

  /// Creates an HTTP breadcrumb for testing.
  static VooBreadcrumb createHttp({
    String method = 'GET',
    String url = 'https://api.test.com/endpoint',
    int? statusCode = 200,
    int? durationMs = 100,
    bool isError = false,
  }) {
    return VooBreadcrumb.http(
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: durationMs,
      isError: isError,
    );
  }

  /// Creates a user action breadcrumb for testing.
  static VooBreadcrumb createUserAction({
    String action = 'tap',
    String? elementId,
    String? elementType = 'button',
    String? screenName = 'TestScreen',
  }) {
    return VooBreadcrumb.userAction(
      action: action,
      elementId: elementId,
      elementType: elementType,
      screenName: screenName,
    );
  }

  /// Creates an error breadcrumb for testing.
  static VooBreadcrumb createError({
    String message = 'Test error occurred',
    String? errorType = 'TestException',
    String? stackTrace,
  }) {
    return VooBreadcrumb.error(
      message: message,
      errorType: errorType,
      stackTrace: stackTrace,
    );
  }

  /// Creates a system breadcrumb for testing.
  static VooBreadcrumb createSystem({
    String event = 'test_event',
    VooBreadcrumbLevel level = VooBreadcrumbLevel.info,
    Map<String, dynamic>? data,
  }) {
    return VooBreadcrumb.system(
      event: event,
      level: level,
      data: data,
    );
  }

  /// Creates a custom breadcrumb for testing.
  static VooBreadcrumb createCustom({
    String category = 'custom',
    String message = 'Custom breadcrumb',
    VooBreadcrumbLevel level = VooBreadcrumbLevel.info,
    Map<String, dynamic>? data,
  }) {
    return VooBreadcrumb(
      type: VooBreadcrumbType.custom,
      category: category,
      message: message,
      level: level,
      data: data,
    );
  }
}
