import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/domain/entities/performance_trace.dart';

void main() {
  group('PerformanceTrace', () {
    test('should create with required fields', () {
      final startTime = DateTime.now();
      final trace = PerformanceTrace(name: 'test_trace', startTime: startTime);

      expect(trace.name, equals('test_trace'));
      expect(trace.startTime, equals(startTime));
      expect(trace.id, contains('test_trace'));
      expect(trace.endTime, isNull);
      expect(trace.attributes, isEmpty);
      expect(trace.metrics, isEmpty);
    });

    test('should generate unique id', () {
      final trace1 = PerformanceTrace(name: 'trace', startTime: DateTime.now());
      final trace2 = PerformanceTrace(name: 'trace', startTime: DateTime.now());

      expect(trace1.id, isNot(equals(trace2.id)));
    });

    group('duration', () {
      test('should return null when trace not ended', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());

        expect(trace.duration, isNull);
      });

      test('should return duration after stop', () async {
        final startTime = DateTime.now();
        final trace = PerformanceTrace(name: 'test', startTime: startTime);

        await Future.delayed(const Duration(milliseconds: 50));
        trace.stop();

        expect(trace.duration, isNotNull);
        expect(trace.duration!.inMilliseconds, greaterThanOrEqualTo(50));
      });
    });

    group('isRunning', () {
      test('should return true when trace not ended', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());

        expect(trace.isRunning, isTrue);
      });

      test('should return false after stop', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(trace.isRunning, isFalse);
      });
    });

    group('start', () {
      test('should throw when already stopped', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(() => trace.start(), throwsStateError);
      });
    });

    group('stop', () {
      test('should set end time', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(trace.endTime, isNotNull);
      });

      test('should throw when already stopped', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(() => trace.stop(), throwsStateError);
      });

      test('should call stop callback', () {
        bool callbackCalled = false;
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.setStopCallback((_) => callbackCalled = true);
        trace.stop();

        expect(callbackCalled, isTrue);
      });

      test('should pass trace to stop callback', () {
        PerformanceTrace? receivedTrace;
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.setStopCallback((t) => receivedTrace = t);
        trace.stop();

        expect(receivedTrace, equals(trace));
      });
    });

    group('putAttribute', () {
      test('should add attribute', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.putAttribute('key', 'value');

        expect(trace.attributes['key'], equals('value'));
      });

      test('should overwrite existing attribute', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.putAttribute('key', 'value1');
        trace.putAttribute('key', 'value2');

        expect(trace.attributes['key'], equals('value2'));
      });

      test('should throw when trace completed', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(() => trace.putAttribute('key', 'value'), throwsStateError);
      });
    });

    group('putMetric', () {
      test('should add metric', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.putMetric('counter', 10);

        expect(trace.metrics['counter'], equals(10));
      });

      test('should overwrite existing metric', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.putMetric('counter', 10);
        trace.putMetric('counter', 20);

        expect(trace.metrics['counter'], equals(20));
      });

      test('should throw when trace completed', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(() => trace.putMetric('counter', 10), throwsStateError);
      });
    });

    group('incrementMetric', () {
      test('should increment new metric from 0', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.incrementMetric('counter');

        expect(trace.metrics['counter'], equals(1));
      });

      test('should increment existing metric', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.putMetric('counter', 5);
        trace.incrementMetric('counter');

        expect(trace.metrics['counter'], equals(6));
      });

      test('should increment by specified value', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.incrementMetric('counter', 10);

        expect(trace.metrics['counter'], equals(10));
      });

      test('should throw when trace completed', () {
        final trace = PerformanceTrace(name: 'test', startTime: DateTime.now());
        trace.stop();

        expect(() => trace.incrementMetric('counter'), throwsStateError);
      });
    });

    group('toMap', () {
      test('should serialize running trace', () {
        final startTime = DateTime(2024, 1, 1, 12, 0, 0);
        final trace = PerformanceTrace(name: 'test', startTime: startTime);
        trace.putAttribute('attr1', 'value1');
        trace.putMetric('metric1', 100);

        final map = trace.toMap();

        expect(map['id'], contains('test'));
        expect(map['name'], equals('test'));
        expect(map['start_time'], equals(startTime.toIso8601String()));
        expect(map['end_time'], isNull);
        expect(map['duration_ms'], isNull);
        expect(map['attributes'], equals({'attr1': 'value1'}));
        expect(map['metrics'], equals({'metric1': 100}));
      });

      test('should serialize completed trace', () {
        final startTime = DateTime(2024, 1, 1, 12, 0, 0);
        final trace = PerformanceTrace(name: 'test', startTime: startTime);
        trace.stop();

        final map = trace.toMap();

        expect(map['end_time'], isNotNull);
        expect(map['duration_ms'], isNotNull);
      });
    });
  });
}
