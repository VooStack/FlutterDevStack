import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import 'package:dio/dio.dart';
import 'package:voo_toast/voo_toast.dart';
import 'widgets/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // VooLogger now works with ZERO configuration!
  // Just call logging methods directly - it auto-initializes with smart defaults.
  //
  // For explicit control, use:
  // await VooLogger.ensureInitialized(config: LoggingConfig.production());

  // Optional: Initialize VooToast for toast notifications
  try {
    VooToastController.instance;
  } catch (_) {
    VooToastController.init();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VooLogging Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const VooToastOverlay(child: LoggingDemoScreen()),
    );
  }
}

class LoggingDemoScreen extends StatefulWidget {
  const LoggingDemoScreen({super.key});

  @override
  State<LoggingDemoScreen> createState() => _LoggingDemoScreenState();
}

class _LoggingDemoScreenState extends State<LoggingDemoScreen> {
  late final Dio dio;
  List<LogEntry> recentLogs = [];
  LogStatistics? stats;
  bool toastEnabled = false;
  int _selectedTab = 0;

  // Config options
  String _selectedPreset = 'default';
  bool _enablePrettyLogs = true;
  bool _showEmojis = true;
  bool _showTimestamp = true;
  bool _showBorders = true;
  bool _showMetadata = true;
  LogLevel _minimumLevel = LogLevel.verbose;

  @override
  void initState() {
    super.initState();
    _setupDio();
    _listenToLogs();
    _loadStats();
  }

