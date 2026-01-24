import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/data/services/fps_monitor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FpsMonitorService', () {
    setUp(() {
      FpsMonitorService.reset();
    });

    tearDown(() {
      FpsMonitorService.reset();
    });

    group('singleton', () {
      test('should return same instance', () {
        final instance1 = FpsMonitorService.instance;
        final instance2 = FpsMonitorService.instance;

        expect(identical(instance1, instance2), isTrue);
      });

      test('should return new instance after reset', () {
        final instance1 = FpsMonitorService.instance;
        FpsMonitorService.reset();
        final instance2 = FpsMonitorService.instance;

        expect(identical(instance1, instance2), isFalse);
      });
    });

    group('monitoring lifecycle', () {
      test('should not be monitoring initially', () {
        expect(FpsMonitorService.isMonitoring, isFalse);
      });

      test('should start monitoring', () {
        FpsMonitorService.startMonitoring();

        expect(FpsMonitorService.isMonitoring, isTrue);
      });

      test('should stop monitoring', () {
        FpsMonitorService.startMonitoring();
        FpsMonitorService.stopMonitoring();

        expect(FpsMonitorService.isMonitoring, isFalse);
      });

      test('should not start twice', () {
        FpsMonitorService.startMonitoring();
        FpsMonitorService.startMonitoring();

        expect(FpsMonitorService.isMonitoring, isTrue);
      });

      test('should reset counters on start', () {
        FpsMonitorService.startMonitoring();
        FpsMonitorService.stopMonitoring();

        expect(FpsMonitorService.droppedFrameCount, equals(0));
        expect(FpsMonitorService.totalFrameCount, equals(0));

        FpsMonitorService.startMonitoring();

        expect(FpsMonitorService.droppedFrameCount, equals(0));
        expect(FpsMonitorService.totalFrameCount, equals(0));
      });
    });

    group('currentFps', () {
      test('should return 60 when no samples', () {
        expect(FpsMonitorService.currentFps, equals(60.0));
      });
    });

    group('isJanking', () {
      test('should return false when no samples', () {
        expect(FpsMonitorService.isJanking, isFalse);
      });

      test('should return false with less than 3 samples', () {
        FpsMonitorService.startMonitoring();
        expect(FpsMonitorService.isJanking, isFalse);
      });
    });

    group('jankPercentage', () {
      test('should return 0 when no frames', () {
        expect(FpsMonitorService.jankPercentage, equals(0.0));
      });
    });

    group('getStats', () {
      test('should return default stats when no samples', () {
        final stats = FpsMonitorService.getStats();

        expect(stats.averageFps, equals(60.0));
        expect(stats.minFps, equals(60.0));
        expect(stats.maxFps, equals(60.0));
        expect(stats.jankyFrameCount, equals(0));
        expect(stats.totalFrameCount, equals(0));
        expect(stats.jankyPercentage, equals(0.0));
      });
    });

    group('getRecentSamples', () {
      test('should return empty list when no samples', () {
        final samples = FpsMonitorService.getRecentSamples();

        expect(samples, isEmpty);
      });

      test('should return empty list with count 0', () {
        final samples = FpsMonitorService.getRecentSamples(0);

        expect(samples, isEmpty);
      });
    });

    group('fpsStream', () {
      test('should be a broadcast stream', () {
        final stream = FpsMonitorService.fpsStream;

        expect(stream.isBroadcast, isTrue);
      });
    });

    group('dispose', () {
      test('should stop monitoring on dispose', () async {
        FpsMonitorService.startMonitoring();
        await FpsMonitorService.dispose();

        expect(FpsMonitorService.isMonitoring, isFalse);
      });
    });
  });

  group('FpsSample', () {
    test('should create with required fields', () {
      final sample = FpsSample(
        fps: 60.0,
        isJanky: false,
        frameDurationMs: 16.67,
        timestamp: DateTime.now(),
      );

      expect(sample.fps, equals(60.0));
      expect(sample.isJanky, isFalse);
      expect(sample.frameDurationMs, equals(16.67));
    });

    test('should serialize to JSON', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
      final sample = FpsSample(
        fps: 59.5,
        isJanky: true,
        frameDurationMs: 35.0,
        timestamp: timestamp,
      );

      final json = sample.toJson();

      expect(json['fps'], equals(59.5));
      expect(json['isJanky'], isTrue);
      expect(json['frameDurationMs'], equals(35.0));
      expect(json['timestamp'], equals(timestamp.toIso8601String()));
    });
  });

  group('FpsStats', () {
    test('should create with required fields', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 10));
      final endTime = DateTime.now();

      final stats = FpsStats(
        averageFps: 58.5,
        minFps: 45.0,
        maxFps: 60.0,
        jankyFrameCount: 5,
        totalFrameCount: 600,
        jankyPercentage: 0.83,
        startTime: startTime,
        endTime: endTime,
      );

      expect(stats.averageFps, equals(58.5));
      expect(stats.minFps, equals(45.0));
      expect(stats.maxFps, equals(60.0));
      expect(stats.jankyFrameCount, equals(5));
      expect(stats.totalFrameCount, equals(600));
      expect(stats.jankyPercentage, equals(0.83));
    });

    test('should serialize to JSON', () {
      final startTime = DateTime(2024, 1, 1, 12, 0, 0);
      final endTime = DateTime(2024, 1, 1, 12, 0, 10);

      final stats = FpsStats(
        averageFps: 58.5,
        minFps: 45.0,
        maxFps: 60.0,
        jankyFrameCount: 5,
        totalFrameCount: 600,
        jankyPercentage: 0.83,
        startTime: startTime,
        endTime: endTime,
      );

      final json = stats.toJson();

      expect(json['averageFps'], equals(58.5));
      expect(json['minFps'], equals(45.0));
      expect(json['maxFps'], equals(60.0));
      expect(json['jankyFrameCount'], equals(5));
      expect(json['totalFrameCount'], equals(600));
      expect(json['jankyPercentage'], equals(0.83));
      expect(json['startTime'], equals(startTime.toIso8601String()));
      expect(json['endTime'], equals(endTime.toIso8601String()));
    });

    test('should have readable toString', () {
      final stats = FpsStats(
        averageFps: 58.5,
        minFps: 45.0,
        maxFps: 60.0,
        jankyFrameCount: 5,
        totalFrameCount: 600,
        jankyPercentage: 0.83,
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );

      final str = stats.toString();

      expect(str, contains('58.5'));
      expect(str, contains('0.8'));
      expect(str, contains('5/600'));
    });
  });
}
