import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_logging/features/logging/data/services/cloud_sync_service.dart';
import 'package:voo_logging/features/logging/domain/entities/cloud_sync_config.dart';
import 'package:voo_logging/features/logging/domain/entities/log_entry.dart';
import 'package:voo_logging/core/domain/enums/log_level.dart';

void main() {
  group('Error Fingerprinting Integration Tests', () {
    late CloudSyncService syncService;
    late List<Map<String, dynamic>> capturedRequests;
    late int requestCount;

    setUp(() {
      capturedRequests = [];
      requestCount = 0;
    });

    tearDown(() {
      syncService.dispose();
    });

    MockClient createMockClient({int statusCode = 200}) => MockClient((request) async {
      requestCount++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      capturedRequests.add({'url': request.url.toString(), 'headers': request.headers, 'body': body});
      return http.Response('{"success": true}', statusCode);
    });

    test('should include error fingerprint data in logs', () async {
      const config = CloudSyncConfig(enabled: true, endpoint: 'https://api.test.com', apiKey: 'test-key', projectId: 'test-project', batchSize: 5);

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      syncService.queueLog(
        LogEntry(
          id: 'error-1',
          timestamp: DateTime.now(),
          message: 'NullPointerException: Object reference not set',
          level: LogLevel.error,
          category: 'Runtime',
          tag: 'CrashHandler',
          metadata: const {
            'error_type': 'NullPointerException',
            'stack_trace': '''
at com.example.MainActivity.onCreate(MainActivity.java:42)
at android.app.Activity.performCreate(Activity.java:8000)
at android.app.ActivityThread.performLaunchActivity(ActivityThread.java:3400)
''',
            'file': 'MainActivity.java',
            'line': 42,
            'is_fatal': true,
          },
        ),
      );

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final log = capturedRequests.first['body']['logs'][0];
      expect(log['level'], 'error');
      expect(log['context']['error_type'], 'NullPointerException');
      expect(log['context']['stack_trace'], isNotNull);
      expect(log['context']['is_fatal'], true);
    });

    test('should include stack trace for grouping', () async {
      const config = CloudSyncConfig(enabled: true, endpoint: 'https://api.test.com', apiKey: 'test-key', projectId: 'test-project', batchSize: 5);

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      const stackTrace = '''
at package:my_app/services/api_service.dart:145:12
at package:my_app/features/home/bloc/home_bloc.dart:78:5
at package:bloc/src/bloc.dart:234:22
''';

      syncService.queueLog(
        LogEntry(
          id: 'error-stack',
          timestamp: DateTime.now(),
          message: 'API request failed',
          level: LogLevel.error,
          category: 'Network',
          metadata: const {'error_type': 'HttpException', 'stack_trace': stackTrace, 'method': 'fetchData', 'file': 'api_service.dart', 'line': 145},
        ),
      );

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final log = capturedRequests.first['body']['logs'][0];
      expect(log['context']['stack_trace'], contains('api_service.dart:145'));
      expect(log['context']['file'], 'api_service.dart');
      expect(log['context']['line'], 145);
    });

    test('should group similar errors together', () async {
      const config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 3,
        prioritizeErrors: false, // Disable to allow proper batching
      );

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      // Same error occurring multiple times
      for (var i = 0; i < 3; i++) {
        syncService.queueLog(
          LogEntry(
            id: 'same-error-$i',
            timestamp: DateTime.now().add(Duration(seconds: i)),
            message: 'Database connection failed',
            level: LogLevel.error,
            category: 'Database',
            metadata: {
              'error_type': 'ConnectionException',
              'stack_trace': '''
at package:my_app/data/database.dart:89:8
at package:my_app/repositories/user_repository.dart:34:12
''',
              'occurrence': i + 1,
            },
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 200));

      expect(requestCount, greaterThanOrEqualTo(1));

      // Collect all logs from all requests
      final allLogs = <dynamic>[];
      for (final request in capturedRequests) {
        final logs = request['body']['logs'] as List;
        allLogs.addAll(logs);
      }
      expect(allLogs.length, 3);

      // All logs should have same error type and similar stack trace
      for (final log in allLogs) {
        expect(log['context']['error_type'], 'ConnectionException');
        expect(log['context']['stack_trace'], contains('database.dart:89'));
      }
    });

    test('should differentiate errors by type', () async {
      const config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 3,
        prioritizeErrors: false, // Disable to allow proper batching
      );

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      // Different error types
      syncService.queueLog(
        LogEntry(
          id: 'error-null',
          timestamp: DateTime.now(),
          message: 'Null reference error',
          level: LogLevel.error,
          category: 'Runtime',
          metadata: const {'error_type': 'NullPointerException', 'file': 'user_service.dart', 'line': 45},
        ),
      );

      syncService.queueLog(
        LogEntry(
          id: 'error-http',
          timestamp: DateTime.now(),
          message: 'HTTP 500 error',
          level: LogLevel.error,
          category: 'Network',
          metadata: const {'error_type': 'HttpException', 'file': 'api_client.dart', 'line': 123},
        ),
      );

      syncService.queueLog(
        LogEntry(
          id: 'error-format',
          timestamp: DateTime.now(),
          message: 'Invalid date format',
          level: LogLevel.error,
          category: 'Parsing',
          metadata: const {'error_type': 'FormatException', 'file': 'date_parser.dart', 'line': 67},
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(requestCount, greaterThanOrEqualTo(1));

      // Collect all logs from all requests
      final allLogs = <dynamic>[];
      for (final request in capturedRequests) {
        final logs = request['body']['logs'] as List;
        allLogs.addAll(logs);
      }
      expect(allLogs.length, 3);

      // Verify different error types
      final errorTypes = allLogs.map((l) => l['context']['error_type']).toSet();
      expect(errorTypes, contains('NullPointerException'));
      expect(errorTypes, contains('HttpException'));
      expect(errorTypes, contains('FormatException'));
    });

    test('should include breadcrumbs with errors', () async {
      const config = CloudSyncConfig(enabled: true, endpoint: 'https://api.test.com', apiKey: 'test-key', projectId: 'test-project', batchSize: 5);

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      syncService.queueLog(
        LogEntry(
          id: 'error-with-breadcrumbs',
          timestamp: DateTime.now(),
          message: 'Payment failed',
          level: LogLevel.error,
          category: 'Billing',
          metadata: const {
            'error_type': 'PaymentException',
            'breadcrumbs': [
              {'type': 'navigation', 'message': 'Opened Cart Page', 'timestamp': '2024-01-15T10:00:00Z'},
              {'type': 'user', 'message': 'Clicked Checkout', 'timestamp': '2024-01-15T10:01:00Z'},
              {'type': 'http', 'message': 'POST /api/payment', 'timestamp': '2024-01-15T10:01:30Z'},
              {'type': 'error', 'message': 'Payment declined', 'timestamp': '2024-01-15T10:01:35Z'},
            ],
          },
        ),
      );

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final log = capturedRequests.first['body']['logs'][0];
      expect(log['context']['breadcrumbs'], isNotNull);
      expect(log['context']['breadcrumbs'].length, 4);
    });

    test('should track error severity correctly', () async {
      const config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 2,
        prioritizeErrors: false, // Disable to allow proper batching
      );

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      // Non-fatal error
      syncService.queueLog(
        LogEntry(
          id: 'error-non-fatal',
          timestamp: DateTime.now(),
          message: 'Image load failed',
          level: LogLevel.error,
          metadata: const {'error_type': 'NetworkImageException', 'is_fatal': false, 'severity': 'low'},
        ),
      );

      // Fatal error
      syncService.queueLog(
        LogEntry(
          id: 'error-fatal',
          timestamp: DateTime.now(),
          message: 'App crash',
          level: LogLevel.fatal,
          metadata: const {'error_type': 'FlutterError', 'is_fatal': true, 'severity': 'critical'},
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(requestCount, greaterThanOrEqualTo(1));

      // Collect all logs from all requests
      final allLogs = <dynamic>[];
      for (final request in capturedRequests) {
        final logs = request['body']['logs'] as List;
        allLogs.addAll(logs);
      }
      expect(allLogs.length, 2);

      final nonFatal = allLogs.firstWhere((l) => l['context']['is_fatal'] == false);
      final fatal = allLogs.firstWhere((l) => l['context']['is_fatal'] == true);

      expect(nonFatal['context']['severity'], 'low');
      expect(fatal['context']['severity'], 'critical');
    });

    test('should include affected user count data', () async {
      const config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test-project',
        batchSize: 5,
        prioritizeErrors: false, // Disable error prioritization for batching test
      );

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      // Warnings (not errors) from different users to test batching
      for (var i = 0; i < 5; i++) {
        syncService.queueLog(
          LogEntry(
            id: 'user-warning-$i',
            timestamp: DateTime.now(),
            message: 'Session expiring soon',
            level: LogLevel.warning,
            metadata: {'warning_type': 'SessionWarning', 'user_id': 'user_$i', 'session_id': 'session_$i'},
          ),
        );
      }

      // Wait for batch to trigger automatically
      await Future.delayed(const Duration(milliseconds: 200));

      expect(requestCount, greaterThanOrEqualTo(1));

      // Collect all logs from all requests
      final allLogs = <dynamic>[];
      for (final request in capturedRequests) {
        final logs = request['body']['logs'] as List;
        allLogs.addAll(logs);
      }
      expect(allLogs.length, 5);

      // Verify each log has user context
      final userIds = allLogs.map((l) => l['context']['user_id']).toSet();
      expect(userIds.length, 5);
    });

    test('should handle errors with long stack traces', () async {
      const config = CloudSyncConfig(enabled: true, endpoint: 'https://api.test.com', apiKey: 'test-key', projectId: 'test-project', batchSize: 5);

      syncService = CloudSyncService(config: config, client: createMockClient());
      syncService.initialize();

      // Long stack trace
      final longStackTrace = List.generate(50, (i) => 'at package:my_app/file_$i.dart:${i * 10}:${i * 2}').join('\n');

      syncService.queueLog(
        LogEntry(
          id: 'deep-stack-error',
          timestamp: DateTime.now(),
          message: 'Deep call stack error',
          level: LogLevel.error,
          metadata: {'error_type': 'StackOverflowError', 'stack_trace': longStackTrace, 'stack_depth': 50},
        ),
      );

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestCount, 1);
      final log = capturedRequests.first['body']['logs'][0];
      expect(log['context']['stack_trace'], isNotNull);
      expect(log['context']['stack_depth'], 50);
    });
  });
}
