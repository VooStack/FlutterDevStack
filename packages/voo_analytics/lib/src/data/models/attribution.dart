import 'package:flutter/foundation.dart';

/// Attribution data for tracking where users came from.
///
/// Captures UTM parameters, referrers, deep links, and install attribution.
@immutable
class VooAttribution {
  // UTM Parameters (standard marketing attribution)
  /// Traffic source (e.g., google, facebook, newsletter, direct).
  final String? utmSource;

  /// Marketing medium (e.g., cpc, social, email, organic).
  final String? utmMedium;

  /// Campaign name (e.g., spring_sale, black_friday).
  final String? utmCampaign;

  /// Paid search term (e.g., running+shoes).
  final String? utmTerm;

  /// Content identifier for A/B testing (e.g., logolink, textlink).
  final String? utmContent;

  // Referrer Tracking
  /// Full referrer URL.
  final String? referrer;

  /// Extracted hostname from referrer.
  final String? referrerHost;

  // Deep Link Tracking
  /// Full deep link URL that opened the app.
  final String? deepLink;

  /// Path portion of the deep link.
  final String? deepLinkPath;

  /// Query parameters from the deep link.
  final Map<String, String>? deepLinkParams;

  // Install Attribution (primarily Android)
  /// Where the app was installed from (play_store, app_store, direct, web).
  final String? installSource;

  /// Android Play Store install referrer string.
  final String? installReferrer;

  /// When the app was first installed.
  final DateTime? installTime;

  // Touch Attribution
  /// First interaction timestamp (first touch attribution).
  final DateTime? firstTouch;

  /// Most recent interaction timestamp (last touch attribution).
  final DateTime? lastTouch;

  /// Attribution model used (first_touch, last_touch, linear).
  final String attributionModel;

  const VooAttribution({
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    this.referrer,
    this.referrerHost,
    this.deepLink,
    this.deepLinkPath,
    this.deepLinkParams,
    this.installSource,
    this.installReferrer,
    this.installTime,
    this.firstTouch,
    this.lastTouch,
    this.attributionModel = 'last_touch',
  });

  /// Creates attribution from a deep link URL.
  factory VooAttribution.fromDeepLink(Uri uri, {DateTime? timestamp}) {
    final params = uri.queryParameters;
    final now = timestamp ?? DateTime.now();

    return VooAttribution(
      utmSource: params['utm_source'],
      utmMedium: params['utm_medium'],
      utmCampaign: params['utm_campaign'],
      utmTerm: params['utm_term'],
      utmContent: params['utm_content'],
      deepLink: uri.toString(),
      deepLinkPath: uri.path,
      deepLinkParams: params.isNotEmpty ? Map.from(params) : null,
      firstTouch: now,
      lastTouch: now,
    );
  }

