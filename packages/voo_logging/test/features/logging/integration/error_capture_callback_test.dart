import 'package:flutter_test/flutter_test.dart';
import 'package:voo_logging/voo_logging.dart';

void main() {
  group('ErrorCaptureCallback Integration Tests', () {
    late LoggerRepositoryImpl repository;
    late List<Map<String, String?>> capturedErrors;

    setUp(() async {
      capturedErrors = [];
      repository = LoggerRepositoryImpl();

      // Set up the error capture callback
      repository.onErrorCaptured = ({required String message, String? errorType, String? stackTrace}) {
        capturedErrors.add({'message': message, 'errorType': errorType, 'stackTrace': stackTrace});
      };

      await repository.initialize(appName: 'TestApp', appVersion: '1.0.0', config: const LoggingConfig(enablePrettyLogs: false));
    });

    tearDown(() {
      repository.close();
    });

    test('callback is invoked for error level logs', () async {
      await repository.error('Test error message');

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'Test error message');
    });

    test('callback is invoked for fatal level logs', () async {
      await repository.fatal('Test fatal message');

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'Test fatal message');
    });

    test('callback is NOT invoked for info level logs', () async {
      await repository.info('Test info message');

      expect(capturedErrors.isEmpty, isTrue);
    });

    test('callback is NOT invoked for warning level logs', () async {
      await repository.warning('Test warning message');

      expect(capturedErrors.isEmpty, isTrue);
    });

    test('callback is NOT invoked for debug level logs', () async {
      await repository.debug('Test debug message');

      expect(capturedErrors.isEmpty, isTrue);
    });

    test('callback is NOT invoked for verbose level logs', () async {
      await repository.verbose('Test verbose message');

      expect(capturedErrors.isEmpty, isTrue);
    });

    test('callback receives error type from error object', () async {
      const testError = FormatException('Invalid format');
      await repository.error('Test error with exception', error: testError);

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'Test error with exception');
      expect(capturedErrors.first['errorType'], 'FormatException');
    });

    test('callback receives stack trace when provided', () async {
      final testStackTrace = StackTrace.current;
      await repository.error('Test error with stack', stackTrace: testStackTrace);

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'Test error with stack');
      expect(capturedErrors.first['stackTrace'], isNotNull);
      expect(capturedErrors.first['stackTrace'], contains('error_capture_callback_test.dart'));
    });

    test('callback receives all error information', () async {
      final testError = ArgumentError('Invalid argument');
      final testStackTrace = StackTrace.current;

      await repository.error('Complete error test', error: testError, stackTrace: testStackTrace);

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'Complete error test');
      expect(capturedErrors.first['errorType'], 'ArgumentError');
      expect(capturedErrors.first['stackTrace'], isNotNull);
    });

    test('multiple errors are captured in order', () async {
      await repository.error('First error');
      await repository.fatal('Second error (fatal)');
      await repository.error('Third error');

      expect(capturedErrors.length, 3);
      expect(capturedErrors[0]['message'], 'First error');
      expect(capturedErrors[1]['message'], 'Second error (fatal)');
      expect(capturedErrors[2]['message'], 'Third error');
    });

    test('callback with null values handles gracefully', () async {
      await repository.error('Error without extras');

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'Error without extras');
      expect(capturedErrors.first['errorType'], isNull);
      expect(capturedErrors.first['stackTrace'], isNull);
    });

    test('callback is not called when set to null', () async {
      repository.onErrorCaptured = null;

      await repository.error('Error should not be captured');

      expect(capturedErrors.isEmpty, isTrue);
    });

    test('callback exception does not break logging', () async {
      repository.onErrorCaptured = ({required String message, String? errorType, String? stackTrace}) {
        throw Exception('Callback failure');
      };

      // Should not throw
      await repository.error('Error with failing callback');

      // Logging should continue to work
      expect(true, isTrue);
    });

    test('callback can be changed dynamically', () async {
      // Log first error with original callback
      await repository.error('First error');

      // Change callback
      final secondCallbackErrors = <String>[];
      repository.onErrorCaptured = ({required String message, String? errorType, String? stackTrace}) {
        secondCallbackErrors.add(message);
      };

      // Log second error with new callback
      await repository.error('Second error');

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'First error');
      expect(secondCallbackErrors.length, 1);
      expect(secondCallbackErrors.first, 'Second error');
    });
  });

  group('ErrorCaptureCallback with VooLogger', () {
    late List<Map<String, String?>> capturedErrors;

    setUp(() async {
      capturedErrors = [];

      await VooLogger.initialize(appName: 'TestApp', config: const LoggingConfig(enablePrettyLogs: false));

      // Access repository and set callback
      final repo = VooLogger.instance.repository as LoggerRepositoryImpl;
      repo.onErrorCaptured = ({required String message, String? errorType, String? stackTrace}) {
        capturedErrors.add({'message': message, 'errorType': errorType, 'stackTrace': stackTrace});
      };
    });

    test('VooLogger.error triggers callback', () async {
      await VooLogger.error('VooLogger error test');

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'VooLogger error test');
    });

    test('VooLogger.fatal triggers callback', () async {
      await VooLogger.fatal('VooLogger fatal test');

      expect(capturedErrors.length, 1);
      expect(capturedErrors.first['message'], 'VooLogger fatal test');
    });

    test('VooLogger.info does not trigger callback', () async {
      await VooLogger.info('VooLogger info test');

      expect(capturedErrors.isEmpty, isTrue);
    });

    test('VooLogger.warning does not trigger callback', () async {
      await VooLogger.warning('VooLogger warning test');

      expect(capturedErrors.isEmpty, isTrue);
    });
  });

  group('ErrorCaptureCallback TypeDef', () {
    test('typedef matches expected signature', () {
      // Create a function that matches the typedef
      void testCallback({required String message, String? errorType, String? stackTrace}) {
        // No-op
      }

      // This should compile without error
      final ErrorCaptureCallback callback = testCallback;

      expect(callback, isNotNull);
    });

    test('typedef can be used as a type annotation', () {
      ErrorCaptureCallback? nullableCallback;

      expect(nullableCallback, isNull);

      nullableCallback = ({required String message, String? errorType, String? stackTrace}) {
        // Assigned callback
      };

      expect(nullableCallback, isNotNull);
    });
  });
}
