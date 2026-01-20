import 'package:flutter/foundation.dart';
import 'voo_feature.dart';

/// Feature toggle configuration for a project.
///
/// All features are disabled by default (privacy-first).
/// This configuration is fetched from the server and cached locally
/// to avoid unnecessary API calls when features are disabled.
@immutable
class VooFeatureConfig {
  /// Enable general event logging/analytics.
  final bool analyticsEnabled;

  /// Enable touch tracking for heatmap visualization.
  final bool touchTrackingEnabled;

  /// Enable session replay recording.
  final bool sessionReplayEnabled;

  /// Enable error capture and reporting.
  final bool errorTrackingEnabled;

  /// Enable screen view / navigation tracking.
  final bool screenViewsEnabled;

  /// Enable funnel conversion tracking.
  final bool funnelTrackingEnabled;

  /// Enable install attribution, deep links, and UTM parameter tracking.
  final bool attributionEnabled;

  /// Enable cross-app usage tracking (Android only).
  final bool appUsageEnabled;

  /// Enable screen engagement metrics (time on screen, scroll depth, interactions).
  final bool screenEngagementEnabled;

  /// Enable performance metrics tracking.
  final bool performanceEnabled;

  /// When this config was last updated on the server.
  final DateTime? updatedAt;

  /// When this config was cached locally.
  final DateTime? cachedAt;

  const VooFeatureConfig({
    this.analyticsEnabled = false,
    this.touchTrackingEnabled = false,
    this.sessionReplayEnabled = false,
    this.errorTrackingEnabled = false,
    this.screenViewsEnabled = false,
    this.funnelTrackingEnabled = false,
    this.attributionEnabled = false,
    this.appUsageEnabled = false,
    this.screenEngagementEnabled = false,
    this.performanceEnabled = false,
    this.updatedAt,
    this.cachedAt,
  });

  /// Default configuration with all features disabled.
  static const VooFeatureConfig allDisabled = VooFeatureConfig();

  /// Check if a specific feature is enabled.
  bool isEnabled(VooFeature feature) {
    switch (feature) {
      case VooFeature.analytics:
        return analyticsEnabled;
      case VooFeature.touchTracking:
        return touchTrackingEnabled;
      case VooFeature.sessionReplay:
        return sessionReplayEnabled;
      case VooFeature.errorTracking:
        return errorTrackingEnabled;
      case VooFeature.screenViews:
        return screenViewsEnabled;
      case VooFeature.funnelTracking:
        return funnelTrackingEnabled;
      case VooFeature.attribution:
        return attributionEnabled;
      case VooFeature.appUsage:
        return appUsageEnabled;
      case VooFeature.screenEngagement:
        return screenEngagementEnabled;
      case VooFeature.performance:
        return performanceEnabled;
    }
  }

  /// Whether any feature is enabled.
  bool get hasAnyEnabled =>
      analyticsEnabled ||
      touchTrackingEnabled ||
      sessionReplayEnabled ||
      errorTrackingEnabled ||
      screenViewsEnabled ||
      funnelTrackingEnabled ||
      attributionEnabled ||
      appUsageEnabled ||
      screenEngagementEnabled ||
      performanceEnabled;

  /// Create from JSON response from the server.
  factory VooFeatureConfig.fromJson(Map<String, dynamic> json) {
    return VooFeatureConfig(
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? false,
      touchTrackingEnabled: json['touchTrackingEnabled'] as bool? ?? false,
      sessionReplayEnabled: json['sessionReplayEnabled'] as bool? ?? false,
      errorTrackingEnabled: json['errorTrackingEnabled'] as bool? ?? false,
      screenViewsEnabled: json['screenViewsEnabled'] as bool? ?? false,
      funnelTrackingEnabled: json['funnelTrackingEnabled'] as bool? ?? false,
      attributionEnabled: json['attributionEnabled'] as bool? ?? false,
      appUsageEnabled: json['appUsageEnabled'] as bool? ?? false,
      screenEngagementEnabled: json['screenEngagementEnabled'] as bool? ?? false,
      performanceEnabled: json['performanceEnabled'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      cachedAt: json['cachedAt'] != null
          ? DateTime.tryParse(json['cachedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON for local caching.
  Map<String, dynamic> toJson() {
    return {
      'analyticsEnabled': analyticsEnabled,
      'touchTrackingEnabled': touchTrackingEnabled,
      'sessionReplayEnabled': sessionReplayEnabled,
      'errorTrackingEnabled': errorTrackingEnabled,
      'screenViewsEnabled': screenViewsEnabled,
      'funnelTrackingEnabled': funnelTrackingEnabled,
      'attributionEnabled': attributionEnabled,
      'appUsageEnabled': appUsageEnabled,
      'screenEngagementEnabled': screenEngagementEnabled,
      'performanceEnabled': performanceEnabled,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (cachedAt != null) 'cachedAt': cachedAt!.toIso8601String(),
    };
  }

  /// Create a copy with the cachedAt timestamp set to now.
  VooFeatureConfig withCachedAt(DateTime cachedAt) {
    return VooFeatureConfig(
      analyticsEnabled: analyticsEnabled,
      touchTrackingEnabled: touchTrackingEnabled,
      sessionReplayEnabled: sessionReplayEnabled,
      errorTrackingEnabled: errorTrackingEnabled,
      screenViewsEnabled: screenViewsEnabled,
      funnelTrackingEnabled: funnelTrackingEnabled,
      attributionEnabled: attributionEnabled,
      appUsageEnabled: appUsageEnabled,
      screenEngagementEnabled: screenEngagementEnabled,
      performanceEnabled: performanceEnabled,
      updatedAt: updatedAt,
      cachedAt: cachedAt,
    );
  }

  @override
  String toString() {
    final enabled = <String>[];
    if (analyticsEnabled) enabled.add('analytics');
    if (touchTrackingEnabled) enabled.add('touchTracking');
    if (sessionReplayEnabled) enabled.add('sessionReplay');
    if (errorTrackingEnabled) enabled.add('errorTracking');
    if (screenViewsEnabled) enabled.add('screenViews');
    if (funnelTrackingEnabled) enabled.add('funnelTracking');
    if (attributionEnabled) enabled.add('attribution');
    if (appUsageEnabled) enabled.add('appUsage');
    if (screenEngagementEnabled) enabled.add('screenEngagement');
    if (performanceEnabled) enabled.add('performance');
    return 'VooFeatureConfig(enabled: [${enabled.join(', ')}])';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VooFeatureConfig &&
        other.analyticsEnabled == analyticsEnabled &&
        other.touchTrackingEnabled == touchTrackingEnabled &&
        other.sessionReplayEnabled == sessionReplayEnabled &&
        other.errorTrackingEnabled == errorTrackingEnabled &&
        other.screenViewsEnabled == screenViewsEnabled &&
        other.funnelTrackingEnabled == funnelTrackingEnabled &&
        other.attributionEnabled == attributionEnabled &&
        other.appUsageEnabled == appUsageEnabled &&
        other.screenEngagementEnabled == screenEngagementEnabled &&
        other.performanceEnabled == performanceEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      analyticsEnabled,
      touchTrackingEnabled,
      sessionReplayEnabled,
      errorTrackingEnabled,
      screenViewsEnabled,
      funnelTrackingEnabled,
      attributionEnabled,
      appUsageEnabled,
      screenEngagementEnabled,
      performanceEnabled,
    );
  }
}
