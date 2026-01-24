import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('Meter', () {
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

    group('createCounter', () {
      test('should create a counter', () {
        final counter = meter.createCounter('test.counter');

        expect(counter, isNotNull);
        expect(counter.name, equals('test.counter'));
      });

      test('should create counter with description and unit', () {
        final counter = meter.createCounter(
          'test.counter',
          description: 'A test counter',
          unit: '{requests}',
        );

        expect(counter.description, equals('A test counter'));
        expect(counter.unit, equals('{requests}'));
      });

      test('should return same counter for same name', () {
        final counter1 = meter.createCounter('same.counter');
        final counter2 = meter.createCounter('same.counter');

        expect(identical(counter1, counter2), isTrue);
      });
    });

    group('createUpDownCounter', () {
      test('should create an up-down counter', () {
        final counter = meter.createUpDownCounter('test.updown');

        expect(counter, isNotNull);
        expect(counter.name, equals('test.updown'));
      });

      test('should create up-down counter with description and unit', () {
        final counter = meter.createUpDownCounter(
          'test.updown',
          description: 'An up-down counter',
          unit: '{connections}',
        );

        expect(counter.description, equals('An up-down counter'));
        expect(counter.unit, equals('{connections}'));
      });
    });

    group('createHistogram', () {
      test('should create a histogram', () {
        final histogram = meter.createHistogram('test.histogram');

        expect(histogram, isNotNull);
        expect(histogram.name, equals('test.histogram'));
      });

      test('should create histogram with explicit bounds', () {
        final histogram = meter.createHistogram(
          'test.histogram',
          explicitBounds: [10, 50, 100, 250, 500, 1000],
        );

        expect(histogram.explicitBounds, isNotNull);
        expect(histogram.explicitBounds!.length, equals(6));
      });

      test('should create histogram with description and unit', () {
        final histogram = meter.createHistogram(
          'test.histogram',
          description: 'Request duration',
          unit: 'ms',
        );

        expect(histogram.description, equals('Request duration'));
        expect(histogram.unit, equals('ms'));
      });
    });

    group('createGauge', () {
      test('should create a gauge', () {
        final gauge = meter.createGauge('test.gauge');

        expect(gauge, isNotNull);
        expect(gauge.name, equals('test.gauge'));
      });

      test('should create gauge with description and unit', () {
        final gauge = meter.createGauge(
          'test.gauge',
          description: 'Memory usage',
          unit: 'By',
        );

        expect(gauge.description, equals('Memory usage'));
        expect(gauge.unit, equals('By'));
      });
    });
  });
}
