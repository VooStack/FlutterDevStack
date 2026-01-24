import 'package:flutter_test/flutter_test.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

void main() {
  group('Logger', () {
    late TelemetryResource resource;
    late OTLPHttpExporter exporter;
    late TelemetryConfig config;
    late LoggerProvider loggerProvider;
    late Logger logger;

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
      logger = loggerProvider.getLogger('test-logger');
    });

    group('logging methods', () {
      test('should log debug message', () {
        expect(() => logger.debug('Debug message'), returnsNormally);
      });

      test('should log info message', () {
        expect(() => logger.info('Info message'), returnsNormally);
      });

      test('should log warning message', () {
        expect(() => logger.warn('Warning message'), returnsNormally);
      });

      test('should log error message', () {
        expect(() => logger.error('Error message'), returnsNormally);
      });

      test('should log fatal message', () {
        expect(() => logger.fatal('Fatal message'), returnsNormally);
      });
    });

    group('logging with attributes', () {
      test('should log with attributes', () {
        expect(
          () => logger.info(
            'User action',
            attributes: {'user.id': '123', 'action': 'login'},
          ),
          returnsNormally,
        );
      });

      test('should log error with exception details', () {
        expect(
          () => logger.error(
            'Request failed',
            attributes: {
              'exception.type': 'HttpException',
              'exception.message': 'Connection refused',
            },
          ),
          returnsNormally,
        );
      });
    });

    group('log method', () {
      test('should log with specified severity', () {
        expect(
          () => logger.log(SeverityNumber.info, 'Custom log message'),
          returnsNormally,
        );
      });

      test('should log with attributes', () {
        expect(
          () => logger.log(
            SeverityNumber.warn,
            'Warning message',
            attributes: {'custom': 'value'},
          ),
          returnsNormally,
        );
      });

      test('should log with trace context when trace provider is set', () {
        final traceProvider = TraceProvider(
          resource: resource,
          exporter: exporter,
          config: config,
        );
        loggerProvider.traceProvider = traceProvider;

        final tracer = traceProvider.getTracer('test-tracer');
        final span = tracer.startSpan('test-span');

        // Log while span is active - should capture trace context
        expect(
          () => logger.log(SeverityNumber.info, 'Log with trace context'),
          returnsNormally,
        );

        span.end();
        traceProvider.popSpan();
      });
    });
  });
}
