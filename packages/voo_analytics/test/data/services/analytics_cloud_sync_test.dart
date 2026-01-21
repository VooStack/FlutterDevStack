import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_analytics/src/data/services/analytics_cloud_sync.dart';
import 'package:voo_analytics/src/domain/entities/touch_event.dart';
import 'package:voo_core/src/models/voo_point.dart';

void main() {
  group('AnalyticsCloudSyncConfig', () {
    group('constructor', () {
      test('should create with default values', () {
        const config = AnalyticsCloudSyncConfig();

        expect(config.enabled, isFalse);
        expect(config.endpoint, isNull);
        expect(config.apiKey, isNull);
        expect(config.projectId, isNull);
        expect(config.batchSize, equals(100));
        expect(config.batchInterval, equals(const Duration(seconds: 30)));
        expect(config.maxRetries, equals(3));
        expect(config.timeout, equals(const Duration(seconds: 10)));
        expect(config.maxQueueSize, equals(2000));
      });

      test('should create with custom values', () {
        const config = AnalyticsCloudSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
          projectId: 'test-project',
          batchSize: 50,
          batchInterval: Duration(seconds: 60),
        );

        expect(config.enabled, isTrue);
        expect(config.endpoint, equals('https://api.example.com'));
        expect(config.apiKey, equals('test-key'));
        expect(config.projectId, equals('test-project'));
        expect(config.batchSize, equals(50));
        expect(config.batchInterval, equals(const Duration(seconds: 60)));
      });
    });

    group('eventsEndpoint', () {
      test('should generate correct endpoint URL', () {
        const config = AnalyticsCloudSyncConfig(
          endpoint: 'https://api.devstack.io/api',
        );
        expect(config.eventsEndpoint, 'https://api.devstack.io/api/v1/telemetry/analytics');
      });

      test('should return null when endpoint is null', () {
        const config = AnalyticsCloudSyncConfig();
        expect(config.eventsEndpoint, isNull);
      });
    });

    group('isValid', () {
      test('should return false when disabled', () {
        const config = AnalyticsCloudSyncConfig(
          enabled: false,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
        );
        expect(config.isValid, isFalse);
      });

      test('should return true when properly configured', () {
        const config = AnalyticsCloudSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'test-key',
        );
        expect(config.isValid, isTrue);
      });
    });

    group('factory constructors', () {
      test('production should have correct defaults', () {
        final config = AnalyticsCloudSyncConfig.production(
          endpoint: 'https://api.prod.com',
          apiKey: 'prod-key',
          projectId: 'prod-project',
        );

        expect(config.enabled, isTrue);
        expect(config.batchSize, equals(100));
        expect(config.batchInterval, equals(const Duration(seconds: 60)));
      });

      test('development should have smaller batches', () {
        final config = AnalyticsCloudSyncConfig.development(
          endpoint: 'https://api.dev.com',
          apiKey: 'dev-key',
          projectId: 'dev-project',
        );

        expect(config.enabled, isTrue);
        expect(config.batchSize, equals(20));
        expect(config.batchInterval, equals(const Duration(seconds: 15)));
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        const original = AnalyticsCloudSyncConfig(
          enabled: true,
          endpoint: 'https://api.example.com',
          apiKey: 'key1',
        );

        final copied = original.copyWith(apiKey: 'key2');

        expect(copied.enabled, isTrue);
        expect(copied.endpoint, equals('https://api.example.com'));
        expect(copied.apiKey, equals('key2'));
      });
    });
  });

  group('AnalyticsEventData', () {
    test('should convert to JSON correctly', () {
      final event = AnalyticsEventData(
        eventName: 'button_click',
        category: 'user_interaction',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30),
        parameters: {'button_id': 'submit'},
        action: 'click',
        label: 'checkout_submit',
        value: 1.0,
      );

      final json = event.toJson();

      expect(json['name'], equals('button_click'));
      expect(json['category'], equals('user_interaction'));
      expect(json['timestamp'], equals('2024-01-15T10:30:00.000Z'));
      expect(json['properties'], equals({'button_id': 'submit'}));
      expect(json['action'], equals('click'));
      expect(json['label'], equals('checkout_submit'));
      expect(json['value'], equals(1.0));
    });

    test('should use default category when not provided', () {
      final event = AnalyticsEventData(
        eventName: 'test_event',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30),
      );

      final json = event.toJson();
      expect(json['category'], equals('general'));
    });
  });

  group('AnalyticsCloudSyncService', () {
    late AnalyticsCloudSyncService syncService;
    late List<Map<String, dynamic>> capturedRequests;
    int requestCount = 0;

    AnalyticsCloudSyncConfig createValidConfig({
      int batchSize = 5,
      Duration batchInterval = const Duration(hours: 1),
    }) {
      return AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-api-key',
        projectId: 'test-project-id',
        batchSize: batchSize,
        batchInterval: batchInterval,
      );
    }

    MockClient createMockClient({int statusCode = 200}) {
      return MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedRequests.add({
          'url': request.url.toString(),
          'method': request.method,
          'headers': request.headers,
          'body': body,
        });
        return http.Response('{"success": true}', statusCode);
      });
    }

    setUp(() {
      requestCount = 0;
      capturedRequests = [];
    });

    tearDown(() {
      syncService.dispose();
    });

    group('initialization', () {
      test('should initialize with valid config', () {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig(),
          client: createMockClient(),
        );
        syncService.initialize();

        expect(syncService.pendingCount, equals(0));
      });

      test('should not queue events when disabled', () {
        syncService = AnalyticsCloudSyncService(
          config: const AnalyticsCloudSyncConfig(enabled: false),
          client: createMockClient(),
        );
        syncService.initialize();

        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test',
          timestamp: DateTime.now(),
        ));

        expect(syncService.pendingCount, equals(0));
      });
    });

    group('queueEvent', () {
      test('should queue events when enabled', () {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig(),
          client: createMockClient(),
        );
        syncService.initialize();

        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test',
          timestamp: DateTime.now(),
        ));

        expect(syncService.pendingCount, equals(1));
      });

      test('should auto-flush when batch size reached', () async {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig(batchSize: 2),
          client: createMockClient(),
        );
        syncService.initialize();

        syncService.queueEvent(AnalyticsEventData(
          eventName: 'event1',
          timestamp: DateTime.now(),
        ));
        syncService.queueEvent(AnalyticsEventData(
          eventName: 'event2',
          timestamp: DateTime.now(),
        ));

        await Future.delayed(const Duration(milliseconds: 100));

        expect(requestCount, equals(1));
        expect(capturedRequests.first['body']['events'].length, equals(2));
      });
    });

    group('queueTouchEvent', () {
      test('should queue touch events (deprecated - cleared on flush)', () {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig(),
          client: createMockClient(),
        );
        syncService.initialize();

        syncService.queueTouchEvent(TouchEvent(
          id: 'touch-1',
          position: const VooPoint(100.0, 200.0),
          screenName: 'home',
          route: '/home',
          type: TouchType.tap,
          timestamp: DateTime.now(),
        ));

        // Touch events are still queued but cleared on flush (not part of standard API)
        expect(syncService.pendingCount, equals(1));
      });
    });

    group('flush', () {
      test('should send events with batch metadata', () async {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig(),
          client: createMockClient(),
        );
        syncService.initialize();

        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test_event',
          timestamp: DateTime.now(),
        ));

        await syncService.flush();

        // Verify batch structure matches EventsBatchRequest
        final body = capturedRequests.first['body'];
        expect(body['events'].length, equals(1));
        expect(body.containsKey('sessionId'), isTrue);
        expect(body.containsKey('userId'), isTrue);
        expect(body.containsKey('deviceId'), isTrue);
        expect(body.containsKey('platform'), isTrue);
        expect(body.containsKey('appVersion'), isTrue);
        // projectId and touchEvents are no longer included in standard API
        expect(body.containsKey('projectId'), isFalse);
        expect(body.containsKey('touchEvents'), isFalse);
      });

      test('should include correct headers', () async {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig(),
          client: createMockClient(),
        );
        syncService.initialize();

        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test',
          timestamp: DateTime.now(),
        ));

        await syncService.flush();

        final headers = capturedRequests.first['headers'];
        expect(headers['Content-Type'], equals('application/json'));
        expect(headers['X-API-Key'], equals('test-api-key'));
      });
    });

    group('error handling', () {
      test('should handle sync failures gracefully', () async {
        syncService = AnalyticsCloudSyncService(
          config: createValidConfig().copyWith(maxRetries: 0),
          client: createMockClient(statusCode: 500),
        );
        syncService.initialize();

        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test',
          timestamp: DateTime.now(),
        ));

        final result = await syncService.flush();

        expect(result, isFalse);
        expect(syncService.pendingCount, equals(1)); // Re-queued
      });
    });
  });
}
