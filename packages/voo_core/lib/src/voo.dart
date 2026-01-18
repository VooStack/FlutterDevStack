import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:voo_core/src/voo_options.dart';
import 'package:voo_core/src/voo_plugin.dart';
import 'package:voo_core/src/exceptions/voo_exception.dart';
import 'package:voo_core/src/models/voo_config.dart';
import 'package:voo_core/src/models/voo_context.dart';
import 'package:voo_core/src/models/voo_device_info.dart';
import 'package:voo_core/src/models/voo_user_context.dart';
import 'package:voo_core/src/services/voo_device_info_service.dart';

/// Central initialization and management for all Voo packages.
/// Works similar to Firebase Core, providing a unified entry point.
///
/// ## Quick Start
/// ```dart
/// await Voo.initializeApp(
///   config: VooConfig(
///     endpoint: 'https://api.example.com/api',
///     apiKey: 'your-api-key',
///     projectId: 'your-project-id',
///   ),
/// );
///
/// // Device info is auto-collected
/// print(Voo.deviceInfo?.deviceModel);
///
/// // Set user after authentication
/// Voo.setUserId(user.id);
/// Voo.setUserProperty('plan', 'premium');
///
/// // Access combined context for sync payloads
/// final payload = Voo.context?.toSyncPayload();
/// ```
class Voo {
  static final Map<String, VooPlugin> _plugins = {};
  static final Map<String, VooApp> _apps = {};
  static bool _initialized = false;
  static VooOptions? _options;
  static const String _defaultAppName = '[DEFAULT]';

  // New: Central context management
  static VooConfig? _config;
  static VooDeviceInfo? _deviceInfo;
  static VooUserContext? _userContext;

  Voo._();

  // Existing getters
  static VooOptions? get options => _options;
  static bool get isInitialized => _initialized;
  static Map<String, VooPlugin> get plugins => Map.unmodifiable(_plugins);
  static Map<String, VooApp> get apps => Map.unmodifiable(_apps);

  // New: Typed context getters

  /// The API and project configuration.
  static VooConfig? get config => _config;

  /// Device information collected at initialization.
  static VooDeviceInfo? get deviceInfo => _deviceInfo;

  /// User and session context (mutable).
  static VooUserContext? get userContext => _userContext;

  /// Combined context for child packages.
  ///
  /// Returns null if Voo is not fully initialized.
  /// Child packages should use this to get sync payloads.
  static VooContext? get context {
    if (_config == null || _deviceInfo == null || _userContext == null) {
      return null;
    }
    return VooContext(
      config: _config!,
      deviceInfo: _deviceInfo!,
      userContext: _userContext!,
    );
  }

  // New: User context convenience methods

  /// Sets the current user ID.
  ///
  /// Call this after user authentication. All child packages will
  /// automatically include this in their sync payloads.
  static void setUserId(String? userId) {
    _userContext?.setUserId(userId);
  }

  /// Sets a user property.
  ///
  /// User properties are included in telemetry sync payloads.
  static void setUserProperty(String key, dynamic value) {
    _userContext?.setUserProperty(key, value);
  }

  /// Sets multiple user properties at once.
  static void setUserProperties(Map<String, dynamic> properties) {
    _userContext?.setUserProperties(properties);
  }

  /// Clears all user identification and properties.
  ///
  /// Call this on logout.
  static void clearUser() {
    _userContext?.clearUser();
  }

  /// Starts a new session with an optional custom session ID.
  ///
  /// Call this on app foreground or after significant events.
  static void startNewSession([String? sessionId]) {
    _userContext?.startNewSession(sessionId);
  }

  /// Gets the current session ID.
  static String? get sessionId => _userContext?.sessionId;

  /// Gets the current user ID.
  static String? get userId => _userContext?.userId;

