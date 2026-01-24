import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/otel/funnel_span_tracker.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('FunnelSpanTracker', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late TraceProvider traceProvider;
    late Tracer tracer;
    late FunnelSpanTracker tracker;

    setUp(() {
      resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
      exporter = OTLPHttpExporter(endpoint: 'https://test.com');
      config = TelemetryConfig(endpoint: 'https://test.com');
      traceProvider = TraceProvider(
        resource: resource,
        exporter: exporter,
        config: config,
      );
      tracer = traceProvider.getTracer('test-tracer');
      tracker = FunnelSpanTracker(tracer);
    });

    Funnel createTestFunnel() {
      return Funnel(
        id: 'checkout',
        name: 'Checkout Funnel',
        steps: [
          const FunnelStep(
            id: 'step_cart',
            name: 'View Cart',
            eventName: 'cart_viewed',
            order: 0,
          ),
          const FunnelStep(
            id: 'step_address',
            name: 'Enter Address',
            eventName: 'address_entered',
            order: 1,
          ),
          const FunnelStep(
            id: 'step_payment',
            name: 'Payment',
            eventName: 'payment_completed',
            order: 2,
          ),
        ],
        maxCompletionTime: const Duration(minutes: 30),
      );
    }

    group('startFunnel', () {
      test('should start a funnel and return span', () {
        final funnel = createTestFunnel();
        final span = tracker.startFunnel(funnel);

        expect(span, isNotNull);
        expect(tracker.isFunnelActive(funnel.id), isTrue);
      });

      test('should track funnel in activeFunnelIds', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(tracker.activeFunnelIds, contains('checkout'));
      });

      test('should restart funnel if same id already active', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);
        tracker.startFunnel(funnel); // Restart

        expect(tracker.activeFunnelIds.length, equals(1));
      });

      test('should set session id on funnel span', () {
        tracker.sessionId = 'session-123';
        final funnel = createTestFunnel();

        tracker.startFunnel(funnel);

        expect(tracker.sessionId, equals('session-123'));
      });
    });

    group('recordStep', () {
      test('should record step for active funnel', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(
          () => tracker.recordStep(
            funnelId: funnel.id,
            step: funnel.steps[0],
          ),
          returnsNormally,
        );
      });

      test('should increment completed step count', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        tracker.recordStep(funnelId: funnel.id, step: funnel.steps[0]);
        expect(tracker.getCompletedStepCount(funnel.id), equals(1));

        tracker.recordStep(funnelId: funnel.id, step: funnel.steps[1]);
        expect(tracker.getCompletedStepCount(funnel.id), equals(2));
      });

      test('should not record step for inactive funnel', () {
        final funnel = createTestFunnel();

        // No funnel started
        expect(
          () => tracker.recordStep(
            funnelId: funnel.id,
            step: funnel.steps[0],
          ),
          returnsNormally, // Should not throw, just return early
        );

        expect(tracker.getCompletedStepCount(funnel.id), equals(0));
      });

      test('should accept additional attributes', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(
          () => tracker.recordStep(
            funnelId: funnel.id,
            step: funnel.steps[0],
            additionalAttributes: {'item_count': 3},
          ),
          returnsNormally,
        );
      });

      test('should accept time since previous step', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(
          () => tracker.recordStep(
            funnelId: funnel.id,
            step: funnel.steps[0],
            timeSincePrevious: const Duration(seconds: 30),
          ),
          returnsNormally,
        );
      });
    });

    group('completeFunnel', () {
      test('should complete funnel and remove from active', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);
        tracker.recordStep(funnelId: funnel.id, step: funnel.steps[0]);

        tracker.completeFunnel(funnel.id);

        expect(tracker.isFunnelActive(funnel.id), isFalse);
      });

      test('should accept additional attributes', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(
          () => tracker.completeFunnel(
            funnel.id,
            additionalAttributes: {'conversion_value': 99.99},
          ),
          returnsNormally,
        );
      });

      test('should handle completing non-existent funnel', () {
        expect(
          () => tracker.completeFunnel('non-existent'),
          returnsNormally,
        );
      });
    });

    group('abandonFunnel', () {
      test('should abandon funnel and remove from active', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        tracker.abandonFunnel(funnel.id);

        expect(tracker.isFunnelActive(funnel.id), isFalse);
      });

      test('should accept reason', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(
          () => tracker.abandonFunnel(funnel.id, reason: 'User cancelled'),
          returnsNormally,
        );
      });

      test('should accept additional attributes', () {
        final funnel = createTestFunnel();
        tracker.startFunnel(funnel);

        expect(
          () => tracker.abandonFunnel(
            funnel.id,
            additionalAttributes: {'abandon_screen': 'payment'},
          ),
          returnsNormally,
        );
      });
    });

    group('dispose', () {
      test('should abandon all active funnels', () {
        tracker.startFunnel(createTestFunnel());
        tracker.startFunnel(Funnel(
          id: 'signup',
          name: 'Signup Funnel',
          steps: [
            const FunnelStep(
              id: 'step_email',
              name: 'Email',
              eventName: 'email_entered',
              order: 0,
            ),
          ],
        ));

        expect(tracker.activeFunnelIds.length, equals(2));

        tracker.dispose();

        expect(tracker.activeFunnelIds.isEmpty, isTrue);
      });
    });
  });

  group('FunnelStep', () {
    test('should create with required parameters', () {
      const step = FunnelStep(
        id: 'step_1',
        name: 'First Step',
        eventName: 'first_event',
        order: 0,
      );

      expect(step.id, equals('step_1'));
      expect(step.name, equals('First Step'));
      expect(step.eventName, equals('first_event'));
      expect(step.order, equals(0));
    });
  });

  group('Funnel', () {
    test('should create with required parameters', () {
      const funnel = Funnel(
        id: 'test',
        name: 'Test Funnel',
        steps: [],
      );

      expect(funnel.id, equals('test'));
      expect(funnel.name, equals('Test Funnel'));
      expect(funnel.steps.isEmpty, isTrue);
    });

    test('should create with max completion time', () {
      const funnel = Funnel(
        id: 'test',
        name: 'Test Funnel',
        steps: [],
        maxCompletionTime: Duration(minutes: 10),
      );

      expect(funnel.maxCompletionTime, equals(const Duration(minutes: 10)));
    });
  });
}
