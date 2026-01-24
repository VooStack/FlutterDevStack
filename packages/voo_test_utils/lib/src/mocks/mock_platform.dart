import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Mock implementation of PathProviderPlatform for testing.
class MockPathProviderPlatform extends PathProviderPlatform {
  final String? applicationDocumentsPath;
  final String? temporaryPath;
  final String? applicationSupportPath;
  final String? libraryPath;
  final String? externalStoragePath;
  final List<String>? externalCachePaths;
  final List<String>? externalStoragePaths;
  final String? downloadPath;

  MockPathProviderPlatform({
    this.applicationDocumentsPath = '.',
    this.temporaryPath = '.',
    this.applicationSupportPath = '.',
    this.libraryPath = '.',
    this.externalStoragePath = '.',
    this.externalCachePaths,
    this.externalStoragePaths,
    this.downloadPath = '.',
  });

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      applicationDocumentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;

  @override
  Future<String?> getApplicationSupportPath() async => applicationSupportPath;

  @override
  Future<String?> getLibraryPath() async => libraryPath;

  @override
  Future<String?> getExternalStoragePath() async => externalStoragePath;

  @override
  Future<List<String>?> getExternalCachePaths() async => externalCachePaths;

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async =>
      externalStoragePaths;

  @override
  Future<String?> getDownloadsPath() async => downloadPath;
}

/// Sets up a mock test environment with Flutter binding and path provider.
void setUpTestEnvironment({
  String applicationDocumentsPath = '.',
  String temporaryPath = '.',
  String applicationSupportPath = '.',
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = MockPathProviderPlatform(
    applicationDocumentsPath: applicationDocumentsPath,
    temporaryPath: temporaryPath,
    applicationSupportPath: applicationSupportPath,
  );
}

/// Resets the test environment after tests.
void tearDownTestEnvironment() {
  // Reset any static state if needed
}
