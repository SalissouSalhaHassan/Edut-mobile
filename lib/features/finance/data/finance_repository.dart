import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/di/injection.dart';

class FinanceRepository {
  final MobileApiClient _apiClient;
  final SupabaseClient _client;

  FinanceRepository({MobileApiClient? apiClient, SupabaseClient? client})
      : _apiClient = apiClient ?? MobileApiClient(),
        _client = client ?? SupabaseClientManager().client;

  String _feesCacheKey(int schoolId, int sessionId) =>
      "student_fees_${schoolId}_$sessionId";

  String _statsCacheKey(int schoolId, int sessionId) =>
      "finance_stats_${schoolId}_$sessionId";

  String _paymentsCacheKey(int feeId) => "fee_payments_$feeId";

  String _sessionsCacheKey(int schoolId) => "finance_sessions_$schoolId";

  Future<void> _updateCachedFeeAfterPayment({
    required int feeId,
    required double newPaid,
    required double newReduction,
    required double newBalance,
    required String newStatus,
  }) async {
    if (!Hive.isBoxOpen(OfflineStoreManager.boxStudentFees)) {
      return;
    }

    final box = Hive.box(OfflineStoreManager.boxStudentFees);
    final keys = box.keys.cast<dynamic>().map((e) => e.toString()).toList();

    for (final key in keys) {
      if (!key.startsWith('student_fees_')) {
        continue;
      }

      final cachedFees = box.get(key);
      if (cachedFees is! List) {
        continue;
      }

      bool updated = false;
      final mappedFees = cachedFees.map((item) {
        if (item is! Map) return item;
        final fee = Map<String, dynamic>.from(item);
        final currentId = (fee['id'] as num?)?.toInt();
        if (currentId == feeId) {
          fee['total_paid'] = newPaid;
          fee['total_reduction'] = newReduction;
          fee['balance'] = newBalance;
          fee['status'] = newStatus;
          updated = true;
        }
        return fee;
      }).toList();

      if (updated) {
        await box.put(key, mappedFees);

        final parts = key.split('_');
        if (parts.length >= 4) {
          final schoolId = int.tryParse(parts[2]);
          final sessionId = int.tryParse(parts[3]);
          if (schoolId != null && sessionId != null) {
            await _refreshStatsCacheFromFees(
              schoolId: schoolId,
              sessionId: sessionId,
              fees: mappedFees
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(),
            );
          }
        }
      }
    }
  }

  Map<String, dynamic> _buildStatsFromFees(List<Map<String, dynamic>> fees) {
    double totalExpected = 0.0;
    double totalCollected = 0.0;
    double totalDebts = 0.0;

    for (final row in fees) {
      totalExpected += (row['total_expected'] as num?)?.toDouble() ?? 0.0;
      totalCollected += (row['total_paid'] as num?)?.toDouble() ?? 0.0;
      totalDebts += (row['balance'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'success': true,
      'stats': {
        'totalExpected': totalExpected,
        'totalCollected': totalCollected,
        'totalDebts': totalDebts,
      },
    };
  }

  Future<void> _refreshStatsCacheFromFees({
    required int schoolId,
    required int sessionId,
    required List<Map<String, dynamic>> fees,
  }) async {
    final cacheManager = locator<OfflineStoreManager>();
    final stats = _buildStatsFromFees(fees);
    await cacheManager.saveDataList(
      boxName: OfflineStoreManager.boxStudentFees,
      key: _statsCacheKey(schoolId, sessionId),
      data: [stats],
    );
  }

  /// Fetch financial statistics for a school and session
  Future<Map<String, dynamic>> getFinanceStats({
    required int schoolId,
    required int sessionId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = _statsCacheKey(schoolId, sessionId);

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Fetching finance stats from local cache.");
      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        return Map<String, dynamic>.from(cachedList.first);
      }

      final cachedFees = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: _feesCacheKey(schoolId, sessionId),
      );
      if (cachedFees.isNotEmpty) {
        return _buildStatsFromFees(cachedFees);
      }

      return {
        'success': false,
        'error': 'Pas de connexion internet et aucune donnee en cache.',
      };
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/finance/summary?action=getFinanceStats&schoolId=$schoolId&sessionId=$sessionId',
      );
      
      final result = Map<String, dynamic>.from(response);

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
        data: [result],
      );

