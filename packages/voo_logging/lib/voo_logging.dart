/// A zero-config, production-ready logging package for Flutter.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:voo_logging/voo_logging.dart';
///
/// // Just use it - no initialization required!
/// VooLogger.info('Hello world');
/// VooLogger.debug('Debug message');
/// VooLogger.warning('Warning message');
/// VooLogger.error('Error occurred', error: e);
/// ```
///
/// ## Structured Logging
///
/// ```dart
/// VooLogger.info(
///   'User logged in',
///   category: 'Auth',
///   tag: 'login',
///   metadata: {'userId': '123', 'method': 'email'},
/// );
/// ```
///
/// ## Configuration
///
/// ```dart
/// // Use presets
/// await VooLogger.initialize(config: LoggingConfig.development());
/// await VooLogger.initialize(config: LoggingConfig.production());
///
/// // Or customize
/// await VooLogger.initialize(
///   config: LoggingConfig(
///     enablePrettyLogs: true,
///     showEmojis: true,
///     showTimestamp: true,
///     showBorders: true,
///     showMetadata: true,
///     minimumLevel: LogLevel.debug,
///   ),
/// );
/// ```
///
/// ## Dio Integration
///
/// ```dart
/// final dio = Dio();
/// final interceptor = VooDioInterceptor();
///
/// dio.interceptors.add(InterceptorsWrapper(
///   onRequest: interceptor.onRequest,
///   onResponse: interceptor.onResponse,
///   onError: interceptor.onError,
/// ));
///
/// // All HTTP requests are now logged automatically
/// ```
///
/// ## Features
///
/// - Zero-config: works out of the box
/// - Pretty console output with colors, borders, emojis
/// - Persistent storage (survives app restarts)
/// - DevTools integration for real-time monitoring
/// - Dio interceptor for automatic HTTP logging
/// - Cross-platform: iOS, Android, Web, macOS, Windows, Linux
///
/// See the [README](https://pub.dev/packages/voo_logging) for full documentation.
library voo_logging;

export 'core/core.dart';
export 'features/logging/domain/entities/network_log_entry.dart';
export 'features/logging/domain/interceptors/dio_interceptor.dart';
export 'features/logging/domain/interceptors/network_interceptor.dart';
export 'features/logging/logging.dart';
// OTEL components
export 'src/otel/otel_logging_config.dart';
export 'src/otel/trace_context_provider.dart' show TraceContext, TraceContextProvider;
export 'src/voo_logging_plugin.dart';
