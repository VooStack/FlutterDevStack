import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/data/models/attribution.dart';

void main() {
  group('VooAttribution', () {
    group('constructor', () {
      test('should create with default values', () {
        const attribution = VooAttribution();

        expect(attribution.attributionModel, equals('last_touch'));
        expect(attribution.utmSource, isNull);
        expect(attribution.utmMedium, isNull);
      });

      test('should create with UTM parameters', () {
        const attribution = VooAttribution(
          utmSource: 'google',
          utmMedium: 'cpc',
          utmCampaign: 'spring_sale',
          utmTerm: 'running shoes',
          utmContent: 'banner_1',
        );

        expect(attribution.utmSource, equals('google'));
        expect(attribution.utmMedium, equals('cpc'));
        expect(attribution.utmCampaign, equals('spring_sale'));
        expect(attribution.utmTerm, equals('running shoes'));
        expect(attribution.utmContent, equals('banner_1'));
      });
    });

    group('fromDeepLink', () {
      test('should extract UTM parameters from URI', () {
        final uri = Uri.parse(
          'https://app.example.com/product?utm_source=facebook&utm_medium=social&utm_campaign=launch',
        );

        final attribution = VooAttribution.fromDeepLink(uri);

        expect(attribution.utmSource, equals('facebook'));
        expect(attribution.utmMedium, equals('social'));
        expect(attribution.utmCampaign, equals('launch'));
        expect(attribution.deepLink, equals(uri.toString()));
        expect(attribution.deepLinkPath, equals('/product'));
      });

      test('should set timestamp', () {
        final uri = Uri.parse('https://app.example.com');
        final timestamp = DateTime(2024, 1, 1);

        final attribution = VooAttribution.fromDeepLink(uri, timestamp: timestamp);

        expect(attribution.firstTouch, equals(timestamp));
        expect(attribution.lastTouch, equals(timestamp));
      });
    });

    group('fromUtmParams', () {
      test('should create from parameter map', () {
        final attribution = VooAttribution.fromUtmParams({
          'utm_source': 'newsletter',
          'utm_medium': 'email',
          'utm_campaign': 'weekly',
        });

        expect(attribution.utmSource, equals('newsletter'));
        expect(attribution.utmMedium, equals('email'));
        expect(attribution.utmCampaign, equals('weekly'));
      });
    });

    group('fromReferrer', () {
      test('should create from referrer URL', () {
        final attribution = VooAttribution.fromReferrer('https://www.google.com/search?q=test');

        expect(attribution.referrer, equals('https://www.google.com/search?q=test'));
        expect(attribution.referrerHost, equals('www.google.com'));
      });

      test('should handle invalid URL', () {
        final attribution = VooAttribution.fromReferrer('not a valid url');

        expect(attribution.referrer, equals('not a valid url'));
        expect(attribution.referrerHost, isNull);
      });
    });

    group('computed properties', () {
      test('should detect UTM params', () {
        const withUtm = VooAttribution(utmSource: 'google');
        const withoutUtm = VooAttribution();

        expect(withUtm.hasUtmParams, isTrue);
        expect(withoutUtm.hasUtmParams, isFalse);
      });

      test('should detect deep link', () {
        const withDeepLink = VooAttribution(deepLink: 'app://page');
        const withoutDeepLink = VooAttribution();

        expect(withDeepLink.isFromDeepLink, isTrue);
        expect(withoutDeepLink.isFromDeepLink, isFalse);
      });

      test('should detect referrer', () {
        const withReferrer = VooAttribution(referrer: 'https://google.com');
        const withoutReferrer = VooAttribution();

        expect(withReferrer.hasReferrer, isTrue);
        expect(withoutReferrer.hasReferrer, isFalse);
      });

      test('should detect organic traffic', () {
        const organic = VooAttribution();
        const paid = VooAttribution(utmSource: 'google');

        expect(organic.isOrganic, isTrue);
        expect(paid.isOrganic, isFalse);
      });

      test('should get primary source', () {
        expect(const VooAttribution(utmSource: 'google').primarySource, equals('google'));
        expect(
          const VooAttribution(referrerHost: 'facebook.com').primarySource,
          equals('facebook.com'),
        );
        expect(
          const VooAttribution(installSource: 'play_store').primarySource,
          equals('play_store'),
        );
        expect(const VooAttribution().primarySource, equals('direct'));
      });
    });

    group('channel detection', () {
      test('should detect paid search', () {
        expect(const VooAttribution(utmMedium: 'cpc').channel, equals('paid_search'));
        expect(const VooAttribution(utmMedium: 'ppc').channel, equals('paid_search'));
      });

      test('should detect social', () {
        expect(const VooAttribution(utmMedium: 'social').channel, equals('social'));
      });

      test('should detect email', () {
        expect(const VooAttribution(utmMedium: 'email').channel, equals('email'));
      });

      test('should detect organic search from referrer', () {
        expect(
          const VooAttribution(referrerHost: 'www.google.com').channel,
          equals('organic_search'),
        );
        expect(
          const VooAttribution(referrerHost: 'www.bing.com').channel,
          equals('organic_search'),
        );
      });

      test('should detect social from referrer', () {
        expect(
          const VooAttribution(referrerHost: 'facebook.com').channel,
          equals('social'),
        );
        expect(
          const VooAttribution(referrerHost: 'twitter.com').channel,
          equals('social'),
        );
      });

      test('should detect referral', () {
        expect(
          const VooAttribution(referrerHost: 'blog.example.com').channel,
          equals('referral'),
        );
      });

      test('should default to direct', () {
        expect(const VooAttribution().channel, equals('direct'));
      });
    });

    group('merge', () {
      test('should keep first touch data', () {
        const first = VooAttribution(
          utmSource: 'google',
          utmMedium: 'cpc',
          firstTouch: null,
        );
        const second = VooAttribution(
          utmSource: 'facebook',
          utmMedium: 'social',
        );

        final merged = first.merge(second);

        expect(merged.utmSource, equals('google'));
        expect(merged.utmMedium, equals('cpc'));
      });

      test('should update last touch with newest data', () {
        final first = VooAttribution(
          deepLink: 'app://page1',
          lastTouch: DateTime(2024, 1, 1),
        );
        final second = VooAttribution(
          deepLink: 'app://page2',
          lastTouch: DateTime(2024, 1, 2),
        );

        final merged = first.merge(second);

        expect(merged.deepLink, equals('app://page2'));
        expect(merged.lastTouch, equals(DateTime(2024, 1, 2)));
      });

      test('should fill in missing values', () {
        const first = VooAttribution(utmSource: 'google');
        const second = VooAttribution(utmMedium: 'cpc');

        final merged = first.merge(second);

        expect(merged.utmSource, equals('google'));
        expect(merged.utmMedium, equals('cpc'));
      });
    });

    group('toJson/fromJson', () {
      test('should round-trip through JSON', () {
        final original = VooAttribution(
          utmSource: 'google',
          utmMedium: 'cpc',
          utmCampaign: 'spring',
          utmTerm: 'shoes',
          utmContent: 'banner',
          referrer: 'https://google.com',
          referrerHost: 'google.com',
          deepLink: 'app://page',
          deepLinkPath: '/page',
          deepLinkParams: {'id': '123'},
          installSource: 'play_store',
          firstTouch: DateTime(2024, 1, 1),
          lastTouch: DateTime(2024, 1, 2),
        );

        final json = original.toJson();
        final restored = VooAttribution.fromJson(json);

        expect(restored.utmSource, equals(original.utmSource));
        expect(restored.utmMedium, equals(original.utmMedium));
        expect(restored.utmCampaign, equals(original.utmCampaign));
        expect(restored.deepLink, equals(original.deepLink));
        expect(restored.installSource, equals(original.installSource));
      });

      test('should handle missing optional fields', () {
        final json = <String, dynamic>{};

        final attribution = VooAttribution.fromJson(json);

        expect(attribution.utmSource, isNull);
        expect(attribution.attributionModel, equals('last_touch'));
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        const attribution = VooAttribution(
          utmSource: 'google',
          utmCampaign: 'spring',
        );

        final str = attribution.toString();

        expect(str, contains('google'));
        expect(str, contains('spring'));
      });
    });
  });
}
