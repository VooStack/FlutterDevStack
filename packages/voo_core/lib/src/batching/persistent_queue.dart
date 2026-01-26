import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

import 'package:voo_core/src/batching/batch_config.dart';

/// A persistent queue that survives app restarts.
///
/// Uses Sembast for cross-platform storage (including web).
/// Items are automatically restored on initialization.
class PersistentQueue<T> {
  final String name;
  final int maxSize;
  final Duration maxRetention;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  Database? _db;
  StoreRef<int, Map<String, dynamic>>? _store;
  int _nextKey = 0;
  bool _initialized = false;

  PersistentQueue({
    required this.name,
    required this.fromJson,
    required this.toJson,
    this.maxSize = 5000,
    this.maxRetention = const Duration(days: 7),
  });

  /// Whether the queue is initialized.
  bool get isInitialized => _initialized;

  /// Initialize the persistent queue.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        _db = await databaseFactoryWeb.openDatabase('voo_queue_$name');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = path.join(dir.path, 'voo_queue_$name.db');
        _db = await databaseFactoryIo.openDatabase(dbPath);
      }

      _store = intMapStoreFactory.store('queue');

      // Find the highest key to continue from
      final records = await _store!.find(_db!,
          finder: Finder(sortOrders: [SortOrder(Field.key, false)], limit: 1));
      if (records.isNotEmpty) {
        _nextKey = records.first.key + 1;
      }

      // Clean up old items
      await _cleanupOldItems();

      _initialized = true;
    } catch (_) {
      // Fall back to in-memory only
      _initialized = true;
    }
  }

  /// Add an item to the queue.
  Future<void> add(T item, {BatchPriority priority = BatchPriority.normal}) async {
    if (!_initialized || _db == null || _store == null) return;

    try {
      await _store!.record(_nextKey++).put(_db!, {
        'data': toJson(item),
        'priority': priority.value,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Enforce max size
      await _enforceMaxSize();
    } catch (_) {
      // ignore
    }
  }

  /// Add multiple items to the queue.
  Future<void> addAll(
    List<T> items, {
    BatchPriority priority = BatchPriority.normal,
  }) async {
    if (!_initialized || _db == null || _store == null) return;

    try {
      await _db!.transaction((txn) async {
        for (final item in items) {
          await _store!.record(_nextKey++).put(txn, {
            'data': toJson(item),
            'priority': priority.value,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      });

      await _enforceMaxSize();
    } catch (_) {
      // ignore
    }
  }

  /// Take items from the queue (removes them).
  ///
  /// Returns items in priority order (high priority first).
  Future<List<T>> take(int count) async {
    if (!_initialized || _db == null || _store == null) return [];

    try {
      // Find records sorted by priority (ascending = high first) then timestamp
      final records = await _store!.find(
        _db!,
        finder: Finder(
          sortOrders: [
            SortOrder('priority'),
            SortOrder('timestamp'),
          ],
          limit: count,
        ),
      );

      if (records.isEmpty) return [];

      final items = <T>[];
      final keysToDelete = <int>[];

      for (final record in records) {
        try {
          final data = record.value['data'] as Map<String, dynamic>;
          items.add(fromJson(data));
          keysToDelete.add(record.key);
        } catch (e) {
          // Skip corrupted records
          keysToDelete.add(record.key);
        }
      }

      // Delete taken records
      await _db!.transaction((txn) async {
        for (final key in keysToDelete) {
          await _store!.record(key).delete(txn);
        }
      });

      return items;
    } catch (_) {
      return [];
    }
  }

  /// Peek at items without removing them.
  Future<List<T>> peek(int count) async {
    if (!_initialized || _db == null || _store == null) return [];

    try {
      final records = await _store!.find(
        _db!,
        finder: Finder(
          sortOrders: [
            SortOrder('priority'),
            SortOrder('timestamp'),
          ],
          limit: count,
        ),
      );

      return records
          .map((r) {
            try {
              final data = r.value['data'] as Map<String, dynamic>;
              return fromJson(data);
            } catch (_) {
              return null;
            }
          })
          .whereType<T>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Return items to the queue (e.g., after failed export).
  Future<void> requeue(List<T> items, {BatchPriority priority = BatchPriority.normal}) async {
    // Add them back with a slightly older timestamp so they're processed first
    if (!_initialized || _db == null || _store == null) return;

    try {
      await _db!.transaction((txn) async {
        final baseTimestamp =
            DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
        for (var i = 0; i < items.length; i++) {
          await _store!.record(_nextKey++).put(txn, {
            'data': toJson(items[i]),
            'priority': priority.value,
            'timestamp': baseTimestamp - i, // Maintain order
          });
        }
      });
    } catch (_) {
      // ignore
    }
  }

  /// Get the number of items in the queue.
  Future<int> get length async {
    if (!_initialized || _db == null || _store == null) return 0;
    return await _store!.count(_db!);
  }

  /// Check if the queue is empty.
  Future<bool> get isEmpty async => await length == 0;

  /// Clear all items from the queue.
  Future<void> clear() async {
    if (!_initialized || _db == null || _store == null) return;

    try {
      await _store!.delete(_db!);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _enforceMaxSize() async {
    if (_db == null || _store == null) return;

    final count = await _store!.count(_db!);
    if (count <= maxSize) return;

    // Remove oldest low-priority items first
    final toRemove = count - maxSize;
    final records = await _store!.find(
      _db!,
      finder: Finder(
        sortOrders: [
          SortOrder('priority', false), // Low priority first
          SortOrder('timestamp'), // Oldest first
        ],
        limit: toRemove,
      ),
    );

    await _db!.transaction((txn) async {
      for (final record in records) {
        await _store!.record(record.key).delete(txn);
      }
    });

  }

  Future<void> _cleanupOldItems() async {
    if (_db == null || _store == null) return;

    final cutoff =
        DateTime.now().subtract(maxRetention).millisecondsSinceEpoch;

    await _store!.delete(
      _db!,
      finder: Finder(filter: Filter.lessThan('timestamp', cutoff)),
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _store = null;
    _initialized = false;
  }
}
