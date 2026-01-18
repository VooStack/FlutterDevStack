import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents usage statistics for an installed app.
@immutable
class AppUsageStats {
  /// Package name (e.g., "com.facebook.katana").
  final String packageName;

  /// Human-readable app name.
  final String? appName;

  /// Total time the app was in foreground during the period.
  final Duration totalTimeInForeground;

  /// When the app was last used.
  final DateTime? lastUsed;

  /// Number of times the app was launched during the period.
  final int launchCount;

  /// App category (games, social, productivity, etc.).
  final String? category;

  const AppUsageStats({required this.packageName, this.appName, required this.totalTimeInForeground, this.lastUsed, required this.launchCount, this.category});

  /// Whether this app was actively used (more than 1 minute).
  bool get wasActivelyUsed => totalTimeInForeground.inMinutes >= 1;

  /// Average session duration if there were launches.
  Duration? get averageSessionDuration {
    if (launchCount == 0) return null;
    return Duration(milliseconds: totalTimeInForeground.inMilliseconds ~/ launchCount);
  }

  Map<String, dynamic> toJson() => {
    'package_name': packageName,
    if (appName != null) 'app_name': appName,
    'total_time_in_foreground_ms': totalTimeInForeground.inMilliseconds,
    if (lastUsed != null) 'last_used': lastUsed!.toIso8601String(),
    'launch_count': launchCount,
    if (category != null) 'category': category,
  };

  factory AppUsageStats.fromJson(Map<String, dynamic> json) => AppUsageStats(
    packageName: json['package_name'] as String,
    appName: json['app_name'] as String?,
    totalTimeInForeground: Duration(milliseconds: json['total_time_in_foreground_ms'] as int),
    lastUsed: json['last_used'] != null ? DateTime.parse(json['last_used'] as String) : null,
    launchCount: json['launch_count'] as int,
    category: json['category'] as String?,
  );

  @override
  String toString() =>
      'AppUsageStats($packageName: '
      '${totalTimeInForeground.inMinutes}min, launches: $launchCount)';
}

/// Represents an installed app on the device.
@immutable
class InstalledApp {
  /// Package name.
  final String packageName;

  /// Human-readable app name.
  final String? appName;

  /// App category.
  final String? category;

  /// When the app was installed.
  final DateTime? installTime;

  /// When the app was last updated.
  final DateTime? lastUpdateTime;

  /// App version name.
  final String? versionName;

  /// Whether this is a system app.
  final bool isSystemApp;

  const InstalledApp({required this.packageName, this.appName, this.category, this.installTime, this.lastUpdateTime, this.versionName, this.isSystemApp = false});

  Map<String, dynamic> toJson() => {
    'package_name': packageName,
    if (appName != null) 'app_name': appName,
    if (category != null) 'category': category,
    if (installTime != null) 'install_time': installTime!.toIso8601String(),
    if (lastUpdateTime != null) 'last_update_time': lastUpdateTime!.toIso8601String(),
    if (versionName != null) 'version_name': versionName,
    'is_system_app': isSystemApp,
  };

  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
    packageName: json['package_name'] as String,
    appName: json['app_name'] as String?,
    category: json['category'] as String?,
    installTime: json['install_time'] != null ? DateTime.parse(json['install_time'] as String) : null,
    lastUpdateTime: json['last_update_time'] != null ? DateTime.parse(json['last_update_time'] as String) : null,
    versionName: json['version_name'] as String?,
    isSystemApp: json['is_system_app'] as bool? ?? false,
  );
}

/// App categories for classification.
class AppCategories {
  static const String games = 'games';
  static const String social = 'social';
  static const String communication = 'communication';
  static const String productivity = 'productivity';
  static const String entertainment = 'entertainment';
  static const String news = 'news';
  static const String shopping = 'shopping';
  static const String finance = 'finance';
  static const String health = 'health';
  static const String education = 'education';
  static const String travel = 'travel';
  static const String music = 'music';
  static const String photography = 'photography';
  static const String utilities = 'utilities';
  static const String other = 'other';

  /// Categorize an app based on its package name.
  ///
  /// This is a simple heuristic - for better categorization,
  /// use the Google Play Store category from the API.
  static String categorizeByPackage(String packageName) {
    final pkg = packageName.toLowerCase();

    // Social apps
    if (pkg.contains('facebook') || pkg.contains('instagram') || pkg.contains('twitter') || pkg.contains('snapchat') || pkg.contains('tiktok') || pkg.contains('linkedin')) {
      return social;
    }

    // Communication
    if (pkg.contains('whatsapp') || pkg.contains('messenger') || pkg.contains('telegram') || pkg.contains('signal') || pkg.contains('discord') || pkg.contains('slack')) {
      return communication;
    }

    // Games
    if (pkg.contains('game') || pkg.contains('supercell') || pkg.contains('rovio') || pkg.contains('king.') || pkg.contains('zynga')) {
      return games;
    }

    // Entertainment
    if (pkg.contains('netflix') || pkg.contains('youtube') || pkg.contains('hulu') || pkg.contains('disney') || pkg.contains('spotify') || pkg.contains('twitch')) {
      return entertainment;
    }

    // Shopping
    if (pkg.contains('amazon') || pkg.contains('ebay') || pkg.contains('wish') || pkg.contains('shop') || pkg.contains('alibaba')) {
      return shopping;
    }

    // Finance
    if (pkg.contains('bank') || pkg.contains('paypal') || pkg.contains('venmo') || pkg.contains('cash') || pkg.contains('crypto') || pkg.contains('coinbase')) {
      return finance;
    }

    // Productivity
    if (pkg.contains('google.docs') || pkg.contains('microsoft') || pkg.contains('notion') || pkg.contains('evernote') || pkg.contains('trello')) {
      return productivity;
    }

    return other;
  }
}

