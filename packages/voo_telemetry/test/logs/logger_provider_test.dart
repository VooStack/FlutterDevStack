import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('LoggerProvider', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late LoggerProvider loggerProvider;

    setUp(() {
      resource = TelemetryResource(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
      exporter = OTLPHttpExporter(endpoint: 'https://test.com');
      config = TelemetryConfig(endpoint: 'https://test.com');
      loggerProvider = LoggerProvider(
        resource: resource,
        exporter: exporter,
        config: config,
      );
    });

    group('initialization', () {
      test('should create with required parameters', () {
        expect(loggerProvider, isNotNull);
      });

      test('should initialize without error', () async {
        await expectLater(loggerProvider.initialize(), completes);
      });
    });

    group('getLogger', () {
      test('should create a new logger', () {
        final logger = loggerProvider.getLogger('test-logger');

        expect(logger, isNotNull);
        expect(logger.name, equals('test-logger'));
      });

      test('should return same logger for same name', () {
        final logger1 = loggerProvider.getLogger('test-logger');
        final logger2 = loggerProvider.getLogger('test-logger');

        expect(identical(logger1, logger2), isTrue);
      });

      test('should return different loggers for different names', () {
        final logger1 = loggerProvider.getLogger('logger-1');
        final logger2 = loggerProvider.getLogger('logger-2');

        expect(identical(logger1, logger2), isFalse);
      });
    });

    group('traceProvider', () {
      test('should accept trace provider for correlation', () {
        final traceProvider = TraceProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );

        loggerProvider.traceProvider = traceProvider;

        expect(loggerProvider.traceProvider, equals(traceProvider));
      });
    });

    group('addLogRecord', () {
      test('should add log record without error', () {
        final logRecord = LogRecord(
          body: 'Test log message',
          severityNumber: SeverityNumber.info,
          severityText: 'INFO',
        );

        expect(() => loggerProvider.addLogRecord(logRecord), returnsNormally);
      });

      test('should add error log record without error', () {
        final logRecord = LogRecord(
          body: 'Error occurred',
          severityNumber: SeverityNumber.error,
          severityText: 'ERROR',
          attributes: {'exception.type': 'TestException'},
        );

        expect(() => loggerProvider.addLogRecord(logRecord), returnsNormally);
      });
    });

    group('flush', () {
      test('should flush without error when no pending logs', () async {
        await expectLater(loggerProvider.flush(), completes);
      });

      test('should flush pending logs', () async {
        final logRecord = LogRecord(
          body: 'Test message',
          severityNumber: SeverityNumber.info,
          severityText: 'INFO',
        );
        loggerProvider.addLogRecord(logRecord);

        await expectLater(loggerProvider.flush(), completes);
      });
    });

    group('shutdown', () {
      test('should shutdown without error', () async {
        await expectLater(loggerProvider.shutdown(), completes);
      });
    });
  });
}