  void _setupDio() {
    dio = Dio();
    final interceptor = VooDioInterceptor();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: interceptor.onRequest,
      onResponse: interceptor.onResponse,
      onError: interceptor.onError,
    ));
  }

  void _listenToLogs() {
    VooLogger.instance.stream.listen((log) {
      setState(() {
        recentLogs.insert(0, log);
        if (recentLogs.length > 50) recentLogs.removeLast();
      });
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final newStats = await VooLogger.instance.getStatistics();
    setState(() => stats = newStats);
  }

  Future<void> _clearLogs() async {
    await VooLogger.instance.clearLogs();
    setState(() => recentLogs.clear());
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VooLogging Demo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(toastEnabled ? Icons.notifications_active : Icons.notifications_off_outlined),
            onPressed: () => setState(() => toastEnabled = !toastEnabled),
            tooltip: 'Toggle toast notifications',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                DemoTabButton(
                  label: 'Quick Log',
                  index: 0,
                  icon: Icons.flash_on,
                  isSelected: _selectedTab == 0,
                  onSelect: (index) => setState(() => _selectedTab = index),
                ),
                DemoTabButton(
                  label: 'Categories',
                  index: 1,
                  icon: Icons.category,
                  isSelected: _selectedTab == 1,
                  onSelect: (index) => setState(() => _selectedTab = index),
                ),
                DemoTabButton(
                  label: 'Network',
                  index: 2,
                  icon: Icons.wifi,
                  isSelected: _selectedTab == 2,
                  onSelect: (index) => setState(() => _selectedTab = index),
                ),
                DemoTabButton(
                  label: 'Config',
                  index: 3,
                  icon: Icons.tune,
                  isSelected: _selectedTab == 3,
                  onSelect: (index) => setState(() => _selectedTab = index),
                ),
                DemoTabButton(
                  label: 'Stats',
                  index: 4,
                  icon: Icons.analytics,
                  isSelected: _selectedTab == 4,
                  onSelect: (index) => setState(() => _selectedTab = index),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                QuickLogTab(
                  toastEnabled: toastEnabled,
                  onLogWithMetadata: _logWithMetadata,
                  onLogMultiple: _logMultiple,
                ),
                const CategoriesTab(),
                NetworkTab(onMakeRequest: _makeRequest),
                ConfigTab(
                  selectedPreset: _selectedPreset,
                  enablePrettyLogs: _enablePrettyLogs,
                  showEmojis: _showEmojis,
                  showTimestamp: _showTimestamp,
                  showBorders: _showBorders,
                  showMetadata: _showMetadata,
                  minimumLevel: _minimumLevel,
                  onPresetSelected: _applyPreset,
                  onPrettyLogsChanged: (v) {
                    setState(() => _enablePrettyLogs = v);
                    _applyConfig();
                  },
                  onShowEmojisChanged: (v) {
                    setState(() => _showEmojis = v);
                    _applyConfig();
                  },
                  onShowTimestampChanged: (v) {
                    setState(() => _showTimestamp = v);
                    _applyConfig();
                  },
                  onShowBordersChanged: (v) {
                    setState(() => _showBorders = v);
                    _applyConfig();
                  },
                  onShowMetadataChanged: (v) {
                    setState(() => _showMetadata = v);
                    _applyConfig();
                  },
                  onMinimumLevelChanged: (level) {
                    setState(() => _minimumLevel = level);
                    _applyConfig();
                  },
                  onLogAllLevels: _logAllLevels,
                ),
                StatsTab(stats: stats),
              ],
            ),
          ),
          LogStreamWidget(logs: recentLogs),
        ],
      ),
    );
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'development':
          _enablePrettyLogs = true;
          _showEmojis = true;
          _showTimestamp = true;
          _showBorders = true;
          _showMetadata = true;
          _minimumLevel = LogLevel.verbose;
        case 'production':
          _enablePrettyLogs = false;
          _showEmojis = false;
          _showTimestamp = true;
          _showBorders = false;
          _showMetadata = false;
          _minimumLevel = LogLevel.warning;
        case 'minimal':
          _enablePrettyLogs = false;
          _showEmojis = false;
          _showTimestamp = false;
          _showBorders = false;
          _showMetadata = false;
          _minimumLevel = LogLevel.info;
        default:
          _enablePrettyLogs = true;
          _showEmojis = true;
          _showTimestamp = true;
          _showBorders = true;
          _showMetadata = true;
          _minimumLevel = LogLevel.verbose;
      }
    });
    _applyConfig();
  }

  Future<void> _applyConfig() async {
    final config = LoggingConfig(
      enablePrettyLogs: _enablePrettyLogs,
      showEmojis: _showEmojis,
      showTimestamp: _showTimestamp,
      showBorders: _showBorders,
      showMetadata: _showMetadata,
      minimumLevel: _minimumLevel,
    );
    await VooLogger.initialize(config: config);
  }

  void _logAllLevels() {
    VooLogger.verbose('This is a verbose message - detailed tracing info');
    VooLogger.debug('This is a debug message - debugging information');
    VooLogger.info('This is an info message - general information');
    VooLogger.warning('This is a warning message - something to watch');
    VooLogger.error('This is an error message', error: Exception('Sample error'));
    VooLogger.fatal('This is a fatal message', error: Exception('Critical failure'));
  }

  void _logWithMetadata() {
    VooLogger.info(
      'User interaction logged',
      category: 'Analytics',
      tag: 'user_action',
      metadata: {
        'screen': 'demo',
        'action': 'button_click',
        'timestamp': DateTime.now().toIso8601String(),
        'sessionId': 'demo-session-123',
      },
      shouldNotify: toastEnabled,
    );
  }

  Future<void> _logMultiple() async {
    for (var i = 1; i <= 10; i++) {
      await VooLogger.info('Batch log #$i', category: 'Batch', tag: 'test');
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _makeRequest(String url, {bool isPost = false}) async {
    try {
      if (isPost) {
        await dio.post(url, data: {'title': 'Test', 'body': 'Content'});
      } else {
        await dio.get(url);
      }
      VooLogger.info('Request completed: $url', category: 'Network', shouldNotify: toastEnabled);
    } catch (e) {
      VooLogger.error('Request failed: $url', category: 'Network', error: e, shouldNotify: toastEnabled);
    }
  }
}
