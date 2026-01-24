import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/data/models/funnel.dart';

void main() {
  group('VooFunnel', () {
    group('constructor', () {
      test('should create with required parameters', () {
        const funnel = VooFunnel(
          id: 'checkout',
          name: 'Checkout Funnel',
          steps: [],
        );

        expect(funnel.id, equals('checkout'));
        expect(funnel.name, equals('Checkout Funnel'));
        expect(funnel.steps.isEmpty, isTrue);
        expect(funnel.isActive, isTrue);
      });

      test('should create with optional parameters', () {
        const funnel = VooFunnel(
          id: 'checkout',
          name: 'Checkout Funnel',
          description: 'Track user checkout flow',
          steps: [],
          maxCompletionTime: Duration(minutes: 30),
          isActive: false,
        );

        expect(funnel.description, equals('Track user checkout flow'));
        expect(funnel.maxCompletionTime, equals(const Duration(minutes: 30)));
        expect(funnel.isActive, isFalse);
      });
    });

    group('simple factory', () {
      test('should create funnel from event names', () {
        final funnel = VooFunnel.simple(
          id: 'checkout',
          name: 'Checkout',
          eventNames: ['cart_viewed', 'checkout_started', 'payment_completed'],
        );

        expect(funnel.steps.length, equals(3));
        expect(funnel.steps[0].name, equals('cart_viewed'));
        expect(funnel.steps[0].eventName, equals('cart_viewed'));
        expect(funnel.steps[0].order, equals(0));
        expect(funnel.steps[1].order, equals(1));
        expect(funnel.steps[2].order, equals(2));
      });

      test('should create with max completion time', () {
        final funnel = VooFunnel.simple(
          id: 'signup',
          name: 'Signup',
          eventNames: ['email_entered', 'password_set'],
          maxCompletionTime: const Duration(minutes: 10),
        );

        expect(funnel.maxCompletionTime, equals(const Duration(minutes: 10)));
      });
    });

    group('toJson', () {
      test('should serialize to JSON', () {
        const funnel = VooFunnel(
          id: 'checkout',
          name: 'Checkout Funnel',
          description: 'Test funnel',
          steps: [
            VooFunnelStep(
              id: 'step_1',
              name: 'Step 1',
              eventName: 'event_1',
              order: 0,
            ),
          ],
          maxCompletionTime: Duration(minutes: 30),
          isActive: true,
        );

        final json = funnel.toJson();

        expect(json['id'], equals('checkout'));
        expect(json['name'], equals('Checkout Funnel'));
        expect(json['description'], equals('Test funnel'));
        expect(json['max_completion_time_ms'], equals(30 * 60 * 1000));
        expect(json['is_active'], isTrue);
        expect(json['steps'], isA<List>());
        expect((json['steps'] as List).length, equals(1));
      });
    });

    group('fromJson', () {
      test('should deserialize from JSON', () {
        final json = {
          'id': 'checkout',
          'name': 'Checkout Funnel',
          'description': 'Test funnel',
          'steps': [
            {
              'id': 'step_1',
              'name': 'Step 1',
              'event_name': 'event_1',
              'order': 0,
            },
          ],
          'max_completion_time_ms': 30 * 60 * 1000,
          'is_active': true,
        };

        final funnel = VooFunnel.fromJson(json);

        expect(funnel.id, equals('checkout'));
        expect(funnel.name, equals('Checkout Funnel'));
        expect(funnel.description, equals('Test funnel'));
        expect(funnel.maxCompletionTime, equals(const Duration(minutes: 30)));
        expect(funnel.isActive, isTrue);
        expect(funnel.steps.length, equals(1));
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'test',
          'name': 'Test',
          'steps': <Map<String, dynamic>>[],
        };

        final funnel = VooFunnel.fromJson(json);

        expect(funnel.description, isNull);
        expect(funnel.maxCompletionTime, isNull);
        expect(funnel.isActive, isTrue);
      });
    });
  });

  group('VooFunnelStep', () {
    group('constructor', () {
      test('should create with required parameters', () {
        const step = VooFunnelStep(
          id: 'step_1',
          name: 'First Step',
          eventName: 'first_event',
          order: 0,
        );

        expect(step.id, equals('step_1'));
        expect(step.name, equals('First Step'));
        expect(step.eventName, equals('first_event'));
        expect(step.order, equals(0));
        expect(step.isOptional, isFalse);
      });

      test('should create with optional parameters', () {
        const step = VooFunnelStep(
          id: 'step_1',
          name: 'First Step',
          eventName: 'first_event',
          order: 0,
          requiredParams: {'userId': 'required'},
          maxTimeSincePrevious: Duration(minutes: 5),
          isOptional: true,
        );

        expect(step.requiredParams, isNotNull);
        expect(step.maxTimeSincePrevious, equals(const Duration(minutes: 5)));
        expect(step.isOptional, isTrue);
      });
    });

    group('toJson', () {
      test('should serialize to JSON', () {
        const step = VooFunnelStep(
          id: 'step_1',
          name: 'First Step',
          eventName: 'first_event',
          order: 0,
          requiredParams: {'key': 'value'},
          maxTimeSincePrevious: Duration(minutes: 5),
          isOptional: true,
        );

        final json = step.toJson();

        expect(json['id'], equals('step_1'));
        expect(json['name'], equals('First Step'));
        expect(json['event_name'], equals('first_event'));
        expect(json['order'], equals(0));
        expect(json['required_params'], equals({'key': 'value'}));
        expect(json['max_time_since_previous_ms'], equals(5 * 60 * 1000));
        expect(json['is_optional'], isTrue);
      });
    });

    group('fromJson', () {
      test('should deserialize from JSON', () {
        final json = {
          'id': 'step_1',
          'name': 'First Step',
          'event_name': 'first_event',
          'order': 0,
          'required_params': {'key': 'value'},
          'max_time_since_previous_ms': 5 * 60 * 1000,
          'is_optional': true,
        };

        final step = VooFunnelStep.fromJson(json);

        expect(step.id, equals('step_1'));
        expect(step.name, equals('First Step'));
        expect(step.eventName, equals('first_event'));
        expect(step.order, equals(0));
        expect(step.maxTimeSincePrevious, equals(const Duration(minutes: 5)));
        expect(step.isOptional, isTrue);
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'step_1',
          'name': 'First Step',
          'event_name': 'first_event',
          'order': 0,
        };

        final step = VooFunnelStep.fromJson(json);

        expect(step.requiredParams, isNull);
        expect(step.maxTimeSincePrevious, isNull);
        expect(step.isOptional, isFalse);
      });
    });
  });
}
