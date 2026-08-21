import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineOperation {
  final String id;
  final String table;
  final String action; // 'insert' | 'update' | 'delete' | 'batch_insert' | 'custom'
  final Map<String, dynamic> data;
  final String timestamp;
  bool isSynced;
  int retryCount;
  String? lastError;

  static const int maxRetries = 3;

  OfflineOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
    required this.timestamp,
    this.isSynced = false,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table': table,
      'action': action,
      'data': data,
      'timestamp': timestamp,
      'isSynced': isSynced,
      'retryCount': retryCount,
      'lastError': lastError,
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
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
    );
  }
}

class OfflineQueueManager {
  static const String boxQueueName = 'operations_queue';
  /// Dead-letter queue: stores operations that failed after maxRetries
  static const String boxDeadLetterName = 'operations_dlq';
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// Initialize queue box
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) {
        await Hive.openBox(boxQueueName);
      }
      if (!Hive.isBoxOpen(boxDeadLetterName)) {
        await Hive.openBox(boxDeadLetterName);
      }
      _updatePendingCount();
      debugPrint("✅ OfflineQueueManager: Queue Hive box initialized successfully.");
    } catch (e) {
      debugPrint("❌ OfflineQueueManager Initialization Error: $e");
    }
  }

  void _updatePendingCount() {
    pendingCountNotifier.value = getPendingOperations().length;
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
      _updatePendingCount();
      debugPrint("➕ Enqueued Operation -> ID: $id, Table: $table, Action: $action");
    } catch (e) {
      debugPrint("❌ Failed to enqueue operation: $e");
    }
  }

  /// Enqueue an HTTP API request for offline synchronization
  Future<void> enqueueRequest({
    required String endpoint,
    required String method,
    required Map<String, dynamic> body,
  }) async {
    await enqueue(
      table: endpoint,
      action: method,
      data: body,
    );
  }

  /// Get list of all pending operations sorted chronologically
  List<OfflineOperation> getPendingOperations() {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) return [];
      final box = Hive.box(boxQueueName);
      
      final List<OfflineOperation> list = [];
      for (var key in box.keys) {
        if (key == 'last_sync_time') continue;
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
      _updatePendingCount();
      debugPrint("➖ Dequeued Operation -> ID: $id");
    } catch (e) {
      debugPrint("❌ Error dequeuing operation $id: $e");
    }
  }

  /// Increment retry count for a failed operation
  Future<void> incrementRetry(String id, {String? error}) async {
    try {
      final box = Hive.box(boxQueueName);
      final val = box.get(id);
      if (val is Map) {
        final op = OfflineOperation.fromMap(val);
        op.retryCount += 1;
        op.lastError = error;
        await box.put(id, op.toMap());
        debugPrint("🔁 Retry #${op.retryCount} for Operation -> ID: $id");
      }
    } catch (e) {
      debugPrint("❌ Error updating retry count for $id: $e");
    }
  }

  /// Move a permanently failed operation to the dead-letter queue
  Future<void> moveToDeadLetter(String id, {String? reason}) async {
    try {
      final box = Hive.box(boxQueueName);
      final dlqBox = Hive.box(boxDeadLetterName);
      final val = box.get(id);
      if (val is Map) {
        final op = OfflineOperation.fromMap(val);
        op.lastError = reason ?? op.lastError;
        await dlqBox.put("dlq_$id", op.toMap());
        await box.delete(id);
        _updatePendingCount();
        debugPrint("☠️ Operation moved to Dead-Letter Queue -> ID: $id, Reason: $reason");
      }
    } catch (e) {
      debugPrint("❌ Error moving to DLQ: $e");
    }
  }

  /// Get all dead-letter operations for admin inspection
  List<OfflineOperation> getDeadLetterOperations() {
    try {
      if (!Hive.isBoxOpen(boxDeadLetterName)) return [];
      final box = Hive.box(boxDeadLetterName);
      return box.values
          .whereType<Map>()
          .map((e) => OfflineOperation.fromMap(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear the entire queue
  Future<void> clearQueue() async {
    try {
      if (Hive.isBoxOpen(boxQueueName)) {
        await Hive.box(boxQueueName).clear();
        _updatePendingCount();
      }
    } catch (e) {
      debugPrint("❌ Error clearing queue: $e");
    }
  }
}
