import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooErrorTrackingService', () {
    setUp(() {
      VooErrorTrackingService.instance.reset();
    });

    tearDown(() async {
      VooErrorTrackingService.instance.reset();
      await Voo.dispose();
    });

    group('enable/disable', () {
      test('should be disabled by default after reset', () {
        expect(VooErrorTrackingService.instance.isEnabled, isFalse);
      });

      test('should enable error tracking', () {
        VooErrorTrackingService.instance.enable();

        expect(VooErrorTrackingService.instance.isEnabled, isTrue);
      });

      test('should disable error tracking', () {
        VooErrorTrackingService.instance.enable();
        VooErrorTrackingService.instance.disable();

        expect(VooErrorTrackingService.instance.isEnabled, isFalse);
      });
    });

    group('submitError', () {
      test('should not submit when disabled', () async {
        // Should complete without error even when disabled
        await expectLater(
          VooErrorTrackingService.instance.submitError(
            message: 'Test error',
          ),
          completes,
        );
      });

      test('should not submit without Voo context', () async {
        VooErrorTrackingService.instance.enable();

        // Should complete without error even without context
        await expectLater(
          VooErrorTrackingService.instance.submitError(
            message: 'Test error',
          ),
          completes,
        );
      });
    });

    group('createErrorCaptureCallback', () {
      test('should return a valid callback function', () {
        final callback = VooErrorTrackingService.instance.createErrorCaptureCallback();

        expect(callback, isA<VooErrorCaptureCallback>());
      });

      test('should invoke callback without throwing', () {
        final callback = VooErrorTrackingService.instance.createErrorCaptureCallback();

        expect(
          () => callback(
            message: 'Test error',
            errorType: 'TestException',
            stackTrace: 'at line 1',
          ),
          returnsNormally,
        );
      });
    });

    group('reset', () {
      test('should reset enabled state', () {
        VooErrorTrackingService.instance.enable();
        expect(VooErrorTrackingService.instance.isEnabled, isTrue);

        VooErrorTrackingService.instance.reset();
        expect(VooErrorTrackingService.instance.isEnabled, isFalse);
      });
    });
  });
}
