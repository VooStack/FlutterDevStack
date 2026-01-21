import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voo_devtools_extension/core/services/package_detection_service.dart';
import 'package:voo_devtools_extension/data/datasources/devtools_log_datasource_impl.dart';
import 'package:voo_devtools_extension/data/repositories/devtools_log_repository_impl.dart';
import 'package:voo_devtools_extension/domain/repositories/devtools_log_repository.dart';
import 'package:voo_devtools_extension/presentation/pages/adaptive_voo_page.dart';

/// Wrapper widget that initializes dependencies after DevToolsExtension.
///
/// This widget handles:
/// - Package detection service initialization
/// - Data source and repository creation
/// - Passing repository to AdaptiveVooPage for local BLoC provision
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  late final PackageDetectionService packageDetectionService;
  late final DevToolsLogDataSourceImpl dataSource;
  late final DevToolsLogRepository repository;

  @override
  void initState() {
    super.initState();
    // Initialize package detection service
    packageDetectionService = PackageDetectionService();
    packageDetectionService.startMonitoring();

    // Initialize after DevToolsExtension has set up serviceManager
    dataSource = DevToolsLogDataSourceImpl();
    repository = DevToolsLogRepositoryImpl(dataSource: dataSource);
  }

  @override
  void dispose() {
    packageDetectionService.stopMonitoring();
    packageDetectionService.dispose();
    dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provide repository via RepositoryProvider for page-level BLoC creation
    return RepositoryProvider<DevToolsLogRepository>.value(
      value: repository,
      child: StreamBuilder<Map<String, bool>>(
        stream: packageDetectionService.packageStatusStream,
        initialData: packageDetectionService.packageStatus,
        builder: (context, snapshot) {
          final packageStatus = snapshot.data ?? {};
          return AdaptiveVooPage(pluginStatus: packageStatus);
        },
      ),
    );
  }
}
