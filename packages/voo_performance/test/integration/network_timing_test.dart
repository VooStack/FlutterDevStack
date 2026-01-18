import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_performance/src/data/services/performance_cloud_sync.dart';

void main() {
  group('Network Timing Integration Tests', () {
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

    test('should capture DNS lookup time', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 350.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/users',
        tags: {
          'dns_lookup_ms': '25',
          'phase': 'dns',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['dns_lookup_ms'], '25');
      expect(metric['endpoint'], '/api/v1/users');
    });

    test('should capture TCP connection time', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 450.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/products',
        tags: {
          'tcp_connect_ms': '45',
          'phase': 'tcp',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['tcp_connect_ms'], '45');
    });

    test('should capture TLS handshake time', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 550.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/auth',
        tags: {
          'tls_handshake_ms': '85',
          'phase': 'tls',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['tls_handshake_ms'], '85');
    });

    test('should capture time to first byte (TTFB)', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 320.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/data',
        tags: {
          'ttfb_ms': '180',
          'phase': 'ttfb',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['ttfb_ms'], '180');
    });

    test('should capture full network timing breakdown', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Complete timing breakdown
      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 650.0, // Total time
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/orders',
        tags: {
          'dns_lookup_ms': '25',
          'tcp_connect_ms': '45',
          'tls_handshake_ms': '85',
          'ttfb_ms': '350',
          'content_download_ms': '145',
          'method': 'POST',
          'status_code': '200',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['name'], 'http_request');
      expect(metric['value'], 650.0);
      expect(metric['tags']['dns_lookup_ms'], '25');
      expect(metric['tags']['tcp_connect_ms'], '45');
      expect(metric['tags']['tls_handshake_ms'], '85');
      expect(metric['tags']['ttfb_ms'], '350');
      expect(metric['tags']['content_download_ms'], '145');

      // Verify timing adds up approximately
      final dns = int.parse(metric['tags']['dns_lookup_ms'] as String);
      final tcp = int.parse(metric['tags']['tcp_connect_ms'] as String);
      final tls = int.parse(metric['tags']['tls_handshake_ms'] as String);
      final ttfb = int.parse(metric['tags']['ttfb_ms'] as String);
      final download = int.parse(metric['tags']['content_download_ms'] as String);
      expect(dns + tcp + tls + ttfb + download, 650);
    });

    test('should track multiple endpoint timings', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 10,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      final endpoints = ['/api/v1/users', '/api/v1/products', '/api/v1/orders'];

      for (var i = 0; i < endpoints.length; i++) {
        syncService.queueMetric(PerformanceMetricData(
          name: 'http_request',
          metricType: 'timer',
          value: 200.0 + (i * 100),
          unit: 'ms',
          timestamp: DateTime.now(),
          endpoint: endpoints[i],
          tags: {
            'dns_lookup_ms': '${15 + i * 5}',
            'ttfb_ms': '${100 + i * 50}',
          },
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metrics = capturedRequests.first['body']['metrics'] as List;
      expect(metrics.length, 3);

      // Verify different endpoints
      expect(metrics[0]['endpoint'], '/api/v1/users');
      expect(metrics[1]['endpoint'], '/api/v1/products');
      expect(metrics[2]['endpoint'], '/api/v1/orders');
    });

    test('should capture slow request metrics', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // A slow request
      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 5000.0, // 5 seconds - very slow
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/analytics',
        tags: {
          'dns_lookup_ms': '50',
          'tcp_connect_ms': '200',
          'tls_handshake_ms': '300',
          'ttfb_ms': '4000', // Main bottleneck
          'content_download_ms': '450',
          'is_slow': 'true',
          'threshold_exceeded': '3000',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['value'], 5000.0);
      expect(metric['tags']['is_slow'], 'true');
      expect(metric['tags']['ttfb_ms'], '4000'); // TTFB is the bottleneck
    });

    test('should track request errors with timing', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // A failed request
      syncService.queueMetric(PerformanceMetricData(
        name: 'http_request',
        metricType: 'timer',
        value: 30000.0, // Timeout
        unit: 'ms',
        timestamp: DateTime.now(),
        endpoint: '/api/v1/timeout',
        tags: {
          'dns_lookup_ms': '25',
          'tcp_connect_ms': '45',
          'status_code': '0', // No response
          'error': 'connection_timeout',
          'is_error': 'true',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['is_error'], 'true');
      expect(metric['tags']['error'], 'connection_timeout');
      expect(metric['tags']['status_code'], '0');
    });
  });
}
