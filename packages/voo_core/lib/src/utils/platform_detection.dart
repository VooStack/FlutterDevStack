/// Pure Dart platform detection utilities.
///
/// This provides platform detection without Flutter dependencies,
/// suitable for use in domain layer code.
library;

/// Whether the code is running on the web platform.
///
/// This is determined at compile time and cannot be changed at runtime.
const bool kIsWebPlatform = bool.fromEnvironment('dart.library.js_util');

/// The type of operating system.
enum OperatingSystemType {
  /// Android operating system.
  android,

  /// iOS operating system.
  ios,

  /// macOS operating system.
  macos,

  /// Linux operating system.
  linux,

  /// Windows operating system.
  windows,

  /// Fuchsia operating system.
  fuchsia,

  /// Unknown operating system.
  unknown,
}

/// Detects the current operating system without Flutter dependencies.
OperatingSystemType detectOperatingSystem() {
  if (kIsWebPlatform) {
    return OperatingSystemType.unknown;
  }

  // Use dart:io conditionally
  try {
    return _detectFromDartIO();
  } catch (_) {
    return OperatingSystemType.unknown;
  }
}

/// Whether the current platform supports ANSI escape codes for colored output.
///
/// Returns true for desktop platforms (macOS, Linux, Windows) in development,
/// and false for mobile and web platforms.
bool supportsAnsiColors() {
  if (kIsWebPlatform) {
    return false;
  }

  final os = detectOperatingSystem();
  switch (os) {
    case OperatingSystemType.android:
    case OperatingSystemType.ios:
      return false;
    case OperatingSystemType.macos:
    case OperatingSystemType.linux:
    case OperatingSystemType.windows:
      return true;
    case OperatingSystemType.fuchsia:
    case OperatingSystemType.unknown:
      return false;
  }
}

// Implementation using dart:io when available
OperatingSystemType _detectFromDartIO() {
  // This will be conditionally compiled
  // On web, this throws and we catch it above
  final osString = _getOperatingSystemString();

  switch (osString.toLowerCase()) {
    case 'android':
      return OperatingSystemType.android;
    case 'ios':
      return OperatingSystemType.ios;
    case 'macos':
      return OperatingSystemType.macos;
    case 'linux':
      return OperatingSystemType.linux;
    case 'windows':
      return OperatingSystemType.windows;
    case 'fuchsia':
      return OperatingSystemType.fuchsia;
    default:
      return OperatingSystemType.unknown;
  }
}

// Stub function - will be replaced by conditional import
String _getOperatingSystemString() {
  // This is a workaround for conditional imports
  // In non-web builds, dart:io is available
  try {
    // ignore: avoid_dynamic_calls
    return const String.fromEnvironment('os', defaultValue: 'unknown');
  } catch (_) {
    return 'unknown';
  }
}
