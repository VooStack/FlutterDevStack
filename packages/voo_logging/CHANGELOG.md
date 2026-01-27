## 2.1.0

### New Features
- **FEAT**: Enhanced OTEL log adapter and trace context provider for improved telemetry correlation
- **FEAT**: Add API test configuration for Dio interceptor integration tests

### Improvements
- **REFACTOR**: Clean up OTEL log exporter debug statements
- **REFACTOR**: Update imports to use centralized voo_core package
- **REFACTOR**: Improved log entries and cleanup for better clarity
- **DEPS**: Requires `voo_core: ^1.2.0`, `voo_telemetry: ^1.1.0`

### Tests
- **TEST**: Add unit tests for OtelLogExporter functionality and log handling

---

## 2.0.0

> **BREAKING CHANGE**: Full migration to OpenTelemetry (OTEL) as the default telemetry export mechanism.

### Breaking Changes
- **REMOVED**: `CloudSyncService` and `CloudSyncConfig` are no longer used
- **REMOVED**: Custom `/api/v1/telemetry/*` endpoints - all data now flows through OTLP
- **CHANGED**: OTEL export is now auto-enabled when `Voo.context` is available
- **CHANGED**: `LoggingConfig.cloudSync` parameter is deprecated and ignored

### New Features
- **FEAT**: Auto-enable OTEL export via `Voo.context` - no manual configuration needed
- **FEAT**: Logs automatically exported to `/v1/logs` OTLP endpoint
- **FEAT**: Trace context correlation - logs include traceId/spanId from active spans
- **FEAT**: Configurable batching (10 logs debug / 50 logs production)
- **FEAT**: Automatic retry with re-queuing on export failure

### Migration Guide

```dart
// Before (1.x)
await VooLogger.initialize(
  config: LoggingConfig(
    cloudSync: CloudSyncConfig(
      enabled: true,
      endpoint: 'https://api.example.com',
      apiKey: 'your-key',
    ),
  ),
);

// After (2.0) - OTEL auto-enabled via Voo.context
await Voo.initializeApp(
  config: VooConfig(
    endpoint: 'https://api.example.com',
    apiKey: 'your-key',
  ),
);
await VooLogger.initialize(); // OTEL auto-configured!
```

---

## 1.1.1

### New Features
- **FEAT**: Add new example UI components with modular tab-based architecture
  - `ToggleOption` widget for toggle settings in configuration
  - `CategoriesTab` for categorized logging actions
  - `ConfigTab` for logging presets and options
  - `NetworkTab` for network request logging
  - `QuickLogTab` for quick log level actions
  - `StatsTab` for log statistics and configuration info
- **FEAT**: Add reusable UI components (`CategoryButton`, `CodeExample`, `ConfigInfo`, `ConfigRow`, `DemoTabButton`, `LogButton`, `LogEntryWidget`, `LogStreamWidget`, `PresetButton`, `SectionTitle`, `StatCard`, `StatChip`)

### Improvements
- **REFACTOR**: Simplified logging configuration entities (removed unnecessary immutability annotations)
- **ENHANCEMENT**: Refactored example app main.dart for cleaner architecture

---

## 1.1.0

### Improvements
- **ENHANCEMENT**: Make `projectId` optional in `CloudSyncConfig` - the API key is now sufficient for authentication as the server derives the project from it
- **ENHANCEMENT**: Updated factory constructors (`production`, `development`) to not require `projectId`
- **DEPS**: Requires `voo_core: ^1.1.0`

---

## 1.0.0

> Note: This release marks the first stable major version with breaking changes.

### Breaking Changes
- Requires `voo_core: ^1.0.0`
- Cloud sync now uses shared `BaseSyncService` from voo_core

### New Features
- **FEAT**: Add breadcrumb service integration for tracking user navigation
- **FEAT**: Feature toggle support for enabling/disabling logging features dynamically
- **FEAT**: Revenue tracking integration for logging financial events
- **FEAT**: CI/CD pipeline logging support
- **FEAT**: Enhanced batch-level metadata in sync payloads

### Improvements
- **REFACTOR**: Simplified constructor parameters and improved code readability
- **ENHANCEMENT**: Better integration with VooUserContext for session tracking
- **ENHANCEMENT**: Improved memory management and cleanup

---

## 0.4.11

 - **FIX**: Bug fixes and improvements.

## 0.4.10

 - **FIX**: Add missing `context`, `appVersion`, and `deviceId` fields to `LogEntry` entity for cloud sync.
 - **FIX**: Remove unused `cloud_sync_config.dart` import from `logger_repository_impl.dart`.
 - **FIX**: Remove duplicate `http` dev dependency (already in regular dependencies).

