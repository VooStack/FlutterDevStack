import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_performance/src/data/services/performance_cloud_sync.dart';

void main() {
  group('PerformanceCloudSyncService Integration Tests', () {
    late PerformanceCloudSyncService syncService;
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

    test('should batch performance metrics correctly', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
        batchInterval: const Duration(hours: 1),
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      for (var i = 0; i < 5; i++) {
        syncService.queueMetric(PerformanceMetricData(
          name: 'test_metric_$i',
          metricType: 'gauge',
          value: i * 10.0,
          unit: 'ms',
          timestamp: DateTime.now(),
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      expect(capturedRequests.first['body']['metrics'].length, 5);
      expect(capturedRequests.first['body']['projectId'], 'test-project');
    });

    test('should batch network metrics correctly', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 3,
        batchInterval: const Duration(hours: 1),
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      for (var i = 0; i < 3; i++) {
        syncService.queueNetworkMetric(NetworkMetricData(
          method: 'GET',
          url: 'https://api.example.com/endpoint$i',
          statusCode: 200,
          duration: 100 + i * 50,
          timestamp: DateTime.now(),
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      expect(capturedRequests.first['body']['networkMetrics'].length, 3);
    });

    test('should include API key in headers', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'my-secret-key',
        projectId: 'project-123',
        batchSize: 1,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueMetric(PerformanceMetricData(
        name: 'test',
        metricType: 'counter',
        value: 1.0,
        unit: 'count',
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(capturedRequests.first['headers']['X-API-Key'], 'my-secret-key');
    });

    test('should not sync when disabled', () async {
      final config = const PerformanceCloudSyncConfig(enabled: false);

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      for (var i = 0; i < 10; i++) {
        syncService.queueMetric(PerformanceMetricData(
          name: 'test',
          metricType: 'gauge',
          value: 1.0,
          unit: 'ms',
          timestamp: DateTime.now(),
        ));
      }

      await syncService.flush();

      expect(requestCount, 0);
    });

    test('should format network metric data correctly', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 1,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueNetworkMetric(NetworkMetricData(
        method: 'POST',
        url: 'https://api.example.com/users',
        statusCode: 201,
        duration: 250,
        requestSize: 1024,
        responseSize: 512,
        timestamp: DateTime.utc(2024, 1, 15, 10, 30),
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      final metric = capturedRequests.first['body']['networkMetrics'][0];
      expect(metric['method'], 'POST');
      expect(metric['url'], 'https://api.example.com/users');
      expect(metric['statusCode'], 201);
      expect(metric['duration'], 250);
      expect(metric['requestSize'], 1024);
      expect(metric['responseSize'], 512);
    });
  });

  group('PerformanceCloudSyncConfig Tests', () {
    test('should validate configuration', () {
      final invalid = const PerformanceCloudSyncConfig(enabled: true);
      expect(invalid.isValid, false);

      final valid = const PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'key',
      );
      expect(valid.isValid, true);
    });

    test('production preset should have correct defaults', () {
      final config = PerformanceCloudSyncConfig.production(
        endpoint: 'https://api.test.com',
        apiKey: 'key',
        projectId: 'project',
      );

      expect(config.enabled, true);
      expect(config.batchSize, 100);
      expect(config.batchInterval, const Duration(seconds: 60));
    });

    test('development preset should have smaller batches', () {
      final config = PerformanceCloudSyncConfig.development(
        endpoint: 'https://api.test.com',
        apiKey: 'key',
        projectId: 'project',
      );

      expect(config.batchSize, 20);
      expect(config.batchInterval, const Duration(seconds: 15));
    });
  });
}