      return result;
    } catch (e) {
      debugPrint("Error fetching finance stats: $e");
      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        return Map<String, dynamic>.from(cachedList.first);
      }
      return {
        'success': false,
        'error': 'Erreur lors de la recuperation des statistiques: $e',
      };
    }
  }

  /// Get list of student fees for a session and school
  Future<List<Map<String, dynamic>>> getStudentFeesList({
    required int schoolId,
    required int sessionId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = _feesCacheKey(schoolId, sessionId);

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Fetching student fees from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/finance/invoices?action=getStudentFeesList&schoolId=$schoolId&sessionId=$sessionId',
      );

      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
        data: list,
      );
      await _refreshStatsCacheFromFees(
        schoolId: schoolId,
        sessionId: sessionId,
        fees: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching student fees list: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
      );
    }
  }

  /// Fetch payment history for a specific student fee ID
  Future<List<Map<String, dynamic>>> getFeePayments(int feeId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = _paymentsCacheKey(feeId);

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Fetching fee payments from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/finance/payments?action=getFeePayments&feeId=$feeId',
      );

      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching fee payments: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: cacheKey,
      );
    }
  }

  /// Record a payment and update the student fee balance
  Future<Map<String, dynamic>> recordPayment({
    required int feeId,
    required int schoolId,
    required double amount,
    required double reduction,
    required String paymentMode,
    required String reference,
    required String monthConcerned,
    required String recordedBy,
    required double currentPaid,
    required double currentReduction,
    required double totalExpected,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();
    final cacheManager = locator<OfflineStoreManager>();

    final double newPaid = currentPaid + amount;
    final double newReduction = currentReduction + reduction;
    final double newBalance = totalExpected - newPaid - newReduction;

    String newStatus = "Impaye";
    if (newBalance <= 0) {
      newStatus = "Solde";
    } else if (newPaid > 0) {
      newStatus = "Partiel";
    }

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Queueing fee payment locally.");
      await queueManager.enqueue(
        table: 'fee_payments',
        action: 'record_payment',
        data: {
          'feeId': feeId,
          'schoolId': schoolId,
          'amount': amount,
          'reduction': reduction,
          'paymentMode': paymentMode,
          'reference': reference,
          'monthConcerned': monthConcerned,
          'recordedBy': recordedBy,
          'currentPaid': currentPaid,
          'currentReduction': currentReduction,
          'totalExpected': totalExpected,
        },
      );

      final paymentCacheKey = _paymentsCacheKey(feeId);
      final cachedPayments = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: paymentCacheKey,
      );
      final localPayment = {
        'id': null,
        'fee_id': feeId,
        'school_id': schoolId,
        'amount': amount,
        'reduction': reduction,
        'payment_mode': paymentMode,
        'reference': reference.isNotEmpty ? reference : null,
        'month_concerned': monthConcerned.isNotEmpty ? monthConcerned : null,
        'date_paid': DateTime.now().toIso8601String(),
        'recorded_by': recordedBy,
        'is_pending_sync': true,
      };
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: paymentCacheKey,
        data: [localPayment, ...cachedPayments],
      );

      await _updateCachedFeeAfterPayment(
        feeId: feeId,
        newPaid: newPaid,
        newReduction: newReduction,
        newBalance: newBalance,
        newStatus: newStatus,
      );

      return {
        'success': true,
        'payment': localPayment,
        'queued': true,
        'newPaid': newPaid,
        'newReduction': newReduction,
        'newBalance': newBalance,
        'newStatus': newStatus,
      };
    }

    try {
      final response = await _apiClient.postJson(
        '/api/mobile/finance/payments',
        {
          'action': 'recordPayment',
          'payload': {
            'feeId': feeId,
            'schoolId': schoolId,
            'amount': amount,
            'reduction': reduction,
            'paymentMode': paymentMode,
            'reference': reference,
            'monthConcerned': monthConcerned,
            'recordedBy': recordedBy,
            'currentPaid': currentPaid,
            'currentReduction': currentReduction,
            'totalExpected': totalExpected,
          },
        },
      );

      if (response['success'] == true) {
        final paymentResponse = response['payment'];
        await _updateCachedFeeAfterPayment(
          feeId: feeId,
          newPaid: newPaid,
          newReduction: newReduction,
          newBalance: newBalance,
          newStatus: newStatus,
        );

        return {
          'success': true,
          'payment': paymentResponse,
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Erreur inconnue',
        };
      }
    } catch (e) {
      debugPrint("Error recording payment: $e");
      return {
        'success': false,
        'error': 'Erreur lors de l\'enregistrement du paiement: $e',
      };
    }
  }

  /// Fetch active academic sessions for the school
  Future<List<Map<String, dynamic>>> getSessions(int schoolId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = _sessionsCacheKey(schoolId);

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Fetching finance sessions from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxSchoolSessions,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/finance/summary?action=getSessions&schoolId=$schoolId',
      );

      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxSchoolSessions,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching sessions in finance: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxSchoolSessions,
        key: cacheKey,
      );
    }
  }

  /// Fetch the official school document header config
  Future<Map<String, dynamic>> getDocumentHeader(int schoolId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "document_header_$schoolId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Fetching document header from local cache.");
      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        return {'success': true, 'data': Map<String, dynamic>.from(cachedList.first)};
      }
      return {'success': false, 'error': 'Aucune configuration d\'en-tête en cache.'};
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/document-header',
      );
      
      final data = Map<String, dynamic>.from(response['data'] ?? {});
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
        data: [data],
      );
      return {'success': true, 'data': data};
    } catch (e) {
      debugPrint("Error fetching document header: $e");
      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        return {'success': true, 'data': Map<String, dynamic>.from(cachedList.first)};
      }
      return {
        'success': false,
        'error': 'Erreur lors du chargement de l\'en-tête: $e',
      };
    }
  }

  /// Synchronize student fees school-wide (matching web sync logic)
  Future<Map<String, dynamic>> syncStudentFees({
    required int schoolId,
    required int sessionId,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/finance/invoices',
        {
          'action': 'syncStudentFees',
          'payload': {
            'schoolId': schoolId,
            'sessionId': sessionId,
          },
        },
      );
      return response;
    } catch (e) {
      debugPrint("Error syncing student fees: $e");
      return {
        'success': false,
        'error': 'Erreur lors de la synchronisation des dossiers: $e',
      };
    }
  }
}
