import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/api/sync_engine.dart';

class AcademicsRepository {
  final SupabaseClient _client;

  AcademicsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

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
      final List<dynamic> response = await _client
          .from('class_subjects')
          .select('class_id, subject_id, school_classes(class_name, section_id, school_sections(educational_level)), school_subjects(subject_name)')
          .eq('employee_id', employeeId);
      
      final list = List<Map<String, dynamic>>.from(response);
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
      final List<dynamic> response = await _client
          .from('class_subjects')
          .select('class_id, subject_id, school_classes(class_name, section_id, school_sections(educational_level)), school_subjects(subject_name)')
          .eq('school_id', schoolId);
      
      final list = List<Map<String, dynamic>>.from(response);
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
      // First try with school_id filter
      List<dynamic> response = await _client
          .from('school_sessions')
          .select('id, session_name, is_active, status, school_id')
          .eq('school_id', schoolId)
          .order('id', ascending: false);

      // Fallback: no school filter (handles old records)
      if (response.isEmpty) {
        debugPrint("⚠️ No sessions for school_id=$schoolId, fetching all sessions...");
        response = await _client
            .from('school_sessions')
            .select('id, session_name, is_active, status, school_id')
            .order('id', ascending: false);
      }

      debugPrint("✅ Fetched ${response.length} sessions");
      final list = List<Map<String, dynamic>>.from(response);
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
      // First try with both school_id and session_id
      List<dynamic> response = await _client
          .from('academic_periods')
          .select('id, name, period_type, is_active, session_id, school_id')
          .eq('school_id', schoolId)
          .eq('session_id', sessionId)
          .order('id');

      // Fallback 1: session_id only (school_id may be null in old records)
      if (response.isEmpty) {
        debugPrint("⚠️ No periods for school_id=$schoolId & session_id=$sessionId, trying session only...");
        response = await _client
            .from('academic_periods')
            .select('id, name, period_type, is_active, session_id, school_id')
            .eq('session_id', sessionId)
            .order('id');
      }

      // Fallback 2: any active period for this school
      if (response.isEmpty) {
        debugPrint("⚠️ No periods for session_id=$sessionId, fetching any active periods...");
        response = await _client
            .from('academic_periods')
            .select('id, name, period_type, is_active, session_id, school_id')
            .order('id');
      }

      debugPrint("✅ Fetched ${response.length} periods");
      final list = List<Map<String, dynamic>>.from(response);
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
      final List<dynamic> response = await _client
          .from('grading_appreciations')
          .select('name, base_score, display_order')
          .order('display_order');
      return List<Map<String, dynamic>>.from(response);
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
      // 1. Fetch class details to get class name and level
      final classRes = await _client
          .from('school_classes')
          .select('class_name, section_id, school_sections(educational_level)')
          .eq('id', classId)
          .single();
      
      final className = classRes['class_name'] as String;
      final level = classRes['school_sections']?['educational_level'] as String? ?? 'Lycée';

      // 2. Fetch subject coefficient from class_subjects
      final subLinkRes = await _client
          .from('class_subjects')
          .select('coefficient')
          .eq('class_id', classId)
          .eq('subject_id', subjectId)
          .maybeSingle();
      
      final num coeff = subLinkRes != null ? (subLinkRes['coefficient'] as num? ?? 1) : 1;

      // 3. Fetch active students in class
      final List<dynamic> studentsList = await _client
          .from('students')
          .select('id, num_admission, nom_etudiant, photo_path')
          .eq('classe', className)
          .eq('statut', 'Actif')
          .eq('school_id', schoolId)
          .order('nom_etudiant');

      // 4. Fetch existing grades/results
      final List<dynamic> resultsList = await _client
          .from('student_results')
          .select('id, student_id, class_work_score, exam_score, total_score, weighted_score, absences, observation, appreciation, rank')
          .eq('class_id', classId)
          .eq('subject_id', subjectId)
          .eq('session_id', sessionId)
          .eq('term', term);

      // 5. Map student results
      final Map<int, Map<String, dynamic>> resultsMap = {
        for (var r in resultsList)
          (r['student_id'] as num).toInt(): Map<String, dynamic>.from(r)
      };

      final List<Map<String, dynamic>> gridData = [];
      for (var student in studentsList) {
        final studentId = (student['id'] as num).toInt();
        final res = resultsMap[studentId];

        gridData.add({
          'student_id': studentId,
          'num_admission': student['num_admission'] ?? 'N/A',
          'nom_etudiant': student['nom_etudiant'] ?? 'Sans Nom',
          'photo_path': student['photo_path'],
          'class_work_score': res?['class_work_score'],
          'exam_score': res?['exam_score'],
          'total_score': res?['total_score'],
          'weighted_score': res?['weighted_score'],
          'absences': res?['absences'] ?? 0,
          'observation': res?['observation'] ?? '',
          'appreciation': res?['appreciation'] ?? '-',
          'rank': res?['rank'] ?? '-',
        });
      }

