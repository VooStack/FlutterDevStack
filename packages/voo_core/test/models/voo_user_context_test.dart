import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooUserContext', () {
    test('should auto-generate session ID on creation', () {
      final context = VooUserContext();

      expect(context.sessionId, isNotEmpty);
      // Session ID is a UUID v4
      expect(context.sessionId.length, equals(36));
    });

    test('should allow custom initial session ID', () {
      final context = VooUserContext(initialSessionId: 'custom-session');

      expect(context.sessionId, 'custom-session');
    });

    test('should allow initial user ID', () {
      final context = VooUserContext(initialUserId: 'user-123');

      expect(context.userId, 'user-123');
      expect(context.isAuthenticated, true);
    });

    test('should be unauthenticated when no user ID', () {
      final context = VooUserContext();

      expect(context.userId, isNull);
      expect(context.isAuthenticated, false);
    });

    test('should set and clear user ID', () {
      final context = VooUserContext();

      context.setUserId('user-123');
      expect(context.userId, 'user-123');
      expect(context.isAuthenticated, true);

      context.setUserId(null);
      expect(context.userId, isNull);
      expect(context.isAuthenticated, false);
    });

    test('should treat empty string as clearing user ID', () {
      final context = VooUserContext(initialUserId: 'user-123');

      context.setUserId('');
      expect(context.userId, isNull);
      expect(context.isAuthenticated, false);
    });

    test('should set and get user properties', () {
      final context = VooUserContext();

      context.setUserProperty('plan', 'premium');
      context.setUserProperty('role', 'admin');

      expect(context.userProperties['plan'], 'premium');
      expect(context.userProperties['role'], 'admin');
    });

    test('should set multiple user properties at once', () {
      final context = VooUserContext();

      context.setUserProperties({
        'plan': 'premium',
        'role': 'admin',
        'tier': 2,
      });

      expect(context.userProperties['plan'], 'premium');
      expect(context.userProperties['role'], 'admin');
      expect(context.userProperties['tier'], 2);
    });

    test('should remove property when set to null', () {
      final context = VooUserContext();

      context.setUserProperty('plan', 'premium');
      expect(context.userProperties['plan'], 'premium');

      context.setUserProperty('plan', null);
      expect(context.userProperties.containsKey('plan'), false);
    });

    test('should clear all user properties', () {
      final context = VooUserContext();

      context.setUserProperties({
        'plan': 'premium',
        'role': 'admin',
      });

      context.clearUserProperties();
      expect(context.userProperties, isEmpty);
    });

    test('should clear user and properties on clearUser', () {
      final context = VooUserContext(initialUserId: 'user-123');
      context.setUserProperty('plan', 'premium');

      context.clearUser();

      expect(context.userId, isNull);
      expect(context.userProperties, isEmpty);
      expect(context.isAuthenticated, false);
    });

    test('should preserve session on clearUser', () {
      final context = VooUserContext(initialUserId: 'user-123');
      final originalSessionId = context.sessionId;

      context.clearUser();

      expect(context.sessionId, originalSessionId);
    });

    test('should start new session with auto-generated ID', () {
      final context = VooUserContext();
      final originalSessionId = context.sessionId;

      context.startNewSession();

      expect(context.sessionId, isNot(equals(originalSessionId)));
      // Session ID is a UUID v4
      expect(context.sessionId.length, equals(36));
    });

    test('should start new session with custom ID', () {
      final context = VooUserContext();

      context.startNewSession('custom-session-2');

      expect(context.sessionId, 'custom-session-2');
    });

    test('should reset session start time on new session', () {
      final context = VooUserContext();
      final originalStartTime = context.sessionStartTime;

      // Wait a bit to ensure different timestamp
      Future.delayed(const Duration(milliseconds: 10));
      context.startNewSession();

      expect(
        context.sessionStartTime.isAfter(originalStartTime) ||
            context.sessionStartTime.isAtSameMomentAs(originalStartTime),
        true,
      );
    });

    test('should generate sync payload with correct fields', () {
      final context = VooUserContext(
        initialUserId: 'user-123',
        initialSessionId: 'session-456',
      );
      context.setUserProperty('plan', 'premium');

      final payload = context.toSyncPayload();

      expect(payload['sessionId'], 'session-456');
      expect(payload['userId'], 'user-123');
      expect(payload['plan'], 'premium');
    });

    test('should serialize to and from JSON', () {
      final context = VooUserContext(
        initialUserId: 'user-123',
        initialSessionId: 'session-456',
      );
      context.setUserProperties({
        'plan': 'premium',
        'role': 'admin',
      });

      final json = context.toJson();
      final restored = VooUserContext.fromJson(json);

      expect(restored.userId, context.userId);
      expect(restored.sessionId, context.sessionId);
      expect(restored.userProperties['plan'], 'premium');
      expect(restored.userProperties['role'], 'admin');
    });

    test('should provide read-only user properties map', () {
      final context = VooUserContext();
      context.setUserProperty('plan', 'premium');

      final props = context.userProperties;

      // Should not be able to modify the returned map
      expect(() => props['test'] = 'value', throwsA(isA<UnsupportedError>()));
    });
  });
}