  /// Creates attribution from UTM parameters.
  factory VooAttribution.fromUtmParams(Map<String, String> params,
      {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();

    return VooAttribution(
      utmSource: params['utm_source'],
      utmMedium: params['utm_medium'],
      utmCampaign: params['utm_campaign'],
      utmTerm: params['utm_term'],
      utmContent: params['utm_content'],
      firstTouch: now,
      lastTouch: now,
    );
  }

  /// Creates attribution from a referrer URL.
  factory VooAttribution.fromReferrer(String referrerUrl,
      {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    Uri? uri;

    try {
      uri = Uri.parse(referrerUrl);
    } catch (_) {
      // Invalid URL
    }

    return VooAttribution(
      referrer: referrerUrl,
      referrerHost: uri?.host,
      firstTouch: now,
      lastTouch: now,
    );
  }

  /// Whether this attribution has any UTM parameters.
  bool get hasUtmParams =>
      utmSource != null ||
      utmMedium != null ||
      utmCampaign != null ||
      utmTerm != null ||
      utmContent != null;

  /// Whether this attribution came from a deep link.
  bool get isFromDeepLink => deepLink != null;

  /// Whether this attribution has referrer information.
  bool get hasReferrer => referrer != null;

  /// Whether this is organic traffic (no paid attribution).
  bool get isOrganic =>
      !hasUtmParams && !isFromDeepLink && referrerHost == null;

  /// Gets the primary attribution source for reporting.
  String get primarySource {
    if (utmSource != null) return utmSource!;
    if (referrerHost != null) return referrerHost!;
    if (installSource != null) return installSource!;
    return 'direct';
  }

  /// Gets the attribution channel based on medium.
  String get channel {
    final medium = utmMedium?.toLowerCase();
    if (medium == null) {
      if (referrerHost != null) {
        if (referrerHost!.contains('google') ||
            referrerHost!.contains('bing') ||
            referrerHost!.contains('yahoo')) {
          return 'organic_search';
        }
        if (referrerHost!.contains('facebook') ||
            referrerHost!.contains('twitter') ||
            referrerHost!.contains('instagram') ||
            referrerHost!.contains('linkedin')) {
          return 'social';
        }
        return 'referral';
      }
      return 'direct';
    }

    switch (medium) {
      case 'cpc':
      case 'ppc':
      case 'paid':
        return 'paid_search';
      case 'social':
        return 'social';
      case 'email':
        return 'email';
      case 'affiliate':
        return 'affiliate';
      case 'display':
        return 'display';
      case 'organic':
        return 'organic_search';
      default:
        return medium;
    }
  }

  /// Merges with another attribution, keeping first touch but updating last touch.
  VooAttribution merge(VooAttribution other) {
    return VooAttribution(
      // Keep first touch data
      utmSource: utmSource ?? other.utmSource,
      utmMedium: utmMedium ?? other.utmMedium,
      utmCampaign: utmCampaign ?? other.utmCampaign,
      utmTerm: utmTerm ?? other.utmTerm,
      utmContent: utmContent ?? other.utmContent,
      referrer: referrer ?? other.referrer,
      referrerHost: referrerHost ?? other.referrerHost,
      installSource: installSource ?? other.installSource,
      installReferrer: installReferrer ?? other.installReferrer,
      installTime: installTime ?? other.installTime,
      firstTouch: firstTouch ?? other.firstTouch,
      // Update last touch with newest data
      deepLink: other.deepLink ?? deepLink,
      deepLinkPath: other.deepLinkPath ?? deepLinkPath,
      deepLinkParams: other.deepLinkParams ?? deepLinkParams,
      lastTouch: other.lastTouch ?? lastTouch,
      attributionModel: attributionModel,
    );
  }

  /// Converts to JSON for storage/transmission.
  Map<String, dynamic> toJson() {
    return {
      if (utmSource != null) 'utm_source': utmSource,
      if (utmMedium != null) 'utm_medium': utmMedium,
      if (utmCampaign != null) 'utm_campaign': utmCampaign,
      if (utmTerm != null) 'utm_term': utmTerm,
      if (utmContent != null) 'utm_content': utmContent,
      if (referrer != null) 'referrer': referrer,
      if (referrerHost != null) 'referrer_host': referrerHost,
      if (deepLink != null) 'deep_link': deepLink,
      if (deepLinkPath != null) 'deep_link_path': deepLinkPath,
      if (deepLinkParams != null) 'deep_link_params': deepLinkParams,
      if (installSource != null) 'install_source': installSource,
      if (installReferrer != null) 'install_referrer': installReferrer,
      if (installTime != null) 'install_time': installTime!.toIso8601String(),
      if (firstTouch != null) 'first_touch': firstTouch!.toIso8601String(),
      if (lastTouch != null) 'last_touch': lastTouch!.toIso8601String(),
      'attribution_model': attributionModel,
      'primary_source': primarySource,
      'channel': channel,
    };
  }

  /// Creates from JSON.
  factory VooAttribution.fromJson(Map<String, dynamic> json) {
    return VooAttribution(
      utmSource: json['utm_source'] as String?,
      utmMedium: json['utm_medium'] as String?,
      utmCampaign: json['utm_campaign'] as String?,
      utmTerm: json['utm_term'] as String?,
      utmContent: json['utm_content'] as String?,
      referrer: json['referrer'] as String?,
      referrerHost: json['referrer_host'] as String?,
      deepLink: json['deep_link'] as String?,
      deepLinkPath: json['deep_link_path'] as String?,
      deepLinkParams: json['deep_link_params'] != null
          ? Map<String, String>.from(json['deep_link_params'] as Map)
          : null,
      installSource: json['install_source'] as String?,
      installReferrer: json['install_referrer'] as String?,
      installTime: json['install_time'] != null
          ? DateTime.parse(json['install_time'] as String)
          : null,
      firstTouch: json['first_touch'] != null
          ? DateTime.parse(json['first_touch'] as String)
          : null,
      lastTouch: json['last_touch'] != null
          ? DateTime.parse(json['last_touch'] as String)
          : null,
      attributionModel:
          json['attribution_model'] as String? ?? 'last_touch',
    );
  }

  @override
  String toString() {
    return 'VooAttribution(source: $primarySource, channel: $channel, '
        'campaign: $utmCampaign)';
  }
}
