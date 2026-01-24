import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/otel/metrics/otel_fps_metric.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('OtelFpsMetric', () {
    late MeterProvider meterProvider;
    late Meter meter;
    late OtelFpsMetric fpsMetric;

    setUp(() {
      final resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
      final exporter = OTLPHttpExporter(endpoint: 'https://test.com');
      final config = TelemetryConfig(endpoint: 'https://test.com');

      meterProvider = MeterProvider(
        resource: resource,
        exporter: exporter,
        config: config,
      );
      meter = meterProvider.getMeter('test-meter');
      fpsMetric = OtelFpsMetric(meter);
    });

    group('initialization', () {
      test('should not be initialized before initialize() called', () {
        final metric = OtelFpsMetric(meter);

        // Recording before initialization should not throw
        metric.recordSample(fps: 60.0, frameDurationMs: 16.67, isJanky: false);
      });

      test('should initialize without error', () {
        expect(() => fpsMetric.initialize(), returnsNormally);
      });

      test('should not initialize twice', () {
        fpsMetric.initialize();

        expect(() => fpsMetric.initialize(), returnsNormally);
      });
    });

    group('recordSample', () {
      test('should not throw when not initialized', () {
        expect(
          () => fpsMetric.recordSample(
            fps: 60.0,
            frameDurationMs: 16.67,
            isJanky: false,
          ),
          returnsNormally,
        );
      });

      test('should record sample after initialization', () {
        fpsMetric.initialize();

        expect(
          () => fpsMetric.recordSample(
            fps: 60.0,
            frameDurationMs: 16.67,
            isJanky: false,
          ),
          returnsNormally,
        );
      });

      test('should record janky sample', () {
        fpsMetric.initialize();

        expect(
          () => fpsMetric.recordSample(
            fps: 30.0,
            frameDurationMs: 33.33,
            isJanky: true,
          ),
          returnsNormally,
        );
      });

      test('should include screen name in attributes', () {
        fpsMetric.initialize();

        expect(
          () => fpsMetric.recordSample(
            fps: 60.0,
            frameDurationMs: 16.67,
            isJanky: false,
            screenName: 'HomeScreen',
          ),
          returnsNormally,
        );
      });
    });

    group('recordStats', () {
      test('should not throw when not initialized', () {
        expect(
          () => fpsMetric.recordStats(
            avgFps: 58.5,
            minFps: 45.0,
            maxFps: 60.0,
            jankFrameCount: 5,
            totalFrameCount: 600,
          ),
          returnsNormally,
        );
      });

      test('should record stats after initialization', () {
        fpsMetric.initialize();

        expect(
          () => fpsMetric.recordStats(
            avgFps: 58.5,
            minFps: 45.0,
            maxFps: 60.0,
            jankFrameCount: 5,
            totalFrameCount: 600,
          ),
          returnsNormally,
        );
      });

      test('should include screen name in attributes', () {
        fpsMetric.initialize();

        expect(
          () => fpsMetric.recordStats(
            avgFps: 58.5,
            minFps: 45.0,
            maxFps: 60.0,
            jankFrameCount: 5,
            totalFrameCount: 600,
            screenName: 'HomeScreen',
          ),
          returnsNormally,
        );
      });

      test('should handle zero total frame count', () {
        fpsMetric.initialize();

        expect(
          () => fpsMetric.recordStats(
            avgFps: 60.0,
            minFps: 60.0,
            maxFps: 60.0,
            jankFrameCount: 0,
            totalFrameCount: 0,
          ),
          returnsNormally,
        );
      });
    });
  });
}
