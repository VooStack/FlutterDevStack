import 'voo_config.dart';
import 'voo_device_info.dart';
import 'voo_user_context.dart';

/// Combined context for Voo SDK, providing unified access to device,
/// configuration, and user information.
///
/// This class is the primary interface for child packages (voo_analytics,
/// voo_logging, voo_performance) to access shared context without manually
/// extracting from configuration maps.
///
/// Access via [Voo.context] after initialization:
/// ```dart
/// final context = Voo.context;
/// if (context != null) {
///   final payload = context.toSyncPayload();
///   // Use payload for API requests
/// }
/// ```
class VooContext {
  /// Device information collected at initialization.
  final VooDeviceInfo deviceInfo;

  /// API and project configuration.
  final VooConfig config;

  /// User and session state.
  final VooUserContext userContext;

  const VooContext({
    required this.deviceInfo,
    required this.config,
    required this.userContext,
  });

  /// The current session ID.
  String get sessionId => userContext.sessionId;

  /// The current user ID, or null if not authenticated.
  String? get userId => userContext.userId;

  /// The device ID.
  String get deviceId => deviceInfo.deviceId;

  /// The platform/OS name.
  String get platform => deviceInfo.osName;

  /// The app version.
  String get appVersion => deviceInfo.appVersion;

  /// The project ID.
  String? get projectId => config.projectId;

  /// The organization ID, if set.
  String? get organizationId => config.organizationId;

  /// The environment name.
  String get environment => config.environment;

  /// Whether the user is authenticated.
  bool get isAuthenticated => userContext.isAuthenticated;

  /// Whether cloud sync is enabled and configured correctly.
  bool get canSync => config.enableCloudSync && config.isValid;

  /// Returns a map suitable for sync service payloads.
  ///
  /// This is the primary method used by child packages to include
  /// context in their API requests. It combines essential fields from
  /// device info, user context, and configuration.
  ///
  /// Example output:
  /// ```dart
  /// {
  ///   'sessionId': 'session_1234567890_123456',
  ///   'userId': 'user-abc-123',
  ///   'deviceId': 'device-xyz-789',
  ///   'deviceModel': 'iPhone 14 Pro',
  ///   'platform': 'iOS',
  ///   'osVersion': '17.0',
  ///   'appVersion': '1.0.0',
  ///   'buildNumber': '42',
  ///   'locale': 'en_US',
  ///   'timezone': 'America/New_York',
  ///   'environment': 'production',
  ///   'projectId': 'project-123',
  ///   'organizationId': 'org-456',
  /// }
  /// ```
  Map<String, dynamic> toSyncPayload() => {
        // User context
        'sessionId': userContext.sessionId,
        'userId': userContext.userId ?? '',
        ...userContext.userProperties,

        // Device info
        'deviceId': deviceInfo.deviceId,
        'deviceModel': deviceInfo.deviceModel,
        'platform': deviceInfo.osName,
        'osVersion': deviceInfo.osVersion,
        'appVersion': deviceInfo.appVersion,
        'buildNumber': deviceInfo.buildNumber,
        'locale': deviceInfo.locale,
        'timezone': deviceInfo.timezone,
        'isPhysicalDevice': deviceInfo.isPhysicalDevice,

        // Config
        'environment': config.environment,
        'projectId': config.projectId,
        if (config.organizationId != null)
          'organizationId': config.organizationId,
      };

  /// Returns a minimal payload with only essential fields.
  ///
  /// Use this when bandwidth is constrained or for high-frequency events.
  Map<String, dynamic> toMinimalPayload() => {
        'sessionId': userContext.sessionId,
        'userId': userContext.userId ?? '',
        'deviceId': deviceInfo.deviceId,
        'platform': deviceInfo.osName,
        'appVersion': deviceInfo.appVersion,
      };

  /// Returns HTTP headers for authenticated API requests.
  ///
  /// Includes authorization and organization headers.
  Map<String, String> toHeaders() => {
        'Content-Type': 'application/json',
        'X-API-Key': config.apiKey,
        if (config.projectId != null) 'X-Project-Id': config.projectId!,
        if (config.organizationId != null)
          'X-Organization-Id': config.organizationId!,
        'X-Session-Id': userContext.sessionId,
        if (userContext.userId != null) 'X-User-Id': userContext.userId!,
      };

  /// Converts the entire context to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'deviceInfo': deviceInfo.toJson(),
        'config': config.toJson(),
        'userContext': userContext.toJson(),
      };

  @override
  String toString() {
    return 'VooContext(sessionId: $sessionId, userId: $userId, '
        'deviceId: $deviceId, platform: $platform, '
        'projectId: $projectId, environment: $environment)';
  }
}
