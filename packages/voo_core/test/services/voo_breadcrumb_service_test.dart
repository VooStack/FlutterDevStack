import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooBreadcrumbService', () {
    setUp(() {
      VooBreadcrumbService.reset();
    });

    tearDown(() {
      VooBreadcrumbService.reset();
    });

    group('initialization', () {
      test('should auto-initialize on first breadcrumb', () {
        expect(VooBreadcrumbService.isInitialized, isFalse);

        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Test',
        ));

        expect(VooBreadcrumbService.isInitialized, isTrue);
      });

      test('should initialize with custom max breadcrumbs', () {
        VooBreadcrumbService.initialize(maxBreadcrumbs: 50);

        expect(VooBreadcrumbService.maxBreadcrumbs, equals(50));
      });
    });

    group('addBreadcrumb', () {
      test('should add breadcrumb to trail', () {
        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Test breadcrumb',
        ));

        expect(VooBreadcrumbService.count, equals(1));
      });

      test('should enforce max breadcrumb limit', () {
        VooBreadcrumbService.initialize(maxBreadcrumbs: 3);

        for (var i = 0; i < 5; i++) {
          VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
            type: VooBreadcrumbType.custom,
            category: 'test',
            message: 'Breadcrumb $i',
          ));
        }

        expect(VooBreadcrumbService.count, equals(3));
      });

      test('should remove oldest breadcrumbs when limit exceeded', () {
        VooBreadcrumbService.initialize(maxBreadcrumbs: 3);

        for (var i = 0; i < 5; i++) {
          VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
            type: VooBreadcrumbType.custom,
            category: 'test',
            message: 'Breadcrumb $i',
          ));
        }

        final breadcrumbs = VooBreadcrumbService.getAllBreadcrumbs();
        expect(breadcrumbs.first.message, equals('Breadcrumb 2'));
        expect(breadcrumbs.last.message, equals('Breadcrumb 4'));
      });
    });

    group('convenience methods', () {
      test('should add navigation breadcrumb', () {
        VooBreadcrumbService.addNavigationBreadcrumb(
          from: 'Home',
          to: 'Profile',
          action: 'push',
        );

        final recent = VooBreadcrumbService.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.navigation));
        expect(recent.first.data?['from'], equals('Home'));
        expect(recent.first.data?['to'], equals('Profile'));
        expect(recent.first.data?['action'], equals('push'));
      });

      test('should add HTTP breadcrumb', () {
        VooBreadcrumbService.addHttpBreadcrumb(
          method: 'POST',
          url: 'https://api.test.com/users',
          statusCode: 201,
          durationMs: 250,
          requestSize: 100,
          responseSize: 500,
        );

        final recent = VooBreadcrumbService.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.http));
        expect(recent.first.data?['method'], equals('POST'));
        expect(recent.first.data?['status_code'], equals(201));
        expect(recent.first.data?['duration_ms'], equals(250));
      });

      test('should add user action breadcrumb', () {
        VooBreadcrumbService.addUserActionBreadcrumb(
          action: 'tap',
          elementId: 'submit-button',
          elementType: 'ElevatedButton',
          screenName: 'LoginScreen',
        );

        final recent = VooBreadcrumbService.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.user));
        expect(recent.first.data?['action'], equals('tap'));
        expect(recent.first.data?['element_id'], equals('submit-button'));
      });

      test('should add console breadcrumb', () {
        VooBreadcrumbService.addConsoleBreadcrumb(
          message: 'Debug message',
          level: VooBreadcrumbLevel.debug,
        );

        final recent = VooBreadcrumbService.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.console));
        expect(recent.first.level, equals(VooBreadcrumbLevel.debug));
      });

      test('should add error breadcrumb', () {
        VooBreadcrumbService.addErrorBreadcrumb(
          message: 'Something went wrong',
          errorType: 'NullPointerException',
          stackTrace: 'at line 42',
        );

        final recent = VooBreadcrumbService.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.error));
        expect(recent.first.level, equals(VooBreadcrumbLevel.error));
        expect(recent.first.data?['error_type'], equals('NullPointerException'));
      });

      test('should add system breadcrumb', () {
        VooBreadcrumbService.addSystemBreadcrumb(
          event: 'app_resumed',
          level: VooBreadcrumbLevel.info,
        );

        final recent = VooBreadcrumbService.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.system));
        expect(recent.first.category, equals('system.app_resumed'));
      });
    });

    group('retrieval methods', () {
      setUp(() {
        for (var i = 0; i < 10; i++) {
          VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
            type: VooBreadcrumbType.custom,
            category: 'test',
            message: 'Breadcrumb $i',
          ));
        }
      });

      test('should get recent breadcrumbs with limit', () {
        final recent = VooBreadcrumbService.getRecentBreadcrumbs(5);

        expect(recent.length, equals(5));
        // Recent = newest first
        expect(recent.first.message, equals('Breadcrumb 9'));
        expect(recent.last.message, equals('Breadcrumb 5'));
      });

      test('should get all breadcrumbs in chronological order', () {
        final all = VooBreadcrumbService.getAllBreadcrumbs();

        expect(all.length, equals(10));
        expect(all.first.message, equals('Breadcrumb 0'));
        expect(all.last.message, equals('Breadcrumb 9'));
      });

      test('should get breadcrumbs as JSON', () {
        final json = VooBreadcrumbService.getRecentBreadcrumbsJson(2);

        expect(json.length, equals(2));
        expect(json.first['message'], equals('Breadcrumb 9'));
        expect(json.first['type'], equals('custom'));
      });
    });

    group('filtering', () {
      setUp(() {
        VooBreadcrumbService.addNavigationBreadcrumb(from: 'A', to: 'B');
        VooBreadcrumbService.addHttpBreadcrumb(method: 'GET', url: 'test.com');
        VooBreadcrumbService.addConsoleBreadcrumb(
          message: 'debug',
          level: VooBreadcrumbLevel.debug,
        );
        VooBreadcrumbService.addErrorBreadcrumb(message: 'error');
      });

      test('should filter by type', () {
        final navigation =
            VooBreadcrumbService.getBreadcrumbsByType(VooBreadcrumbType.navigation);
        expect(navigation.length, equals(1));
        expect(navigation.first.type, equals(VooBreadcrumbType.navigation));

        final http =
            VooBreadcrumbService.getBreadcrumbsByType(VooBreadcrumbType.http);
        expect(http.length, equals(1));
      });

      test('should filter by level', () {
        final errors =
            VooBreadcrumbService.getBreadcrumbsByLevel(VooBreadcrumbLevel.error);
        expect(errors.length, equals(1));

        final debug =
            VooBreadcrumbService.getBreadcrumbsByLevel(VooBreadcrumbLevel.debug);
        expect(debug.length, equals(1));
      });
    });

    group('listeners', () {
      test('should notify listeners when breadcrumb added', () {
        final received = <VooBreadcrumb>[];
        VooBreadcrumbService.addListener((b) => received.add(b));

        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Test',
        ));

        expect(received.length, equals(1));
        expect(received.first.message, equals('Test'));
      });

      test('should remove listener', () {
        final received = <VooBreadcrumb>[];
        void listener(VooBreadcrumb b) => received.add(b);

        VooBreadcrumbService.addListener(listener);
        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'First',
        ));

        VooBreadcrumbService.removeListener(listener);
        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Second',
        ));

        expect(received.length, equals(1));
      });
    });

    group('clear and dispose', () {
      test('should clear all breadcrumbs', () {
        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Test',
        ));

        VooBreadcrumbService.clear();

        expect(VooBreadcrumbService.count, equals(0));
      });

      test('should dispose and reset state', () {
        VooBreadcrumbService.initialize(maxBreadcrumbs: 50);
        VooBreadcrumbService.addBreadcrumb(VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Test',
        ));

        VooBreadcrumbService.dispose();

        expect(VooBreadcrumbService.isInitialized, isFalse);
        expect(VooBreadcrumbService.count, equals(0));
      });
    });
  });
}
