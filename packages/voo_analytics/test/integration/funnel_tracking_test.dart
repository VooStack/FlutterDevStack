import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_analytics/src/data/services/analytics_cloud_sync.dart';

void main() {
  group('Funnel Tracking Integration Tests', () {
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

    test('should track funnel step events', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 10,
        batchInterval: const Duration(hours: 1),
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Simulate a purchase funnel
      final funnelSteps = [
        'view_product',
        'add_to_cart',
        'begin_checkout',
        'purchase',
      ];

      for (var i = 0; i < funnelSteps.length; i++) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: funnelSteps[i],
          timestamp: DateTime.now().add(Duration(seconds: i)),
          category: 'purchase_funnel',
          parameters: {
            'funnel_step': i + 1,
            'total_steps': funnelSteps.length,
            'product_id': 'product_123',
          },
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final events = capturedRequests.first['body']['events'] as List;
      expect(events.length, 4);

      // Verify funnel steps are in order
      expect(events[0]['name'], 'view_product');
      expect(events[1]['name'], 'add_to_cart');
      expect(events[2]['name'], 'begin_checkout');
      expect(events[3]['name'], 'purchase');

      // Verify funnel metadata is included
      expect(events[0]['properties']['funnel_step'], 1);
      expect(events[3]['properties']['funnel_step'], 4);
    });

    test('should track user conversion through funnel', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 20,
        batchInterval: const Duration(hours: 1),
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // User 1: Completes all steps
      final user1Steps = ['signup_start', 'email_entered', 'password_set', 'signup_complete'];
      for (final step in user1Steps) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: step,
          timestamp: DateTime.now(),
          category: 'signup_funnel',
          parameters: {'user_id': 'user_1'},
        ));
      }

      // User 2: Drops off at step 2
      final user2Steps = ['signup_start', 'email_entered'];
      for (final step in user2Steps) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: step,
          timestamp: DateTime.now(),
          category: 'signup_funnel',
          parameters: {'user_id': 'user_2'},
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final events = capturedRequests.first['body']['events'] as List;
      expect(events.length, 6);

      // Verify both user journeys are captured
      final user1Events = events.where((e) => e['properties']['user_id'] == 'user_1').toList();
      final user2Events = events.where((e) => e['properties']['user_id'] == 'user_2').toList();

      expect(user1Events.length, 4);
      expect(user2Events.length, 2);
    });

    test('should include conversion event markers', () async {
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

      // Track a conversion event
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'purchase',
        timestamp: DateTime.now(),
        category: 'conversion',
        parameters: {
          'is_conversion': true,
          'conversion_value': 99.99,
          'currency': 'USD',
          'product_id': 'product_456',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['name'], 'purchase');
      expect(event['properties']['is_conversion'], true);
      expect(event['properties']['conversion_value'], 99.99);
    });

    test('should track complex multi-step funnel', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 15,
        batchInterval: const Duration(hours: 1),
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      final complexFunnel = [
        'landing_page_view',
        'cta_click',
        'signup_modal_open',
        'email_input',
        'password_input',
        'terms_accepted',
        'signup_submitted',
        'email_verified',
        'profile_completed',
      ];

      for (var i = 0; i < complexFunnel.length; i++) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: complexFunnel[i],
          timestamp: DateTime.now().add(Duration(seconds: i * 10)),
          category: 'onboarding_funnel',
          parameters: {
            'funnel_step': i + 1,
            'total_steps': complexFunnel.length,
            'time_since_start': i * 10,
          },
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final events = capturedRequests.first['body']['events'] as List;
      expect(events.length, 9);

      // Verify first and last steps
      expect(events.first['name'], 'landing_page_view');
      expect(events.last['name'], 'profile_completed');
      expect(events.last['properties']['funnel_step'], 9);
    });

    test('should track funnel with time delays', () async {
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

      final now = DateTime.now();

      // Step 1 at t=0
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'step_1',
        timestamp: now,
        category: 'timed_funnel',
        parameters: {'time_since_previous': 0},
      ));

      // Step 2 at t=30 seconds
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'step_2',
        timestamp: now.add(const Duration(seconds: 30)),
        category: 'timed_funnel',
        parameters: {'time_since_previous': 30},
      ));

      // Step 3 at t=2 minutes
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'step_3',
        timestamp: now.add(const Duration(minutes: 2)),
        category: 'timed_funnel',
        parameters: {'time_since_previous': 90},
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final events = capturedRequests.first['body']['events'] as List;
      expect(events.length, 3);

      // Verify time deltas are captured
      expect(events[1]['properties']['time_since_previous'], 30);
      expect(events[2]['properties']['time_since_previous'], 90);
    });
  });
}
