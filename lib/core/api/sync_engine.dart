import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../di/injection.dart';
import 'offline_queue_manager.dart';
import 'supabase_client.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/academics/data/academics_repository.dart';
import '../../features/finance/data/finance_repository.dart';

class SyncEngine {
  final SupabaseClient _client;
  final OfflineQueueManager _queueManager;
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier<DateTime?>(null);

  SyncEngine({
    SupabaseClient? client,
    OfflineQueueManager? queueManager,
  })  : _client = client ?? SupabaseClientManager().client,
        _queueManager = queueManager ?? locator<OfflineQueueManager>();

  /// Start monitoring connectivity and trigger auto-sync
  void start() {
    _checkInitialConnection();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectionChange);
    
    // Load last sync time
    try {
      if (Hive.isBoxOpen(OfflineQueueManager.boxQueueName)) {
        final box = Hive.box(OfflineQueueManager.boxQueueName);
        final val = box.get('last_sync_time');
        if (val != null) {
          lastSyncNotifier.value = DateTime.tryParse(val.toString());
        }
      }
    } catch (_) {}
  }

  void stop() {
    _subscription?.cancel();
  }

  Future<void> _checkInitialConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    if (isOnlineNotifier.value) {
      triggerSync();
    }
  }

  void _handleConnectionChange(List<ConnectivityResult> results) {
    final wasOffline = !isOnlineNotifier.value;
    _updateConnectionStatus(results);
    
    // Trigger sync when transitioning from offline to online
    if (isOnlineNotifier.value && wasOffline) {
      debugPrint("🔌 Connection Restored! Starting synchronization...");
      triggerSync();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    isOnlineNotifier.value = hasConnection;
    debugPrint("📶 Connectivity Status: ${hasConnection ? 'ONLINE' : 'OFFLINE'}");
  }

  Future<void> updateLastSyncTime() async {
    final now = DateTime.now();
    lastSyncNotifier.value = now;
    try {
      if (Hive.isBoxOpen(OfflineQueueManager.boxQueueName)) {
        final box = Hive.box(OfflineQueueManager.boxQueueName);
        await box.put('last_sync_time', now.toIso8601String());
      }
    } catch (_) {}
  }

  /// Manually trigger queue processing
  Future<void> triggerSync() async {
    if (isSyncingNotifier.value || !isOnlineNotifier.value) return;

    final pending = _queueManager.getPendingOperations();
    if (pending.isEmpty) {
      // Even if no pending ops, update sync time on request
      await updateLastSyncTime();
      return;
    }

    isSyncingNotifier.value = true;
    debugPrint("🔄 SyncEngine: Starting sync for ${pending.length} pending operations.");

    try {
      bool allSuccessful = true;
      for (var op in pending) {
        final success = await _replayOperation(op);
        if (success) {
          await _queueManager.dequeue(op.id);
        } else {
          allSuccessful = false;
          // If an operation fails, stop and retry later to maintain execution order
          debugPrint("⚠️ SyncEngine: Operation failed. Halting sync queue.");
          break;
        }
      }
      if (allSuccessful) {
        await updateLastSyncTime();
      }
    } catch (e) {
      debugPrint("❌ SyncEngine: Unexpected error during sync: $e");
    } finally {
      isSyncingNotifier.value = false;
      debugPrint("🔄 SyncEngine: Sync process finished.");
    }
  }

  /// Replay a single operation on Supabase or the corresponding repository
  Future<bool> _replayOperation(OfflineOperation op) async {
    debugPrint("🔁 Replaying Operation -> ID: ${op.id}, Table: ${op.table}, Action: ${op.action}");
    
    try {
      if (op.table == 'student_attendance' && op.action == 'batch_attendance') {
        final repo = locator<AttendanceRepository>();
        final data = op.data;
        
        final res = await repo.saveStudentBatchAttendance(
          classId: data['classId'] as int,
          dateStr: data['dateStr'] as String,
          subjectId: data['subjectId'] as int?,
          employeeId: data['employeeId'] as int?,
          records: List<Map<String, dynamic>>.from(
            (data['records'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          ),
          sendSMS: data['sendSMS'] as bool? ?? false,
          sendWhatsApp: data['sendWhatsApp'] as bool? ?? false,
        );
        
        return res['success'] == true;
      } 
      
      else if (op.table == 'student_results' && op.action == 'save_grades') {
        final repo = locator<AcademicsRepository>();
        final data = op.data;
        
        final res = await repo.saveStudentGrades(
          grades: List<Map<String, dynamic>>.from(
            (data['grades'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          ),
        );
        
        return res['success'] == true;
      } 
      
      else if (op.table == 'student_results' && op.action == 'save_devoirs') {
        final repo = locator<AcademicsRepository>();
        final data = op.data;
        
        final res = await repo.saveDevoirGrades(
          devoirsList: List<Map<String, dynamic>>.from(
            (data['devoirsList'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          ),
        );
        
        return res['success'] == true;
      } 
      
      else if (op.table == 'fee_payments' && op.action == 'record_payment') {
        final repo = locator<FinanceRepository>();
        final data = op.data;
        
        final res = await repo.recordPayment(
          feeId: data['feeId'] as int,
          schoolId: data['schoolId'] as int,
          amount: (data['amount'] as num).toDouble(),
          reduction: (data['reduction'] as num).toDouble(),
          paymentMode: data['paymentMode'] as String,
          reference: data['reference'] as String,
          monthConcerned: data['monthConcerned'] as String,
          recordedBy: data['recordedBy'] as String,
          currentPaid: (data['currentPaid'] as num).toDouble(),
          currentReduction: (data['currentReduction'] as num).toDouble(),
          totalExpected: (data['totalExpected'] as num).toDouble(),
        );
        
        return res['success'] == true;
      } 
      
      // Fallback: simple upsert in Supabase table
      else {
        await _client.from(op.table).upsert(op.data);
        return true;
      }
    } catch (e) {
      debugPrint("❌ Error replaying operation ${op.id}: $e");
      return false;
    }
  }
}
