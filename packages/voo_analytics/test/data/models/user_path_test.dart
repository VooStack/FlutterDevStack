import 'package:flutter_test/flutter_test.dart';
import 'package:voo_analytics/src/data/models/user_path.dart';

void main() {
  group('VooUserPath', () {
    VooPathNode createNode({
      required String screenName,
      int interactions = 0,
      Duration duration = const Duration(seconds: 30),
    }) {
      return VooPathNode(
        screenName: screenName,
        enterTime: DateTime(2024, 1, 1),
        duration: duration,
        interactionCount: interactions,
        exitType: 'navigate',
      );
    }

    group('constructor', () {
      test('should create with required parameters', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [createNode(screenName: 'HomeScreen')],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.sessionId, equals('session-123'));
        expect(path.nodes.length, equals(1));
        expect(path.totalDuration, equals(const Duration(minutes: 5)));
      });

      test('should create with optional parameters', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          userId: 'user-456',
          nodes: [],
          totalDuration: const Duration(minutes: 5),
          endedWithConversion: true,
          conversionEvent: 'purchase_completed',
          startTime: DateTime(2024, 1, 1),
          endTime: DateTime(2024, 1, 1, 0, 5),
          attribution: {'utm_source': 'google'},
        );

        expect(path.userId, equals('user-456'));
        expect(path.endedWithConversion, isTrue);
        expect(path.conversionEvent, equals('purchase_completed'));
        expect(path.endTime, isNotNull);
        expect(path.attribution, isNotNull);
      });
    });

    group('computed properties', () {
      test('should calculate screen count', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
            createNode(screenName: 'Settings'),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.screenCount, equals(3));
      });

      test('should calculate total interactions', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home', interactions: 5),
            createNode(screenName: 'Profile', interactions: 3),
            createNode(screenName: 'Settings', interactions: 2),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.totalInteractions, equals(10));
      });

      test('should calculate average time per screen', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
          ],
          totalDuration: const Duration(minutes: 2),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.averageTimePerScreen, equals(const Duration(minutes: 1)));
      });

      test('should return zero average for empty path', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [],
          totalDuration: Duration.zero,
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.averageTimePerScreen, equals(Duration.zero));
      });

      test('should get entry screen', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.entryScreen, equals('Home'));
      });

      test('should return null entry screen for empty path', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [],
          totalDuration: Duration.zero,
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.entryScreen, isNull);
      });

      test('should get exit screen', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.exitScreen, equals('Profile'));
      });

      test('should get unique screens', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
            createNode(screenName: 'Home'),
            createNode(screenName: 'Settings'),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(path.uniqueScreens, equals({'Home', 'Profile', 'Settings'}));
      });

      test('should detect bounce', () {
        final bouncePath = VooUserPath(
          sessionId: 'session-123',
          nodes: [createNode(screenName: 'Home')],
          totalDuration: const Duration(seconds: 10),
          startTime: DateTime(2024, 1, 1),
        );

        final normalPath = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        expect(bouncePath.isBounce, isTrue);
        expect(normalPath.isBounce, isFalse);
      });

      test('should create path summary', () {
        final shortPath = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
          ],
          totalDuration: const Duration(minutes: 5),
          startTime: DateTime(2024, 1, 1),
        );

        final longPath = VooUserPath(
          sessionId: 'session-123',
          nodes: [
            createNode(screenName: 'Home'),
            createNode(screenName: 'Profile'),
            createNode(screenName: 'Settings'),
            createNode(screenName: 'Checkout'),
          ],
          totalDuration: const Duration(minutes: 10),
          startTime: DateTime(2024, 1, 1),
        );

        expect(shortPath.pathSummary, equals('Home → Profile'));
        expect(longPath.pathSummary, equals('Home → ... → Checkout'));
      });
    });

    group('toJson', () {
      test('should serialize to JSON', () {
        final path = VooUserPath(
          sessionId: 'session-123',
          userId: 'user-456',
          nodes: [createNode(screenName: 'Home', interactions: 5)],
          totalDuration: const Duration(minutes: 5),
          endedWithConversion: true,
          conversionEvent: 'purchase',
          startTime: DateTime(2024, 1, 1, 10, 0),
          endTime: DateTime(2024, 1, 1, 10, 5),
        );

        final json = path.toJson();

        expect(json['session_id'], equals('session-123'));
        expect(json['user_id'], equals('user-456'));
        expect(json['total_duration_ms'], equals(5 * 60 * 1000));
        expect(json['ended_with_conversion'], isTrue);
        expect(json['conversion_event'], equals('purchase'));
        expect(json['screen_count'], equals(1));
        expect(json['total_interactions'], equals(5));
        expect(json['is_bounce'], isTrue);
      });
    });

    group('fromJson', () {
      test('should deserialize from JSON', () {
        final json = {
          'session_id': 'session-123',
          'user_id': 'user-456',
          'nodes': [
            {
              'screen_name': 'Home',
              'enter_time': '2024-01-01T10:00:00.000',
              'duration_ms': 30000,
              'interaction_count': 5,
              'exit_type': 'navigate',
            },
          ],
          'total_duration_ms': 300000,
          'ended_with_conversion': true,
          'conversion_event': 'purchase',
          'start_time': '2024-01-01T10:00:00.000',
          'end_time': '2024-01-01T10:05:00.000',
        };

        final path = VooUserPath.fromJson(json);

        expect(path.sessionId, equals('session-123'));
        expect(path.userId, equals('user-456'));
        expect(path.nodes.length, equals(1));
        expect(path.endedWithConversion, isTrue);
      });
    });
  });

  group('VooPathNode', () {
    group('constructor', () {
      test('should create with required parameters', () {
        final node = VooPathNode(
          screenName: 'HomeScreen',
          enterTime: DateTime(2024, 1, 1),
          duration: const Duration(seconds: 30),
          interactionCount: 5,
          exitType: 'navigate',
        );

        expect(node.screenName, equals('HomeScreen'));
        expect(node.interactionCount, equals(5));
        expect(node.exitType, equals('navigate'));
      });
    });

    group('computed properties', () {
      test('should detect engagement with interactions', () {
        final engaged = VooPathNode(
          screenName: 'Home',
          enterTime: DateTime(2024, 1, 1),
          duration: const Duration(seconds: 30),
          interactionCount: 1,
          exitType: 'navigate',
        );

        final notEngaged = VooPathNode(
          screenName: 'Home',
          enterTime: DateTime(2024, 1, 1),
          duration: const Duration(seconds: 30),
          interactionCount: 0,
          exitType: 'navigate',
        );

        expect(engaged.wasEngaged, isTrue);
        expect(notEngaged.wasEngaged, isFalse);
      });

      test('should detect engagement with scroll depth', () {
        final engaged = VooPathNode(
          screenName: 'Home',
          enterTime: DateTime(2024, 1, 1),
          duration: const Duration(seconds: 30),
          interactionCount: 0,
          exitType: 'navigate',
          scrollDepth: 0.5,
        );

        expect(engaged.wasEngaged, isTrue);
      });

      test('should get duration in seconds', () {
        final node = VooPathNode(
          screenName: 'Home',
          enterTime: DateTime(2024, 1, 1),
          duration: const Duration(seconds: 90),
          interactionCount: 0,
          exitType: 'navigate',
        );

        expect(node.durationSeconds, equals(90));
      });
    });

    group('toJson/fromJson', () {
      test('should round-trip through JSON', () {
        final original = VooPathNode(
          screenName: 'HomeScreen',
          enterTime: DateTime(2024, 1, 1, 10, 0),
          duration: const Duration(seconds: 30),
          interactionCount: 5,
          nextScreen: 'ProfileScreen',
          exitType: 'navigate',
          scrollDepth: 0.75,
          routeParams: {'id': '123'},
          events: ['button_clicked'],
        );

        final json = original.toJson();
        final restored = VooPathNode.fromJson(json);

        expect(restored.screenName, equals(original.screenName));
        expect(restored.interactionCount, equals(original.interactionCount));
        expect(restored.nextScreen, equals(original.nextScreen));
        expect(restored.scrollDepth, equals(original.scrollDepth));
      });
    });
  });
}
