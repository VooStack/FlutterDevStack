import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_analytics/src/data/services/analytics_cloud_sync.dart';
import 'package:voo_analytics/src/domain/entities/touch_event.dart';

void main() {
  group('AnalyticsCloudSyncService Integration Tests', () {
    late AnalyticsCloudSyncService syncService;
    late List<Map<String, dynamic>> capturedRequests;
    late int requestCount;

    setUp(() {
      capturedRequests = [];
      requestCount = 0;
    });

    tearDown(() {
      syncService.dispose();
    });

    MockClient createMockClient({int statusCode = 200}) {
      return MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedRequests.add({
          'url': request.url.toString(),
          'headers': request.headers,
          'body': body,
        });
        return http.Response('{"success": true}', statusCode);
      });
    }

    test('should batch analytics events correctly', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
        batchInterval: const Duration(hours: 1),
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      for (var i = 0; i < 5; i++) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test_event_$i',
          timestamp: DateTime.now(),
          parameters: {'index': i},
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      expect(capturedRequests.first['body']['events'].length, 5);
      expect(capturedRequests.first['body']['projectId'], 'test-project');
    });

    test('should include touch events in payload when flushing', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 3,
        batchInterval: const Duration(hours: 1),
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Queue touch events first
      for (var i = 0; i < 3; i++) {
        syncService.queueTouchEvent(TouchEvent(
          id: 'test-touch-$i',
          position: Offset(i * 10.0, i * 20.0),
          screenName: 'TestScreen',
          type: TouchType.tap,
          timestamp: DateTime.now(),
        ));
      }

      // Queue analytics events to trigger flush (touch events are included in payload)
      for (var i = 0; i < 3; i++) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: 'event_$i',
          timestamp: DateTime.now(),
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      expect(capturedRequests.first['body']['events'].length, 3);
      expect(capturedRequests.first['body']['touchEvents'].length, 3);
    });

    test('should include API key in headers', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'my-secret-key',
        projectId: 'project-123',
        batchSize: 1,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueEvent(AnalyticsEventData(
        eventName: 'test',
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(capturedRequests.first['headers']['X-API-Key'], 'my-secret-key');
    });

    test('should not sync when disabled', () async {
      final config = const AnalyticsCloudSyncConfig(enabled: false);

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      for (var i = 0; i < 10; i++) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: 'test',
          timestamp: DateTime.now(),
        ));
      }

      await syncService.flush();

      expect(requestCount, 0);
    });
  });

  group('AnalyticsCloudSyncConfig Tests', () {
    test('should validate configuration', () {
      final invalid = const AnalyticsCloudSyncConfig(enabled: true);
      expect(invalid.isValid, false);

      final valid = const AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'key',
      );
      expect(valid.isValid, true);
    });

    test('production preset should have correct defaults', () {
      final config = AnalyticsCloudSyncConfig.production(
        endpoint: 'https://api.test.com',
        apiKey: 'key',
        projectId: 'project',
      );

      expect(config.enabled, true);
      expect(config.batchSize, 100);
      expect(config.batchInterval, const Duration(seconds: 60));
    });
  });
}
