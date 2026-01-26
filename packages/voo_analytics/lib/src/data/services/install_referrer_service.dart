import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:voo_core/voo_core.dart';

/// Install referrer data from the app store.
///
/// This contains attribution information about how the user
/// discovered and installed the app.
@immutable
class InstallReferrer {
  /// The raw referrer URL or string from the app store.
  ///
  /// On Android, this is typically the `referrer` parameter from
  /// the Play Store install URL.
  final String? rawReferrer;

  /// UTM source parameter (utm_source).
  ///
  /// Identifies which site sent the traffic (e.g., "google", "facebook").
  final String? source;

  /// UTM medium parameter (utm_medium).
  ///
  /// Identifies what type of link was used (e.g., "cpc", "banner", "email").
  final String? medium;

  /// UTM campaign parameter (utm_campaign).
  ///
  /// Identifies a specific campaign (e.g., "spring_sale").
  final String? campaign;

  /// UTM term parameter (utm_term).
  ///
  /// Identifies search terms (e.g., "running+shoes").
  final String? term;

  /// UTM content parameter (utm_content).
  ///
  /// Identifies what was clicked (e.g., "logolink", "textlink").
  final String? content;

  /// When the referrer URL was clicked.
  final DateTime? clickTime;

  /// When the app was installed.
  final DateTime? installTime;

  /// When the install referrer was retrieved.
  final DateTime retrievedAt;

  /// The install source (Play Store, App Store, direct, etc.).
  final String installSource;

  /// Google Play Install Referrer API response time in ms.
  final int? googlePlayResponseTimeMs;

  /// Whether the install is from an organic (non-paid) source.
  final bool isOrganic;

  const InstallReferrer({
    this.rawReferrer,
    this.source,
    this.medium,
    this.campaign,
    this.term,
    this.content,
    this.clickTime,
    this.installTime,
    required this.retrievedAt,
    required this.installSource,
    this.googlePlayResponseTimeMs,
    this.isOrganic = true,
  });

  /// Whether this referrer has any UTM parameters.
  bool get hasUtmParams =>
      source != null ||
      medium != null ||
      campaign != null ||
      term != null ||
      content != null;

  /// Time between click and install.
  Duration? get clickToInstallTime {
    if (clickTime == null || installTime == null) return null;
    return installTime!.difference(clickTime!);
  }

  /// Parse UTM parameters from a referrer string.
  factory InstallReferrer.fromReferrerString(
    String referrer, {
    DateTime? clickTime,
    DateTime? installTime,
    String installSource = 'play_store',
    int? responseTimeMs,
  }) {
    final params = _parseReferrer(referrer);

    return InstallReferrer(
      rawReferrer: referrer,
      source: params['utm_source'],
      medium: params['utm_medium'],
      campaign: params['utm_campaign'],
      term: params['utm_term'],
      content: params['utm_content'],
      clickTime: clickTime,
      installTime: installTime,
      retrievedAt: DateTime.now(),
      installSource: installSource,
      googlePlayResponseTimeMs: responseTimeMs,
      isOrganic: params['utm_source'] == null && params['utm_medium'] == null,
    );
  }

  /// Create an organic (non-attributed) referrer.
  factory InstallReferrer.organic({
    DateTime? installTime,
    String installSource = 'organic',
  }) =>
      InstallReferrer(
        retrievedAt: DateTime.now(),
        installSource: installSource,
        installTime: installTime,
        isOrganic: true,
      );

  /// Create for App Store (iOS).
  factory InstallReferrer.appStore({DateTime? installTime}) => InstallReferrer(
        retrievedAt: DateTime.now(),
        installSource: 'app_store',
        installTime: installTime,
        isOrganic: true, // iOS doesn't provide referrer data directly
      );