## 0.4.9

 - **DOCS**: Add comprehensive dartdoc comments with code examples to library, VooLogger, and LoggingConfig
 - **DOCS**: Improve API documentation for better pub.dev discoverability

## 0.4.8

 - **FIX**: Web platform compatibility for PrettyLogFormatter (removed dart:io dependency that caused silent failures)
 - **FEAT**: Add `showMetadata` configuration option to control metadata section display in log output
 - **ENHANCEMENT**: Add Config tab to example app for live configuration preview and testing
 - **DOCS**: Rewrite README with clearer zero-config usage, configuration tables, and output examples

## 0.4.7

 - **FIX**: Add error handling for web IndexedDB cursor issues (idb_shim compatibility)
 - **FIX**: Add missing `path_provider_platform_interface` dev dependency for tests
 - **ENHANCEMENT**: Graceful degradation on web when IndexedDB operations fail

## 0.4.6

 - **FEAT**: Zero-config initialization - VooLogger now auto-initializes on first use with smart defaults
 - **FEAT**: Add `LoggingConfig.minimal()` factory that auto-detects debug/release mode
 - **FEAT**: Add log retention settings (`maxLogs`, `retentionDays`, `autoCleanup`) to prevent unbounded storage growth
 - **FEAT**: Add automatic log cleanup on initialization based on retention settings
 - **FEAT**: Add `VooLogger.ensureInitialized()` for explicit initialization when custom config is needed
 - **FEAT**: Add `VooLogger.isInitialized` getter to check initialization status
 - **ENHANCEMENT**: VooCore is now optional - VooLogger works standalone without `Voo.initializeApp()`
 - **ENHANCEMENT**: Updated `LoggingConfig.development()` and `LoggingConfig.production()` with sensible retention defaults
 - **ENHANCEMENT**: Improved VooDioInterceptor documentation with clearer usage examples
 - **FIX**: Fixed version mismatch in VooLoggingPlugin (was reporting 0.2.0, now correctly reports 0.4.6)
 - **FIX**: Removed unused `shouldNotify` parameter from `verbose()` and `debug()` methods
 - **DEPRECATION**: `VooLoggingPlugin.initialize()` parameters (`maxEntries`, `enableConsoleOutput`, `enableFileStorage`) are deprecated - use `config` parameter instead

## 0.4.5

 - **FEAT**: Add per-type logging configuration for granular control over different log categories
 - **FEAT**: Separate console and DevTools output configuration for each log type
 - **FEAT**: Add LogTypeConfig entity for configuring network, analytics, error, and other log types independently
 - **FEAT**: Add production and development factory configurations with sensible defaults
 - **FEAT**: Enable storage control per log type to optimize database usage
 - **FIX**: Remove redundant minimumLevel parameter from VooLogger.initialize()
 - **FIX**: Fix repository re-initialization when config changes to properly update minimum log levels
 - **ENHANCEMENT**: Add LogType enum (general, network, analytics, performance, error, system)
 - **ENHANCEMENT**: Add withLogTypeConfig method to easily update specific log type configurations
 - **ENHANCEMENT**: Map log categories to LogType automatically for consistent configuration

## 0.4.4

 - **FEAT**: Update version in pubspec.yaml and adjust VooAdaptiveNavigationRail test for border radius and width changes.
 - **FEAT**: Add various scaffold and navigation components for improved UI structure.
 - **FEAT**: add example modules and run configurations for VooFlutter packages.

## 0.4.3

 - **FIX**: ensure proper disposal of scroll controllers in VooDataGridController.
 - **FEAT**: Introduce voo_tokens package for design tokens and responsive utilities.
 - **FEAT**: Integrate VooToast for enhanced logging notifications; update dependencies and CHANGELOG.
 - **FEAT**: Enhance form components with configurable options and improved theming.
 - **FEAT**: Update LICENSE files to include full MIT License text.
 - **FEAT**: Update VooLogging example to initialize VooCore and enhance logging configuration.
 - **FEAT**: Implement Windows runner for Voo Data Grid example.

## 0.4.2

* Fixed VooToast notification behavior:
  - Verbose and debug logs no longer show toast notifications (too low-level for user notifications)
  - Added proper log level checking to respect minimum configured log level
  - Toast notifications now only appear for info, warning, error, and fatal logs when `shouldNotify` is enabled

## 0.4.1

  fixed error causing repeated error in console ```DebugService: Error serving requestsError: Unsupported operation: Cannot send Null```
  
