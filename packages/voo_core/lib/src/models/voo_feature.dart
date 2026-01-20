/// SDK features that can be toggled on/off per project.
///
/// All features are disabled by default (privacy-first).
/// Feature configuration is fetched from the server and cached locally.
enum VooFeature {
  /// General event logging/analytics.
  analytics,

  /// Touch tracking for heatmap visualization.
  touchTracking,

  /// Session replay recording.
  sessionReplay,

  /// Error capture and reporting.
  errorTracking,

  /// Screen view / navigation tracking.
  screenViews,

  /// Funnel conversion tracking.
  funnelTracking,

  /// Install attribution, deep links, and UTM parameter tracking.
  attribution,

  /// Cross-app usage tracking (Android only).
  appUsage,

  /// Screen engagement metrics (time on screen, scroll depth, interactions).
  screenEngagement,

  /// Performance metrics tracking.
  performance,

  /// Logs/logging feature.
  logs,

  /// Revenue tracking and analytics.
  revenue,

  /// CI/CD pipelines feature.
  pipelines,
}
