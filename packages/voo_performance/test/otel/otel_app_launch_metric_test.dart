import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/otel/metrics/otel_app_launch_metric.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('OtelAppLaunchMetric', () {
    late MeterProvider meterProvider;
    late TraceProvider traceProvider;
    late Meter meter;
    late Tracer tracer;
    late OtelAppLaunchMetric appLaunchMetric;

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
      traceProvider = TraceProvider(
        resource: resource,
        exporter: exporter,
        config: config,
      );
      meter = meterProvider.getMeter('test-meter');
      tracer = traceProvider.getTracer('test-tracer');
      appLaunchMetric = OtelAppLaunchMetric(tracer, meter);
    });

    group('initialization', () {
      test('should not be initialized before initialize() called', () {
        final metric = OtelAppLaunchMetric(tracer, meter);

        // Recording before initialization should not throw
        metric.recordLaunch(
          launchType: LaunchType.cold,
          timeToFirstFrameMs: 500,
          isSuccessful: true,
        );
      });

      test('should initialize without error', () {
        expect(() => appLaunchMetric.initialize(), returnsNormally);
      });

      test('should not initialize twice', () {
        appLaunchMetric.initialize();

        expect(() => appLaunchMetric.initialize(), returnsNormally);
      });
    });

    group('recordLaunch', () {
      test('should not throw when not initialized', () {
        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.cold,
            timeToFirstFrameMs: 500,
            isSuccessful: true,
          ),
          returnsNormally,
        );
      });

      test('should record cold launch after initialization', () {
        appLaunchMetric.initialize();

        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.cold,
            timeToFirstFrameMs: 500,
            isSuccessful: true,
          ),
          returnsNormally,
        );
      });

      test('should record warm launch', () {
        appLaunchMetric.initialize();

        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.warm,
            timeToFirstFrameMs: 200,
            isSuccessful: true,
          ),
          returnsNormally,
        );
      });

      test('should record hot launch', () {
        appLaunchMetric.initialize();

        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.hot,
            timeToFirstFrameMs: 50,
            isSuccessful: true,
          ),
          returnsNormally,
        );
      });

      test('should record with time to interactive', () {
        appLaunchMetric.initialize();

        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.cold,
            timeToFirstFrameMs: 500,
            timeToInteractiveMs: 1000,
            isSuccessful: true,
          ),
          returnsNormally,
        );
      });

      test('should record failed launch', () {
        appLaunchMetric.initialize();

        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.cold,
            timeToFirstFrameMs: null,
            isSuccessful: false,
          ),
          returnsNormally,
        );
      });

      test('should record slow launch', () {
        appLaunchMetric.initialize();

        expect(
          () => appLaunchMetric.recordLaunch(
            launchType: LaunchType.cold,
            timeToFirstFrameMs: 5000,
            timeToInteractiveMs: 8000,
            isSuccessful: true,
            isSlow: true,
          ),
          returnsNormally,
        );
      });
    });

    group('startLaunchSpan', () {
      test('should create span for cold launch', () {
        appLaunchMetric.initialize();

        final span = appLaunchMetric.startLaunchSpan(LaunchType.cold);

        expect(span, isNotNull);
        expect(span.name, equals('app.launch'));
        expect(span.isRecording, isTrue);

        span.end();
      });

      test('should create span for warm launch', () {
        appLaunchMetric.initialize();

        final span = appLaunchMetric.startLaunchSpan(LaunchType.warm);

        expect(span, isNotNull);
        expect(span.isRecording, isTrue);

        span.end();
      });
    });

    group('endLaunchSpan', () {
      test('should end span successfully', () {
        appLaunchMetric.initialize();

        final span = appLaunchMetric.startLaunchSpan(LaunchType.cold);
        appLaunchMetric.endLaunchSpan(span, isSuccessful: true);

        expect(span.isRecording, isFalse);
      });

      test('should end span with failure', () {
        appLaunchMetric.initialize();

        final span = appLaunchMetric.startLaunchSpan(LaunchType.cold);
        appLaunchMetric.endLaunchSpan(span, isSuccessful: false);

        expect(span.isRecording, isFalse);
        expect(span.status.code, equals(StatusCode.error));
      });

      test('should include timing metrics in span', () {
        appLaunchMetric.initialize();

        final span = appLaunchMetric.startLaunchSpan(LaunchType.cold);
        appLaunchMetric.endLaunchSpan(
          span,
          isSuccessful: true,
          timeToFirstFrameMs: 500,
          timeToInteractiveMs: 1000,
        );

        expect(span.isRecording, isFalse);
      });
    });
  });

  group('LaunchType enum', () {
    test('should have expected values', () {
      expect(LaunchType.values.length, equals(3));
      expect(LaunchType.cold.name, equals('cold'));
      expect(LaunchType.warm.name, equals('warm'));
      expect(LaunchType.hot.name, equals('hot'));
    });
  });
}
