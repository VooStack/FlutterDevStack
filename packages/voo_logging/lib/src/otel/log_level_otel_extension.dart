import 'package:voo_logging/core/domain/enums/log_level.dart';
import 'package:voo_telemetry/voo_telemetry.dart';

/// Extension to map VooLogger LogLevel to OpenTelemetry SeverityNumber.
///
/// OTEL uses a 1-24 scale for severity:
/// - TRACE: 1-4
/// - DEBUG: 5-8
/// - INFO: 9-12
/// - WARN: 13-16
/// - ERROR: 17-20
/// - FATAL: 21-24
extension LogLevelOtelExtension on LogLevel {
  /// Get the corresponding OTEL SeverityNumber.
  SeverityNumber get otelSeverityNumber {
    switch (this) {
      case LogLevel.verbose:
        return SeverityNumber.trace; // 1
      case LogLevel.debug:
        return SeverityNumber.debug; // 5
      case LogLevel.info:
        return SeverityNumber.info; // 9
      case LogLevel.warning:
        return SeverityNumber.warn; // 13
      case LogLevel.error:
        return SeverityNumber.error; // 17
      case LogLevel.fatal:
        return SeverityNumber.fatal; // 21
    }
  }

  /// Get the OTEL severity text (uppercase).
  String get otelSeverityText {
    switch (this) {
      case LogLevel.verbose:
        return 'TRACE';
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.fatal:
        return 'FATAL';
    }
  }

  /// Get the numeric OTEL severity value (1-24).
  int get otelSeverityValue => otelSeverityNumber.value;
}

/// Extension to convert OTEL SeverityNumber back to VooLogger LogLevel.
extension SeverityNumberLogLevelExtension on SeverityNumber {
  /// Get the corresponding VooLogger LogLevel.
  ///
  /// Maps ranges to the closest VooLogger level:
  /// - 1-4 (TRACE) → verbose
  /// - 5-8 (DEBUG) → debug
  /// - 9-12 (INFO) → info
  /// - 13-16 (WARN) → warning
  /// - 17-20 (ERROR) → error
  /// - 21-24 (FATAL) → fatal
  LogLevel get toLogLevel {
    final value = this.value;
    if (value <= 4) return LogLevel.verbose;
    if (value <= 8) return LogLevel.debug;
    if (value <= 12) return LogLevel.info;
    if (value <= 16) return LogLevel.warning;
    if (value <= 20) return LogLevel.error;
    return LogLevel.fatal;
  }
}
