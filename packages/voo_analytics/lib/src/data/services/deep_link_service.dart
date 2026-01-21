import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

import 'package:voo_analytics/src/data/models/attribution.dart';

/// Service for handling deep links and app links.
///
/// Listens for incoming links (both cold start and while app is running),
/// extracts UTM parameters, and tracks attribution.
///
/// ## Setup
///
/// 1. Add to pubspec.yaml:
/// ```yaml
/// dependencies:
///   app_links: ^6.0.0
/// ```
///
/// 2. Configure your app for deep links:
///    - iOS: Add Associated Domains capability
///    - Android: Add intent filters in AndroidManifest.xml
///
/// ## Usage
///
/// ```dart
/// // Initialize during app startup
/// await DeepLinkService.initialize();
///
/// // Listen for deep link events
/// DeepLinkService.linkStream.listen((uri) {
///   // Handle the deep link navigation
///   navigateToPath(uri.path);
/// });
///
/// // Get current attribution
/// final attribution = DeepLinkService.currentAttribution;
/// print('User came from: ${attribution?.primarySource}');
/// ```
class DeepLinkService {
  static DeepLinkService? _instance;
  static bool _initialized = false;

  final AppLinks _appLinks = AppLinks();

  /// Current attribution data.
  VooAttribution? _currentAttribution;

  /// Stream controller for deep link events.
  final StreamController<Uri> _linkController =
      StreamController<Uri>.broadcast();

  /// Stream subscription for app links.
  StreamSubscription<Uri>? _linkSubscription;

  /// Initial link that opened the app (cold start).
  Uri? _initialLink;

  DeepLinkService._();

  /// Get the singleton instance.
  static DeepLinkService get instance {
    _instance ??= DeepLinkService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Stream of incoming deep links.
  static Stream<Uri> get linkStream => instance._linkController.stream;

  /// The initial link that opened the app (null if opened normally).
  static Uri? get initialLink => instance._initialLink;

  /// Current attribution data.
  static VooAttribution? get currentAttribution => instance._currentAttribution;

  /// Initialize the deep link service.
  ///
  /// Call this early in your app's startup (before runApp if possible).
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get the initial link that opened the app (cold start)
      instance._initialLink = await instance._appLinks.getInitialLink();

      if (instance._initialLink != null) {
        if (kDebugMode) {
          debugPrint(
              'DeepLinkService: Cold start with link: ${instance._initialLink}');
        }
        instance._handleIncomingLink(instance._initialLink!);
      }

      // Listen for links while app is running
      instance._linkSubscription =
          instance._appLinks.uriLinkStream.listen((uri) {
        if (kDebugMode) {
          debugPrint('DeepLinkService: Received link: $uri');
        }
        instance._handleIncomingLink(uri);
      });

      _initialized = true;

      if (kDebugMode) {
        debugPrint('DeepLinkService: Initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeepLinkService: Failed to initialize: $e');
      }
    }
  }

  /// Handle an incoming deep link.
  void _handleIncomingLink(Uri uri) {
    // Only track attribution if the feature is enabled
    if (Voo.featureConfig.isEnabled(VooFeature.attribution)) {
      // Extract attribution from the link
      final attribution = VooAttribution.fromDeepLink(uri);

      // Merge with existing attribution (keeps first touch)
      if (_currentAttribution != null) {
        _currentAttribution = _currentAttribution!.merge(attribution);
      } else {
        _currentAttribution = attribution;
      }

      // Update user context with attribution
      _updateUserContext(attribution);
    }

    // Add breadcrumb (always, for debugging)
    Voo.addBreadcrumb(VooBreadcrumb(
      type: VooBreadcrumbType.custom,
      category: 'deep_link',
      message: 'Deep link received: ${uri.path}',
      data: {
        'uri': uri.toString(),
        'path': uri.path,
        if (uri.queryParameters.isNotEmpty) 'params': uri.queryParameters,
      },
    ));

    // Emit the link for navigation handling
    _linkController.add(uri);
  }

  /// Update user context with attribution data.
  void _updateUserContext(VooAttribution attribution) {
    try {
      final properties = <String, dynamic>{};

      if (attribution.utmSource != null) {
        properties['utm_source'] = attribution.utmSource;
      }
      if (attribution.utmMedium != null) {
        properties['utm_medium'] = attribution.utmMedium;
      }
      if (attribution.utmCampaign != null) {
        properties['utm_campaign'] = attribution.utmCampaign;
      }
      if (attribution.primarySource != 'direct') {
        properties['attribution_source'] = attribution.primarySource;
        properties['attribution_channel'] = attribution.channel;
      }

      if (properties.isNotEmpty) {
        Voo.setUserProperties(properties);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeepLinkService: Failed to update user context: $e');
      }
    }
  }

  /// Manually set attribution (e.g., from web referrer or install referrer).
  static void setAttribution(VooAttribution attribution) {
    if (instance._currentAttribution != null) {
      instance._currentAttribution =
          instance._currentAttribution!.merge(attribution);
    } else {
      instance._currentAttribution = attribution;
    }

    instance._updateUserContext(attribution);

    if (kDebugMode) {
      debugPrint('DeepLinkService: Attribution set: $attribution');
    }
  }

  /// Parse UTM parameters from a URL string.
  static Map<String, String> parseUtmParams(String url) {
    try {
      final uri = Uri.parse(url);
      final utmParams = <String, String>{};

      for (final key in [
        'utm_source',
        'utm_medium',
        'utm_campaign',
        'utm_term',
        'utm_content'
      ]) {
        final value = uri.queryParameters[key];
        if (value != null && value.isNotEmpty) {
          utmParams[key] = value;
        }
      }

      return utmParams;
    } catch (e) {
      return {};
    }
  }

  /// Check if a URL has UTM parameters.
  static bool hasUtmParams(String url) {
    return parseUtmParams(url).isNotEmpty;
  }

  /// Get attribution as JSON for analytics events.
  static Map<String, dynamic>? getAttributionJson() {
    return instance._currentAttribution?.toJson();
  }

  /// Clear current attribution (e.g., on logout).
  static void clearAttribution() {
    instance._currentAttribution = null;

    if (kDebugMode) {
      debugPrint('DeepLinkService: Attribution cleared');
    }
  }

  /// Dispose resources.
  static Future<void> dispose() async {
    await instance._linkSubscription?.cancel();
    await instance._linkController.close();
    _initialized = false;
    _instance = null;

    if (kDebugMode) {
      debugPrint('DeepLinkService: Disposed');
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    instance._currentAttribution = null;
    instance._initialLink = null;
    _initialized = false;
    _instance = null;
  }
}
