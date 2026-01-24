import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:voo_core/src/models/voo_config.dart';
import 'package:voo_core/src/models/voo_feature.dart';
import 'package:voo_core/src/models/voo_feature_config.dart';

/// Service for managing SDK feature configuration.
///
/// Fetches feature toggles from the server and caches them locally.
/// All features are disabled by default (privacy-first).
///
/// The service uses TTL-based caching:
/// - Config is fetched on initialization
/// - Cached locally for the TTL duration (default: 1 hour)
/// - Refreshed when TTL expires or on app foreground
///
/// Example usage:
/// ```dart
/// // Check if a feature is enabled before collecting data
/// if (Voo.featureConfig.isEnabled(VooFeature.sessionReplay)) {
///   // Capture session replay data
/// }
/// ```
class VooFeatureConfigService {
  static final VooFeatureConfigService _instance = VooFeatureConfigService._();
  static VooFeatureConfigService get instance => _instance;

  VooFeatureConfigService._();

  VooFeatureConfig _config = VooFeatureConfig.allDisabled;
  File? _cacheFile;
  DateTime? _lastFetchTime;
  bool _isFetching = false;
  bool _initialized = false;
  VooConfig? _vooConfig;

  /// Default TTL for cached config (1 hour).
  static const Duration defaultTtl = Duration(hours: 1);

  /// Current TTL for cached config.
  Duration _ttl = defaultTtl;

  /// The current feature configuration.
  VooFeatureConfig get config => _config;

  /// Check if a specific feature is enabled.
  ///
  /// Returns false if the feature is disabled or if config hasn't been loaded.
  bool isEnabled(VooFeature feature) {
    return _config.isEnabled(feature);
  }

  /// Initialize the service with Voo configuration.
  ///
  /// This is called automatically by [Voo.initializeApp].
  /// Loads cached config and fetches fresh config from the server.
  Future<void> initialize(VooConfig config) async {
    if (_initialized) return;

    _vooConfig = config;
    _initialized = true;

    // Load from cache first for immediate availability
    await _loadFromCache();

    // Then fetch fresh config from server
    await fetchConfig();

    if (kDebugMode) {
      debugPrint('VooFeatureConfig: Initialized - $_config');
    }
  }

  /// Refresh config if TTL has expired.
  ///
  /// Call this on app foreground to pick up config changes.
  Future<void> refreshIfNeeded() async {
    if (_shouldRefresh()) {
      await fetchConfig();
    }
  }

  /// Force fetch config from the server.
  ///
  /// Use this when you need to immediately pick up config changes.
  Future<void> fetchConfig() async {
    if (_isFetching || _vooConfig == null || !_vooConfig!.isValid) return;
    _isFetching = true;

    try {
      final url = '${_vooConfig!.endpoint}/v1/sdk/config';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-API-Key': _vooConfig!.apiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final features = json['features'] as Map<String, dynamic>?;

        if (features != null) {
          _config = VooFeatureConfig.fromJson(features)
              .withCachedAt(DateTime.now());

          // Update TTL from server response
          final cacheTtlSeconds = json['cacheTtlSeconds'] as int?;
          if (cacheTtlSeconds != null && cacheTtlSeconds > 0) {
            _ttl = Duration(seconds: cacheTtlSeconds);
          }

          _lastFetchTime = DateTime.now();
          await _saveToCache();

          if (kDebugMode) {
            debugPrint('VooFeatureConfig: Fetched from server - $_config');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              'VooFeatureConfig: Failed to fetch (${response.statusCode})');
        }
      }
    } catch (e) {
      // Silent fail - keep using cached config
      if (kDebugMode) {
        debugPrint('VooFeatureConfig: Failed to fetch: $e');
      }
    } finally {
      _isFetching = false;
    }
  }

  /// Called when the app resumes from background.
  ///
  /// Refreshes config if TTL has expired.
  void onAppResume() {
    refreshIfNeeded();
  }

  /// Reset the service to initial state.
  ///
  /// Used for testing or when disposing.
  void reset() {
    _config = VooFeatureConfig.allDisabled;
    _cacheFile = null;
    _lastFetchTime = null;
    _isFetching = false;
    _initialized = false;
    _vooConfig = null;
    _ttl = defaultTtl;
  }

  /// Set config directly for testing.
  ///
  /// This bypasses server fetch and cache loading.
  @visibleForTesting
  void setConfigForTesting(VooFeatureConfig config) {
    _config = config;
    _initialized = true;
  }

  bool _shouldRefresh() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _ttl;
  }

  Future<void> _loadFromCache() async {
    if (kIsWeb) return; // Web uses memory only

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/voo_core');
      _cacheFile = File('${cacheDir.path}/feature_config.json');

      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        final configJson = json['config'] as Map<String, dynamic>?;
        if (configJson != null) {
          _config = VooFeatureConfig.fromJson(configJson);
        }

        final cachedAtStr = json['cachedAt'] as String?;
        if (cachedAtStr != null) {
          _lastFetchTime = DateTime.tryParse(cachedAtStr);
        }

        if (kDebugMode) {
          debugPrint('VooFeatureConfig: Loaded from cache - $_config');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooFeatureConfig: Failed to load cache: $e');
      }
    }
  }

  Future<void> _saveToCache() async {
    if (kIsWeb || _cacheFile == null) return;

    try {
      final cacheDir = _cacheFile!.parent;
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheData = {
        'config': _config.toJson(),
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await _cacheFile!.writeAsString(jsonEncode(cacheData));

      if (kDebugMode) {
        debugPrint('VooFeatureConfig: Saved to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VooFeatureConfig: Failed to save cache: $e');
      }
    }
  }
}
