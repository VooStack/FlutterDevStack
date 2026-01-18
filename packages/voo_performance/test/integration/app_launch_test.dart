import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_performance/src/data/services/performance_cloud_sync.dart';

void main() {
  group('App Launch Metrics Integration Tests', () {
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

    test('should detect cold start correctly', () async {
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

      // Cold start metrics (typically > 500ms)
      syncService.queueMetric(PerformanceMetricData(
        name: 'app_launch',
        metricType: 'timer',
        value: 1250.0, // 1.25 seconds - typical cold start
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {
          'launch_type': 'cold',
          'process_start': 'true',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['name'], 'app_launch');
      expect(metric['value'], 1250.0);
      expect(metric['tags']['launch_type'], 'cold');
    });

    test('should detect warm start correctly', () async {
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

      // Warm start metrics (typically < 500ms)
      syncService.queueMetric(PerformanceMetricData(
        name: 'app_launch',
        metricType: 'timer',
        value: 180.0, // 180ms - typical warm start
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {
          'launch_type': 'warm',
          'from_background': 'true',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['name'], 'app_launch');
      expect(metric['value'], 180.0);
      expect(metric['tags']['launch_type'], 'warm');
    });

    test('should measure time to first frame', () async {
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

      syncService.queueMetric(PerformanceMetricData(
        name: 'time_to_first_frame',
        metricType: 'timer',
        value: 850.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {
          'frame_type': 'first',
          'is_rendered': 'true',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['name'], 'time_to_first_frame');
      expect(metric['unit'], 'ms');
      expect(metric['value'], 850.0);
    });

    test('should measure time to interactive', () async {
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

      syncService.queueMetric(PerformanceMetricData(
        name: 'time_to_interactive',
        metricType: 'timer',
        value: 1500.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {
          'is_interactive': 'true',
          'input_ready': 'true',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['name'], 'time_to_interactive');
      expect(metric['value'], 1500.0);
    });

    test('should capture complete launch sequence', () async {
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

      final launchTime = 1200.0;
      final ttfTime = launchTime + 150.0;
      final ttiTime = ttfTime + 350.0;

      // App launch
      syncService.queueMetric(PerformanceMetricData(
        name: 'app_launch',
        metricType: 'timer',
        value: launchTime,
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {'launch_type': 'cold'},
      ));

      // Time to first frame
      syncService.queueMetric(PerformanceMetricData(
        name: 'time_to_first_frame',
        metricType: 'timer',
        value: ttfTime,
        unit: 'ms',
        timestamp: DateTime.now(),
      ));

      // Time to interactive
      syncService.queueMetric(PerformanceMetricData(
        name: 'time_to_interactive',
        metricType: 'timer',
        value: ttiTime,
        unit: 'ms',
        timestamp: DateTime.now(),
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metrics = capturedRequests.first['body']['metrics'] as List;
      expect(metrics.length, 3);

      // Verify all metrics are present
      final names = metrics.map((m) => m['name']).toList();
      expect(names, contains('app_launch'));
      expect(names, contains('time_to_first_frame'));
      expect(names, contains('time_to_interactive'));

      // Verify timing order
      final appLaunch = metrics.firstWhere((m) => m['name'] == 'app_launch');
      final ttf = metrics.firstWhere((m) => m['name'] == 'time_to_first_frame');
      final tti = metrics.firstWhere((m) => m['name'] == 'time_to_interactive');

      expect(appLaunch['value'] < ttf['value'], isTrue);
      expect(ttf['value'] < tti['value'], isTrue);
    });

    test('should track hot start correctly', () async {
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

      // Hot start (app was running, just resumed)
      syncService.queueMetric(PerformanceMetricData(
        name: 'app_launch',
        metricType: 'timer',
        value: 50.0, // Very fast - just resuming
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {
          'launch_type': 'hot',
          'was_in_memory': 'true',
          'resume_from': 'background',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['launch_type'], 'hot');
      expect(metric['value'], lessThan(100)); // Hot starts are very fast
    });

    test('should track initialization phases', () async {
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

      // Track individual initialization phases
      final phases = {
        'native_init': 200.0,
        'flutter_init': 150.0,
        'widget_build': 100.0,
        'data_load': 250.0,
      };

      for (final entry in phases.entries) {
        syncService.queueMetric(PerformanceMetricData(
          name: 'init_phase',
          metricType: 'timer',
          value: entry.value,
          unit: 'ms',
          timestamp: DateTime.now(),
          tags: {
            'phase': entry.key,
          },
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metrics = capturedRequests.first['body']['metrics'] as List;
      expect(metrics.length, 4);

      // Verify all phases are tracked
      final trackedPhases = metrics.map((m) => m['tags']['phase']).toSet();
      expect(trackedPhases, contains('native_init'));
      expect(trackedPhases, contains('flutter_init'));
      expect(trackedPhases, contains('widget_build'));
      expect(trackedPhases, contains('data_load'));
    });

    test('should include device context in launch metrics', () async {
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
        name: 'app_launch',
        metricType: 'timer',
        value: 1100.0,
        unit: 'ms',
        timestamp: DateTime.now(),
        tags: {
          'launch_type': 'cold',
          'device_class': 'mid_range',
          'memory_at_launch_mb': '512',
          'cpu_count': '4',
          'is_low_end': 'false',
        },
      ));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metric = capturedRequests.first['body']['metrics'][0];
      expect(metric['tags']['device_class'], 'mid_range');
      expect(metric['tags']['memory_at_launch_mb'], '512');
    });

    test('should batch multiple launch sessions', () async {
      final config = PerformanceCloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 20,
      );

      syncService = PerformanceCloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Simulate multiple launches over time
      for (var i = 0; i < 5; i++) {
        final isCold = i % 2 == 0;
        syncService.queueMetric(PerformanceMetricData(
          name: 'app_launch',
          metricType: 'timer',
          value: isCold ? 1000.0 + (i * 100) : 150.0 + (i * 20),
          unit: 'ms',
          timestamp: DateTime.now().add(Duration(minutes: i * 30)),
          tags: {
            'launch_type': isCold ? 'cold' : 'warm',
            'session_number': '$i',
          },
        ));
      }

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final metrics = capturedRequests.first['body']['metrics'] as List;
      expect(metrics.length, 5);

      // Verify cold starts have higher values
      final coldStarts = metrics.where((m) => m['tags']['launch_type'] == 'cold').toList();
      final warmStarts = metrics.where((m) => m['tags']['launch_type'] == 'warm').toList();

      expect(coldStarts.length, 3);
      expect(warmStarts.length, 2);

      // Cold starts should be slower than warm starts
      final avgCold = coldStarts.map((m) => m['value'] as double).reduce((a, b) => a + b) / coldStarts.length;
      final avgWarm = warmStarts.map((m) => m['value'] as double).reduce((a, b) => a + b) / warmStarts.length;
      expect(avgCold, greaterThan(avgWarm));
    });
  });
}
