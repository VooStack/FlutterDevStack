import 'package:flutter_test/flutter_test.dart';
import 'package:voo_performance/src/data/services/memory_monitor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryMonitorService', () {
    setUp(() {
      MemoryMonitorService.reset();
    });

    tearDown(() {
      MemoryMonitorService.reset();
    });

    group('singleton', () {
      test('should return same instance', () {
        final instance1 = MemoryMonitorService.instance;
        final instance2 = MemoryMonitorService.instance;

        expect(identical(instance1, instance2), isTrue);
      });

      test('should return new instance after reset', () {
        final instance1 = MemoryMonitorService.instance;
        MemoryMonitorService.reset();
        final instance2 = MemoryMonitorService.instance;

        expect(identical(instance1, instance2), isFalse);
      });
    });

    group('initialization', () {
      test('should not be initialized initially', () {
        expect(MemoryMonitorService.isInitialized, isFalse);
      });

      test('should be initialized after initialize()', () async {
        await MemoryMonitorService.initialize();

        expect(MemoryMonitorService.isInitialized, isTrue);
      });

      test('should not initialize twice', () async {
        await MemoryMonitorService.initialize();
        await MemoryMonitorService.initialize();

        expect(MemoryMonitorService.isInitialized, isTrue);
      });
    });

    group('monitoring lifecycle', () {
      test('should not be monitoring initially', () {
        expect(MemoryMonitorService.isMonitoring, isFalse);
      });

      test('should start monitoring', () {
        MemoryMonitorService.startMonitoring();

        expect(MemoryMonitorService.isMonitoring, isTrue);
      });

      test('should stop monitoring', () {
        MemoryMonitorService.startMonitoring();
        MemoryMonitorService.stopMonitoring();

        expect(MemoryMonitorService.isMonitoring, isFalse);
      });

      test('should stop existing timer when starting new monitoring', () {
        MemoryMonitorService.startMonitoring(
            interval: const Duration(seconds: 10));
        MemoryMonitorService.startMonitoring(
            interval: const Duration(seconds: 5));

        expect(MemoryMonitorService.isMonitoring, isTrue);
      });
    });

    group('takeSnapshot', () {
      test('should return a snapshot', () async {
        final snapshot = await MemoryMonitorService.takeSnapshot();

        expect(snapshot, isNotNull);
        expect(snapshot.timestamp, isNotNull);
      });

      test('should add snapshot to history', () async {
        await MemoryMonitorService.takeSnapshot();
        await MemoryMonitorService.takeSnapshot();

        expect(MemoryMonitorService.history.length, equals(2));
      });

      test('should include context if provided', () async {
        final snapshot =
            await MemoryMonitorService.takeSnapshot(context: 'test_context');

        expect(snapshot.context, equals('test_context'));
      });

      test('should enforce history size limit', () async {
        for (int i = 0; i < 110; i++) {
          await MemoryMonitorService.takeSnapshot();
        }

        expect(MemoryMonitorService.history.length, lessThanOrEqualTo(100));
      });
    });

    group('history', () {
      test('should return empty list initially', () {
        expect(MemoryMonitorService.history, isEmpty);
      });

      test('should return unmodifiable list', () {
        final history = MemoryMonitorService.history;

        expect(() => history.add(MemorySnapshot(timestamp: DateTime.now())),
            throwsUnsupportedError);
      });
    });

    group('peakHeapUsage', () {
      test('should return 0 initially', () {
        expect(MemoryMonitorService.peakHeapUsage, equals(0));
      });
    });

    group('pressureEventCount', () {
      test('should return 0 initially', () {
        expect(MemoryMonitorService.pressureEventCount, equals(0));
      });
    });

    group('memoryGrowthBytes', () {
      test('should return null without baseline', () {
        expect(MemoryMonitorService.memoryGrowthBytes, isNull);
      });
    });

    group('memoryGrowthPercent', () {
      test('should return null without baseline', () {
        expect(MemoryMonitorService.memoryGrowthPercent, isNull);
      });
    });

    group('averageHeapUsageBytes', () {
      test('should return null without samples', () {
        expect(MemoryMonitorService.averageHeapUsageBytes, isNull);
      });
    });

    group('pressure callbacks', () {
      test('should add callback', () {
        bool called = false;
        MemoryMonitorService.onMemoryPressure((_) => called = true);

        expect(called, isFalse);
      });

      test('should remove callback', () {
        void callback(MemoryPressureLevel level) {}
        MemoryMonitorService.onMemoryPressure(callback);
        MemoryMonitorService.removeMemoryPressureCallback(callback);
      });
    });

    group('streams', () {
      test('snapshotStream should be broadcast', () {
        expect(MemoryMonitorService.snapshotStream.isBroadcast, isTrue);
      });

      test('pressureStream should be broadcast', () {
        expect(MemoryMonitorService.pressureStream.isBroadcast, isTrue);
      });
    });

    group('dispose', () {
      test('should reset state on dispose', () async {
        await MemoryMonitorService.initialize();
        MemoryMonitorService.startMonitoring();
        await MemoryMonitorService.dispose();

        expect(MemoryMonitorService.isInitialized, isFalse);
        expect(MemoryMonitorService.isMonitoring, isFalse);
      });
    });
  });

  group('MemorySnapshot', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();
      final snapshot = MemorySnapshot(timestamp: timestamp);

      expect(snapshot.timestamp, equals(timestamp));
      expect(snapshot.pressureLevel, equals(MemoryPressureLevel.none));
      expect(snapshot.isUnderPressure, isFalse);
    });

    test('should create with all fields', () {
      final snapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        heapUsageBytes: 100 * 1024 * 1024,
        externalUsageBytes: 10 * 1024 * 1024,
        heapCapacityBytes: 200 * 1024 * 1024,
        objectCount: 10000,
        usagePercent: 50.0,
        isUnderPressure: false,
        pressureLevel: MemoryPressureLevel.none,
        gcCount: 5,
        context: 'test',
      );

      expect(snapshot.heapUsageMB, closeTo(100.0, 0.1));
      expect(snapshot.externalUsageMB, closeTo(10.0, 0.1));
      expect(snapshot.heapCapacityMB, closeTo(200.0, 0.1));
      expect(snapshot.totalUsageBytes, equals(110 * 1024 * 1024));
      expect(snapshot.totalUsageMB, closeTo(110.0, 0.1));
    });

    test('should handle null values in computed properties', () {
      final snapshot = MemorySnapshot(timestamp: DateTime.now());

      expect(snapshot.heapUsageMB, isNull);
      expect(snapshot.externalUsageMB, isNull);
      expect(snapshot.heapCapacityMB, isNull);
      expect(snapshot.totalUsageBytes, isNull);
      expect(snapshot.totalUsageMB, isNull);
    });

    test('should serialize to JSON', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
      final snapshot = MemorySnapshot(
        timestamp: timestamp,
        heapUsageBytes: 100 * 1024 * 1024,
        pressureLevel: MemoryPressureLevel.moderate,
        isUnderPressure: true,
        context: 'test_context',
      );

      final json = snapshot.toJson();

      expect(json['timestamp'], equals(timestamp.toIso8601String()));
      expect(json['heap_usage_bytes'], equals(100 * 1024 * 1024));
      expect(json['pressure_level'], equals('moderate'));
      expect(json['is_under_pressure'], isTrue);
      expect(json['context'], equals('test_context'));
    });

    test('should deserialize from JSON', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
      final json = {
        'timestamp': timestamp.toIso8601String(),
        'heap_usage_bytes': 100 * 1024 * 1024,
        'pressure_level': 'moderate',
        'is_under_pressure': true,
        'context': 'test_context',
      };

      final snapshot = MemorySnapshot.fromJson(json);

      expect(snapshot.timestamp, equals(timestamp));
      expect(snapshot.heapUsageBytes, equals(100 * 1024 * 1024));
      expect(snapshot.pressureLevel, equals(MemoryPressureLevel.moderate));
      expect(snapshot.isUnderPressure, isTrue);
      expect(snapshot.context, equals('test_context'));
    });

    test('should have readable toString', () {
      final snapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        heapUsageBytes: 100 * 1024 * 1024,
        pressureLevel: MemoryPressureLevel.none,
      );

      final str = snapshot.toString();

      expect(str, contains('100.0'));
      expect(str, contains('none'));
    });
  });

  group('MemoryPressureLevel', () {
    test('should have expected values', () {
      expect(MemoryPressureLevel.values.length, equals(3));
      expect(MemoryPressureLevel.none.name, equals('none'));
      expect(MemoryPressureLevel.moderate.name, equals('moderate'));
      expect(MemoryPressureLevel.critical.name, equals('critical'));
    });
  });
}
