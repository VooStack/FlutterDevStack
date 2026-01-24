import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/otel/screen_view_span_manager.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('ScreenViewSpanManager', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late TraceProvider traceProvider;
    late Tracer tracer;
    late ScreenViewSpanManager manager;

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
      manager = ScreenViewSpanManager(tracer);
    });

    tearDown(() {
      manager.dispose();
    });

    group('startScreenView', () {
      test('should start a new screen view span', () {
        final span = manager.startScreenView(screenName: 'HomeScreen');

        expect(span, isNotNull);
        expect(manager.activeScreenSpan, equals(span));
      });

      test('should end previous span when starting new one', () async {
        final span1 = manager.startScreenView(screenName: 'HomeScreen');
        await Future.delayed(const Duration(milliseconds: 10));
        final span2 = manager.startScreenView(screenName: 'ProfileScreen');

        expect(span1.isRecording, isFalse);
        expect(span2.isRecording, isTrue);
        expect(manager.activeScreenSpan, equals(span2));
      });

      test('should set screen class attribute', () {
        manager.startScreenView(
          screenName: 'HomeScreen',
          screenClass: 'HomeScreenWidget',
        );

        expect(manager.activeScreenSpan, isNotNull);
      });

      test('should track previous screen', () {
        manager.startScreenView(
          screenName: 'ProfileScreen',
          previousScreen: 'HomeScreen',
        );

        expect(manager.activeScreenSpan, isNotNull);
      });

      test('should set session id on span', () {
        manager.sessionId = 'session-123';
        manager.startScreenView(screenName: 'HomeScreen');

        expect(manager.sessionId, equals('session-123'));
      });

      test('should set user id on span', () {
        manager.userId = 'user-456';
        manager.startScreenView(screenName: 'HomeScreen');

        expect(manager.userId, equals('user-456'));
      });

      test('should accept route params', () {
        manager.startScreenView(
          screenName: 'UserScreen',
          routeParams: {'userId': '123', 'tab': 'profile'},
        );

        expect(manager.activeScreenSpan, isNotNull);
      });

      test('should accept navigation action', () {
        manager.startScreenView(
          screenName: 'ProfileScreen',
          navigationAction: 'push',
        );

        expect(manager.activeScreenSpan, isNotNull);
      });
    });

    group('trace context', () {
      test('should return trace context when screen active', () {
        manager.startScreenView(screenName: 'HomeScreen');

        expect(manager.currentTraceContext, isNotNull);
        expect(manager.traceId, isNotNull);
        expect(manager.spanId, isNotNull);
      });

      test('should return null context when no active screen', () {
        expect(manager.currentTraceContext, isNull);
        expect(manager.traceId, isNull);
        expect(manager.spanId, isNull);
      });
    });

    group('addScreenEvent', () {
      test('should add event to active screen span', () {
        manager.startScreenView(screenName: 'HomeScreen');

        expect(
          () => manager.addScreenEvent('button_clicked', attributes: {
            'button_id': 'submit',
          }),
          returnsNormally,
        );
      });

      test('should handle no active span gracefully', () {
        expect(
          () => manager.addScreenEvent('button_clicked'),
          returnsNormally,
        );
      });
    });

    group('recordInteraction', () {
      test('should record tap interaction', () {
        manager.startScreenView(screenName: 'HomeScreen');

        expect(
          () => manager.recordInteraction(
            interactionType: 'tap',
            elementId: 'button_1',
            elementType: 'ElevatedButton',
            x: 100.0,
            y: 200.0,
          ),
          returnsNormally,
        );
      });

      test('should record scroll interaction', () {
        manager.startScreenView(screenName: 'HomeScreen');

        expect(
          () => manager.recordInteraction(
            interactionType: 'scroll',
            additionalAttributes: {'scroll_depth': 0.75},
          ),
          returnsNormally,
        );
      });

      test('should handle no active span gracefully', () {
        expect(
          () => manager.recordInteraction(interactionType: 'tap'),
          returnsNormally,
        );
      });
    });

    group('setScreenAttribute', () {
      test('should set attribute on active span', () {
        manager.startScreenView(screenName: 'HomeScreen');

        expect(
          () => manager.setScreenAttribute('custom.attr', 'value'),
          returnsNormally,
        );
      });

      test('should handle no active span gracefully', () {
        expect(
          () => manager.setScreenAttribute('custom.attr', 'value'),
          returnsNormally,
        );
      });
    });

    group('dispose', () {
      test('should end all screen spans', () {
        manager.startScreenView(screenName: 'HomeScreen');
        manager.startScreenView(screenName: 'ProfileScreen');
        manager.startScreenView(screenName: 'SettingsScreen');

        manager.dispose();

        expect(manager.activeScreenSpan, isNull);
      });

      test('should handle empty state', () {
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
