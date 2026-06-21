import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineOperation {
  final String id;
  final String table;
  final String action; // 'insert' | 'update' | 'delete' | 'batch_insert' | 'custom'
  final Map<String, dynamic> data;
  final String timestamp;
  bool isSynced;

  OfflineOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
    required this.timestamp,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table': table,
      'action': action,
      'data': data,
      'timestamp': timestamp,
      'isSynced': isSynced,
    };
  }

  factory OfflineOperation.fromMap(Map<dynamic, dynamic> map) {
    return OfflineOperation(
      id: map['id'] as String,
      table: map['table'] as String,
      action: map['action'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
      timestamp: map['timestamp'] as String,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }
}

class OfflineQueueManager {
  static const String boxQueueName = 'operations_queue';

  /// Initialize queue box
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) {
        await Hive.openBox(boxQueueName);
      }
      debugPrint("✅ OfflineQueueManager: Queue Hive box initialized successfully.");
    } catch (e) {
      debugPrint("❌ OfflineQueueManager Initialization Error: $e");
    }
  }

  /// Enqueue a new operation
  Future<void> enqueue({
    required String table,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    try {
      final box = Hive.box(boxQueueName);
      final id = "${DateTime.now().millisecondsSinceEpoch}_${table}_$action";
      
      final operation = OfflineOperation(
        id: id,
        table: table,
        action: action,
        data: data,
        timestamp: DateTime.now().toIso8601String(),
      );

      await box.put(id, operation.toMap());
      debugPrint("➕ Enqueued Operation -> ID: $id, Table: $table, Action: $action");
    } catch (e) {
      debugPrint("❌ Error enqueuing operation: $e");
    }
  }

  /// Get list of all pending operations sorted chronologically
  List<OfflineOperation> getPendingOperations() {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) return [];
      final box = Hive.box(boxQueueName);
      
      final List<OfflineOperation> list = [];
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          list.add(OfflineOperation.fromMap(val));
        }
      }
      
      // Sort by timestamp or ID
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (e) {
      debugPrint("❌ Error reading queue: $e");
      return [];
    }
  }

  /// Remove operation from queue (after successful sync)
  Future<void> dequeue(String id) async {
    try {
      final box = Hive.box(boxQueueName);
      await box.delete(id);
      debugPrint("➖ Dequeued Operation -> ID: $id");
    } catch (e) {
      debugPrint("❌ Error dequeuing operation $id: $e");
    }
  }

  /// Clear the entire queue
  Future<void> clearQueue() async {
    try {
      if (Hive.isBoxOpen(boxQueueName)) {
        await Hive.box(boxQueueName).clear();
      }
    } catch (e) {
      debugPrint("❌ Error clearing queue: $e");
    }
  }
}
