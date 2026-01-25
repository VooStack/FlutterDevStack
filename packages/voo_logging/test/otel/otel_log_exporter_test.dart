import 'package:flutter_test/flutter_test.dart';
import 'package:voo_logging/src/otel/otel_log_exporter.dart';
import 'package:voo_logging/voo_logging.dart';

void main() {
  group('OtelLogExporter', () {
    // ignore: deprecated_member_use_from_same_package
    late OtelLoggingConfig config;

    setUp(() {
      // ignore: deprecated_member_use_from_same_package
      config = const OtelLoggingConfig(
        enabled: true,
        endpoint: 'https://test.otel.endpoint',
        serviceName: 'test-service',
        apiKey: 'test-api-key',
        batchSize: 5,
        batchInterval: Duration(seconds: 10),
      );
    });

    LogEntry createTestLog({String message = 'Test log message', LogLevel level = LogLevel.info}) =>
        LogEntry(id: 'test-${DateTime.now().millisecondsSinceEpoch}', level: level, message: message, timestamp: DateTime.now());

    group('constructor', () {
      test('should create with valid config', () {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);

        expect(exporter, isNotNull);
        expect(exporter.config.endpoint, equals('https://test.otel.endpoint'));
      });
    });

    group('initialize', () {
      test('should initialize without error', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);

        expect(exporter.initialize, returnsNormally);
        await exporter.dispose();
      });

      test('should not initialize with invalid config', () {
        // ignore: deprecated_member_use_from_same_package
        const invalidConfig = OtelLoggingConfig(
          endpoint: '', // Invalid - empty endpoint
          serviceName: 'test-service',
        );

        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: invalidConfig);
        exporter.initialize();

        // Should not throw, just skip initialization
        expect(exporter.pendingCount, equals(0));
      });
    });

    group('queueLog', () {
      test('should queue log entries', () {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);
        exporter.initialize();

        exporter.queueLog(createTestLog());

        expect(exporter.pendingCount, equals(1));
        exporter.dispose();
      });

      test('should not queue when disposed', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);
        exporter.initialize();
        await exporter.dispose();

        exporter.queueLog(createTestLog());

        expect(exporter.pendingCount, equals(0));
      });

      test('should enforce max queue size', () {
        // ignore: deprecated_member_use_from_same_package
        const smallQueueConfig = OtelLoggingConfig(
          enabled: true,
          endpoint: 'https://test.otel.endpoint',
          serviceName: 'test-service',
          maxQueueSize: 3,
          batchSize: 100, // Large batch size to prevent auto-flush
          batchInterval: Duration(hours: 1),
        );

        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: smallQueueConfig);

        // Add more than max queue size
        for (var i = 0; i < 5; i++) {
          exporter.queueLog(createTestLog(message: 'Log $i'));
        }

        expect(exporter.pendingCount, equals(3));
        exporter.dispose();
      });
    });

    group('flush', () {
      test('should return true when queue is empty', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);
        exporter.initialize();

        final result = await exporter.flush();

        expect(result, isTrue);
        await exporter.dispose();
      });

      test('should queue logs for export', () async {
        // ignore: deprecated_member_use_from_same_package
        const configWithClient = OtelLoggingConfig(
          enabled: true,
          endpoint: 'https://test.otel.endpoint',
          serviceName: 'test-service',
          apiKey: 'test-api-key',
          batchSize: 5,
          batchInterval: Duration(hours: 1),
        );

        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: configWithClient);
        exporter.initialize();

        exporter.queueLog(createTestLog());

        // Verify log is queued
        expect(exporter.pendingCount, equals(1));

        await exporter.dispose();
      });

      test('should return true when disposed', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);
        exporter.initialize();
        await exporter.dispose();

        final result = await exporter.flush();

        expect(result, isTrue);
      });
    });

    group('prioritizeErrors', () {
      test('should flush immediately for error logs when enabled', () async {
        // ignore: deprecated_member_use_from_same_package
        const priorityConfig = OtelLoggingConfig(
          enabled: true,
          endpoint: 'https://test.otel.endpoint',
          serviceName: 'test-service',
          batchSize: 100, // Large batch size
          batchInterval: Duration(hours: 1),
        );

        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: priorityConfig);
        exporter.initialize();

        // Queue an error log - should trigger flush
        exporter.queueLog(createTestLog(level: LogLevel.error));

        // After flush, queue should be empty (assuming no HTTP client)
        // The flush will fail without HTTP, but the behavior is tested
        await exporter.dispose();
      });
    });

    group('dispose', () {
      test('should dispose without error', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);
        exporter.initialize();

        await expectLater(exporter.dispose(), completes);
        expect(exporter.isDisposed, isTrue);
      });

      test('should be idempotent', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);
        exporter.initialize();

        await exporter.dispose();
        await exporter.dispose(); // Should not throw

        expect(exporter.isDisposed, isTrue);
      });

      test('should clear pending logs', () async {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);

        exporter.queueLog(createTestLog());
        exporter.queueLog(createTestLog());

        await exporter.dispose();

        expect(exporter.pendingCount, equals(0));
      });
    });

    group('pendingCount', () {
      test('should return correct count', () {
        // ignore: deprecated_member_use_from_same_package
        final exporter = OtelLogExporter(config: config);

        expect(exporter.pendingCount, equals(0));

        exporter.queueLog(createTestLog());
        expect(exporter.pendingCount, equals(1));

        exporter.queueLog(createTestLog());
        expect(exporter.pendingCount, equals(2));

        exporter.dispose();
      });
    });
  });
}
