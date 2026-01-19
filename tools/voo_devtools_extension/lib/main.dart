import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:voo_analytics/voo_analytics.dart';
import 'package:voo_core/voo_core.dart';
import 'package:voo_devtools_extension/core/services/theme_service.dart';
import 'package:voo_devtools_extension/presentation/widgets/app_wrapper.dart';
import 'package:voo_logging/voo_logging.dart';
import 'package:voo_performance/voo_performance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dogfooding: Initialize Voo core for the DevTools extension itself
  // No config = local only, no API sync (appropriate for the extension)
  await Voo.initializeApp();

  // Initialize VooLogger for structured logging
  await VooLogger.ensureInitialized(
    config: LoggingConfig(
      minimumLevel: LogLevel.debug,
      enablePrettyLogs: true,
      showEmojis: true,
    ),
  );

  // Initialize VooAnalytics for event tracking
  await VooAnalyticsPlugin.initialize(
    enableTouchTracking: false, // Not needed for DevTools extension
    enableEventLogging: true,
    enableUserProperties: true,
  );

  // Initialize VooPerformance for performance tracing
  await VooPerformancePlugin.initialize(
    enableNetworkMonitoring: false, // Extension doesn't make API calls
    enableTraceMonitoring: true,
    enableAutoAppStartTrace: true,
  );

  await VooLogger.info(
    'VooDevToolsExtension starting',
    category: 'Lifecycle',
    tag: 'startup',
  );

  await ThemeService().initialize();
  runApp(const VooDevToolsExtension());
}

class VooDevToolsExtension extends StatelessWidget {
  const VooDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Voo DevTools',
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeService.themeMode,
          home: DevToolsExtension(child: AppWrapper()),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    const seedColor = Color(0xFF00796B); // Teal
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const seedColor = Color(0xFF00796B); // Teal
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
