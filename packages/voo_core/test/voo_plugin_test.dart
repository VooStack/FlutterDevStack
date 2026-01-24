import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooPlugin', () {
    group('abstract interface', () {
      test('should implement name and version', () {
        final plugin = TestPlugin();

        expect(plugin.name, equals('test-plugin'));
        expect(plugin.version, equals('1.0.0'));
      });

      test('should provide plugin info', () {
        final plugin = TestPlugin();

        final info = plugin.getInfo();

        expect(info['name'], equals('test-plugin'));
        expect(info['version'], equals('1.0.0'));
      });
    });

    group('lifecycle', () {
      test('should call onAppInitialized when app is initialized', () async {
        final plugin = TrackingPlugin();

        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        await Voo.registerPlugin(plugin);

        expect(plugin.initializedApps.length, equals(1));
      });

      test('should call dispose when unregistered', () async {
        final plugin = TrackingPlugin();

        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        await Voo.registerPlugin(plugin);
        await Voo.unregisterPlugin('tracking-plugin');

        expect(plugin.disposed, isTrue);
      });

      test('should call dispose when Voo disposes', () async {
        final plugin = TrackingPlugin();

        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        await Voo.registerPlugin(plugin);
        await Voo.dispose();

        expect(plugin.disposed, isTrue);
      });
    });

    group('getInstanceForApp', () {
      test('should return self by default', () {
        final plugin = TestPlugin();
        final instance = plugin.getInstanceForApp(Object());

        expect(instance, equals(plugin));
      });

      test('should allow custom instance per app', () async {
        final plugin = AppSpecificPlugin();

        await Voo.initializeApp(
          config: VooConfig(
            endpoint: 'https://test.com',
            apiKey: 'test-key',
            projectId: 'test-project',
          ),
        );

        await Voo.registerPlugin(plugin);

        final app = Voo.app();
        final instance = plugin.getInstanceForApp(app);

        expect(instance, isA<AppSpecificInstance>());
        expect((instance as AppSpecificInstance).appName, equals(app.name));
      });
    });
  });

  tearDown(() async {
    await Voo.dispose();
  });
}

class TestPlugin extends VooPlugin {
  @override
  String get name => 'test-plugin';

  @override
  String get version => '1.0.0';
}

class TrackingPlugin extends VooPlugin {
  final List<Object> initializedApps = [];
  final List<Object> deletedApps = [];
  bool disposed = false;

  @override
  String get name => 'tracking-plugin';

  @override
  String get version => '1.0.0';

  @override
  FutureOr<void> onAppInitialized(Object app) {
    initializedApps.add(app);
  }

  @override
  FutureOr<void> onAppDeleted(Object app) {
    deletedApps.add(app);
  }

  @override
  FutureOr<void> dispose() {
    disposed = true;
  }
}

class AppSpecificInstance {
  final String appName;
  AppSpecificInstance(this.appName);
}

class AppSpecificPlugin extends VooPlugin {
  final Map<String, AppSpecificInstance> _instances = {};

  @override
  String get name => 'app-specific-plugin';

  @override
  String get version => '1.0.0';

  @override
  FutureOr<void> onAppInitialized(Object app) {
    if (app is VooApp) {
      _instances[app.name] = AppSpecificInstance(app.name);
    }
  }

  @override
  dynamic getInstanceForApp(Object app) {
    if (app is VooApp) {
      return _instances[app.name];
    }
    return this;
  }
}
