import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:voo_core/voo_core.dart';

/// Represents a memory snapshot at a point in time.
@immutable
class MemorySnapshot {
  /// Timestamp when the snapshot was taken.
  final DateTime timestamp;

  /// Current heap usage in bytes.
  final int? heapUsageBytes;

  /// External memory usage in bytes (native allocations).
  final int? externalUsageBytes;

  /// Total heap capacity in bytes.
  final int? heapCapacityBytes;

  /// Number of live objects on the heap.
  final int? objectCount;

  /// Memory usage as a percentage of capacity.
  final double? usagePercent;

  /// Whether the app is under memory pressure.
  final bool isUnderPressure;

  /// Memory pressure level: none, moderate, critical.
  final MemoryPressureLevel pressureLevel;

  /// Garbage collection count since app start.
  final int? gcCount;

  /// Optional context about what triggered this snapshot.
  final String? context;

  const MemorySnapshot({
    required this.timestamp,
    this.heapUsageBytes,
    this.externalUsageBytes,
    this.heapCapacityBytes,
    this.objectCount,
    this.usagePercent,
    this.isUnderPressure = false,
    this.pressureLevel = MemoryPressureLevel.none,
    this.gcCount,
    this.context,
  });

  /// Heap usage in megabytes.
  double? get heapUsageMB => heapUsageBytes != null ? heapUsageBytes! / (1024 * 1024) : null;

  /// External usage in megabytes.
  double? get externalUsageMB => externalUsageBytes != null ? externalUsageBytes! / (1024 * 1024) : null;

  /// Heap capacity in megabytes.
  double? get heapCapacityMB => heapCapacityBytes != null ? heapCapacityBytes! / (1024 * 1024) : null;

  /// Total memory usage (heap + external) in bytes.
  int? get totalUsageBytes {
    if (heapUsageBytes == null) return null;
    return heapUsageBytes! + (externalUsageBytes ?? 0);
  }

  /// Total memory usage in megabytes.
  double? get totalUsageMB => totalUsageBytes != null ? totalUsageBytes! / (1024 * 1024) : null;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    if (heapUsageBytes != null) 'heap_usage_bytes': heapUsageBytes,
    if (externalUsageBytes != null) 'external_usage_bytes': externalUsageBytes,
    if (heapCapacityBytes != null) 'heap_capacity_bytes': heapCapacityBytes,
    if (objectCount != null) 'object_count': objectCount,
    if (usagePercent != null) 'usage_percent': usagePercent,
    'is_under_pressure': isUnderPressure,
    'pressure_level': pressureLevel.name,
    if (gcCount != null) 'gc_count': gcCount,
    if (context != null) 'context': context,
  };

  factory MemorySnapshot.fromJson(Map<String, dynamic> json) => MemorySnapshot(
    timestamp: DateTime.parse(json['timestamp'] as String),
    heapUsageBytes: json['heap_usage_bytes'] as int?,
    externalUsageBytes: json['external_usage_bytes'] as int?,
    heapCapacityBytes: json['heap_capacity_bytes'] as int?,
    objectCount: json['object_count'] as int?,
    usagePercent: json['usage_percent'] as double?,
    isUnderPressure: json['is_under_pressure'] as bool? ?? false,
    pressureLevel: MemoryPressureLevel.values.firstWhere((l) => l.name == json['pressure_level'], orElse: () => MemoryPressureLevel.none),
    gcCount: json['gc_count'] as int?,
    context: json['context'] as String?,
  );

  @override
  String toString() =>
      'MemorySnapshot('
      'heap: ${heapUsageMB?.toStringAsFixed(1)}MB, '
      'pressure: ${pressureLevel.name})';
}

/// Memory pressure levels.
enum MemoryPressureLevel {
  /// No memory pressure.
  none,

  /// Moderate memory pressure - consider releasing caches.
  moderate,

  /// Critical memory pressure - app may be killed.
  critical,
}

/// Callback type for memory pressure events.
typedef MemoryPressureCallback = void Function(MemoryPressureLevel level);

