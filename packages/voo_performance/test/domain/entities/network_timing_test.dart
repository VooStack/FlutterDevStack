import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/domain/entities/network_timing.dart';

void main() {
  group('NetworkTiming', () {
    test('should create with all null values', () {
      const timing = NetworkTiming();

      expect(timing.dnsLookupMs, isNull);
      expect(timing.tcpConnectMs, isNull);
      expect(timing.tlsHandshakeMs, isNull);
      expect(timing.timeToFirstByteMs, isNull);
      expect(timing.contentDownloadMs, isNull);
      expect(timing.connectionReused, isFalse);
      expect(timing.http2Multiplexed, isFalse);
    });

    test('should create with all fields', () {
      const timing = NetworkTiming(
        dnsLookupMs: 10,
        tcpConnectMs: 20,
        tlsHandshakeMs: 30,
        timeToFirstByteMs: 50,
        contentDownloadMs: 100,
        requestQueueMs: 5,
        responseParsingMs: 10,
        connectionReused: true,
        http2Multiplexed: true,
        httpVersion: '2',
        remoteIp: '192.168.1.1',
        remotePort: 443,
        redirectCount: 1,
        redirectTimeMs: 50,
      );

      expect(timing.dnsLookupMs, equals(10));
      expect(timing.tcpConnectMs, equals(20));
      expect(timing.tlsHandshakeMs, equals(30));
      expect(timing.timeToFirstByteMs, equals(50));
      expect(timing.contentDownloadMs, equals(100));
      expect(timing.connectionReused, isTrue);
      expect(timing.http2Multiplexed, isTrue);
      expect(timing.httpVersion, equals('2'));
      expect(timing.remoteIp, equals('192.168.1.1'));
      expect(timing.remotePort, equals(443));
      expect(timing.redirectCount, equals(1));
      expect(timing.redirectTimeMs, equals(50));
    });

    group('connectionSetupMs', () {
      test('should return null when all timing values are null', () {
        const timing = NetworkTiming();

        expect(timing.connectionSetupMs, isNull);
      });

      test('should calculate sum of DNS, TCP, and TLS', () {
        const timing = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          tlsHandshakeMs: 30,
        );

        expect(timing.connectionSetupMs, equals(60));
      });

      test('should handle partial values', () {
        const timing = NetworkTiming(dnsLookupMs: 10, tcpConnectMs: 20);

        expect(timing.connectionSetupMs, equals(30));
      });
    });

    group('requestResponseMs', () {
      test('should return null when both values are null', () {
        const timing = NetworkTiming();

        expect(timing.requestResponseMs, isNull);
      });

      test('should calculate sum of TTFB and content download', () {
        const timing = NetworkTiming(
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
        );

        expect(timing.requestResponseMs, equals(150));
      });
    });

    group('calculatedTotalMs', () {
      test('should return null when no timing data', () {
        const timing = NetworkTiming();

        expect(timing.calculatedTotalMs, isNull);
      });

      test('should calculate total from all phases', () {
        const timing = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          tlsHandshakeMs: 30,
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
          requestQueueMs: 5,
          responseParsingMs: 10,
          redirectTimeMs: 20,
        );

        // 10 + 20 + 30 + 5 + 50 + 100 + 10 + 20 = 245
        expect(timing.calculatedTotalMs, equals(245));
      });
    });

    group('calculateBandwidth', () {
      test('should return null when contentDownloadMs is null', () {
        const timing = NetworkTiming();

        expect(timing.calculateBandwidth(1024), isNull);
      });

      test('should return null when contentDownloadMs is 0', () {
        const timing = NetworkTiming(contentDownloadMs: 0);

        expect(timing.calculateBandwidth(1024), isNull);
      });

      test('should return null when contentSizeBytes is 0', () {
        const timing = NetworkTiming(contentDownloadMs: 100);

        expect(timing.calculateBandwidth(0), isNull);
      });

      test('should calculate bandwidth in KB/s', () {
        const timing = NetworkTiming(contentDownloadMs: 1000); // 1 second

        // 1024 bytes = 1 KB, 1000ms = 1 second, so 1 KB/s
        expect(timing.calculateBandwidth(1024), closeTo(1.0, 0.01));
      });

      test('should calculate bandwidth for larger downloads', () {
        const timing = NetworkTiming(contentDownloadMs: 500); // 0.5 seconds

        // 10240 bytes = 10 KB, 500ms = 0.5 second, so 20 KB/s
        expect(timing.calculateBandwidth(10240), closeTo(20.0, 0.01));
      });
    });

    group('estimatedLatencyMs', () {
      test('should return tcpConnectMs as latency estimate', () {
        const timing = NetworkTiming(tcpConnectMs: 50);

        expect(timing.estimatedLatencyMs, equals(50));
      });

      test('should return null when tcpConnectMs is null', () {
        const timing = NetworkTiming();

        expect(timing.estimatedLatencyMs, isNull);
      });
    });

    group('isCacheHit', () {
      test('should return true when connectionSetupMs is 0 and ttfb is low', () {
        const timing = NetworkTiming(
          dnsLookupMs: 0,
          tcpConnectMs: 0,
          tlsHandshakeMs: 0,
          timeToFirstByteMs: 1,
        );

        expect(timing.isCacheHit, isTrue);
      });

      test('should return false when ttfb is null', () {
        const timing = NetworkTiming();

        expect(timing.isCacheHit, isFalse);
      });

      test('should return false when ttfb is high', () {
        const timing = NetworkTiming(timeToFirstByteMs: 100);

        expect(timing.isCacheHit, isFalse);
      });
    });

    group('fromTotalTime factory', () {
      test('should create timing with estimated breakdown', () {
        final timing = NetworkTiming.fromTotalTime(1000);

        expect(timing.timeToFirstByteMs, isNotNull);
        expect(timing.contentDownloadMs, isNotNull);
      });

      test('should return empty timing for 0 ms', () {
        final timing = NetworkTiming.fromTotalTime(0);

        expect(timing.timeToFirstByteMs, isNull);
        expect(timing.contentDownloadMs, isNull);
      });

      test('should return empty timing for negative ms', () {
        final timing = NetworkTiming.fromTotalTime(-100);

        expect(timing.timeToFirstByteMs, isNull);
        expect(timing.contentDownloadMs, isNull);
      });
    });

    group('reusedConnection factory', () {
      test('should create timing with connectionReused true', () {
        final timing = NetworkTiming.reusedConnection(
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
        );

        expect(timing.timeToFirstByteMs, equals(50));
        expect(timing.contentDownloadMs, equals(100));
        expect(timing.connectionReused, isTrue);
      });
    });

    group('serialization', () {
      test('should serialize to JSON', () {
        const timing = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          tlsHandshakeMs: 30,
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
          connectionReused: true,
          httpVersion: '2',
        );

        final json = timing.toJson();

        expect(json['dns_lookup_ms'], equals(10));
        expect(json['tcp_connect_ms'], equals(20));
        expect(json['tls_handshake_ms'], equals(30));
        expect(json['time_to_first_byte_ms'], equals(50));
        expect(json['content_download_ms'], equals(100));
        expect(json['connection_reused'], isTrue);
        expect(json['http_version'], equals('2'));
      });

      test('should deserialize from JSON', () {
        final json = {
          'dns_lookup_ms': 10,
          'tcp_connect_ms': 20,
          'tls_handshake_ms': 30,
          'time_to_first_byte_ms': 50,
          'content_download_ms': 100,
          'connection_reused': true,
          'http_version': '2',
        };

        final timing = NetworkTiming.fromJson(json);

        expect(timing.dnsLookupMs, equals(10));
        expect(timing.tcpConnectMs, equals(20));
        expect(timing.tlsHandshakeMs, equals(30));
        expect(timing.timeToFirstByteMs, equals(50));
        expect(timing.contentDownloadMs, equals(100));
        expect(timing.connectionReused, isTrue);
        expect(timing.httpVersion, equals('2'));
      });

      test('should round-trip serialize and deserialize', () {
        const original = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          tlsHandshakeMs: 30,
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
          connectionReused: true,
          http2Multiplexed: true,
        );

        final json = original.toJson();
        final restored = NetworkTiming.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        const original = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          connectionReused: false,
        );

        final copy = original.copyWith(dnsLookupMs: 15, connectionReused: true);

        expect(copy.dnsLookupMs, equals(15));
        expect(copy.tcpConnectMs, equals(20));
        expect(copy.connectionReused, isTrue);
      });
    });

    group('equality', () {
      test('should be equal when matching fields', () {
        const timing1 = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          tlsHandshakeMs: 30,
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
          connectionReused: true,
        );
        const timing2 = NetworkTiming(
          dnsLookupMs: 10,
          tcpConnectMs: 20,
          tlsHandshakeMs: 30,
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
          connectionReused: true,
        );

        expect(timing1, equals(timing2));
        expect(timing1.hashCode, equals(timing2.hashCode));
      });

      test('should not be equal when fields differ', () {
        const timing1 = NetworkTiming(dnsLookupMs: 10);
        const timing2 = NetworkTiming(dnsLookupMs: 20);

        expect(timing1, isNot(equals(timing2)));
      });
    });

    group('toString', () {
      test('should have readable format', () {
        const timing = NetworkTiming(
          timeToFirstByteMs: 50,
          contentDownloadMs: 100,
          connectionReused: true,
        );

        final str = timing.toString();

        expect(str, contains('50'));
        expect(str, contains('100'));
        expect(str, contains('true'));
      });
    });
  });
}
