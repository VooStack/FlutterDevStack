import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/data/services/fps_monitor_service.dart';
import 'package:voo_performance/src/data/services/memory_monitor_service.dart';
import 'package:voo_performance/src/data/services/app_launch_service.dart';
import 'package:voo_performance/src/domain/entities/network_metric.dart';
import 'package:voo_performance/src/domain/entities/performance_trace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Monitoring Integration', () {
    setUp(() {
      FpsMonitorService.reset();
      MemoryMonitorService.reset();
      AppLaunchService.reset();
    });

    tearDown(() {
      FpsMonitorService.reset();
      MemoryMonitorService.reset();
      AppLaunchService.reset();
    });

    group('Service Lifecycle', () {
      test('should initialize all services without conflict', () async {
        // Initialize all services
        await MemoryMonitorService.initialize();
        await AppLaunchService.initialize();

        FpsMonitorService.startMonitoring();
        MemoryMonitorService.startMonitoring();

        expect(FpsMonitorService.isMonitoring, isTrue);
        expect(MemoryMonitorService.isMonitoring, isTrue);
        expect(MemoryMonitorService.isInitialized, isTrue);
        expect(AppLaunchService.isInitialized, isTrue);
      });

      test('should stop all services cleanly', () async {
        // Initialize and start
        await MemoryMonitorService.initialize();
        await AppLaunchService.initialize();
        FpsMonitorService.startMonitoring();
        MemoryMonitorService.startMonitoring();

        // Stop all
        FpsMonitorService.stopMonitoring();
        MemoryMonitorService.stopMonitoring();

        expect(FpsMonitorService.isMonitoring, isFalse);
        expect(MemoryMonitorService.isMonitoring, isFalse);
      });

      test('should reset all services', () async {
        // Initialize and start
        await MemoryMonitorService.initialize();
        FpsMonitorService.startMonitoring();
        MemoryMonitorService.startMonitoring();

        // Reset all
        FpsMonitorService.reset();
        MemoryMonitorService.reset();
        AppLaunchService.reset();

        expect(FpsMonitorService.isMonitoring, isFalse);
        expect(MemoryMonitorService.isMonitoring, isFalse);
        expect(MemoryMonitorService.isInitialized, isFalse);
        expect(AppLaunchService.isInitialized, isFalse);
      });
    });

    group('Performance Trace', () {
      test('should track complete request lifecycle', () async {
        final trace = PerformanceTrace(
          name: 'api_request',
          startTime: DateTime.now(),
        );

        trace.putAttribute('url', 'https://api.example.com/data');
        trace.putAttribute('method', 'GET');
        trace.putMetric('retry_count', 0);

        await Future.delayed(const Duration(milliseconds: 50));

        trace.putMetric('response_size', 1024);
        trace.stop();

        expect(trace.isRunning, isFalse);
        expect(trace.duration, isNotNull);
        expect(trace.duration!.inMilliseconds, greaterThanOrEqualTo(50));
        expect(trace.attributes['url'], equals('https://api.example.com/data'));
        expect(trace.metrics['response_size'], equals(1024));
      });

      test('should track nested traces', () async {
        final parentTrace = PerformanceTrace(
          name: 'parent_operation',
          startTime: DateTime.now(),
        );

        await Future.delayed(const Duration(milliseconds: 10));

        final childTrace = PerformanceTrace(
          name: 'child_operation',
          startTime: DateTime.now(),
        );

        await Future.delayed(const Duration(milliseconds: 20));
        childTrace.stop();

        await Future.delayed(const Duration(milliseconds: 10));
        parentTrace.stop();

        expect(parentTrace.duration!.inMilliseconds,
            greaterThan(childTrace.duration!.inMilliseconds));
      });
    });

    group('Network Metrics', () {
      test('should track successful request metrics', () {
        final metric = NetworkMetric(
          id: 'req-1',
          url: 'https://api.example.com/users',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 150),
          timestamp: DateTime.now(),
          requestSize: 256,
          responseSize: 2048,
        );

        expect(metric.isSuccess, isTrue);
        expect(metric.isError, isFalse);
        expect(metric.duration.inMilliseconds, equals(150));
      });

      test('should track failed request metrics', () {
        final metric = NetworkMetric(
          id: 'req-2',
          url: 'https://api.example.com/users',
          method: 'GET',
          statusCode: 500,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.isSuccess, isFalse);
        expect(metric.isError, isTrue);
      });

      test('should serialize and deserialize network metrics', () {
        final original = NetworkMetric(
          id: 'req-3',
          url: 'https://api.example.com/posts',
          method: 'POST',
          statusCode: 201,
          duration: const Duration(milliseconds: 250),
          timestamp: DateTime.now(),
          requestSize: 1024,
          responseSize: 512,
          fromCache: false,
          priority: 'high',
        );

        final map = original.toMap();
        final restored = NetworkMetric.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.url, equals(original.url));
        expect(restored.method, equals(original.method));
        expect(restored.statusCode, equals(original.statusCode));
        expect(restored.duration, equals(original.duration));
      });
    });

    group('Concurrent Monitoring', () {
      test('should handle concurrent memory snapshots', () async {
        await MemoryMonitorService.initialize();

        // Take multiple snapshots concurrently
        final futures = List.generate(5, (_) {
          return MemoryMonitorService.takeSnapshot();
        });

        await Future.wait(futures);

        expect(MemoryMonitorService.history.length, greaterThanOrEqualTo(5));
      });

      test('should handle rapid trace start/stop', () async {
        final traces = <PerformanceTrace>[];

        for (int i = 0; i < 10; i++) {
          final trace = PerformanceTrace(
            name: 'rapid_trace_$i',
            startTime: DateTime.now(),
          );
          traces.add(trace);
        }

        // Stop in reverse order
        for (final trace in traces.reversed) {
          await Future.delayed(const Duration(milliseconds: 1));
          trace.stop();
        }

        for (final trace in traces) {
          expect(trace.isRunning, isFalse);
          expect(trace.duration, isNotNull);
        }
      });
    });

    group('Error Handling', () {
      test('should handle trace stop callback errors gracefully', () {
        final trace = PerformanceTrace(
          name: 'callback_error_trace',
          startTime: DateTime.now(),
        );

        trace.setStopCallback((_) {
          throw Exception('Callback error');
        });

        // Should throw because callback throws
        expect(() => trace.stop(), throwsException);
      });

      test('should handle double stop error', () {
        final trace = PerformanceTrace(
          name: 'double_stop_trace',
          startTime: DateTime.now(),
        );

        trace.stop();

        expect(() => trace.stop(), throwsStateError);
      });
    });
  });
}
