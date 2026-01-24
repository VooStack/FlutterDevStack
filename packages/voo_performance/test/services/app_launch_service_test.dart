import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/data/services/app_launch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLaunchService', () {
    setUp(() {
      AppLaunchService.reset();
    });

    tearDown(() {
      AppLaunchService.reset();
    });

    group('singleton', () {
      test('should return same instance', () {
        final instance1 = AppLaunchService.instance;
        final instance2 = AppLaunchService.instance;

        expect(identical(instance1, instance2), isTrue);
      });

      test('should return new instance after reset', () {
        final instance1 = AppLaunchService.instance;
        AppLaunchService.reset();
        final instance2 = AppLaunchService.instance;

        expect(identical(instance1, instance2), isFalse);
      });
    });

    group('initialization', () {
      test('should not be initialized initially', () {
        expect(AppLaunchService.isInitialized, isFalse);
      });

      test('should be initialized after initialize()', () async {
        await AppLaunchService.initialize();

        expect(AppLaunchService.isInitialized, isTrue);
      });

      test('should not initialize twice', () async {
        await AppLaunchService.initialize();
        await AppLaunchService.initialize();

        expect(AppLaunchService.isInitialized, isTrue);
      });
    });

    group('markLaunchStart', () {
      test('should set process start time', () {
        AppLaunchService.markLaunchStart();

        // markLaunchStart should be idempotent
        AppLaunchService.markLaunchStart();
      });
    });

    group('markWidgetBindingReady', () {
      test('should set widget binding time', () {
        AppLaunchService.markLaunchStart();
        AppLaunchService.markWidgetBindingReady();
      });
    });

    group('markInteractive', () {
      test('should mark app as interactive', () async {
        AppLaunchService.markLaunchStart();
        await AppLaunchService.initialize();

        // Wait for first frame callback
        await Future.delayed(const Duration(milliseconds: 100));

        AppLaunchService.markInteractive();
      });
    });

    group('launchHistory', () {
      test('should return empty list initially', () {
        expect(AppLaunchService.launchHistory, isEmpty);
      });

      test('should return unmodifiable list', () {
        expect(
          () => AppLaunchService.launchHistory.add(
            AppLaunchMetrics(
              launchType: LaunchType.cold,
              launchTimestamp: DateTime.now(),
            ),
          ),
          throwsUnsupportedError,
        );
      });
    });

    group('initialLaunch', () {
      test('should return null when no launches recorded', () {
        expect(AppLaunchService.initialLaunch, isNull);
      });
    });

    group('launchStream', () {
      test('should be a broadcast stream', () {
        expect(AppLaunchService.launchStream.isBroadcast, isTrue);
      });
    });

    group('recordLaunchError', () {
      test('should record launch error', () async {
        AppLaunchService.recordLaunchError('Test error');

        expect(AppLaunchService.launchHistory.length, equals(1));
        expect(AppLaunchService.launchHistory.first.isSuccessful, isFalse);
        expect(
            AppLaunchService.launchHistory.first.errorMessage, equals('Test error'));
      });
    });

    group('dispose', () {
      test('should reset state on dispose', () async {
        await AppLaunchService.initialize();
        await AppLaunchService.dispose();

        expect(AppLaunchService.isInitialized, isFalse);
      });
    });
  });

  group('AppLaunchMetrics', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();
      final metrics = AppLaunchMetrics(
        launchType: LaunchType.cold,
        launchTimestamp: timestamp,
      );

      expect(metrics.launchType, equals(LaunchType.cold));
      expect(metrics.launchTimestamp, equals(timestamp));
      expect(metrics.isSuccessful, isTrue);
      expect(metrics.errorMessage, isNull);
    });

    test('should create with all fields', () {
      final metrics = AppLaunchMetrics(
        launchType: LaunchType.cold,
        timeToFirstFrame: const Duration(milliseconds: 500),
        timeToInteractive: const Duration(milliseconds: 1000),
        nativeInitTime: const Duration(milliseconds: 100),
        engineInitTime: const Duration(milliseconds: 200),
        dartInitTime: const Duration(milliseconds: 50),
        widgetBindingInitTime: const Duration(milliseconds: 50),
        firstFrameRenderTime: const Duration(milliseconds: 100),
        launchTimestamp: DateTime.now(),
        isSuccessful: true,
      );

      expect(metrics.timeToFirstFrame, equals(const Duration(milliseconds: 500)));
      expect(metrics.timeToInteractive, equals(const Duration(milliseconds: 1000)));
      expect(metrics.totalLaunchTime, equals(const Duration(milliseconds: 1000)));
    });

    test('should calculate totalLaunchTime from timeToInteractive', () {
      final metrics = AppLaunchMetrics(
        launchType: LaunchType.cold,
        timeToInteractive: const Duration(milliseconds: 1000),
        launchTimestamp: DateTime.now(),
      );

      expect(metrics.totalLaunchTime, equals(const Duration(milliseconds: 1000)));
    });

    test('should calculate totalLaunchTime from timeToFirstFrame when no interactive', () {
      final metrics = AppLaunchMetrics(
        launchType: LaunchType.cold,
        timeToFirstFrame: const Duration(milliseconds: 500),
        launchTimestamp: DateTime.now(),
      );

      expect(metrics.totalLaunchTime, equals(const Duration(milliseconds: 500)));
    });

    test('should detect slow launch (>3 seconds)', () {
      final slowLaunch = AppLaunchMetrics(
        launchType: LaunchType.cold,
        timeToInteractive: const Duration(milliseconds: 3500),
        launchTimestamp: DateTime.now(),
      );

      final fastLaunch = AppLaunchMetrics(
        launchType: LaunchType.cold,
        timeToInteractive: const Duration(milliseconds: 2000),
        launchTimestamp: DateTime.now(),
      );

      expect(slowLaunch.isSlowLaunch, isTrue);
      expect(fastLaunch.isSlowLaunch, isFalse);
    });

    test('should serialize to JSON', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
      final metrics = AppLaunchMetrics(
        launchType: LaunchType.cold,
        timeToFirstFrame: const Duration(milliseconds: 500),
        timeToInteractive: const Duration(milliseconds: 1000),
        launchTimestamp: timestamp,
        isSuccessful: true,
      );

      final json = metrics.toJson();

      expect(json['launch_type'], equals('cold'));
      expect(json['time_to_first_frame_ms'], equals(500));
      expect(json['time_to_interactive_ms'], equals(1000));
      expect(json['launch_timestamp'], equals(timestamp.toIso8601String()));
      expect(json['is_successful'], isTrue);
      expect(json['is_slow_launch'], isFalse);
    });

    test('should include error message in JSON when failed', () {
      final metrics = AppLaunchMetrics(
        launchType: LaunchType.cold,
        launchTimestamp: DateTime.now(),
        isSuccessful: false,
        errorMessage: 'Launch failed',
      );

      final json = metrics.toJson();

      expect(json['is_successful'], isFalse);
      expect(json['error_message'], equals('Launch failed'));
    });
  });

  group('LaunchType', () {
    test('should have expected values', () {
      expect(LaunchType.values.length, equals(3));
      expect(LaunchType.cold.name, equals('cold'));
      expect(LaunchType.warm.name, equals('warm'));
      expect(LaunchType.hot.name, equals('hot'));
    });
  });
}
