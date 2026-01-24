import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooFeatureConfigService', () {
    setUp(() {
      VooFeatureConfigService.instance.reset();
    });

    tearDown(() {
      VooFeatureConfigService.instance.reset();
    });

    group('singleton', () {
      test('should return same instance', () {
        final instance1 = VooFeatureConfigService.instance;
        final instance2 = VooFeatureConfigService.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('default config', () {
      test('should have all features disabled by default', () {
        expect(
          VooFeatureConfigService.instance.isEnabled(VooFeature.sessionReplay),
          isFalse,
        );
        expect(
          VooFeatureConfigService.instance.isEnabled(VooFeature.errorTracking),
          isFalse,
        );
        expect(
          VooFeatureConfigService.instance.isEnabled(VooFeature.analytics),
          isFalse,
        );
      });

      test('should return allDisabled config initially', () {
        final config = VooFeatureConfigService.instance.config;

        expect(config.sessionReplayEnabled, isFalse);
        expect(config.errorTrackingEnabled, isFalse);
        expect(config.analyticsEnabled, isFalse);
        expect(config.touchTrackingEnabled, isFalse);
        expect(config.performanceEnabled, isFalse);
      });
    });

    group('isEnabled', () {
      test('should check specific feature', () {
        // All features are disabled by default
        expect(
          VooFeatureConfigService.instance.isEnabled(VooFeature.sessionReplay),
          isFalse,
        );
      });
    });

    group('refreshIfNeeded', () {
      test('should complete without error', () async {
        await expectLater(
          VooFeatureConfigService.instance.refreshIfNeeded(),
          completes,
        );
      });
    });

    group('fetchConfig', () {
      test('should not fetch without valid Voo config', () async {
        // Should complete silently without network request
        await expectLater(
          VooFeatureConfigService.instance.fetchConfig(),
          completes,
        );
      });
    });

    group('onAppResume', () {
      test('should trigger refresh check without error', () {
        expect(
          () => VooFeatureConfigService.instance.onAppResume(),
          returnsNormally,
        );
      });
    });

    group('reset', () {
      test('should reset all state', () {
        VooFeatureConfigService.instance.reset();

        expect(
          VooFeatureConfigService.instance.config,
          equals(VooFeatureConfig.allDisabled),
        );
      });
    });
  });
}
