import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/domain/entities/network_metric.dart';
import 'package:voo_performance/src/domain/entities/network_timing.dart';

void main() {
  group('NetworkMetric', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();
      final metric = NetworkMetric(
        id: 'test-id',
        url: 'https://api.test.com/endpoint',
        method: 'GET',
        statusCode: 200,
        duration: const Duration(milliseconds: 150),
        timestamp: timestamp,
      );

      expect(metric.id, equals('test-id'));
      expect(metric.url, equals('https://api.test.com/endpoint'));
      expect(metric.method, equals('GET'));
      expect(metric.statusCode, equals(200));
      expect(metric.duration, equals(const Duration(milliseconds: 150)));
      expect(metric.timestamp, equals(timestamp));
    });

    test('should create with all optional fields', () {
      final timestamp = DateTime.now();
      final timing = NetworkTiming(
        dnsLookupMs: 10,
        tcpConnectMs: 20,
        tlsHandshakeMs: 30,
        timeToFirstByteMs: 50,
        contentDownloadMs: 100,
      );

      final metric = NetworkMetric(
        id: 'test-id',
        url: 'https://api.test.com/endpoint',
        method: 'POST',
        statusCode: 201,
        duration: const Duration(milliseconds: 250),
        timestamp: timestamp,
        requestSize: 1024,
        responseSize: 2048,
        metadata: {'key': 'value'},
        timing: timing,
        fromCache: true,
        priority: 'high',
        initiator: 'user',
      );

      expect(metric.requestSize, equals(1024));
      expect(metric.responseSize, equals(2048));
      expect(metric.metadata, equals({'key': 'value'}));
      expect(metric.timing, equals(timing));
      expect(metric.fromCache, isTrue);
      expect(metric.priority, equals('high'));
      expect(metric.initiator, equals('user'));
    });

    group('isError', () {
      test('should return true for 4xx status codes', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 404,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.isError, isTrue);
      });

      test('should return true for 5xx status codes', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 500,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.isError, isTrue);
      });

      test('should return false for 2xx status codes', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.isError, isFalse);
      });
    });

    group('isSuccess', () {
      test('should return true for 2xx status codes', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.isSuccess, isTrue);
      });

      test('should return false for non-2xx status codes', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 404,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.isSuccess, isFalse);
      });
    });

    group('bandwidthKBps', () {
      test('should return null without timing', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
          responseSize: 1024,
        );

        expect(metric.bandwidthKBps, isNull);
      });

      test('should return null without responseSize', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
          timing: NetworkTiming(contentDownloadMs: 100),
        );

        expect(metric.bandwidthKBps, isNull);
      });
    });

    group('timeToFirstByteMs', () {
      test('should return value from timing', () {
        final timing = NetworkTiming(timeToFirstByteMs: 50);
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
          timing: timing,
        );

        expect(metric.timeToFirstByteMs, equals(50));
      });

      test('should return null without timing', () {
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.timeToFirstByteMs, isNull);
      });
    });

    group('serialization', () {
      test('should serialize to map', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final metric = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 150),
          timestamp: timestamp,
          requestSize: 1024,
          responseSize: 2048,
        );

        final map = metric.toMap();

        expect(map['id'], equals('test-id'));
        expect(map['url'], equals('https://api.test.com/endpoint'));
        expect(map['method'], equals('GET'));
        expect(map['status_code'], equals(200));
        expect(map['duration_ms'], equals(150));
        expect(map['timestamp'], equals(timestamp.toIso8601String()));
        expect(map['request_size'], equals(1024));
        expect(map['response_size'], equals(2048));
        expect(map['from_cache'], isFalse);
      });

      test('should deserialize from map', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final map = {
          'id': 'test-id',
          'url': 'https://api.test.com/endpoint',
          'method': 'GET',
          'status_code': 200,
          'duration_ms': 150,
          'timestamp': timestamp.toIso8601String(),
          'request_size': 1024,
          'response_size': 2048,
          'from_cache': true,
        };

        final metric = NetworkMetric.fromMap(map);

        expect(metric.id, equals('test-id'));
        expect(metric.url, equals('https://api.test.com/endpoint'));
        expect(metric.method, equals('GET'));
        expect(metric.statusCode, equals(200));
        expect(metric.duration.inMilliseconds, equals(150));
        expect(metric.timestamp, equals(timestamp));
        expect(metric.requestSize, equals(1024));
        expect(metric.responseSize, equals(2048));
        expect(metric.fromCache, isTrue);
      });

      test('should round-trip serialize and deserialize', () {
        final original = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'POST',
          statusCode: 201,
          duration: const Duration(milliseconds: 250),
          timestamp: DateTime.now(),
          requestSize: 1024,
          responseSize: 2048,
          priority: 'high',
        );

        final map = original.toMap();
        final restored = NetworkMetric.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.url, equals(original.url));
        expect(restored.method, equals(original.method));
        expect(restored.statusCode, equals(original.statusCode));
        expect(restored.duration, equals(original.duration));
        expect(restored.requestSize, equals(original.requestSize));
        expect(restored.responseSize, equals(original.responseSize));
        expect(restored.priority, equals(original.priority));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        final copy = original.copyWith(statusCode: 201, method: 'POST');

        expect(copy.id, equals(original.id));
        expect(copy.url, equals(original.url));
        expect(copy.method, equals('POST'));
        expect(copy.statusCode, equals(201));
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final metric1 = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: timestamp,
        );
        final metric2 = NetworkMetric(
          id: 'test-id',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: timestamp,
        );

        expect(metric1, equals(metric2));
      });

      test('should not be equal when fields differ', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final metric1 = NetworkMetric(
          id: 'test-id-1',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: timestamp,
        );
        final metric2 = NetworkMetric(
          id: 'test-id-2',
          url: 'https://api.test.com/endpoint',
          method: 'GET',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
          timestamp: timestamp,
        );

        expect(metric1, isNot(equals(metric2)));
      });
    });
  });
}
