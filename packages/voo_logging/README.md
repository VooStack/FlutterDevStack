# Voo Logging

[![pub package](https://img.shields.io/pub/v/voo_logging.svg)](https://pub.dev/packages/voo_logging)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A zero-config, production-ready logging package for Flutter with pretty console output, persistent storage, and DevTools integration.

## Features

- **Zero Configuration** - Just call `VooLogger.info()` and it works
- **Pretty Console Output** - Formatted logs with borders, colors, and emojis
- **Persistent Storage** - Logs survive app restarts (Sembast-based)
- **DevTools Integration** - Real-time log viewing in Flutter DevTools
- **Cross-Platform** - iOS, Android, Web, macOS, Windows, Linux
- **Dio Integration** - Automatic network request/response logging
- **Structured Logging** - Categories, tags, and metadata support
- **Configurable** - Customize every aspect of log output

## Installation

```yaml
dependencies:
  voo_logging: ^0.4.9
```

## Quick Start

```dart
import 'package:voo_logging/voo_logging.dart';

// That's it! No initialization required.
VooLogger.info('Hello world');
VooLogger.debug('Debug info');
VooLogger.warning('Watch out');
VooLogger.error('Something failed', error: exception);
```

VooLogger auto-initializes on first use with sensible defaults.

## Log Levels

```dart
VooLogger.verbose('Detailed trace info');
VooLogger.debug('Development debugging');
VooLogger.info('General information');
VooLogger.warning('Potential issues');
VooLogger.error('Errors with optional exception', error: e, stackTrace: stack);
VooLogger.fatal('Critical failures', error: e);
```

## Structured Logging

```dart
VooLogger.info(
  'User completed purchase',
  category: 'Payment',
  tag: 'checkout',
  metadata: {
    'orderId': 'ORD-123',
    'amount': 99.99,
    'currency': 'USD',
  },
);
```

## Configuration

### Presets

```dart
// Development - all features enabled
await VooLogger.initialize(config: LoggingConfig.development());

// Production - minimal output, warnings+ only
await VooLogger.initialize(config: LoggingConfig.production());

// Minimal - zero-config defaults
await VooLogger.initialize(config: LoggingConfig.minimal());
```

### Custom Configuration

```dart
await VooLogger.initialize(
  appName: 'MyApp',
  appVersion: '1.0.0',
  config: LoggingConfig(
    // Output formatting
    enablePrettyLogs: true,    // Pretty formatted output
    showEmojis: true,          // Level icons
    showTimestamp: true,       // HH:MM:SS.mmm
    showBorders: true,         // Box borders
    showMetadata: true,        // Metadata section

    // Filtering
    minimumLevel: LogLevel.debug,

    // Storage
    maxLogs: 10000,
    retentionDays: 7,
    autoCleanup: true,
  ),
);
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enablePrettyLogs` | `true` | Enable formatted console output |
| `showEmojis` | `true` | Show emoji icons for log levels |
| `showTimestamp` | `true` | Include timestamps in output |
| `showBorders` | `true` | Show box borders around logs |
| `showMetadata` | `true` | Display metadata section |
| `minimumLevel` | `verbose` | Minimum level to log |
| `maxLogs` | `null` | Maximum logs to retain |
| `retentionDays` | `null` | Auto-delete logs older than N days |

### Runtime Reconfiguration

```dart
// Change config at runtime
await VooLogger.initialize(
  config: LoggingConfig(
    enablePrettyLogs: false,
    showMetadata: false,
    minimumLevel: LogLevel.warning,
  ),
);
```

## Console Output Examples

### Pretty Mode (default)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ℹ️  INFO    │ 14:32:15.123 │ [Payment][checkout]                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ User completed purchase                                                       │
├──────────────────────────────────────────────────────────────────────────────┤
│ 📊 Metadata:                                                                  │
│   • orderId: ORD-123                                                          │
│   • amount: 99.99                                                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Simple Mode (`enablePrettyLogs: false`)

```
[14:32:15.123] [INFO] [Payment] [checkout] User completed purchase
```

### Minimal Mode (production preset)

```
[INFO] User completed purchase
```

## Dio Integration

```dart
import 'package:dio/dio.dart';
import 'package:voo_logging/voo_logging.dart';

final dio = Dio();
final interceptor = VooDioInterceptor();

dio.interceptors.add(InterceptorsWrapper(
  onRequest: interceptor.onRequest,
  onResponse: interceptor.onResponse,
  onError: interceptor.onError,
));

// All HTTP requests are now logged automatically
await dio.get('https://api.example.com/users');
```

## Querying Logs

```dart
// Get recent logs
final logs = await VooLogger.instance.getLogs();

// Filter logs
final logs = await VooLogger.instance.getLogs(
  filter: LogFilter(
    levels: [LogLevel.error, LogLevel.fatal],
    category: 'Payment',
    startTime: DateTime.now().subtract(Duration(hours: 1)),
  ),
);

// Get statistics
final stats = await VooLogger.instance.getStatistics();
print('Total: ${stats.totalLogs}');
print('By level: ${stats.levelCounts}');
print('By category: ${stats.categoryCounts}');

// Clear logs
await VooLogger.instance.clearLogs();
```

## Log Stream

```dart
// Listen to logs in real-time
VooLogger.instance.stream.listen((log) {
  print('New log: ${log.message}');
});
```

## Toast Notifications

```dart
// Show toast with log (requires voo_toast setup)
VooLogger.info('Upload complete', shouldNotify: true);
VooLogger.error('Upload failed', error: e, shouldNotify: true);
```

## DevTools Extension

The package includes a DevTools extension for real-time log monitoring:

1. Run your app in debug mode
2. Open Flutter DevTools
3. Navigate to the "Voo Logger" tab
4. View, filter, and search logs in real-time

## Log Type Configuration

Configure different behaviors for different log categories:

```dart
await VooLogger.initialize(
  config: LoggingConfig(
    logTypeConfigs: {
      LogType.network: LogTypeConfig(
        enableConsoleOutput: false,  // Don't spam console with network logs
        enableDevToolsOutput: true,  // But show in DevTools
        minimumLevel: LogLevel.info,
      ),
      LogType.analytics: LogTypeConfig(
        enableConsoleOutput: false,
        enableStorage: true,
      ),
    },
  ),
);
```

## Platform Support

| Platform | Console | Storage | DevTools |
|----------|---------|---------|----------|
| iOS | ✅ | ✅ | ✅ |
| Android | ✅ | ✅ | ✅ |
| Web | ✅ | ✅ | ✅ |
| macOS | ✅ | ✅ | ✅ |
| Windows | ✅ | ✅ | ✅ |
| Linux | ✅ | ✅ | ✅ |

## API Reference

### VooLogger Static Methods

| Method | Description |
|--------|-------------|
| `verbose(message, ...)` | Log verbose message |
| `debug(message, ...)` | Log debug message |
| `info(message, ...)` | Log info message |
| `warning(message, ...)` | Log warning message |
| `error(message, ...)` | Log error with optional exception |
| `fatal(message, ...)` | Log fatal error |
| `initialize(config)` | Initialize or reconfigure logger |

### VooLogger.instance Methods

| Method | Description |
|--------|-------------|
| `getLogs(filter)` | Query stored logs |
| `getStatistics()` | Get log statistics |
| `clearLogs()` | Clear all stored logs |
| `stream` | Real-time log stream |

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Built by VooStack

Need help with Flutter development or custom logging solutions?

**[Contact Us](https://voostack.com/contact)**

VooStack builds enterprise Flutter applications and developer tools. We're here to help with your next project.