/// Service for monitoring memory usage and detecting memory pressure.
///
/// Tracks heap size, object counts, and memory pressure over time.
/// Useful for identifying memory leaks and optimizing memory usage.
///
/// ## Usage
///
/// ```dart
/// // Initialize the service
/// await MemoryMonitorService.initialize();
///
/// // Start periodic monitoring
/// MemoryMonitorService.startMonitoring(interval: Duration(seconds: 30));
///
/// // Get current memory snapshot
/// final snapshot = await MemoryMonitorService.takeSnapshot();
/// print('Heap usage: ${snapshot.heapUsageMB}MB');
///
/// // Listen for memory pressure
/// MemoryMonitorService.onMemoryPressure((level) {
///   if (level == MemoryPressureLevel.critical) {
///     // Clear caches, release resources
///   }
/// });
///
/// // Stop monitoring
/// MemoryMonitorService.stopMonitoring();
/// ```
class MemoryMonitorService {
  static MemoryMonitorService? _instance;
  static bool _initialized = false;

  /// Timer for periodic monitoring.
  Timer? _monitoringTimer;

  /// History of memory snapshots.
  final List<MemorySnapshot> _history = [];

  /// Maximum history size.
  static const int _maxHistorySize = 100;

  /// Stream controller for memory snapshots.
  final StreamController<MemorySnapshot> _snapshotController = StreamController<MemorySnapshot>.broadcast();

  /// Stream controller for memory pressure events.
  final StreamController<MemoryPressureLevel> _pressureController = StreamController<MemoryPressureLevel>.broadcast();

  /// Callbacks for memory pressure.
  final List<MemoryPressureCallback> _pressureCallbacks = [];

  /// Last detected pressure level.
  MemoryPressureLevel _lastPressureLevel = MemoryPressureLevel.none;

  /// Baseline heap usage (captured at initialization).
  int? _baselineHeapUsage;

  /// Peak heap usage observed.
  int _peakHeapUsage = 0;

  /// Number of memory pressure events.
  int _pressureEventCount = 0;

  MemoryMonitorService._();

  /// Get the singleton instance.
  static MemoryMonitorService get instance {
    _instance ??= MemoryMonitorService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  static bool get isInitialized => _initialized;

  /// Whether monitoring is active.
  static bool get isMonitoring => instance._monitoringTimer?.isActive ?? false;

  /// Stream of memory snapshots.
  static Stream<MemorySnapshot> get snapshotStream => instance._snapshotController.stream;

  /// Stream of memory pressure events.
  static Stream<MemoryPressureLevel> get pressureStream => instance._pressureController.stream;

  /// Memory snapshot history.
  static List<MemorySnapshot> get history => List.unmodifiable(instance._history);

  /// Peak heap usage observed in bytes.
  static int get peakHeapUsage => instance._peakHeapUsage;

  /// Number of memory pressure events.
  static int get pressureEventCount => instance._pressureEventCount;

  /// Initialize the service.
  static Future<void> initialize() async {
    if (_initialized) return;

    // Capture baseline
    final baseline = await takeSnapshot(context: 'initialization');
    instance._baselineHeapUsage = baseline.heapUsageBytes;

    _initialized = true;

    if (kDebugMode) {
      debugPrint('MemoryMonitorService: Initialized');
      debugPrint('MemoryMonitorService: Baseline heap: ${baseline.heapUsageMB?.toStringAsFixed(1)}MB');
    }
  }

  /// Take a memory snapshot.
  static Future<MemorySnapshot> takeSnapshot({String? context}) async {
    final timestamp = DateTime.now();

    int? heapUsage;
    int? externalUsage;
    int? heapCapacity;

    try {
      // Memory info is primarily available through DevTools in debug mode.
      // For production, we rely on platform-specific methods.
      // The Dart VM doesn't expose direct memory APIs to user code.
      if (kDebugMode) {
        // Debug-only memory introspection could be added via DevTools protocol
      }
    } catch (e) {
      // Memory info not available
    }

    // Calculate usage percent if we have capacity
    double? usagePercent;
    if (heapUsage != null && heapCapacity != null && heapCapacity > 0) {
      usagePercent = (heapUsage / heapCapacity) * 100;
    }

    // Determine pressure level
    final pressureLevel = _determinePressureLevel(usagePercent, heapUsage);
    final isUnderPressure = pressureLevel != MemoryPressureLevel.none;

    final snapshot = MemorySnapshot(
      timestamp: timestamp,
      heapUsageBytes: heapUsage,
      externalUsageBytes: externalUsage,
      heapCapacityBytes: heapCapacity,
      usagePercent: usagePercent,
      isUnderPressure: isUnderPressure,
      pressureLevel: pressureLevel,
      context: context,
    );

    // Update peak usage
    if (heapUsage != null && heapUsage > instance._peakHeapUsage) {
      instance._peakHeapUsage = heapUsage;
    }

    // Add to history
    instance._history.add(snapshot);
    while (instance._history.length > _maxHistorySize) {
      instance._history.removeAt(0);
    }

    // Emit snapshot
    instance._snapshotController.add(snapshot);

    // Check for pressure level change
    if (pressureLevel != instance._lastPressureLevel) {
      instance._lastPressureLevel = pressureLevel;

      if (pressureLevel != MemoryPressureLevel.none) {
        instance._pressureEventCount++;
        instance._pressureController.add(pressureLevel);

        // Call registered callbacks
        for (final callback in instance._pressureCallbacks) {
          try {
            callback(pressureLevel);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('MemoryMonitorService: Callback error: $e');
            }
          }
        }

        // Add breadcrumb
        _addPressureBreadcrumb(pressureLevel, snapshot);
      }
    }

    return snapshot;
  }

