import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  late TelemetryResource resource;
  late OTLPHttpExporter exporter;
  late TelemetryConfig config;
  late MeterProvider meterProvider;
  late Meter meter;

  setUp(() {
    resource = TelemetryResource(
      serviceName: 'test-service',
      serviceVersion: '1.0.0',
    );
    exporter = OTLPHttpExporter(endpoint: 'https://test.com');
    config = TelemetryConfig(endpoint: 'https://test.com');
    meterProvider = MeterProvider(
      resource: resource,
      exporter: exporter,
      config: config,
    );
    meter = meterProvider.getMeter('test-meter');
  });

  group('Counter', () {
    test('should add positive values', () {
      final counter = meter.createCounter('test.counter');

      expect(() => counter.add(5), returnsNormally);
      expect(() => counter.add(10), returnsNormally);
    });

    test('should reject negative values', () {
      final counter = meter.createCounter('test.counter');

      expect(() => counter.add(-1), throwsArgumentError);
    });

    test('should increment by 1', () {
      final counter = meter.createCounter('test.counter');

      expect(() => counter.increment(), returnsNormally);
    });

    test('should accept attributes', () {
      final counter = meter.createCounter('test.counter');

      expect(
        () => counter.add(5, attributes: {'method': 'GET', 'status': 200}),
        returnsNormally,
      );
    });
  });

  group('UpDownCounter', () {
    test('should add positive values', () {
      final counter = meter.createUpDownCounter('test.updown');

      expect(() => counter.add(5), returnsNormally);
    });

    test('should add negative values', () {
      final counter = meter.createUpDownCounter('test.updown');

      expect(() => counter.add(-3), returnsNormally);
    });

    test('should accept attributes', () {
      final counter = meter.createUpDownCounter('test.updown');

      expect(
        () => counter.add(1, attributes: {'connection': 'open'}),
        returnsNormally,
      );
    });
  });

  group('Histogram', () {
    test('should record values', () {
      final histogram = meter.createHistogram('test.histogram');

      expect(() => histogram.record(15.5), returnsNormally);
      expect(() => histogram.record(25.0), returnsNormally);
      expect(() => histogram.record(100.0), returnsNormally);
    });

    test('should accept attributes', () {
      final histogram = meter.createHistogram('test.histogram');

      expect(
        () => histogram.record(50.0, attributes: {'endpoint': '/api/users'}),
        returnsNormally,
      );
    });

    test('should handle edge values', () {
      final histogram = meter.createHistogram('test.histogram');

      expect(() => histogram.record(0.0), returnsNormally);
      expect(() => histogram.record(-10.0), returnsNormally);
      expect(() => histogram.record(double.maxFinite), returnsNormally);
    });
  });

  group('Gauge', () {
    test('should set value', () {
      final gauge = meter.createGauge('test.gauge');

      gauge.set(42.5);

      expect(gauge.value, equals(42.5));
    });

    test('should update value', () {
      final gauge = meter.createGauge('test.gauge');

      gauge.set(10.0);
      expect(gauge.value, equals(10.0));

      gauge.set(20.0);
      expect(gauge.value, equals(20.0));
    });

    test('should accept attributes', () {
      final gauge = meter.createGauge('test.gauge');

      expect(
        () => gauge.set(100.0, attributes: {'unit': 'MB'}),
        returnsNormally,
      );
    });

    test('should start at 0', () {
      final gauge = meter.createGauge('test.gauge');

      expect(gauge.value, equals(0.0));
    });
  });
}
