# FlutterDevStack

Flutter SDK suite for DevStack telemetry and observability. A comprehensive toolkit for logging, analytics, performance monitoring, and OpenTelemetry integration.

## Packages

| Package | Version | Description |
|---------|---------|-------------|
| [voo_core](packages/voo_core) | 0.4.3 | Core plugin system and shared utilities |
| [voo_logging](packages/voo_logging) | 0.4.11 | Structured logging with cloud sync |
| [voo_analytics](packages/voo_analytics) | 0.4.4 | Event tracking, user sessions, heat maps |
| [voo_performance](packages/voo_performance) | 0.4.3 | Performance tracing and network metrics |
| [voo_telemetry](packages/voo_telemetry) | 0.2.3 | OpenTelemetry OTLP integration |

## Installation

Add the packages you need to your `pubspec.yaml`:

```yaml
dependencies:
  voo_core: ^0.4.3
  voo_logging: ^0.4.11
  voo_analytics: ^0.4.4
  voo_performance: ^0.4.3
```

## Quick Start

### 1. Initialize Core

```dart
import 'package:voo_core/voo_core.dart';

await Voo.initializeApp(
  options: VooOptions(
    customConfig: {
      'projectId': 'your-project-id',
      'organizationId': 'your-org-id',
    },
  ),
);
```

### 2. Setup Logging

```dart
import 'package:voo_logging/voo_logging.dart';

await VooLogger.initialize(
  appName: 'MyApp',
  appVersion: '1.0.0',
  config: LoggingConfig(
    minimumLevel: LogLevel.debug,
    cloudSync: CloudSyncConfig(
      enabled: true,
      endpoint: 'https://api.devstack.io',
      apiKey: 'ds_test_xxx',
      projectId: 'your-project-id',
    ),
  ),
);

// Usage
await VooLogger.info('App started', category: 'Lifecycle');
await VooLogger.error('API failed', error: e, stackTrace: stackTrace);
```

### 3. Setup Analytics

```dart
import 'package:voo_analytics/voo_analytics.dart';

await VooAnalytics.initialize();

// Track events
VooAnalytics.trackEvent('button_clicked', properties: {
  'button_id': 'submit',
  'screen': 'checkout',
});

// Set user context
VooAnalytics.setUserId('user-123');
VooAnalytics.setUserProperty('plan', 'premium');
```

### 4. Setup Performance Monitoring

```dart
import 'package:voo_performance/voo_performance.dart';

await VooPerformancePlugin.initialize(
  enableNetworkMonitoring: true,
  enableTraceMonitoring: true,
  enableAutoAppStartTrace: true,
);

// Manual traces
final trace = await VooPerformancePlugin.instance.startTrace('api_call');
// ... perform operation
await trace.stop();

// Dio integration
dio.interceptors.add(InterceptorsWrapper(
  onRequest: VooPerformanceDioInterceptor().onRequest,
  onResponse: VooPerformanceDioInterceptor().onResponse,
  onError: VooPerformanceDioInterceptor().onError,
));
```

## Architecture

```
FlutterDevStack/
├── packages/
│   ├── voo_core/           # Foundation package
│   │   └── lib/
│   │       ├── src/
│   │       │   ├── voo.dart              # Main initialization
│   │       │   ├── voo_plugin.dart       # Base plugin class
│   │       │   ├── services/             # Shared services
│   │       │   └── config/               # Shared config
│   │       └── voo_core.dart             # Exports
│   │
│   ├── voo_logging/        # Logging package
│   ├── voo_analytics/      # Analytics package
│   ├── voo_performance/    # Performance package
│   └── voo_telemetry/      # OpenTelemetry package
│
├── tools/
│   └── voo_devtools_extension/   # Chrome DevTools extension
│
└── melos.yaml              # Mono-repo configuration
```

## Cloud Sync

All telemetry packages support automatic cloud sync to DevStack:

- **Batching**: Collects items and sends in batches (default: 50 items)
- **Interval**: Auto-flush at regular intervals (default: 60 seconds)
- **Retry**: Automatic retry with exponential backoff
- **Offline**: Queues items when offline, syncs when connected

### Configuration

```dart
CloudSyncConfig(
  enabled: true,
  endpoint: 'https://api.devstack.io',
  apiKey: 'ds_test_xxx',
  projectId: 'your-project-id',
  batchSize: 50,
  batchInterval: Duration(seconds: 60),
  maxRetries: 3,
  maxQueueSize: 1000,
)
```

## DevTools Extension

The DevTools extension provides real-time visibility into:
- Log entries with filtering
- Analytics events
- Performance traces
- Network requests

Build the extension:
```bash
melos run build_devtools_extension
```

## Development

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Melos CLI

### Setup

```bash
# Install Melos
dart pub global activate melos

# Bootstrap packages
melos bootstrap
```

### Common Commands

```bash
melos run get            # Get dependencies
melos run test_all       # Run all tests
melos run analyze        # Static analysis
melos run format         # Format code
melos run publish        # Publish packages
```

## API Keys

DevStack API keys follow this format:
- `ds_test_*` - Development/test keys
- `ds_live_*` - Production keys

Get your API key from the DevStack dashboard.

## License

MIT License - See [LICENSE](LICENSE) for details.
