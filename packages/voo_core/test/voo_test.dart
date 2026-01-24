import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voo', () {
    tearDown(() async {
      await Voo.dispose();
    });

    group('initialization', () {
      test('should not be initialized before initializeApp', () {
        expect(Voo.isInitialized, isFalse);
      });

      test('should be initialized after initializeApp', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        expect(Voo.isInitialized, isTrue);
      });

      test('should return same app for multiple calls with same name', () async {
        final app1 = await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final app2 = await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        expect(identical(app1, app2), isTrue);
      });

      test('should create named apps', () async {
        await Voo.initializeApp(
          name: 'custom-app',
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        expect(() => Voo.app('custom-app'), returnsNormally);
      });
    });

    group('config', () {
      test('should store config after initialization', () async {
        final config = VooConfig(
          endpoint: 'https://test.com',
          apiKey: 'test-key',
          projectId: 'test-project',
        );

        await Voo.initializeApp(config: config);

        expect(Voo.config, equals(config));
      });

      test('should return null config before initialization', () {
        expect(Voo.config, isNull);
      });
    });

    group('user context', () {
      setUp(() async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );
      });

      test('should set user id', () {
        Voo.setUserId('user-123');

        expect(Voo.userId, equals('user-123'));
      });

      test('should set user property', () {
        Voo.setUserProperty('plan', 'premium');

        expect(Voo.userContext?.userProperties['plan'], equals('premium'));
      });

      test('should set multiple user properties', () {
        Voo.setUserProperties({'name': 'John', 'role': 'admin'});

        expect(Voo.userContext?.userProperties['name'], equals('John'));
        expect(Voo.userContext?.userProperties['role'], equals('admin'));
      });

      test('should clear user on logout', () {
        Voo.setUserId('user-123');
        Voo.setUserProperty('plan', 'premium');

        Voo.clearUser();

        expect(Voo.userId, isNull);
        expect(Voo.userContext?.userProperties.isEmpty, isTrue);
      });

      test('should start new session', () {
        final oldSessionId = Voo.sessionId;
        Voo.startNewSession();
        final newSessionId = Voo.sessionId;

        expect(newSessionId, isNotNull);
        expect(newSessionId, isNot(equals(oldSessionId)));
      });

      test('should start session with custom id', () {
        Voo.startNewSession('custom-session-id');

        expect(Voo.sessionId, equals('custom-session-id'));
      });
    });

    group('breadcrumbs', () {
      setUp(() async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );
        VooBreadcrumbService.clear();
      });

      test('should add breadcrumb', () {
        final breadcrumb = VooBreadcrumb(
          type: VooBreadcrumbType.custom,
          category: 'test',
          message: 'Test breadcrumb',
        );

        Voo.addBreadcrumb(breadcrumb);

        final recent = Voo.getRecentBreadcrumbs(1);
        expect(recent.length, equals(1));
        expect(recent.first.message, equals('Test breadcrumb'));
      });

      test('should add navigation breadcrumb', () {
        Voo.addNavigationBreadcrumb(from: 'Home', to: 'Profile');

        final recent = Voo.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.navigation));
        expect(recent.first.data?['from'], equals('Home'));
        expect(recent.first.data?['to'], equals('Profile'));
      });

      test('should add HTTP breadcrumb', () {
        Voo.addHttpBreadcrumb(
          method: 'GET',
          url: 'https://api.test.com/users',
          statusCode: 200,
          durationMs: 150,
        );

        final recent = Voo.getRecentBreadcrumbs(1);
        expect(recent.first.type, equals(VooBreadcrumbType.http));
        expect(recent.first.data?['method'], equals('GET'));
        expect(recent.first.data?['status_code'], equals(200));
      });
    });

    group('plugins', () {
      test('should register plugin', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final plugin = TestPlugin();
        await Voo.registerPlugin(plugin);

        expect(Voo.hasPlugin('test-plugin'), isTrue);
        expect(Voo.plugins.length, equals(1));
      });

      test('should throw when registering duplicate plugin', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final plugin = TestPlugin();
        await Voo.registerPlugin(plugin);

        expect(
          () async => await Voo.registerPlugin(TestPlugin()),
          throwsA(isA<VooException>()),
        );
      });

      test('should unregister plugin', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final plugin = TestPlugin();
        await Voo.registerPlugin(plugin);
        await Voo.unregisterPlugin('test-plugin');

        expect(Voo.hasPlugin('test-plugin'), isFalse);
      });

      test('should get plugin by name', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final plugin = TestPlugin();
        await Voo.registerPlugin(plugin);

        final retrieved = Voo.getPlugin<TestPlugin>('test-plugin');
        expect(retrieved, equals(plugin));
      });

      test('should return null for non-existent plugin', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final retrieved = Voo.getPlugin<TestPlugin>('non-existent');
        expect(retrieved, isNull);
      });
    });

    group('app retrieval', () {
      test('should get default app', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        expect(() => Voo.app(), returnsNormally);
      });

      test('should throw for non-existent app', () {
        expect(
          () => Voo.app('non-existent'),
          throwsA(isA<VooException>()),
        );
      });

      test('should list all apps', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        expect(Voo.allApps.length, equals(1));
      });
    });

    group('context', () {
      test('should return null context before initialization', () {
        expect(Voo.context, isNull);
      });

      test('should return context after initialization', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        expect(Voo.context, isNotNull);
      });
    });

    group('dispose', () {
      test('should clear all state on dispose', () async {
        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        final plugin = TestPlugin();
        await Voo.registerPlugin(plugin);

        await Voo.dispose();

        expect(Voo.isInitialized, isFalse);
        expect(Voo.config, isNull);
        expect(Voo.userContext, isNull);
        expect(Voo.deviceInfo, isNull);
        expect(Voo.plugins.isEmpty, isTrue);
        expect(Voo.apps.isEmpty, isTrue);
      });
    });
  });
}

class TestPlugin extends VooPlugin {
  @override
  String get name => 'test-plugin';

  @override
  String get version => '1.0.0';
}
