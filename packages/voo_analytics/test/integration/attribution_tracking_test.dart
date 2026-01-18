import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_analytics/src/data/services/analytics_cloud_sync.dart';

void main() {
  group('Attribution Tracking Integration Tests', () {
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

    test('should capture UTM parameters from deep link', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Simulate deep link with UTM parameters
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'deep_link_received',
        timestamp: DateTime.now(),
        category: 'attribution',
        parameters: {
          'utm_source': 'google',
          'utm_medium': 'cpc',
          'utm_campaign': 'spring_sale',
          'utm_term': 'running+shoes',
          'utm_content': 'logolink',
          'deep_link_url': 'myapp://products?utm_source=google&utm_medium=cpc',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['name'], 'deep_link_received');
      expect(event['properties']['utm_source'], 'google');
      expect(event['properties']['utm_medium'], 'cpc');
      expect(event['properties']['utm_campaign'], 'spring_sale');
    });

    test('should attach attribution to events', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 10,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Attribution context
      final attribution = {
        'utm_source': 'facebook',
        'utm_medium': 'social',
        'utm_campaign': 'awareness',
      };

      // Events with attribution attached
      for (var i = 0; i < 3; i++) {
        syncService.queueEvent(AnalyticsEventData(
          eventName: 'screen_view',
          timestamp: DateTime.now(),
          parameters: {
            ...attribution,
            'screen_name': 'screen_$i',
          },
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final events = capturedRequests.first['body']['events'] as List;

      // All events should have attribution
      for (final event in events) {
        expect(event['properties']['utm_source'], 'facebook');
        expect(event['properties']['utm_medium'], 'social');
      }
    });

    test('should track install source', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // First open event with install attribution
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'first_open',
        timestamp: DateTime.now(),
        category: 'lifecycle',
        parameters: {
          'install_source': 'play_store',
          'install_referrer': 'utm_source=google-play&utm_medium=organic',
          'install_time': DateTime.now().toIso8601String(),
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['name'], 'first_open');
      expect(event['properties']['install_source'], 'play_store');
      expect(event['properties']['install_referrer'], isNotNull);
    });

    test('should track campaign attribution', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueEvent(AnalyticsEventData(
        eventName: 'campaign_click',
        timestamp: DateTime.now(),
        category: 'marketing',
        parameters: {
          'campaign_id': 'camp_123',
          'campaign_name': 'Holiday Sale 2024',
          'ad_group_id': 'adg_456',
          'creative_id': 'cr_789',
          'placement': 'instagram_feed',
          'click_id': 'click_abc123',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['properties']['campaign_id'], 'camp_123');
      expect(event['properties']['campaign_name'], 'Holiday Sale 2024');
      expect(event['properties']['placement'], 'instagram_feed');
    });

    test('should track referrer information', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueEvent(AnalyticsEventData(
        eventName: 'app_open',
        timestamp: DateTime.now(),
        category: 'lifecycle',
        parameters: {
          'referrer_url': 'https://www.google.com/search?q=my+app',
          'referrer_host': 'www.google.com',
          'is_organic': true,
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['properties']['referrer_host'], 'www.google.com');
      expect(event['properties']['is_organic'], true);
    });

    test('should persist attribution across sessions', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 10,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // First touch attribution
      final firstTouchAttribution = {
        'first_touch_source': 'facebook',
        'first_touch_medium': 'paid',
        'first_touch_time': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      };

      // Last touch attribution (different)
      final lastTouchAttribution = {
        'last_touch_source': 'google',
        'last_touch_medium': 'organic',
        'last_touch_time': DateTime.now().toIso8601String(),
      };

      // Purchase event with multi-touch attribution
      syncService.queueEvent(AnalyticsEventData(
        eventName: 'purchase',
        timestamp: DateTime.now(),
        category: 'conversion',
        parameters: {
          ...firstTouchAttribution,
          ...lastTouchAttribution,
          'purchase_value': 149.99,
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['properties']['first_touch_source'], 'facebook');
      expect(event['properties']['last_touch_source'], 'google');
    });

    test('should track affiliate attribution', () async {
      final config = AnalyticsCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = AnalyticsCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueEvent(AnalyticsEventData(
        eventName: 'signup',
        timestamp: DateTime.now(),
        category: 'conversion',
        parameters: {
          'affiliate_id': 'aff_12345',
          'affiliate_code': 'PARTNER20',
          'referral_code': 'REF_ABC',
          'promo_code': 'SAVE10',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final event = capturedRequests.first['body']['events'][0];
      expect(event['properties']['affiliate_id'], 'aff_12345');
      expect(event['properties']['affiliate_code'], 'PARTNER20');
    });
  });
}
