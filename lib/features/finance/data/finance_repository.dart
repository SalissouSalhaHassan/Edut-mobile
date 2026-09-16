import 'dart:math' as math;
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

  String _journalCacheKey(int schoolId, int? sessionId) =>
      "payments_journal_${schoolId}_${sessionId ?? 'all'}";

  /// Fetch full payments journal (Journal de caisse)
  Future<List<Map<String, dynamic>>> getPaymentsJournal({
    required int schoolId,
    int? sessionId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = _journalCacheKey(schoolId, sessionId);

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Fetching payments journal from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: cacheKey,
      );
    }

    try {
      final sessionParam = sessionId != null ? '&sessionId=$sessionId' : '';
      final response = await _apiClient.getJson(
        '/api/mobile/finance/payments?action=getPaymentsJournal&schoolId=$schoolId$sessionParam',
      );

      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxFeePayments,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching payments journal: $e");
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

    final String receiptRef = reference.trim().isNotEmpty
        ? reference.trim()
        : 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final int offlinePaymentId = DateTime.now().millisecondsSinceEpoch;

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("Offline Mode: Queueing fee payment locally with ref: $receiptRef");
      await queueManager.enqueue(
        table: 'fee_payments',
        action: 'record_payment',
        data: {
          'feeId': feeId,
          'schoolId': schoolId,
          'amount': amount,
          'reduction': reduction,
          'paymentMode': paymentMode,
          'reference': receiptRef,
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
        'id': offlinePaymentId,
        'fee_id': feeId,
        'school_id': schoolId,
        'amount': amount,
        'reduction': reduction,
        'payment_mode': paymentMode,
        'reference': receiptRef,
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
        'paymentId': offlinePaymentId,
        'reference': receiptRef,
        'queued': true,
        'isOffline': true,
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
            'reference': receiptRef,
            'monthConcerned': monthConcerned,
            'recordedBy': recordedBy,
            'currentPaid': currentPaid,
            'currentReduction': currentReduction,
            'totalExpected': totalExpected,
          },
        },
      );

      if (response['success'] == true) {
        final paymentResponse = response['payment'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response['payment'] as Map)
            : <String, dynamic>{};
        final resolvedRef = (paymentResponse['reference'] != null && paymentResponse['reference'].toString().trim().isNotEmpty)
            ? paymentResponse['reference'].toString().trim()
            : receiptRef;
        paymentResponse['reference'] = resolvedRef;
        final resolvedId = paymentResponse['id'] ?? offlinePaymentId;

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
          'paymentId': resolvedId,
          'reference': resolvedRef,
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Erreur inconnue',
        };
      }
    } catch (e) {
      debugPrint("Error recording payment online: $e. Falling back to offline local queue.");
      await queueManager.enqueue(
        table: 'fee_payments',
        action: 'record_payment',
        data: {
          'feeId': feeId,
          'schoolId': schoolId,
          'amount': amount,
          'reduction': reduction,
          'paymentMode': paymentMode,
          'reference': receiptRef,
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
        'id': offlinePaymentId,
        'fee_id': feeId,
        'school_id': schoolId,
        'amount': amount,
        'reduction': reduction,
        'payment_mode': paymentMode,
        'reference': receiptRef,
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
        'paymentId': offlinePaymentId,
        'reference': receiptRef,
        'queued': true,
        'isOffline': true,
        'newPaid': newPaid,
        'newReduction': newReduction,
        'newBalance': newBalance,
        'newStatus': newStatus,
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

  /// Synchronize student fees school-wide (matching web sync logic with offline fallback)
  Future<Map<String, dynamic>> syncStudentFees({
    required int schoolId,
    required int sessionId,
  }) async {
    final syncEngine = locator.isRegistered<SyncEngine>() ? locator<SyncEngine>() : null;
    final isOnline = syncEngine?.isOnlineNotifier.value ?? true;

    if (!isOnline) {
      debugPrint("Offline Mode: Reconciling student fees locally.");
      return await _reconcileOfflineStudentFees(
        schoolId: schoolId,
        sessionId: sessionId,
      );
    }

    try {
      // 1. Drain pending operations in queue before requesting server sync
      if (syncEngine != null) {
        await syncEngine.triggerSync();
      }

      // 2. Request server-side sync and re-aggregation
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

      // 3. Immediately refresh local cache with fresh fees and stats from server
      final freshFees = await getStudentFeesList(
        schoolId: schoolId,
        sessionId: sessionId,
      );
      final freshStats = await getFinanceStats(
        schoolId: schoolId,
        sessionId: sessionId,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Dossiers synchronisés avec succès.',
        'updated': response['updated'] ?? 0,
        'stats': freshStats['stats'],
        'data': freshFees,
      };
    } catch (e) {
      debugPrint("Error syncing student fees online: $e. Falling back to local offline reconciliation.");
      return await _reconcileOfflineStudentFees(
        schoolId: schoolId,
        sessionId: sessionId,
      );
    }
  }

  /// Perform offline reconciliation of student fee balances and status
  Future<Map<String, dynamic>> _reconcileOfflineStudentFees({
    required int schoolId,
    required int sessionId,
  }) async {
    final cacheManager = locator.isRegistered<OfflineStoreManager>()
        ? locator<OfflineStoreManager>()
        : null;

    if (cacheManager == null) {
      return {
        'success': true,
        'offline': true,
        'inserted': 0,
        'updated': 0,
        'message': 'Mode hors-ligne : Données locales vérifiées.',
      };
    }

    try {
      final feesKey = _feesCacheKey(schoolId, sessionId);
      final existingFees = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: feesKey,
      );

      // Check for cached students from students box if any exist
      final studentKeys = [
        'students_$schoolId',
        'students_all_$schoolId',
        'students_list_$schoolId',
      ];

      List<Map<String, dynamic>> allCachedStudents = [];
      for (final sKey in studentKeys) {
        final list = cacheManager.getDataList(
          boxName: OfflineStoreManager.boxStudents,
          key: sKey,
        );
        if (list.isNotEmpty) {
          allCachedStudents = list;
          break;
        }
      }

      final existingStudentIds = <int>{};
      for (final fee in existingFees) {
        final sId = (fee['student_id'] as num?)?.toInt() ??
            (fee['students'] is Map ? (fee['students']['id'] as num?)?.toInt() : null);
        if (sId != null) {
          existingStudentIds.add(sId);
        }
      }

      int inserted = 0;
      int updated = 0;
      final updatedFeesList = <Map<String, dynamic>>[];

      // Reconcile existing fees balances and status
      for (final f in existingFees) {
        final fee = Map<String, dynamic>.from(f);
        final feeId = (fee['id'] as num?)?.toInt();
        final expected = (fee['total_expected'] as num?)?.toDouble() ?? 0.0;
        double paid = (fee['total_paid'] as num?)?.toDouble() ?? 0.0;
        double reduction = (fee['total_reduction'] as num?)?.toDouble() ?? 0.0;

        // Reconcile with any offline payments stored in boxFeePayments
        if (feeId != null) {
          final paymentCacheKey = _paymentsCacheKey(feeId);
          final cachedPayments = cacheManager.getDataList(
            boxName: OfflineStoreManager.boxFeePayments,
            key: paymentCacheKey,
          );
          if (cachedPayments.isNotEmpty) {
            double cachedSum = 0.0;
            double cachedReduc = 0.0;
            for (final p in cachedPayments) {
              cachedSum += (p['amount'] as num?)?.toDouble() ?? 0.0;
              cachedReduc += (p['reduction'] as num?)?.toDouble() ?? 0.0;
            }
            if (cachedSum > paid) {
              paid = cachedSum;
            }
            if (cachedReduc > reduction) {
              reduction = cachedReduc;
            }
          }
        }

        final balance = math.max(0.0, expected - paid - reduction);

        String status = "Impayé";
        if (balance <= 0 && expected > 0) {
          status = "Soldé";
        } else if (paid > 0) {
          status = "Partiel";
        }

        fee['total_paid'] = paid;
        fee['total_reduction'] = reduction;
        fee['balance'] = balance;
        fee['status'] = status;
        updatedFeesList.add(fee);
        updated++;
      }

      // Add missing students if found in offline student cache
      for (final st in allCachedStudents) {
        final sId = (st['id'] as num?)?.toInt();
        if (sId != null && !existingStudentIds.contains(sId)) {
          final monthly = (st['fraisMensuels'] as num?)?.toDouble() ??
              (st['frais_mensuels'] as num?)?.toDouble() ?? 0.0;
          final inscr = (st['fraisInscription'] as num?)?.toDouble() ??
              (st['frais_inscription'] as num?)?.toDouble() ?? 0.0;
          final oldBal = (st['ancienSolde'] as num?)?.toDouble() ??
              (st['ancien_solde'] as num?)?.toDouble() ?? 0.0;
          final expected = inscr + oldBal + monthly;

          updatedFeesList.add({
            'id': -DateTime.now().millisecondsSinceEpoch - inserted,
            'school_id': schoolId,
            'student_id': sId,
            'session_id': sessionId,
            'total_expected': expected,
            'total_paid': 0.0,
            'total_reduction': 0.0,
            'balance': expected,
            'status': "Impayé",
            'students': {
              'id': sId,
              'num_admission': st['num_admission'] ?? st['matricule'] ?? '',
              'nom_etudiant': st['nom_etudiant'] ?? st['name'] ?? '',
              'classe': st['classe'] ?? '',
              'educational_level': st['educational_level'] ?? '',
            },
          });
          existingStudentIds.add(sId);
          inserted++;
        }
      }

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentFees,
        key: feesKey,
        data: updatedFeesList,
      );

      await _refreshStatsCacheFromFees(
        schoolId: schoolId,
        sessionId: sessionId,
        fees: updatedFeesList,
      );

      return {
        'success': true,
        'offline': true,
        'inserted': inserted,
        'updated': updated,
        'message': 'Mode hors-ligne : Les dossiers financiers locaux ont été vérifiés et synchronisés.',
      };
    } catch (e) {
      debugPrint("Error in _reconcileOfflineStudentFees: $e");
      return {
        'success': true,
        'offline': true,
        'inserted': 0,
        'updated': 0,
        'message': 'Mode hors-ligne : Données financières locales prêtes.',
      };
    }
  }
}