  /// Initialize the default Voo app.
  ///
  /// The recommended way to initialize is with a [VooConfig]:
  /// ```dart
  /// await Voo.initializeApp(
  ///   config: VooConfig(
  ///     endpoint: 'https://api.example.com/api',
  ///     apiKey: 'your-api-key',
  ///     projectId: 'your-project-id',
  ///   ),
  /// );
  /// ```
  ///
  /// For backwards compatibility, you can still use [VooOptions] with
  /// [customConfig], but this is deprecated.
  static Future<VooApp> initializeApp({
    String name = _defaultAppName,
    VooConfig? config,
    VooOptions? options,
  }) async {
    if (_apps.containsKey(name)) {
      return _apps[name]!;
    }

    // Store config
    _config = config;

    // Use provided options or create default
    _options = options ?? const VooOptions();

    // Auto-collect device info if enabled
    if (_options!.autoCollectDeviceInfo) {
      try {
        _deviceInfo = await VooDeviceInfoService.initialize();
        if (kDebugMode) {
          debugPrint('Voo: Collected device info for ${_deviceInfo?.osName}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Voo: Failed to collect device info: $e');
        }
      }
    }

    // Initialize user context with auto-generated session
    _userContext = VooUserContext();
    if (kDebugMode) {
      debugPrint('Voo: Session started: ${_userContext?.sessionId}');
    }

    if (!_initialized) {
      _initialized = true;
    }

    final app = VooApp._(name: name, options: _options!, config: _config);
    _apps[name] = app;

    // Notify all registered plugins about the new app
    for (final plugin in _plugins.values) {
      await plugin.onAppInitialized(app);
    }

    if (kDebugMode) {
      debugPrint('Voo: Initialized app "$name"');
      if (_config != null) {
        debugPrint('Voo: Project: ${_config!.projectId}, Environment: ${_config!.environment}');
      }
    }

    return app;
  }

  /// Get an app by name.
  static VooApp app([String name = _defaultAppName]) {
    final app = _apps[name];
    if (app == null) {
      throw VooException(
        'App "$name" not found. Available apps: ${_apps.keys.join(", ")}',
        code: 'app-not-found',
      );
    }
    return app;
  }

  /// Get all initialized apps.
  static List<VooApp> get allApps => _apps.values.toList();

  /// Register a plugin to be initialized with Voo apps.
  static Future<void> registerPlugin(VooPlugin plugin) async {
    if (_plugins.containsKey(plugin.name)) {
      throw VooException(
        'Plugin ${plugin.name} is already registered',
        code: 'plugin-already-registered',
      );
    }

    _plugins[plugin.name] = plugin;

    // Initialize the plugin with all existing apps
    for (final app in _apps.values) {
      await plugin.onAppInitialized(app);
    }

    if (kDebugMode) {
      debugPrint('Voo: Registered plugin "${plugin.name}"');
    }
  }

  /// Unregister a plugin.
  static Future<void> unregisterPlugin(String pluginName) async {
    final plugin = _plugins.remove(pluginName);
    if (plugin != null) {
      await plugin.dispose();
      if (kDebugMode) {
        debugPrint('Voo: Unregistered plugin "$pluginName"');
      }
    }
  }

  static T? getPlugin<T extends VooPlugin>(String name) {
    final plugin = _plugins[name];
    if (plugin is T) {
      return plugin;
    }
    return null;
  }

  static bool hasPlugin(String name) {
    return _plugins.containsKey(name);
  }

  /// Dispose all apps and plugins.
  static Future<void> dispose() async {
    // Dispose all plugins
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    _plugins.clear();

    // Dispose all apps
    for (final app in _apps.values) {
      await app.dispose();
    }
    _apps.clear();

    // Clear context
    _initialized = false;
    _options = null;
    _config = null;
    _deviceInfo = null;
    _userContext = null;
    VooDeviceInfoService.reset();
  }

  /// Check if a plugin is registered.
  static bool isPluginRegistered<T extends VooPlugin>() {
    return _plugins.values.whereType<T>().isNotEmpty;
  }

  /// Ensure a plugin is registered, throw if not.
  static void ensurePluginRegistered<T extends VooPlugin>(String pluginName) {
    if (!isPluginRegistered<T>()) {
      throw VooException(
        'Plugin "$pluginName" is not registered. Please register it first.',
        code: 'plugin-not-registered',
      );
    }
  }
}

/// Represents a Voo application instance.
class VooApp {
  final String name;
  final VooOptions options;
  final VooConfig? config;
  final Map<String, dynamic> _data = {};

  VooApp._({required this.name, required this.options, this.config});

  /// Check if this is the default app.
  bool get isDefault => name == Voo._defaultAppName;

  /// Store custom data associated with this app.
  void setData(String key, dynamic value) {
    _data[key] = value;
  }

  /// Retrieve custom data associated with this app.
  T? getData<T>(String key) {
    return _data[key] as T?;
  }

  /// Dispose this app.
  Future<void> dispose() async {
    _data.clear();
  }

  /// Delete this app.
  Future<void> delete() async {
    await dispose();
    Voo._apps.remove(name);

    // Notify plugins about app deletion
    for (final plugin in Voo._plugins.values) {
      await plugin.onAppDeleted(this);
    }
  }
}
