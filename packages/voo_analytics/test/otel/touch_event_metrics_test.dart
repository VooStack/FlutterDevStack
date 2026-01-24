import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/otel/touch_event_metrics.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('TouchEventMetrics', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late MeterProvider meterProvider;
    late Meter meter;
    late TouchEventMetrics metrics;

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
      metrics = TouchEventMetrics(meter);
    });

    group('initialize', () {
      test('should initialize without error', () {
        expect(() => metrics.initialize(), returnsNormally);
      });

      test('should not double initialize', () {
        metrics.initialize();
        expect(() => metrics.initialize(), returnsNormally);
      });
    });

    group('recordTouch', () {
      test('should not record when not initialized', () {
        expect(
          () => metrics.recordTouch(
            screenName: 'HomeScreen',
            touchType: TouchType.tap,
            normalizedX: 0.5,
            normalizedY: 0.5,
          ),
          returnsNormally,
        );
      });

      test('should record tap touch event', () {
        metrics.initialize();

        expect(
          () => metrics.recordTouch(
            screenName: 'HomeScreen',
            touchType: TouchType.tap,
            normalizedX: 0.5,
            normalizedY: 0.5,
          ),
          returnsNormally,
        );
      });

      test('should record double tap touch event', () {
        metrics.initialize();

        expect(
          () => metrics.recordTouch(
            screenName: 'HomeScreen',
            touchType: TouchType.doubleTap,
            normalizedX: 0.3,
            normalizedY: 0.7,
          ),
          returnsNormally,
        );
      });

      test('should record long press touch event', () {
        metrics.initialize();

        expect(
          () => metrics.recordTouch(
            screenName: 'HomeScreen',
            touchType: TouchType.longPress,
            normalizedX: 0.8,
            normalizedY: 0.2,
          ),
          returnsNormally,
        );
      });

      test('should accept region attribute', () {
        metrics.initialize();

        expect(
          () => metrics.recordTouch(
            screenName: 'HomeScreen',
            touchType: TouchType.tap,
            normalizedX: 0.5,
            normalizedY: 0.5,
            region: 'center',
          ),
          returnsNormally,
        );
      });

      test('should accept widget type attribute', () {
        metrics.initialize();

        expect(
          () => metrics.recordTouch(
            screenName: 'HomeScreen',
            touchType: TouchType.tap,
            normalizedX: 0.5,
            normalizedY: 0.5,
            widgetType: 'ElevatedButton',
          ),
          returnsNormally,
        );
      });
    });

    group('recordGesture', () {
      test('should not record when not initialized', () {
        expect(
          () => metrics.recordGesture(
            screenName: 'HomeScreen',
            gestureType: TouchType.panEnd,
            durationMs: 500,
          ),
          returnsNormally,
        );
      });

      test('should record pan gesture', () {
        metrics.initialize();

        expect(
          () => metrics.recordGesture(
            screenName: 'HomeScreen',
            gestureType: TouchType.panEnd,
            durationMs: 500,
            normalizedX: 0.5,
            normalizedY: 0.5,
          ),
          returnsNormally,
        );
      });

      test('should record scale gesture', () {
        metrics.initialize();

        expect(
          () => metrics.recordGesture(
            screenName: 'HomeScreen',
            gestureType: TouchType.scaleEnd,
            durationMs: 300,
          ),
          returnsNormally,
        );
      });

      test('should accept additional attributes', () {
        metrics.initialize();

        expect(
          () => metrics.recordGesture(
            screenName: 'HomeScreen',
            gestureType: TouchType.longPress,
            durationMs: 1000,
            additionalAttributes: {'element_id': 'card_1'},
          ),
          returnsNormally,
        );
      });
    });

    group('calculateRegion', () {
      test('should return top-left for (0.1, 0.1)', () {
        expect(TouchEventMetrics.calculateRegion(0.1, 0.1), equals('top-left'));
      });

      test('should return top-center for (0.5, 0.1)', () {
        expect(TouchEventMetrics.calculateRegion(0.5, 0.1), equals('top-center'));
      });

      test('should return top-right for (0.9, 0.1)', () {
        expect(TouchEventMetrics.calculateRegion(0.9, 0.1), equals('top-right'));
      });

      test('should return middle-left for (0.1, 0.5)', () {
        expect(TouchEventMetrics.calculateRegion(0.1, 0.5), equals('middle-left'));
      });

      test('should return center for (0.5, 0.5)', () {
        expect(TouchEventMetrics.calculateRegion(0.5, 0.5), equals('center'));
      });

      test('should return middle-right for (0.9, 0.5)', () {
        expect(TouchEventMetrics.calculateRegion(0.9, 0.5), equals('middle-right'));
      });

      test('should return bottom-left for (0.1, 0.9)', () {
        expect(TouchEventMetrics.calculateRegion(0.1, 0.9), equals('bottom-left'));
      });

      test('should return bottom-center for (0.5, 0.9)', () {
        expect(
          TouchEventMetrics.calculateRegion(0.5, 0.9),
          equals('bottom-center'),
        );
      });

      test('should return bottom-right for (0.9, 0.9)', () {
        expect(
          TouchEventMetrics.calculateRegion(0.9, 0.9),
          equals('bottom-right'),
        );
      });

      test('should handle boundary values', () {
        expect(TouchEventMetrics.calculateRegion(0.0, 0.0), equals('top-left'));
        expect(TouchEventMetrics.calculateRegion(1.0, 1.0), equals('bottom-right'));
        expect(TouchEventMetrics.calculateRegion(0.33, 0.33), equals('center'));
      });
    });
  });

  group('TouchType', () {
    test('should have all expected values', () {
      expect(TouchType.values, contains(TouchType.tap));
      expect(TouchType.values, contains(TouchType.doubleTap));
      expect(TouchType.values, contains(TouchType.longPress));
      expect(TouchType.values, contains(TouchType.panStart));
      expect(TouchType.values, contains(TouchType.panUpdate));
      expect(TouchType.values, contains(TouchType.panEnd));
      expect(TouchType.values, contains(TouchType.scaleStart));
      expect(TouchType.values, contains(TouchType.scaleUpdate));
      expect(TouchType.values, contains(TouchType.scaleEnd));
    });
  });
}