## 0.4.0

> Note: This release has breaking changes.

 - **REFACTOR**: remove deprecated performance sync entity and update plugin structure.
 - **REFACTOR**: Update logging package version to 0.0.7, enhance build scripts, and improve .pubignore.
 - **REFACTOR**: Update logging package configuration and remove unused web assets.
 - **REFACTOR**: Remove unused DevTools extension code and update logging scripts.
 - **REFACTOR**: Move devtools extension widgets and logic to a dedicated package.
 - **FIX**: Update cSpell configuration to include 'devstack'; adjust logging.dart for directive ordering.
 - **FEAT**: Refactor network list and performance list to use new empty state widget.
 - **FEAT**: Refactor NetworkList to support both log and request models.
 - **FEAT**: Update changelogs for voo_analytics, voo_core, voo_logging, and voo_performance packages to reflect deprecation and migration to voo_telemetry.
 - **FEAT**: Enhance topics in pubspec.yaml files for voo_analytics, voo_core, voo_logging, voo_performance, and voo_telemetry packages.
 - **FEAT**: Add comprehensive test suite and configuration for VooTelemetry package.
 - **FEAT**: Update package versions and descriptions; enhance import statements for consistency.
 - **FEAT**: Add DevStack integration guide and example app; enhance telemetry configuration and logging features.
 - **FEAT**: Enhance logging configuration with enableDevToolsJson option; update LogSyncEntity and SyncStorage for improved functionality.
 - **FEAT**: Implement cloud sync functionality for analytics, logging, and performance data; add SyncEntity and CloudSyncManager classes; update version to 0.1.0.
 - **FEAT**: Add pretty logging feature with customizable formatting options; enhance logging configuration and examples.
 - **FEAT**: Implement route-aware touch tracking and heat map visualization; enhance analytics data collection and UI components.
 - **FEAT**: Integrate Voo Analytics and Performance tracking; add example pages for analytics and performance metrics.
 - **FEAT**: Enhance Voo DevTools extension with heat map visualization and analytics improvements.
 - **FEAT**: Update package versions and enhance analytics, performance, and logging functionalities.
 - **FEAT**: Add analytics tracking and UI components to Voo DevTools extension.
 - **FEAT**: Add VooFlutter example app with integration and widget tests.
 - **FEAT**: Add logs and network details panels for improved logging functionality.
 - **FEAT**: Add new Melos run configurations for logging and testing, and update scripts in melos.yaml.
 - **FEAT**: Update version to 0.0.15 and improve CHANGELOG with formatting enhancements for better readability.
 - **FEAT**: Update CHANGELOG for version 0.0.14 with breaking changes and enhancements, add Dio example, and improve interceptor logging.
 - **FEAT**: Update version to 0.0.13 and enhance CHANGELOG with new features for network and performance monitoring.
 - **FEAT**: Add network and performance tabs to VooLoggerPage.
 - **BREAKING** **FEAT**(voo_telemetry): Complete OpenTelemetry migration for VooFlutter.

## 0.3.0

* Added WASM support for web platform
* Improved documentation and API comments
* Added comprehensive examples
* Enhanced pub.dev score compliance
* Performance optimizations

## 0.1.1

**⚠️ DEPRECATED: This package is deprecated. Please use `voo_telemetry` instead.**

* **BREAKING CHANGE**: Complete migration to OpenTelemetry standards
* **DEPRECATED**: All functionality moved to `voo_telemetry` package
* Use `voo_telemetry` for:
  - OpenTelemetry-compliant structured logging
  - Automatic trace context correlation
  - OTLP export to any compatible backend
  - Better performance and reliability

### Migration Guide

```dart
// Before
import 'package:voo_logging/voo_logging.dart';
VooLogger.log('message', level: LogLevel.info);

// After
import 'package:voo_telemetry/voo_telemetry.dart';
VooTelemetry.instance.getLogger().info('message');
```

## 0.1.0

* **BREAKING CHANGE**: Now requires voo_core ^0.1.0
* Added `enableDevToolsJson` configuration option to control JSON output in console
* Fixed duplicate log entries appearing in console (formatted + JSON)
* JSON logs for DevTools integration can now be disabled while keeping pretty formatting
* Default behavior now shows only formatted logs in console (JSON disabled by default)
* Added automatic cloud sync support for log entries
* Introduced LogSyncEntity for cloud synchronization
* Integrated with CloudSyncManager from voo_core
* Logs are automatically queued for sync when API key is configured
* Added support for batch syncing to reduce network overhead
* Enhanced repository to support cloud sync without breaking existing functionality
* Improved offline-first architecture with automatic retry

