import 'package:voo_core/src/voo.dart';
import 'package:voo_core/src/voo_options.dart';
import 'package:voo_core/src/models/voo_config.dart';

/// Represents a Voo application instance.
class VooApp {
  final String name;
  final VooOptions options;
  final VooConfig? config;
  final Map<String, dynamic> _data = {};

  VooApp({required this.name, required this.options, this.config});

  /// Check if this is the default app.
  bool get isDefault => name == '[DEFAULT]';

  /// Store custom data associated with this app.
  void setData(String key, dynamic value) {
    _data[key] = value;
  }

  /// Retrieve custom data associated with this app.
  T? getData<T>(String key) {
    return _data[key] as T?;
  }

  /// Dispose this app.
  Future<void> dispose() async {
    _data.clear();
  }

  /// Delete this app.
  Future<void> delete() async {
    await dispose();
    Voo.removeApp(name);

    // Notify plugins about app deletion
    for (final plugin in Voo.plugins.values) {
      await plugin.onAppDeleted(this);
    }
  }
}