      final res = {
        'success': true,
        'data': gridData,
        'level': level,
        'coefficient': coeff.toDouble(),
      };

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [res],
      );

      return res;
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
      // Fetch existing results mapping
      final List<dynamic> existingList = await _client
          .from('student_results')
          .select('id, student_id')
          .eq('class_id', classId)
          .eq('subject_id', subjectId)
          .eq('session_id', sessionId)
          .eq('term', term);

      final Map<int, int> existingMap = {
        for (var item in existingList)
          (item['student_id'] as num).toInt(): (item['id'] as num).toInt()
      };

      final List<Future> operations = [];
      for (var grade in grades) {
        final studentId = grade['student_id'] as int;
        final existingId = existingMap[studentId];

        final dbValues = {
          'student_id': studentId,
          'subject_id': subjectId,
          'class_id': classId,
          'session_id': sessionId,
          'term': term,
          'class_work_score': grade['class_work_score'],
          'exam_score': grade['exam_score'],
          'total_score': grade['total_score'],
          'coefficient': grade['coefficient'],
          'weighted_score': grade['weighted_score'],
          'absences': grade['absences'] ?? 0,
          'observation': grade['observation'],
          'appreciation': grade['appreciation'],
          'rank': grade['rank'],
        };

        if (existingId != null) {
          operations.add(
            _client.from('student_results').update(dbValues).eq('id', existingId)
          );
        } else {
          operations.add(
            _client.from('student_results').insert(dbValues)
          );
        }
      }

      await Future.wait(operations);

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

      return {'success': true};
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
      // 1. Fetch class details to get class name
      final classRes = await _client
          .from('school_classes')
          .select('class_name')
          .eq('id', classId)
          .single();
      
      final className = classRes['class_name'] as String;

      // 2. Fetch active students in class
      final List<dynamic> studentsList = await _client
          .from('students')
          .select('id, num_admission, nom_etudiant, photo_path')
          .eq('classe', className)
          .eq('statut', 'Actif')
          .eq('school_id', schoolId)
          .order('nom_etudiant');

      // 3. Fetch existing devoir grades
      final List<dynamic> resultsList = await _client
          .from('student_results')
          .select('id, student_id, devoir1, devoir2, devoir3, devoir4, devoir5, moyenne_devoirs')
          .eq('class_id', classId)
          .eq('subject_id', subjectId)
          .eq('session_id', sessionId)
          .eq('term', term);

      // 4. Map student results
      final Map<int, Map<String, dynamic>> resultsMap = {
        for (var r in resultsList)
          (r['student_id'] as num).toInt(): Map<String, dynamic>.from(r)
      };

      final List<Map<String, dynamic>> gridData = [];
      for (var student in studentsList) {
        final studentId = (student['id'] as num).toInt();
        final res = resultsMap[studentId];

        gridData.add({
          'student_id': studentId,
          'num_admission': student['num_admission'] ?? 'N/A',
          'nom_etudiant': student['nom_etudiant'] ?? 'Sans Nom',
          'photo_path': student['photo_path'],
          'devoirs': [
            res?['devoir1'],
            res?['devoir2'],
            res?['devoir3'],
            res?['devoir4'],
            res?['devoir5'],
          ],
          'moyenne_devoirs': res?['moyenne_devoirs'] ?? 0.0,
        });
      }

      final res = {
        'success': true,
        'data': gridData,
      };

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [res],
      );

      return res;
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
      // Fetch existing results mapping
      final List<dynamic> existingList = await _client
          .from('student_results')
          .select('id, student_id')
          .eq('class_id', classId)
          .eq('subject_id', subjectId)
          .eq('session_id', sessionId)
          .eq('term', term);

      final Map<int, int> existingMap = {
        for (var item in existingList)
          (item['student_id'] as num).toInt(): (item['id'] as num).toInt()
      };

      final List<Future> operations = [];
      for (var row in devoirsList) {
        final studentId = row['student_id'] as int;
        final existingId = existingMap[studentId];
        final devoirs = row['devoirs'] as List<dynamic>;
        final avg = row['moyenne_devoirs'] as double;

        final dbValues = {
          'student_id': studentId,
          'subject_id': subjectId,
          'class_id': classId,
          'session_id': sessionId,
          'term': term,
          'devoir1': devoirs[0],
          'devoir2': devoirs[1],
          'devoir3': devoirs[2],
          'devoir4': devoirs[3],
          'devoir5': devoirs[4],
          'moyenne_devoirs': avg,
          'class_work_score': avg, // In the web app, classWorkScore is pre-filled with moyenneDevoirs
        };

        if (existingId != null) {
          operations.add(
            _client.from('student_results').update(dbValues).eq('id', existingId)
          );
        } else {
          operations.add(
            _client.from('student_results').insert(dbValues)
          );
        }
      }

      await Future.wait(operations);

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

      return {'success': true};
    } catch (e) {
      debugPrint("Error saving devoir grades: $e");
      return {
        'success': false,
        'error': 'Erreur lors de la sauvegarde des devoirs: $e',
      };
    }
  }
}