## 0.0.18

* **New Feature**: Added Pretty Logging with beautiful, structured console output
* Added `PrettyLogFormatter` class for formatting logs with colors, borders, and emojis
* Added `LoggingConfig` class to customize logging appearance and behavior
* Enhanced `VooLogger.initialize()` to accept optional `LoggingConfig` parameter
* Added support for ANSI colors in console output (automatically detected)
* Added emoji icons for each log level (💬 🐛 ℹ️ ⚠️ ❌ 💀)
* Added box-drawing characters for structured log display
* Added configurable options:
  - `enablePrettyLogs`: Toggle pretty formatting on/off
  - `showEmojis`: Show/hide emoji icons
  - `showTimestamp`: Include/exclude timestamps
  - `showColors`: Enable/disable ANSI colors
  - `showBorders`: Show/hide decorative borders
  - `lineLength`: Configure maximum line width for wrapping
* Improved metadata display with formatted key-value pairs
* Enhanced error and stack trace formatting
* Updated example app with pretty logging toggle and demonstrations
* Updated documentation with pretty logging examples and configuration

## 0.0.17

* Minor improvements and bug fixes
* Internal code optimizations

## 0.0.16

* Updated voo_core dependency to ^0.0.2
* Enhanced DevTools extension with improved network and performance panels
* Added comprehensive logging panels for better debugging experience
* Improved integration with voo_analytics and voo_performance packages
* Enhanced overall package stability and compatibility

## 0.0.15

* Improved code formatting in VooDioInterceptor for better readability
* Applied dart format to ensure consistent code style

## 0.0.14

* **BREAKING**: VooDioInterceptor methods now return `void` instead of `Future<void>` for proper Dio compatibility
* Enhanced network interceptor to properly track request and response data separately
* Added proper request body tracking as `requestBody` in metadata
* Added proper response body tracking as `responseBody` in metadata
* Fixed DevTools extension to display both request and response bodies in network details
* Added comprehensive Dio example with multiple test scenarios
* Added extensive test coverage for VooDioInterceptor
* Fixed type casting error in network interceptor for response body
* Improved header tracking for both requests and responses

## 0.0.13

* Added network monitoring tab with request/response tracking
* Added performance monitoring tab with metrics visualization
* Improved UI components with consistent spacing constants
* Enhanced state management for tab switching to maintain state
* Updated padding and layout across all components for better UI consistency
* Improved DevTools extension with dedicated network and performance features

## 0.0.12

* Fixed category filtering in DevTools extension to show all unique categories from logs
* Removed duplicate "All" option in category dropdown filter
* Categories are now properly extracted from all logs instead of just filtered logs
* Category list updates dynamically when new logs with new categories are received
* "All" category option now correctly shows all logs regardless of category

## 0.0.11

* Fixed DevTools extension not receiving logs from VooLogger
* Refactored DevTools extension to follow clean architecture principles
* Split datasource into interface and implementation for better separation of concerns
* Removed all debug logging for cleaner production code
* Simplified VM Service connection with automatic retry mechanism
* DevTools extension now properly listens to structured logs via VM Service streaming
* Removed unused stub implementations and unnecessary files

## 0.0.10

* Improved documentation and development instructions

## 0.0.9

* Release updates and maintenance improvements

## 0.0.8

* Removed test/debug logging that was appearing in production
* Removed polling test logs from DevTools extension
* Cleaned up unnecessary debug log statements

## 0.0.7

* Fixed DevTools extension loading issue for published package
* Corrected .pubignore to include main.dart.js in published package
* Ensured all extension build files are properly distributed

## 0.0.6

* fixed .gitignore to allow build folder for dev tools output

## 0.0.5

* aligned versions to match (logging => dev tools)
  
## 0.0.4

* bumped dev tools extension version

## 0.0.3

* Fixed bugs related to logging overflow in dev tools

## 0.0.2

* Add Voo Logger DevTools extension with advanced logging capabilities
* Enhance documentation with detailed installation and usage instructions
* Add automated release workflows for pub.dev publishing
* Update dependencies for improved compatibility
* Refactor code for better readability and consistency
* Add comprehensive CI/CD workflow with devtools extension support
* Improve project structure and analysis options

## 0.0.1

* Initial release
* Core logging functionality with multiple log levels
* Persistent storage using Sembast
* Session and user tracking
* DevTools extension for log viewing and filtering
* Support for categories, tags, and metadata
* Export functionality (JSON, CSV)
* Cross-platform support (iOS, Android, Web, Desktop)
