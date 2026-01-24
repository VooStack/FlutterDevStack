import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/otel/metrics/otel_memory_metric.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('OtelMemoryMetric', () {
    late MeterProvider meterProvider;
    late Meter meter;
    late OtelMemoryMetric memoryMetric;

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
      memoryMetric = OtelMemoryMetric(meter);
    });

    group('initialization', () {
      test('should not be initialized before initialize() called', () {
        final metric = OtelMemoryMetric(meter);

        // Recording before initialization should not throw
        metric.recordSnapshot(
          heapUsageBytes: 100 * 1024 * 1024,
          pressureLevel: 'none',
        );
      });

      test('should initialize without error', () {
        expect(() => memoryMetric.initialize(), returnsNormally);
      });

      test('should not initialize twice', () {
        memoryMetric.initialize();

        expect(() => memoryMetric.initialize(), returnsNormally);
      });
    });

    group('recordSnapshot', () {
      test('should not throw when not initialized', () {
        expect(
          () => memoryMetric.recordSnapshot(
            heapUsageBytes: 100 * 1024 * 1024,
            pressureLevel: 'none',
          ),
          returnsNormally,
        );
      });

      test('should record snapshot after initialization', () {
        memoryMetric.initialize();

        expect(
          () => memoryMetric.recordSnapshot(
            heapUsageBytes: 100 * 1024 * 1024,
            pressureLevel: 'none',
          ),
          returnsNormally,
        );
      });

      test('should record with optional fields', () {
        memoryMetric.initialize();

        expect(
          () => memoryMetric.recordSnapshot(
            heapUsageBytes: 100 * 1024 * 1024,
            externalUsageBytes: 10 * 1024 * 1024,
            heapCapacityBytes: 200 * 1024 * 1024,
            pressureLevel: 'moderate',
          ),
          returnsNormally,
        );
      });

      test('should handle critical pressure level', () {
        memoryMetric.initialize();

        expect(
          () => memoryMetric.recordSnapshot(
            heapUsageBytes: 180 * 1024 * 1024,
            heapCapacityBytes: 200 * 1024 * 1024,
            pressureLevel: 'critical',
          ),
          returnsNormally,
        );
      });

      test('should handle null heapUsageBytes', () {
        memoryMetric.initialize();

        expect(
          () => memoryMetric.recordSnapshot(
            heapUsageBytes: null,
            pressureLevel: 'none',
          ),
          returnsNormally,
        );
      });
    });

    group('recordUsagePercentage', () {
      test('should not throw when not initialized', () {
        expect(
          () => memoryMetric.recordUsagePercentage(usagePercent: 50.0),
          returnsNormally,
        );
      });

      test('should record usage percentage after initialization', () {
        memoryMetric.initialize();

        expect(
          () => memoryMetric.recordUsagePercentage(usagePercent: 50.0),
          returnsNormally,
        );
      });

      test('should include pressure level', () {
        memoryMetric.initialize();

        expect(
          () => memoryMetric.recordUsagePercentage(
            usagePercent: 85.0,
            pressureLevel: 'moderate',
          ),
          returnsNormally,
        );
      });
    });
  });
}
