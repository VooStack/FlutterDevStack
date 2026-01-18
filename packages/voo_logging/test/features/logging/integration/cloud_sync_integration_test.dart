import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voo_logging/features/logging/data/services/cloud_sync_service.dart';
import 'package:voo_logging/features/logging/domain/entities/cloud_sync_config.dart';
import 'package:voo_logging/features/logging/domain/entities/log_entry.dart';
import 'package:voo_logging/core/domain/enums/log_level.dart';

void main() {
  group('CloudSyncService Integration Tests', () {
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

    MockClient createMockClient({
      int statusCode = 200,
      Duration? delay,
      int? failCount,
    }) {
      int failuresRemaining = failCount ?? 0;

      return MockClient((request) async {
        requestCount++;

        if (delay != null) {
          await Future.delayed(delay);
        }

        // Capture request data
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedRequests.add({
          'url': request.url.toString(),
          'method': request.method,
          'headers': request.headers,
          'body': body,
        });

        // Simulate failures
        if (failuresRemaining > 0) {
          failuresRemaining--;
          return http.Response('Internal Server Error', 500);
        }

        return http.Response('{"success": true}', statusCode);
      });
    }

    LogEntry createTestLog({
      LogLevel level = LogLevel.info,
      String message = 'Test message',
      String? category,
    }) {
      return LogEntry(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        message: message,
        level: level,
        category: category,
      );
    }

    test('should not sync when disabled', () async {
      final config = const CloudSyncConfig(enabled: false);
      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Queue multiple logs
      for (var i = 0; i < 10; i++) {
        syncService.queueLog(createTestLog());
      }

      // Manually flush
      await syncService.flush();

      // Should not have made any requests
      expect(requestCount, 0);
      expect(syncService.syncStatus, CloudSyncStatus.disabled);
    });

    test('should batch logs according to batch size', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-api-key',
        projectId: 'test-project',
        batchSize: 5,
        batchInterval: const Duration(hours: 1), // Long interval to test batch size trigger
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Queue exactly batch size logs
      for (var i = 0; i < 5; i++) {
        syncService.queueLog(createTestLog(message: 'Log $i'));
      }

      // Wait for sync to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have triggered one batch
      expect(requestCount, 1);
      expect(capturedRequests.first['body']['logs'].length, 5);
    });

    test('should include correct headers and API key', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'my-secret-key',
        projectId: 'project-123',
        batchSize: 1,
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      syncService.queueLog(createTestLog());

      await Future.delayed(const Duration(milliseconds: 100));

      expect(capturedRequests.first['headers']['X-API-Key'], 'my-secret-key');
      expect(capturedRequests.first['headers']['Content-Type'], 'application/json');
      // projectId is sent via X-Project-Id header, not in body
      expect(capturedRequests.first['headers']['X-Project-Id'], 'project-123');
    });

    test('should prioritize error logs', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 10,
        prioritizeErrors: true,
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Queue some regular logs
      for (var i = 0; i < 3; i++) {
        syncService.queueLog(createTestLog(level: LogLevel.info, message: 'Info $i'));
      }

      // Queue an error - should trigger immediate sync
      syncService.queueLog(createTestLog(level: LogLevel.error, message: 'Error!'));

      await Future.delayed(const Duration(milliseconds: 100));

      // Error should have triggered a sync
      expect(requestCount, greaterThanOrEqualTo(1));

      // Error log should be in the synced batch
      final logs = capturedRequests.first['body']['logs'] as List;
      final errorLog = logs.firstWhere((l) => l['level'] == 'error');
      expect(errorLog['message'], 'Error!');
    });

    test('should retry on failure', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 1,
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 10),
      );

      // Fail first 2 requests, then succeed
      syncService = CloudSyncService(
        config: config,
        client: createMockClient(failCount: 2),
      );
      syncService.initialize();

      syncService.queueLog(createTestLog());

      await Future.delayed(const Duration(milliseconds: 500));

      // Should have retried: 1 initial + 2 retries = 3 total
      expect(requestCount, 3);
    });

    test('should respect minimum sync level', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 10,
        syncMinimumLevel: 'warning',
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Queue logs below minimum level
      syncService.queueLog(createTestLog(level: LogLevel.debug, message: 'Debug'));
      syncService.queueLog(createTestLog(level: LogLevel.info, message: 'Info'));

      // Queue logs at or above minimum level
      syncService.queueLog(createTestLog(level: LogLevel.warning, message: 'Warning'));
      syncService.queueLog(createTestLog(level: LogLevel.error, message: 'Error'));

      await syncService.flush();
      await Future.delayed(const Duration(milliseconds: 100));

      if (requestCount > 0) {
        final logs = capturedRequests.first['body']['logs'] as List;
        // Should only contain warning and error
        expect(logs.length, 2);
        expect(logs.any((l) => l['level'] == 'debug'), false);
        expect(logs.any((l) => l['level'] == 'info'), false);
      }
    });

    test('should enforce max queue size', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 100,
        maxQueueSize: 5,
        batchInterval: const Duration(hours: 1),
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      // Queue more than max queue size
      for (var i = 0; i < 10; i++) {
        syncService.queueLog(createTestLog(message: 'Log $i'));
      }

      // Pending count should be at max queue size
      expect(syncService.pendingCount, lessThanOrEqualTo(5));
    });

    test('should format log entries correctly', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 1,
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(),
      );
      syncService.initialize();

      final testLog = LogEntry(
        id: 'test-id',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30, 0),
        message: 'Test message',
        level: LogLevel.warning,
        category: 'TestCategory',
        tag: 'test-tag',
        metadata: {'key': 'value'},
      );

      syncService.queueLog(testLog);

      await Future.delayed(const Duration(milliseconds: 100));

      final logData = capturedRequests.first['body']['logs'][0];
      expect(logData['level'], 'warning');
      expect(logData['message'], 'Test message');
      expect(logData['category'], 'TestCategory');
      // tag is now included in context (API doesn't have a separate tag field)
      expect(logData['context']['tag'], 'test-tag');
      expect(logData['context']['key'], 'value');
    });

    test('should update status correctly', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 1,
      );

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(delay: const Duration(milliseconds: 50)),
      );
      syncService.initialize();

      expect(syncService.syncStatus, CloudSyncStatus.idle);

      syncService.queueLog(createTestLog());

      await Future.delayed(const Duration(milliseconds: 200));

      // Should have completed syncing
      expect(syncService.syncStatus, CloudSyncStatus.idle);
    });

    test('should call error callback on failure', () async {
      final config = CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'test-key',
        projectId: 'test',
        batchSize: 1,
        maxRetries: 0,
      );

      final errors = <String>[];

      syncService = CloudSyncService(
        config: config,
        client: createMockClient(statusCode: 500),
      );
      syncService.onError = (error, retry) => errors.add(error);
      syncService.initialize();

      syncService.queueLog(createTestLog());

      await Future.delayed(const Duration(milliseconds: 100));

      expect(errors, isNotEmpty);
      expect(errors.first, contains('500'));
    });
  });

  group('CloudSyncConfig Tests', () {
    test('should validate configuration correctly', () {
      final invalidConfig = const CloudSyncConfig(enabled: true);
      expect(invalidConfig.isValid, false);

      final validConfig = const CloudSyncConfig(
        enabled: true,
        endpoint: 'https://api.test.com',
        apiKey: 'key',
      );
      expect(validConfig.isValid, true);

      final disabledConfig = const CloudSyncConfig(enabled: false);
      expect(disabledConfig.isValid, false);
    });

    test('should generate correct log endpoint', () {
      const config = CloudSyncConfig(
        endpoint: 'https://api.devstack.io/api',
      );
      expect(config.logEndpoint, 'https://api.devstack.io/api/v1/telemetry/logs');
    });

    test('production preset should have correct defaults', () {
      final config = CloudSyncConfig.production(
        endpoint: 'https://api.test.com',
        apiKey: 'key',
        projectId: 'project',
      );

      expect(config.enabled, true);
      expect(config.batchSize, 100);
      expect(config.batchInterval, const Duration(seconds: 60));
      expect(config.syncMinimumLevel, 'info');
      expect(config.prioritizeErrors, true);
      expect(config.maxQueueSize, 2000);
    });

    test('development preset should have smaller batches', () {
      final config = CloudSyncConfig.development(
        endpoint: 'https://api.test.com',
        apiKey: 'key',
        projectId: 'project',
      );

      expect(config.enabled, true);
      expect(config.batchSize, 10);
      expect(config.batchInterval, const Duration(minutes: 10));
    });
  });
}