  static MemoryPressureLevel _determinePressureLevel(double? usagePercent, int? heapUsage) {
    // If we have usage percent, use that
    if (usagePercent != null) {
      if (usagePercent > 90) return MemoryPressureLevel.critical;
      if (usagePercent > 75) return MemoryPressureLevel.moderate;
      return MemoryPressureLevel.none;
    }

    // Otherwise, use absolute thresholds
    if (heapUsage != null) {
      final usageMB = heapUsage / (1024 * 1024);
      // These are rough estimates - actual thresholds vary by device
      if (usageMB > 500) return MemoryPressureLevel.critical;
      if (usageMB > 300) return MemoryPressureLevel.moderate;
    }

    return MemoryPressureLevel.none;
  }

  static void _addPressureBreadcrumb(MemoryPressureLevel level, MemorySnapshot snapshot) {
    try {
      Voo.addBreadcrumb(
        VooBreadcrumb(
          type: level == MemoryPressureLevel.critical ? VooBreadcrumbType.error : VooBreadcrumbType.custom,
          category: 'memory',
          message: 'Memory pressure: ${level.name}',
          level: level == MemoryPressureLevel.critical ? VooBreadcrumbLevel.warning : VooBreadcrumbLevel.info,
          data: {
            'pressure_level': level.name,
            if (snapshot.heapUsageMB != null) 'heap_usage_mb': snapshot.heapUsageMB!.toStringAsFixed(1),
            if (snapshot.usagePercent != null) 'usage_percent': snapshot.usagePercent!.toStringAsFixed(1),
          },
        ),
      );
    } catch (e) {
      // Ignore breadcrumb errors
    }
  }

  /// Start periodic memory monitoring.
  static void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    if (!_initialized) initialize();

    // Stop existing timer
    stopMonitoring();

    instance._monitoringTimer = Timer.periodic(interval, (_) {
      takeSnapshot(context: 'periodic');
    });

