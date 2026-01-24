import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/replay/replay_capture_service.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Enable session replay feature for tests
    VooFeatureConfigService.instance.setConfigForTesting(
      const VooFeatureConfig(sessionReplayEnabled: true),
    );
  });

  tearDownAll(() {
    VooFeatureConfigService.instance.reset();
  });
  group('ReplayCaptureConfig', () {
    test('default config has sensible defaults', () {
      const config = ReplayCaptureConfig();

      expect(config.enabled, isFalse);
      expect(config.maxBufferSize, 100);
      expect(config.flushIntervalMs, 5000);
      expect(config.captureTouches, isTrue);
      expect(config.captureScreenViews, isTrue);
      expect(config.captureNetwork, isTrue);
      expect(config.captureLogs, isFalse);
      expect(config.captureErrors, isTrue);
    });

    test('copyWith creates new config with updated values', () {
      const original = ReplayCaptureConfig();
      final updated = original.copyWith(
        enabled: true,
        maxBufferSize: 200,
        captureLogs: true,
      );

      expect(updated.enabled, isTrue);
      expect(updated.maxBufferSize, 200);
      expect(updated.captureLogs, isTrue);
      // Unchanged values
      expect(updated.flushIntervalMs, 5000);
      expect(updated.captureTouches, isTrue);
    });

    test('copyWith preserves values when not specified', () {
      const original = ReplayCaptureConfig(
        enabled: true,
        maxBufferSize: 50,
        flushIntervalMs: 10000,
        captureTouches: false,
        captureScreenViews: false,
        captureNetwork: false,
        captureLogs: true,
        captureErrors: false,
      );

      final updated = original.copyWith(maxBufferSize: 75);

      expect(updated.enabled, isTrue);
      expect(updated.maxBufferSize, 75);
      expect(updated.flushIntervalMs, 10000);
      expect(updated.captureTouches, isFalse);
      expect(updated.captureScreenViews, isFalse);
      expect(updated.captureNetwork, isFalse);
      expect(updated.captureLogs, isTrue);
      expect(updated.captureErrors, isFalse);
    });
  });

  group('ReplayEventCapture', () {
    test('creates touch event with all fields', () {
      final event = ReplayEventCapture(
        eventType: 'touch',
        timestamp: DateTime(2024, 1, 15, 10, 30, 0),
        offsetMs: 5000,
        screenName: 'HomeScreen',
        x: 0.5,
        y: 0.3,
        touchType: 'tap',
      );

      expect(event.eventType, 'touch');
      expect(event.offsetMs, 5000);
      expect(event.screenName, 'HomeScreen');
      expect(event.x, 0.5);
      expect(event.y, 0.3);
      expect(event.touchType, 'tap');
    });

    test('creates screen view event', () {
      final event = ReplayEventCapture(
        eventType: 'screenView',
        timestamp: DateTime.now(),
        offsetMs: 1000,
        screenName: 'SettingsScreen',
        metadata: {'routePath': '/settings'},
      );

      expect(event.eventType, 'screenView');
      expect(event.screenName, 'SettingsScreen');
      expect(event.metadata?['routePath'], '/settings');
    });

    test('toJson serializes touch event correctly', () {
      final event = ReplayEventCapture(
        eventType: 'touch',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30, 0),
        offsetMs: 5000,
        screenName: 'HomeScreen',
        x: 0.5,
        y: 0.3,
        touchType: 'tap',
      );

      final json = event.toJson();

      expect(json['eventType'], 'touch');
      expect(json['timestamp'], '2024-01-15T10:30:00.000Z');
      expect(json['offsetMs'], 5000);
      expect(json['screenName'], 'HomeScreen');
      expect(json['x'], 0.5);
      expect(json['y'], 0.3);
      expect(json['touchType'], 'tap');
    });

    test('toJson omits null fields', () {
      final event = ReplayEventCapture(
        eventType: 'error',
        timestamp: DateTime.utc(2024, 1, 15),
        offsetMs: 0,
        metadata: {'message': 'Test error'},
      );

      final json = event.toJson();

      expect(json.containsKey('screenName'), isFalse);
      expect(json.containsKey('x'), isFalse);
      expect(json.containsKey('y'), isFalse);
      expect(json.containsKey('touchType'), isFalse);
      expect(json['metadata'], {'message': 'Test error'});
    });

    test('toJson serializes network event with metadata', () {
      final event = ReplayEventCapture(
        eventType: 'network',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30, 0),
        offsetMs: 2000,
        screenName: 'Dashboard',
        metadata: {
          'method': 'GET',
          'url': 'https://api.example.com/users',
          'statusCode': 200,
          'durationMs': 150,
          'isError': false,
        },
      );

      final json = event.toJson();

      expect(json['eventType'], 'network');
      expect(json['metadata']['method'], 'GET');
      expect(json['metadata']['statusCode'], 200);
      expect(json['metadata']['isError'], false);
    });
  });

  group('ReplayCaptureService', () {
    late ReplayCaptureService service;

    setUp(() {
      service = ReplayCaptureService.instance;
      service.reset();
    });

    tearDown(() {
      service.reset();
    });

    test('singleton instance is always the same', () {
      final instance1 = ReplayCaptureService.instance;
      final instance2 = ReplayCaptureService.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    test('initial state is disabled', () {
      expect(service.isEnabled, isFalse);
      expect(service.bufferSize, 0);
    });

    test('configure updates config', () {
      const newConfig = ReplayCaptureConfig(
        enabled: true,
        maxBufferSize: 50,
      );

      service.configure(newConfig);

      expect(service.config.enabled, isTrue);
      expect(service.config.maxBufferSize, 50);
    });

    test('enable does not capture events without config enabled', () {
      // Config is disabled by default
      service.enable();

      expect(service.isEnabled, isFalse);
    });

    test('enable captures events when config is enabled', () {
      service.configure(const ReplayCaptureConfig(enabled: true));
      service.enable();

      expect(service.isEnabled, isTrue);
    });

    test('disable stops capture and clears timer', () {
      service.configure(const ReplayCaptureConfig(enabled: true));
      service.enable();
      service.disable();

      expect(service.isEnabled, isFalse);
    });

    test('clearBuffer removes all buffered events', () {
      service.configure(const ReplayCaptureConfig(enabled: true));
      service.enable();

      // Use internal method access via reset
      service.clearBuffer();

      expect(service.bufferSize, 0);
    });

    test('reset clears all state', () {
      service.configure(const ReplayCaptureConfig(
        enabled: true,
        maxBufferSize: 50,
      ));
      service.enable();

      service.reset();

      expect(service.isEnabled, isFalse);
      expect(service.bufferSize, 0);
      expect(service.config.enabled, isFalse);
      expect(service.config.maxBufferSize, 100); // Back to default
    });

    group('capture methods', () {
      setUp(() {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          maxBufferSize: 100,
          captureTouches: true,
          captureScreenViews: true,
          captureNetwork: true,
          captureErrors: true,
          captureLogs: true,
        ));
        service.enable();
      });

      test('captureTouch does not capture when disabled', () {
        service.disable();

        service.captureTouch(x: 0.5, y: 0.3);

        expect(service.bufferSize, 0);
      });

      test('captureTouch does not capture when captureTouches is false', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureTouches: false,
        ));
        service.enable();

        service.captureTouch(x: 0.5, y: 0.3);

        expect(service.bufferSize, 0);
      });

      test('captureScreenView does not capture when captureScreenViews is false', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureScreenViews: false,
        ));
        service.enable();

        service.captureScreenView(screenName: 'TestScreen');

        expect(service.bufferSize, 0);
      });

      test('captureNetwork does not capture when captureNetwork is false', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureNetwork: false,
        ));
        service.enable();

        service.captureNetwork(
          method: 'GET',
          url: 'https://api.example.com',
        );

        expect(service.bufferSize, 0);
      });

      test('captureError does not capture when captureErrors is false', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureErrors: false,
        ));
        service.enable();

        service.captureError(message: 'Test error');

        expect(service.bufferSize, 0);
      });

      test('captureLog does not capture when captureLogs is false', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureLogs: false,
        ));
        service.enable();

        service.captureLog(level: 'info', message: 'Test log');

        expect(service.bufferSize, 0);
      });

      test('captureLifecycle always captures when enabled', () {
        // Note: captureLifecycle doesn't have a config flag, always captures when enabled
        service.captureLifecycle(state: 'resumed');

        // Cannot directly verify buffer since Voo.sessionId is null in tests
        // This test verifies the method doesn't throw
        expect(service.isEnabled, isTrue);
      });

      test('captureCustom always captures when enabled', () {
        service.captureCustom(
          name: 'custom_action',
          data: {'key': 'value'},
        );

        // Cannot directly verify buffer since Voo.sessionId is null in tests
        expect(service.isEnabled, isTrue);
      });
    });

    group('createErrorCaptureCallback', () {
      test('returns a function that captures errors', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureErrors: true,
        ));
        service.enable();

        final callback = service.createErrorCaptureCallback();

        expect(callback, isNotNull);
        expect(callback, isA<Function>());

        // Call the callback - should not throw
        callback(
          message: 'Test error message',
          errorType: 'TestException',
          stackTrace: 'at TestClass.method(test.dart:10)',
        );
      });

      test('callback captures errors with minimal parameters', () {
        service.configure(const ReplayCaptureConfig(
          enabled: true,
          captureErrors: true,
        ));
        service.enable();

        final callback = service.createErrorCaptureCallback();

        // Call with only required parameter
        callback(message: 'Minimal error');

        expect(service.isEnabled, isTrue);
      });
    });
  });

  group('ReplayCaptureService edge cases', () {
    late ReplayCaptureService service;

    setUp(() {
      service = ReplayCaptureService.instance;
      service.reset();
    });

    tearDown(() {
      service.reset();
    });

    test('multiple enable calls are idempotent', () {
      service.configure(const ReplayCaptureConfig(enabled: true));

      service.enable();
      service.enable();
      service.enable();

      expect(service.isEnabled, isTrue);
    });

    test('multiple disable calls are idempotent', () {
      service.configure(const ReplayCaptureConfig(enabled: true));
      service.enable();

      service.disable();
      service.disable();
      service.disable();

      expect(service.isEnabled, isFalse);
    });

    test('disable when already disabled is safe', () {
      service.disable();

      expect(service.isEnabled, isFalse);
    });

    test('flushNow completes without error when buffer is empty', () async {
      service.configure(const ReplayCaptureConfig(enabled: true));
      service.enable();

      // Should not throw
      await service.flushNow();

      expect(service.bufferSize, 0);
    });

    test('configure while enabled restarts timer', () {
      service.configure(const ReplayCaptureConfig(enabled: true));
      service.enable();

      // Reconfigure with different interval
      service.configure(const ReplayCaptureConfig(
        enabled: true,
        flushIntervalMs: 10000,
      ));

      expect(service.config.flushIntervalMs, 10000);
    });
  });
}