/// Service for tracking cross-app usage on Android.
///
/// Uses the Android UsageStats API to gather information about
/// installed apps and app usage patterns.
///
/// **IMPORTANT**: This feature requires explicit user consent and
/// the PACKAGE_USAGE_STATS permission, which requires the user
/// to grant access through Settings.
///
/// ## Android Setup
///
/// Add to AndroidManifest.xml:
/// ```xml
/// <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
///     tools:ignore="ProtectedPermissions" />
/// <queries>
///     <intent>
///         <action android:name="android.intent.action.MAIN" />
///     </intent>
/// </queries>
/// ```
///
/// ## Usage
///
/// ```dart
/// // Check if permission is granted
/// final hasPermission = await VooAppUsageService.hasUsageStatsPermission();
///
/// if (!hasPermission) {
///   // Show dialog explaining why this is needed
///   await VooAppUsageService.requestUsageStatsPermission();
/// }
///
/// // Get installed apps
/// final apps = await VooAppUsageService.getInstalledApps();
///
/// // Get usage stats for the last 7 days
/// final stats = await VooAppUsageService.getUsageStats(
///   startDate: DateTime.now().subtract(Duration(days: 7)),
///   endDate: DateTime.now(),
/// );
/// ```
///
/// ## Privacy Considerations
///
/// - Only collect app usage data with explicit user consent
/// - Consider hashing package names before sending to backend
/// - Don't collect data from sensitive app categories (health, finance)
/// - Clearly explain the purpose of data collection
class VooAppUsageService {
  static const _channel = MethodChannel('voo_analytics/app_usage');

  static VooAppUsageService? _instance;
  static bool _initialized = false;
  static bool _hasPermission = false;

  VooAppUsageService._();

  /// Get the singleton instance.
  static VooAppUsageService get instance {
    _instance ??= VooAppUsageService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Whether the app has usage stats permission.
  static bool get hasPermission => _hasPermission;

  /// Initialize the service.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!Platform.isAndroid) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Only available on Android');
      }
      return;
    }

    try {
      _hasPermission = await hasUsageStatsPermission();
      _initialized = true;

      if (kDebugMode) {
        debugPrint('VooAppUsageService: Initialized (permission: $_hasPermission)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Failed to initialize: $e');
      }
    }
  }

  /// Check if the app has usage stats permission.
  static Future<bool> hasUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      _hasPermission = result ?? false;
      return _hasPermission;
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Native plugin not available');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Permission check failed: $e');
      }
      return false;
    }
  }

  /// Request usage stats permission.
  ///
  /// This opens the Settings page where the user must manually
  /// grant permission to this app.
  static Future<void> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<void>('requestUsageStatsPermission');
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Native plugin not available');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Failed to request permission: $e');
      }
    }
  }

  /// Get list of installed apps.
  ///
  /// [includeSystemApps] - Whether to include system apps.
  /// [categorize] - Whether to add category based on package name.
  static Future<List<InstalledApp>> getInstalledApps({bool includeSystemApps = false, bool categorize = true}) async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps', {'includeSystemApps': includeSystemApps});

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        var app = InstalledApp.fromJson(map);

        if (categorize && app.category == null) {
          app = InstalledApp(
            packageName: app.packageName,
            appName: app.appName,
            category: AppCategories.categorizeByPackage(app.packageName),
            installTime: app.installTime,
            lastUpdateTime: app.lastUpdateTime,
            versionName: app.versionName,
            isSystemApp: app.isSystemApp,
          );
        }

        return app;
      }).toList();
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Native plugin not available');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Failed to get installed apps: $e');
      }
      return [];
    }
  }

  /// Get app usage statistics for a date range.
  ///
  /// Returns usage stats sorted by total time in foreground (descending).
  static Future<List<AppUsageStats>> getUsageStats({required DateTime startDate, required DateTime endDate}) async {
    if (!Platform.isAndroid) return [];

    final hasPermission = await hasUsageStatsPermission();
    if (!hasPermission) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: No usage stats permission');
      }
      return [];
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getUsageStats', {'startTime': startDate.millisecondsSinceEpoch, 'endTime': endDate.millisecondsSinceEpoch});

      if (result == null) return [];

      final stats = result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return AppUsageStats.fromJson(map);
      }).toList();

      // Sort by usage time
      stats.sort((a, b) => b.totalTimeInForeground.compareTo(a.totalTimeInForeground));

      return stats;
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Native plugin not available');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooAppUsageService: Failed to get usage stats: $e');
      }
      return [];
    }
  }

  /// Get aggregated usage stats by category.
  static Future<Map<String, Duration>> getUsageByCategory({required DateTime startDate, required DateTime endDate}) async {
    final stats = await getUsageStats(startDate: startDate, endDate: endDate);

    final byCategory = <String, Duration>{};
    for (final stat in stats) {
      final category = stat.category ?? AppCategories.categorizeByPackage(stat.packageName);
      byCategory[category] = (byCategory[category] ?? Duration.zero) + stat.totalTimeInForeground;
    }

    return byCategory;
  }

  /// Get the most used apps in a date range.
  static Future<List<AppUsageStats>> getMostUsedApps({required DateTime startDate, required DateTime endDate, int limit = 10}) async {
    final stats = await getUsageStats(startDate: startDate, endDate: endDate);
    return stats.take(limit).toList();
  }

  /// Get total screen time for a date range.
  static Future<Duration> getTotalScreenTime({required DateTime startDate, required DateTime endDate}) async {
    final stats = await getUsageStats(startDate: startDate, endDate: endDate);
    return stats.fold<Duration>(Duration.zero, (total, stat) => total + stat.totalTimeInForeground);
  }

  /// Hash a package name for privacy.
  ///
  /// Use this when sending data to backend to anonymize package names.
  static String hashPackageName(String packageName) {
    // Simple hash - in production, use a proper hashing algorithm
    var hash = 0;
    for (var i = 0; i < packageName.length; i++) {
      hash = ((hash << 5) - hash) + packageName.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _hasPermission = false;
    _instance = null;
  }
}

