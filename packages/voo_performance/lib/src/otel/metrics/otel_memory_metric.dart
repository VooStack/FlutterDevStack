import 'package:voo_telemetry/voo_telemetry.dart';
import '../semantic_conventions.dart';

/// Export memory metrics using OTEL Gauge instruments.
///
/// Tracks:
/// - Heap usage as gauge for current memory consumption
/// - External (native) memory usage
/// - Heap capacity for total available memory
class OtelMemoryMetric {
  final Meter _meter;

  late final Gauge _heapUsageGauge;
  late final Gauge _externalUsageGauge;
  late final Gauge _heapCapacityGauge;

  /// Flag indicating if metrics are initialized.
  bool _initialized = false;

  OtelMemoryMetric(this._meter);

  /// Initialize the memory metric instruments.
  void initialize() {
    if (_initialized) return;

    _heapUsageGauge = _meter.createGauge(
      AppSemanticConventions.processRuntimeDartHeapUsage,
      description: 'Current Dart heap usage in bytes',
      unit: 'By',
    );

    _externalUsageGauge = _meter.createGauge(
      AppSemanticConventions.processRuntimeDartExternalUsage,
      description: 'External (native) memory usage in bytes',
      unit: 'By',
    );

    _heapCapacityGauge = _meter.createGauge(
      AppSemanticConventions.processRuntimeDartHeapCapacity,
      description: 'Total Dart heap capacity in bytes',
      unit: 'By',
    );

    _initialized = true;
  }

  /// Record a memory snapshot.
  ///
  /// [heapUsageBytes] Current heap usage in bytes.
  /// [externalUsageBytes] External (native) memory usage in bytes.
  /// [heapCapacityBytes] Total heap capacity in bytes.
  /// [pressureLevel] Memory pressure level (none, moderate, critical).
  /// [isUnderPressure] Whether the app is under memory pressure.
  void recordSnapshot({
    int? heapUsageBytes,
    int? externalUsageBytes,
    int? heapCapacityBytes,
    String? pressureLevel,
    bool? isUnderPressure,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      if (pressureLevel != null) AppSemanticConventions.memoryPressureLevel: pressureLevel,
      if (isUnderPressure != null) AppSemanticConventions.memoryIsUnderPressure: isUnderPressure,
    };

    if (heapUsageBytes != null) {
      _heapUsageGauge.set(heapUsageBytes.toDouble(), attributes: attributes);
    }

    if (externalUsageBytes != null) {
      _externalUsageGauge.set(externalUsageBytes.toDouble(), attributes: attributes);
    }

    if (heapCapacityBytes != null) {
      _heapCapacityGauge.set(heapCapacityBytes.toDouble(), attributes: attributes);
    }
  }

  /// Record memory usage as a percentage of capacity.
  void recordUsagePercentage({
    required double usagePercent,
    String? pressureLevel,
  }) {
    if (!_initialized) return;

    final attributes = <String, dynamic>{
      if (pressureLevel != null) AppSemanticConventions.memoryPressureLevel: pressureLevel,
      'memory.usage_percent': usagePercent,
    };

    // Use heap usage gauge with percentage for quick reference
    _heapUsageGauge.set(usagePercent, attributes: {
      ...attributes,
      'unit': 'percent',
    });
  }
}
