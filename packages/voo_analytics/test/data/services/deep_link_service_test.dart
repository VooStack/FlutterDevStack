import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/data/services/deep_link_service.dart';

void main() {
  group('DeepLinkService', () {
    setUp(() {
      DeepLinkService.reset();
    });

    tearDown(() {
      DeepLinkService.reset();
    });

    group('singleton', () {
      test('should return same instance', () {
        final instance1 = DeepLinkService.instance;
        final instance2 = DeepLinkService.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('initialization', () {
      test('should not be initialized initially', () {
        expect(DeepLinkService.isInitialized, isFalse);
      });

      test('should return null initial link before initialization', () {
        expect(DeepLinkService.initialLink, isNull);
      });

      test('should return null attribution before any links', () {
        expect(DeepLinkService.currentAttribution, isNull);
      });
    });

    group('parseUtmParams', () {
      test('should extract UTM parameters from URL', () {
        const url =
            'https://app.example.com?utm_source=google&utm_medium=cpc&utm_campaign=spring';

        final params = DeepLinkService.parseUtmParams(url);

        expect(params['utm_source'], equals('google'));
        expect(params['utm_medium'], equals('cpc'));
        expect(params['utm_campaign'], equals('spring'));
      });

      test('should extract all UTM parameters', () {
        const url =
            'https://app.example.com?utm_source=fb&utm_medium=social&utm_campaign=launch&utm_term=app&utm_content=banner';

        final params = DeepLinkService.parseUtmParams(url);

        expect(params.length, equals(5));
        expect(params['utm_source'], equals('fb'));
        expect(params['utm_term'], equals('app'));
        expect(params['utm_content'], equals('banner'));
      });

      test('should return empty map for URL without UTM params', () {
        const url = 'https://app.example.com/page';

        final params = DeepLinkService.parseUtmParams(url);

        expect(params.isEmpty, isTrue);
      });

      test('should return empty map for invalid URL', () {
        final params = DeepLinkService.parseUtmParams('not a url');

        expect(params.isEmpty, isTrue);
      });

      test('should ignore empty UTM values', () {
        const url = 'https://app.example.com?utm_source=google&utm_medium=';

        final params = DeepLinkService.parseUtmParams(url);

        expect(params['utm_source'], equals('google'));
        expect(params.containsKey('utm_medium'), isFalse);
      });
    });

    group('hasUtmParams', () {
      test('should return true when UTM params present', () {
        const url = 'https://app.example.com?utm_source=google';

        expect(DeepLinkService.hasUtmParams(url), isTrue);
      });

      test('should return false when no UTM params', () {
        const url = 'https://app.example.com/page';

        expect(DeepLinkService.hasUtmParams(url), isFalse);
      });
    });

    group('getAttributionJson', () {
      test('should return null when no attribution', () {
        expect(DeepLinkService.getAttributionJson(), isNull);
      });
    });

    group('clearAttribution', () {
      test('should clear without error', () {
        expect(() => DeepLinkService.clearAttribution(), returnsNormally);
      });

      test('should result in null attribution', () {
        DeepLinkService.clearAttribution();

        expect(DeepLinkService.currentAttribution, isNull);
      });
    });

    group('reset', () {
      test('should reset all state', () {
        DeepLinkService.reset();

        expect(DeepLinkService.isInitialized, isFalse);
        expect(DeepLinkService.initialLink, isNull);
        expect(DeepLinkService.currentAttribution, isNull);
      });
    });
  });
}
