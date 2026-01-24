import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/interceptors/performance_dio_interceptor_impl.dart';

void main() {
  group('PerformanceDioInterceptorImpl', () {
    group('constructor', () {
      test('should create with default values', () {
        final interceptor = PerformanceDioInterceptorImpl();

        expect(interceptor, isNotNull);
      });

      test('should create with custom values', () {
        final interceptor = PerformanceDioInterceptorImpl(
          enabled: false,
          trackTraces: false,
          trackMetrics: false,
        );

        expect(interceptor, isNotNull);
      });

      test('should create with enabled tracking', () {
        final interceptor = PerformanceDioInterceptorImpl(
          enabled: true,
          trackTraces: true,
          trackMetrics: true,
        );

        expect(interceptor, isNotNull);
      });

      test('should create with only traces enabled', () {
        final interceptor = PerformanceDioInterceptorImpl(
          enabled: true,
          trackTraces: true,
          trackMetrics: false,
        );

        expect(interceptor, isNotNull);
      });

      test('should create with only metrics enabled', () {
        final interceptor = PerformanceDioInterceptorImpl(
          enabled: true,
          trackTraces: false,
          trackMetrics: true,
        );

        expect(interceptor, isNotNull);
      });
    });
  });
}
