import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('MeterProvider', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late MeterProvider meterProvider;

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
    });

    group('initialization', () {
      test('should create with required parameters', () {
        expect(meterProvider, isNotNull);
      });

      test('should initialize without error', () async {
        await expectLater(meterProvider.initialize(), completes);
      });
    });

    group('getMeter', () {
      test('should create a new meter', () {
        final meter = meterProvider.getMeter('test-meter');

        expect(meter, isNotNull);
        expect(meter.name, equals('test-meter'));
      });

      test('should return same meter for same name', () {
        final meter1 = meterProvider.getMeter('test-meter');
        final meter2 = meterProvider.getMeter('test-meter');

        expect(identical(meter1, meter2), isTrue);
      });

      test('should return different meters for different names', () {
        final meter1 = meterProvider.getMeter('meter-1');
        final meter2 = meterProvider.getMeter('meter-2');

        expect(identical(meter1, meter2), isFalse);
      });
    });

    group('addMetric', () {
      test('should add counter metric without error', () {
        final metric = CounterMetric(name: 'test.counter', value: 10);

        expect(() => meterProvider.addMetric(metric), returnsNormally);
      });

      test('should add gauge metric without error', () {
        final metric = GaugeMetric(name: 'test.gauge', value: 42.5);

        expect(() => meterProvider.addMetric(metric), returnsNormally);
      });

      test('should add histogram metric without error', () {
        final metric =
            HistogramMetric(name: 'test.histogram', values: [10, 20, 30]);

        expect(() => meterProvider.addMetric(metric), returnsNormally);
      });
    });

    group('flush', () {
      test('should flush without error when no pending metrics', () async {
        await expectLater(meterProvider.flush(), completes);
      });

      test('should flush pending metrics', () async {
        final metric = CounterMetric(name: 'test.counter', value: 10);
        meterProvider.addMetric(metric);

        await expectLater(meterProvider.flush(), completes);
      });
    });

    group('shutdown', () {
      test('should shutdown without error', () async {
        await expectLater(meterProvider.shutdown(), completes);
      });
    });
  });
}