  static Map<String, String> _parseReferrer(String referrer) {
    final params = <String, String>{};

    try {
      // Handle both URI encoded and plain text
      final decoded = Uri.decodeComponent(referrer);

      // Split by & to get key-value pairs
      final pairs = decoded.split('&');
      for (final pair in pairs) {
        final keyValue = pair.split('=');
        if (keyValue.length == 2) {
          params[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
    } catch (_) {
      // If parsing fails, try a simple key=value split
      try {
        final pairs = referrer.split('&');
        for (final pair in pairs) {
          final keyValue = pair.split('=');
          if (keyValue.length == 2) {
            params[keyValue[0].trim()] = keyValue[1].trim();
          }
        }
      } catch (_) {
        // Ignore parsing errors
      }
    }

    return params;
  }

  Map<String, dynamic> toJson() => {
        if (rawReferrer != null) 'raw_referrer': rawReferrer,
        if (source != null) 'source': source,
        if (medium != null) 'medium': medium,
        if (campaign != null) 'campaign': campaign,
        if (term != null) 'term': term,
        if (content != null) 'content': content,
        if (clickTime != null) 'click_time': clickTime!.toIso8601String(),
        if (installTime != null) 'install_time': installTime!.toIso8601String(),
        'retrieved_at': retrievedAt.toIso8601String(),
        'install_source': installSource,
        if (googlePlayResponseTimeMs != null)
          'google_play_response_time_ms': googlePlayResponseTimeMs,
        'is_organic': isOrganic,
      };

  factory InstallReferrer.fromJson(Map<String, dynamic> json) => InstallReferrer(
        rawReferrer: json['raw_referrer'] as String?,
        source: json['source'] as String?,
        medium: json['medium'] as String?,
        campaign: json['campaign'] as String?,
        term: json['term'] as String?,
        content: json['content'] as String?,
        clickTime: json['click_time'] != null
            ? DateTime.parse(json['click_time'] as String)
            : null,
        installTime: json['install_time'] != null
            ? DateTime.parse(json['install_time'] as String)
            : null,
        retrievedAt: DateTime.parse(json['retrieved_at'] as String),
        installSource: json['install_source'] as String,
        googlePlayResponseTimeMs: json['google_play_response_time_ms'] as int?,
        isOrganic: json['is_organic'] as bool? ?? true,
      );

  @override
  String toString() => 'InstallReferrer('
      'source: $source, medium: $medium, campaign: $campaign, '
      'isOrganic: $isOrganic)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallReferrer &&
          runtimeType == other.runtimeType &&
          rawReferrer == other.rawReferrer &&
          source == other.source &&
          medium == other.medium &&
          campaign == other.campaign;

  @override
  int get hashCode => Object.hash(rawReferrer, source, medium, campaign);
}

/// Service for retrieving install referrer information.
///
/// On Android, uses the Play Store Install Referrer API.
/// On iOS, provides limited attribution data (Apple doesn't expose referrer).
///
/// ## Usage
///
/// ```dart
/// await InstallReferrerService.initialize();
///
/// final referrer = InstallReferrerService.installReferrer;
/// if (referrer != null) {
///   print('Source: ${referrer.source}');
///   print('Campaign: ${referrer.campaign}');
/// }
/// ```
///
/// ## Android Setup
///
/// Add to `android/app/build.gradle`:
/// ```gradle
/// dependencies {
///     implementation 'com.android.installreferrer:installreferrer:2.2'
/// }
/// ```
class InstallReferrerService {
  static const _channel = MethodChannel('voo_analytics/install_referrer');

  static InstallReferrerService? _instance;
  static bool _initialized = false;
  static InstallReferrer? _cachedReferrer;

  InstallReferrerService._();

  /// Get the singleton instance.
  static InstallReferrerService get instance {
    _instance ??= InstallReferrerService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// The cached install referrer data.
  static InstallReferrer? get installReferrer => _cachedReferrer;

  /// Initialize the service and retrieve install referrer.
  ///
  /// This should be called early in app startup.
  /// The referrer data is cached and will not change during the app session.
  /// Returns null if the attribution feature is disabled at the project level.
  static Future<InstallReferrer?> initialize() async {
    // Check project-level feature toggle
    if (!Voo.featureConfig.isEnabled(VooFeature.attribution)) {
      _initialized = true;
      return null;
    }

    if (_initialized && _cachedReferrer != null) {
      return _cachedReferrer;
    }

    try {
      if (Platform.isAndroid) {
        _cachedReferrer = await _getAndroidReferrer();
      } else if (Platform.isIOS) {
        _cachedReferrer = await _getIosReferrer();
      } else {
        // Web and other platforms
        _cachedReferrer = InstallReferrer.organic(
          installSource: _getPlatformSource(),
        );
      }

      _initialized = true;

      return _cachedReferrer;
    } catch (_) {
      // Return organic referrer as fallback
      _cachedReferrer = InstallReferrer.organic(
        installSource: _getPlatformSource(),
      );
      _initialized = true;
      return _cachedReferrer;
    }
  }

  /// Get install referrer on Android using platform channel.
  static Future<InstallReferrer> _getAndroidReferrer() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getInstallReferrer',
      );

      if (result == null) {
        return InstallReferrer.organic(installSource: 'play_store');
      }

      final referrerString = result['referrer'] as String?;
      final clickTimeSeconds = result['clickTimeSeconds'] as int?;
      final installTimeSeconds = result['installTimeSeconds'] as int?;
      final responseTimeMs = result['responseTimeMs'] as int?;

      if (referrerString == null || referrerString.isEmpty) {
        return InstallReferrer.organic(
          installSource: 'play_store',
          installTime: installTimeSeconds != null
              ? DateTime.fromMillisecondsSinceEpoch(installTimeSeconds * 1000)
              : null,
        );
      }

      return InstallReferrer.fromReferrerString(
        referrerString,
        clickTime: clickTimeSeconds != null
            ? DateTime.fromMillisecondsSinceEpoch(clickTimeSeconds * 1000)
            : null,
        installTime: installTimeSeconds != null
            ? DateTime.fromMillisecondsSinceEpoch(installTimeSeconds * 1000)
            : null,
        installSource: 'play_store',
        responseTimeMs: responseTimeMs,
      );
    } on PlatformException catch (_) {
      return InstallReferrer.organic(installSource: 'play_store');
    } on MissingPluginException {
      // Native implementation not available, use fallback
      return InstallReferrer.organic(installSource: 'play_store');
    }
  }

  /// Get install referrer on iOS.
  ///
  /// iOS doesn't provide install referrer data directly.
  /// For proper iOS attribution, use SKAdNetwork or a third-party
  /// attribution service like AppsFlyer or Branch.
  static Future<InstallReferrer> _getIosReferrer() async {
    // iOS doesn't expose install referrer
    // Could potentially integrate with App Store receipts for install date
    return InstallReferrer.appStore();
  }

  static String _getPlatformSource() {
    if (Platform.isAndroid) return 'play_store';
    if (Platform.isIOS) return 'app_store';
    if (Platform.isMacOS) return 'mac_app_store';
    if (Platform.isWindows) return 'microsoft_store';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Manually set install referrer (for testing or web).
  ///
  /// This is useful for:
  /// - Unit testing
  /// - Web apps where referrer comes from URL params
  /// - Deep link attribution
  @visibleForTesting
  static void setInstallReferrer(InstallReferrer referrer) {
    _cachedReferrer = referrer;
    _initialized = true;
  }

  /// Clear cached referrer (for testing).
  @visibleForTesting
  static void reset() {
    _cachedReferrer = null;
    _initialized = false;
    _instance = null;
  }
}

/// Kotlin/Java implementation reference for Android:
///
/// Add to android/app/src/main/kotlin/.../MainActivity.kt:
///
/// ```kotlin
/// import android.os.Bundle
/// import com.android.installreferrer.api.InstallReferrerClient
/// import com.android.installreferrer.api.InstallReferrerStateListener
/// import io.flutter.embedding.android.FlutterActivity
/// import io.flutter.embedding.engine.FlutterEngine
/// import io.flutter.plugin.common.MethodChannel
///
/// class MainActivity: FlutterActivity() {
///     private val CHANNEL = "voo_analytics/install_referrer"
///     private var referrerClient: InstallReferrerClient? = null
///
///     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
///         super.configureFlutterEngine(flutterEngine)
///
///         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
///             .setMethodCallHandler { call, result ->
///                 if (call.method == "getInstallReferrer") {
///                     getInstallReferrer(result)
///                 } else {
///                     result.notImplemented()
///                 }
///             }
///     }
///
///     private fun getInstallReferrer(result: MethodChannel.Result) {
///         val startTime = System.currentTimeMillis()
///
///         referrerClient = InstallReferrerClient.newBuilder(this).build()
///         referrerClient?.startConnection(object : InstallReferrerStateListener {
///             override fun onInstallReferrerSetupFinished(responseCode: Int) {
///                 when (responseCode) {
///                     InstallReferrerClient.InstallReferrerResponse.OK -> {
///                         val response = referrerClient?.installReferrer
///                         val responseTime = System.currentTimeMillis() - startTime
///
///                         result.success(mapOf(
///                             "referrer" to response?.installReferrer,
///                             "clickTimeSeconds" to response?.referrerClickTimestampSeconds,
///                             "installTimeSeconds" to response?.installBeginTimestampSeconds,
///                             "responseTimeMs" to responseTime.toInt()
///                         ))
///                     }
///                     else -> result.success(null)
///                 }
///                 referrerClient?.endConnection()
///             }
///
///             override fun onInstallReferrerServiceDisconnected() {
///                 result.success(null)
///             }
///         })
///     }
/// }
/// ```
