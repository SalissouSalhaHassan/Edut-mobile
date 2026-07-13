import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/api/sync_engine.dart';

class AcademicsRepository {
  final MobileApiClient _apiClient;
  final SupabaseClient _client;

  AcademicsRepository({MobileApiClient? apiClient, SupabaseClient? client})
      : _apiClient = apiClient ?? MobileApiClient(),
        _client = client ?? SupabaseClientManager().client;

  // Fetch classes and subjects taught by a specific teacher
  Future<List<Map<String, dynamic>>> getTeacherClassesAndSubjects(int employeeId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "teacher_classes_$employeeId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching teacher classes from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getTeacherClassesAndSubjects&employeeId=$employeeId',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching teacher classes and subjects: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
      );
    }
  }

  // Fetch all classes and subjects (for admins/staff)
  Future<List<Map<String, dynamic>>> getAllClassesAndSubjects(int schoolId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "all_classes_$schoolId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching all classes from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getAllClassesAndSubjects&schoolId=$schoolId',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching all classes and subjects: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
      );
    }
  }

  // Get active school sessions
  Future<List<Map<String, dynamic>>> getSessions(int schoolId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "sessions_$schoolId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching sessions from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxSchoolSessions,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getSessions&schoolId=$schoolId',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxSchoolSessions,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching sessions: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxSchoolSessions,
        key: cacheKey,
      );
    }
  }

  // Get active academic periods for a session
  Future<List<Map<String, dynamic>>> getPeriods(int schoolId, int sessionId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "periods_${schoolId}_$sessionId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching periods from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxAcademicPeriods,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getPeriods&schoolId=$schoolId&sessionId=$sessionId',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxAcademicPeriods,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint("Error fetching periods: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxAcademicPeriods,
        key: cacheKey,
      );
    }
  }

  // Get grading scales/appreciations
  Future<List<Map<String, dynamic>>> getGradingScale() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getGradingScale',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching grading scale: $e");
      return [];
    }
  }

  // Get grading grid (Saisie des Notes)
  Future<Map<String, dynamic>> getGradingGrid({
    required int classId,
    required int subjectId,
    required int sessionId,
    required String term,
    required int schoolId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "grading_grid_${classId}_${subjectId}_${sessionId}_$term";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching grading grid from local cache.");
      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        return Map<String, dynamic>.from(cachedList.first);
      }
      return {
        'success': false,
        'error': 'Pas de connexion internet et aucune donnée en cache.',
      };
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getGradingGrid&classId=$classId&subjectId=$subjectId&sessionId=$sessionId&term=${Uri.encodeComponent(term)}&schoolId=$schoolId',
      );
      
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      final level = response['level']?.toString() ?? 'Lycée';
      final coeff = (response['coefficient'] as num?)?.toDouble() ?? 1.0;

      final result = {
        'success': true,
        'data': list,
        'level': level,
        'coefficient': coeff,
      };

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [result],
      );

      return result;
    } catch (e) {
      debugPrint("Error loading grading grid: $e");
      return {
        'success': false,
        'error': 'Erreur lors du chargement de la grille: $e',
      };
    }
  }

  Future<Map<String, dynamic>> saveStudentGrades({
    required List<Map<String, dynamic>> grades,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();
    final cacheManager = locator<OfflineStoreManager>();

    if (grades.isEmpty) return {'success': true};

    final first = grades.first;
    final classId = first['class_id'] as int;
    final subjectId = first['subject_id'] as int;
    final sessionId = first['session_id'] as int;
    final term = first['term'] as String;
    final cacheKey = "grading_grid_${classId}_${subjectId}_${sessionId}_$term";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Queueing student grades save locally.");
      
      await queueManager.enqueue(
        table: 'student_results',
        action: 'save_grades',
        data: {'grades': grades},
      );

      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        final Map<String, dynamic> gridRes = Map<String, dynamic>.from(cachedList.first);
        final List<dynamic> data = gridRes['data'] as List;
        
        final Map<int, Map<String, dynamic>> gradesMap = {
          for (var g in grades)
            (g['student_id'] as num).toInt(): g
        };

        final updatedData = data.map((item) {
          final sId = (item['student_id'] as num).toInt();
          final g = gradesMap[sId];
          if (g != null) {
            final Map<String, dynamic> updatedItem = Map<String, dynamic>.from(item);
            updatedItem['class_work_score'] = g['class_work_score'];
            updatedItem['exam_score'] = g['exam_score'];
            updatedItem['total_score'] = g['total_score'];
            updatedItem['weighted_score'] = g['weighted_score'];
            updatedItem['absences'] = g['absences'] ?? 0;
            updatedItem['observation'] = g['observation'];
            updatedItem['appreciation'] = g['appreciation'];
            updatedItem['rank'] = g['rank'];
            return updatedItem;
          }
          return item;
        }).toList();

        gridRes['data'] = updatedData;
        await cacheManager.saveDataList(
          boxName: OfflineStoreManager.boxStudentResults,
          key: cacheKey,
          data: [gridRes],
        );
      }

      return {'success': true};
    }

    try {
      final response = await _apiClient.postJson(
        '/api/mobile/academics',
        {
          'action': 'saveStudentGrades',
          'payload': {
            'grades': grades,
          },
        },
      );

      // Re-cache online data
      final Map<String, dynamic> gridRes = {
        'success': true,
        'data': grades.map((g) => {
          'student_id': g['student_id'],
          'num_admission': g['num_admission'] ?? 'N/A',
          'nom_etudiant': g['nom_etudiant'] ?? 'Sans Nom',
          'photo_path': g['photo_path'],
          'class_work_score': g['class_work_score'],
          'exam_score': g['exam_score'],
          'total_score': g['total_score'],
          'weighted_score': g['weighted_score'],
          'absences': g['absences'] ?? 0,
          'observation': g['observation'],
          'appreciation': g['appreciation'],
          'rank': g['rank'],
        }).toList(),
        'level': first['level'] ?? 'Lycée',
        'coefficient': (first['coefficient'] as num?)?.toDouble() ?? 1.0,
      };

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [gridRes],
      );

      return response;
    } catch (e) {
      debugPrint("Error saving student grades: $e");
      return {
        'success': false,
        'error': 'Erreur lors de la sauvegarde: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getDevoirGrid({
    required int classId,
    required int subjectId,
    required int sessionId,
    required String term,
    required int schoolId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "devoir_grid_${classId}_${subjectId}_${sessionId}_$term";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching devoir grid from local cache.");
      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        return Map<String, dynamic>.from(cachedList.first);
      }
      return {
        'success': false,
        'error': 'Pas de connexion internet et aucune donnée en cache.',
      };
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/academics?action=getDevoirGrid&classId=$classId&subjectId=$subjectId&sessionId=$sessionId&term=${Uri.encodeComponent(term)}&schoolId=$schoolId',
      );
      
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      final result = {
        'success': true,
        'data': list,
      };

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [result],
      );

      return result;
    } catch (e) {
      debugPrint("Error loading devoir grid: $e");
      return {
        'success': false,
        'error': 'Erreur lors du chargement des devoirs: $e',
      };
    }
  }

  Future<Map<String, dynamic>> saveDevoirGrades({
    required List<Map<String, dynamic>> devoirsList,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();
    final cacheManager = locator<OfflineStoreManager>();

    if (devoirsList.isEmpty) return {'success': true};

    final first = devoirsList.first;
    final classId = first['class_id'] as int;
    final subjectId = first['subject_id'] as int;
    final sessionId = first['session_id'] as int;
    final term = first['term'] as String;
    final cacheKey = "devoir_grid_${classId}_${subjectId}_${sessionId}_$term";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Queueing devoir grades save locally.");
      
      await queueManager.enqueue(
        table: 'student_results',
        action: 'save_devoirs',
        data: {'devoirsList': devoirsList},
      );

      final cachedList = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
      if (cachedList.isNotEmpty) {
        final Map<String, dynamic> gridRes = Map<String, dynamic>.from(cachedList.first);
        final List<dynamic> data = gridRes['data'] as List;
        
        final Map<int, Map<String, dynamic>> devMap = {
          for (var d in devoirsList)
            (d['student_id'] as num).toInt(): d
        };

        final updatedData = data.map((item) {
          final sId = (item['student_id'] as num).toInt();
          final d = devMap[sId];
          if (d != null) {
            final Map<String, dynamic> updatedItem = Map<String, dynamic>.from(item);
            updatedItem['devoirs'] = d['devoirs'];
            updatedItem['moyenne_devoirs'] = d['moyenne_devoirs'];
            return updatedItem;
          }
          return item;
        }).toList();

        gridRes['data'] = updatedData;
        await cacheManager.saveDataList(
          boxName: OfflineStoreManager.boxStudentResults,
          key: cacheKey,
          data: [gridRes],
        );
      }

      return {'success': true};
    }

    try {
      final response = await _apiClient.postJson(
        '/api/mobile/academics',
        {
          'action': 'saveDevoirGrades',
          'payload': {
            'devoirsList': devoirsList,
          },
        },
      );

      // Re-cache online data
      final Map<String, dynamic> gridRes = {
        'success': true,
        'data': devoirsList.map((row) => {
          'student_id': row['student_id'],
          'num_admission': row['num_admission'] ?? 'N/A',
          'nom_etudiant': row['nom_etudiant'] ?? 'Sans Nom',
          'photo_path': row['photo_path'],
          'devoirs': row['devoirs'],
          'moyenne_devoirs': row['moyenne_devoirs'],
        }).toList(),
      };

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [gridRes],
      );

      return response;
    } catch (e) {
      debugPrint("Error saving devoir grades: $e");
      return {
        'success': false,
        'error': 'Erreur lors de la sauvegarde des devoirs: $e',
      };
    }
  }
}