/// Kotlin implementation reference for Android:
///
/// Add to android/app/src/main/kotlin/.../MainActivity.kt:
///
/// ```kotlin
/// import android.app.AppOpsManager
/// import android.app.usage.UsageStats
/// import android.app.usage.UsageStatsManager
/// import android.content.Context
/// import android.content.Intent
/// import android.content.pm.ApplicationInfo
/// import android.content.pm.PackageManager
/// import android.os.Build
/// import android.provider.Settings
/// import io.flutter.embedding.android.FlutterActivity
/// import io.flutter.embedding.engine.FlutterEngine
/// import io.flutter.plugin.common.MethodChannel
///
/// class MainActivity: FlutterActivity() {
///     private val CHANNEL = "voo_analytics/app_usage"
///
///     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
///         super.configureFlutterEngine(flutterEngine)
///
///         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
///             .setMethodCallHandler { call, result ->
///                 when (call.method) {
///                     "hasUsageStatsPermission" -> {
///                         result.success(hasUsageStatsPermission())
///                     }
///                     "requestUsageStatsPermission" -> {
///                         val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
///                         startActivity(intent)
///                         result.success(null)
///                     }
///                     "getInstalledApps" -> {
///                         val includeSystem = call.argument<Boolean>("includeSystemApps") ?: false
///                         result.success(getInstalledApps(includeSystem))
///                     }
///                     "getUsageStats" -> {
///                         val startTime = call.argument<Long>("startTime") ?: 0L
///                         val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
///                         result.success(getUsageStats(startTime, endTime))
///                     }
///                     else -> result.notImplemented()
///                 }
///             }
///     }
///
///     private fun hasUsageStatsPermission(): Boolean {
///         val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
///         val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
///             appOps.unsafeCheckOpNoThrow(
///                 AppOpsManager.OPSTR_GET_USAGE_STATS,
///                 android.os.Process.myUid(),
///                 packageName
///             )
///         } else {
///             appOps.checkOpNoThrow(
///                 AppOpsManager.OPSTR_GET_USAGE_STATS,
///                 android.os.Process.myUid(),
///                 packageName
///             )
///         }
///         return mode == AppOpsManager.MODE_ALLOWED
///     }
///
///     private fun getInstalledApps(includeSystem: Boolean): List<Map<String, Any?>> {
///         val pm = packageManager
///         val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
///
///         return packages
///             .filter { includeSystem || (it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
///             .map { app ->
///                 mapOf(
///                     "package_name" to app.packageName,
///                     "app_name" to pm.getApplicationLabel(app).toString(),
///                     "is_system_app" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
///                 )
///             }
///     }
///
///     private fun getUsageStats(startTime: Long, endTime: Long): List<Map<String, Any?>> {
///         val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
///         val stats = usageStatsManager.queryUsageStats(
///             UsageStatsManager.INTERVAL_DAILY,
///             startTime,
///             endTime
///         )
///
///         return stats
///             .filter { it.totalTimeInForeground > 0 }
///             .map { stat ->
///                 mapOf(
///                     "package_name" to stat.packageName,
///                     "total_time_in_foreground_ms" to stat.totalTimeInForeground,
///                     "last_used" to stat.lastTimeUsed,
///                     "launch_count" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
///                         stat.appLaunchCount
///                     } else {
///                         0
///                     }
///                 )
///             }
///     }
/// }
/// ```
