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
import '../../features/students/data/students_repository.dart';
import '../../features/dashboard/data/dashboard_stats_repository.dart';
import '../../features/pedagogie/data/pedagogie_repository.dart';

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
      preloadAllOfflineData();
    }
  }

  void _handleConnectionChange(List<ConnectivityResult> results) {
    final wasOffline = !isOnlineNotifier.value;
    _updateConnectionStatus(results);
    
    // Trigger sync when transitioning from offline to online
    if (isOnlineNotifier.value && wasOffline) {
      debugPrint("🔌 Connection Restored! Starting synchronization...");
      triggerSync();
      preloadAllOfflineData();
    }
  }

  /// Preload and hydrate local Hive cache for offline availability
  Future<void> preloadAllOfflineData() async {
    if (!isOnlineNotifier.value) return;
    try {
      debugPrint("📦 SyncEngine: Hydrating local Hive cache for offline mode...");
      await Future.wait([
        locator<StudentsRepository>().getStudentsList().catchError((_) => <Map<String, dynamic>>[]),
        locator<DashboardStatsRepository>().getSummary().catchError((_) => <String, dynamic>{}),
        locator<AcademicsRepository>().getSessions(1).catchError((_) => <Map<String, dynamic>>[]),
        locator<AcademicsRepository>().getPeriods(1, 1).catchError((_) => <Map<String, dynamic>>[]),
        locator<AcademicsRepository>().getAllClassesAndSubjects(1).catchError((_) => <Map<String, dynamic>>[]),
        locator<FinanceRepository>().getStudentFeesList(schoolId: 1, sessionId: 1).catchError((_) => <Map<String, dynamic>>[]),
        locator<PedagogieRepository>().getTeacherClassesAndSubjects().catchError((_) => <Map<String, dynamic>>[]),
        locator<PedagogieRepository>().getSeances().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      await updateLastSyncTime();
      debugPrint("✅ SyncEngine: Offline cache hydrated successfully.");
    } catch (e) {
      debugPrint("⚠️ SyncEngine: Preload warning: $e");
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

    int successCount = 0;
    int failedCount = 0;

    try {
      for (var op in pending) {
        if (!isOnlineNotifier.value) {
          debugPrint("📵 SyncEngine: Lost connection during sync. Pausing.");
          break;
        }

        try {
          final success = await _replayOperation(op);
          if (success) {
            await _queueManager.dequeue(op.id);
            successCount++;
          } else {
            // Increment retry count — move to DLQ if maxRetries exceeded
            if (op.retryCount >= OfflineOperation.maxRetries) {
              debugPrint("☠️ SyncEngine: Operation ${op.id} exceeded max retries. Moving to Dead-Letter Queue.");
              await _queueManager.moveToDeadLetter(
                op.id,
                reason: "Exceeded max retries (${OfflineOperation.maxRetries}). Last error: ${op.lastError ?? 'unknown'}",
              );
              failedCount++;
            } else {
              await _queueManager.incrementRetry(op.id, error: "Replay returned false");
              failedCount++;
              debugPrint("⚠️ SyncEngine: Operation ${op.id} failed (retry ${op.retryCount + 1}/${OfflineOperation.maxRetries}). Continuing with next.");
            }
          }
        } catch (opError) {
          debugPrint("❌ SyncEngine: Exception replaying operation ${op.id}: $opError");
          if (op.retryCount >= OfflineOperation.maxRetries) {
            await _queueManager.moveToDeadLetter(op.id, reason: opError.toString());
          } else {
            await _queueManager.incrementRetry(op.id, error: opError.toString());
          }
          failedCount++;
        }
      }

      if (failedCount == 0) {
        await updateLastSyncTime();
      }

      debugPrint("🔄 SyncEngine: Sync complete — ✅ $successCount succeeded, ❌ $failedCount failed/deferred.");
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
      
      else if (op.table == 'cahier_textes' && op.action == 'create_seance') {
        final repo = locator<PedagogieRepository>();
        final data = op.data;
        
        final res = await repo.createSeance(
          classId: data['classId'] as int,
          subjectId: data['subjectId'] as int,
          employeeId: data['employeeId'] as int,
          sessionDate: data['sessionDate'] as String,
          titreLecon: data['titreLecon'] as String,
          heureDebut: data['heureDebut'] as String?,
          heureFin: data['heureFin'] as String?,
          objectifs: data['objectifs'] as String?,
          contenuRealise: data['contenuRealise'] as String?,
          supportsUtilises: data['supportsUtilises'] as String?,
          devoirDonne: data['devoirDonne'] as String?,
          observation: data['observation'] as String?,
          anneeScolaire: data['anneeScolaire'] as String?,
        );
        
        return res.isNotEmpty && res['_isOffline'] != true;
      }

      else if (op.table == 'cahier_textes' && op.action == 'update_seance') {
        final repo = locator<PedagogieRepository>();
        final data = op.data;
        
        await repo.updateSeance(
          data['id'] as int,
          titreLecon: data['titreLecon'] as String?,
          sessionDate: data['sessionDate'] as String?,
          heureDebut: data['heureDebut'] as String?,
          heureFin: data['heureFin'] as String?,
          objectifs: data['objectifs'] as String?,
          contenuRealise: data['contenuRealise'] as String?,
          supportsUtilises: data['supportsUtilises'] as String?,
          devoirDonne: data['devoirDonne'] as String?,
          observation: data['observation'] as String?,
          statut: data['statut'] as String?,
        );
        
        return true;
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