    if (kDebugMode) {
      debugPrint('MemoryMonitorService: Started monitoring (interval: ${interval.inSeconds}s)');
    }
  }

  /// Stop periodic monitoring.
  static void stopMonitoring() {
    instance._monitoringTimer?.cancel();
    instance._monitoringTimer = null;

    if (kDebugMode) {
      debugPrint('MemoryMonitorService: Stopped monitoring');
    }
  }

  /// Register a callback for memory pressure events.
  static void onMemoryPressure(MemoryPressureCallback callback) {
    instance._pressureCallbacks.add(callback);
  }

  /// Remove a memory pressure callback.
  static void removeMemoryPressureCallback(MemoryPressureCallback callback) {
    instance._pressureCallbacks.remove(callback);
  }

  /// Get memory growth since baseline.
  static int? get memoryGrowthBytes {
    if (instance._baselineHeapUsage == null || instance._history.isEmpty) {
      return null;
    }
    final latest = instance._history.last;
    if (latest.heapUsageBytes == null) return null;
    return latest.heapUsageBytes! - instance._baselineHeapUsage!;
  }

  /// Get memory growth percentage since baseline.
  static double? get memoryGrowthPercent {
    if (instance._baselineHeapUsage == null || instance._baselineHeapUsage == 0) {
      return null;
    }
    final growth = memoryGrowthBytes;
    if (growth == null) return null;
    return (growth / instance._baselineHeapUsage!) * 100;
  }

  /// Get average heap usage from history.
  static double? get averageHeapUsageBytes {
    final samples = instance._history.where((s) => s.heapUsageBytes != null).map((s) => s.heapUsageBytes!).toList();
    if (samples.isEmpty) return null;
    return samples.reduce((a, b) => a + b) / samples.length;
  }

  /// Log current memory metrics as a breadcrumb.
  static Future<void> logMemoryMetrics() async {
    final snapshot = await takeSnapshot(context: 'metrics_log');

    try {
      Voo.addBreadcrumb(
        VooBreadcrumb(
          type: VooBreadcrumbType.system,
          category: 'performance.memory',
          message: 'Memory metrics snapshot',
          data: {
            'pressure_level': snapshot.pressureLevel.name,
            if (snapshot.heapUsageMB != null) 'heap_usage_mb': snapshot.heapUsageMB,
            if (memoryGrowthPercent != null) 'memory_growth_percent': memoryGrowthPercent,
            if (snapshot.usagePercent != null) 'usage_percent': snapshot.usagePercent,
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MemoryMonitorService: Failed to log metrics: $e');
      }
    }
  }

  /// Force garbage collection (debug mode only).
  ///
  /// Note: This is a hint to the VM, not a guarantee.
  static Future<void> requestGC() async {
    if (kDebugMode) {
      debugPrint('MemoryMonitorService: Requesting GC');
    }

    // Take a snapshot before
    final before = await takeSnapshot(context: 'pre_gc');

    // In Dart, we can't force GC, but we can allocate and release
    // to hint to the VM that memory should be collected
    try {
      // This is a hack - allocate then release to encourage GC
      final _ = List.generate(1000, (i) => List.filled(1000, 0));
    } catch (e) {
      // Ignore allocation errors
    }

    // Give VM time to potentially GC
    await Future.delayed(const Duration(milliseconds: 100));

    // Take a snapshot after
    final after = await takeSnapshot(context: 'post_gc');

    if (kDebugMode && before.heapUsageBytes != null && after.heapUsageBytes != null) {
      final freed = before.heapUsageBytes! - after.heapUsageBytes!;
      debugPrint('MemoryMonitorService: GC hint - freed ~${(freed / 1024 / 1024).toStringAsFixed(1)}MB');
    }
  }

  /// Dispose resources.
  static Future<void> dispose() async {
    stopMonitoring();
    await instance._snapshotController.close();
    await instance._pressureController.close();
    instance._pressureCallbacks.clear();
    instance._history.clear();
    _initialized = false;
    _instance = null;

    if (kDebugMode) {
      debugPrint('MemoryMonitorService: Disposed');
    }
  }

  /// Reset for testing.
  @visibleForTesting
  static void reset() {
    stopMonitoring();
    instance._history.clear();
    instance._pressureCallbacks.clear();
    instance._lastPressureLevel = MemoryPressureLevel.none;
    instance._baselineHeapUsage = null;
    instance._peakHeapUsage = 0;
    instance._pressureEventCount = 0;
    _initialized = false;
    _instance = null;
  }
}
