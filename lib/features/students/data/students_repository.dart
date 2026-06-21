import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../attendance/data/attendance_repository.dart';

class StudentsRepository {
  final SupabaseClient _client;

  StudentsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  Future<List<Map<String, dynamic>>> getStudentsList() async {
    try {
      final session = locator<SessionManager>();
      final schoolId = int.tryParse(await session.getSchoolId() ?? '');
      final role = (await session.getRole() ?? 'staff').toLowerCase().trim();
      final employeeId = int.tryParse(await session.getEmployeeId() ?? '');

      final query = _client.from('students').select(
            'id, school_id, num_admission, nom_etudiant, photo_path, '
            'educational_level, classe, section, session, sexe, statut, mobile, '
            'whatsapp, nom_pere, created_at',
          );

      List<dynamic> rows;

      final isTeacher = role == 'teacher' ||
          role == 'enseignant' ||
          role == 'professeur' ||
          role.contains('teacher') ||
          role.contains('enseignant') ||
          role.contains('professeur');

      if (schoolId != null) {
        rows = await query.eq('school_id', schoolId).order('created_at');
      } else {
        rows = await query.order('created_at');
      }

      var students = List<Map<String, dynamic>>.from(rows);

      if (isTeacher && employeeId != null) {
        final teachingAssignments =
            await locator<AttendanceRepository>().getTeacherClassesAndSubjects(
          employeeId,
        );
        final allowedClasses = teachingAssignments
            .map((item) => item['school_classes']?['class_name']?.toString())
            .whereType<String>()
            .toSet();
        students = students
            .where((student) => allowedClasses.contains(student['classe']))
            .toList();
      }

      students.sort((a, b) => (a['nom_etudiant'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['nom_etudiant'] ?? '').toString().toLowerCase()));
      return students;
    } catch (e) {
      debugPrint('Error fetching students list: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStudentDetails(int studentId) async {
    try {
      final result = await _client
          .from('students')
          .select(
            'id, school_id, num_admission, nom_etudiant, nom_arabe, sexe, '
            'religion, date_naissance, lieu_naissance, cnic, groupe_sanguin, '
            'session, educational_level, classe, section, categorie, nom_pere, '
            'cnic_pere, mobile, whatsapp, frais_mensuels, ancien_solde, '
            'frais_inscription, statut, behavior_score, photo_path, created_at',
          )
          .eq('id', studentId)
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('Error fetching student details: $e');
      return null;
    }
  }

  Future<Map<String, List<String>>> getStudentFormOptions() async {
    try {
      final sectionsQuery = _client
          .from('school_sections')
          .select('id, section_name, educational_level');
      final classesQuery = _client
          .from('school_classes')
          .select('id, class_name, section_id, school_sections(section_name, educational_level)');

      final sectionsRows = await sectionsQuery;
      final classesRows = await classesQuery;

      final sections = List<Map<String, dynamic>>.from(sectionsRows);
      final classes = List<Map<String, dynamic>>.from(classesRows);

      final levels = sections
          .map((item) => item['educational_level']?.toString())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final sectionNames = sections
          .map((item) => item['section_name']?.toString())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final classNames = classes
          .map((item) => item['class_name']?.toString())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return {
        'levels': levels,
        'sections': sectionNames,
        'classes': classNames,
      };
    } catch (e) {
      debugPrint('Error fetching student form options: $e');
      return {
        'levels': [],
        'sections': [],
        'classes': [],
      };
    }
  }

  Future<Map<String, dynamic>> saveStudent({
    int? studentId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final schoolId = int.tryParse(
        await locator<SessionManager>().getSchoolId() ?? '',
      );
      final data = Map<String, dynamic>.from(payload);
      if (schoolId != null) {
        data['school_id'] = schoolId;
      }

      if (studentId == null) {
        await _client.from('students').insert(data);
      } else {
        await _client.from('students').update(data).eq('id', studentId);
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error saving student: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> getPromotionOptions() async {
    try {
      final schoolId = int.tryParse(
        await locator<SessionManager>().getSchoolId() ?? '',
      );

      var classesQuery = _client
          .from('school_classes')
          .select('id, class_name');
      if (schoolId != null) {
        classesQuery = classesQuery.eq('school_id', schoolId);
      }
      final classesRows = await classesQuery.order('class_name');

      var sessionsQuery = _client
          .from('school_sessions')
          .select('id, session_name, is_active, status');
      if (schoolId != null) {
        sessionsQuery = sessionsQuery.eq('school_id', schoolId);
      }
      final sessionsRows = await sessionsQuery.order('id', ascending: false);

      return {
        'classes': List<Map<String, dynamic>>.from(classesRows),
        'sessions': List<Map<String, dynamic>>.from(sessionsRows),
      };
    } catch (e) {
      debugPrint('Error fetching promotion options: $e');
      return {
        'classes': <Map<String, dynamic>>[],
        'sessions': <Map<String, dynamic>>[],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getPromotionHistory({
    int limit = 20,
  }) async {
    try {
      final rows = await _client
          .from('activity_logs')
          .select('id, username, details, created_at, entity_id')
          .eq('action_type', 'student_promotion')
          .eq('entity_type', 'promotion')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching promotion history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPromotionPreview({
    required List<Map<String, dynamic>> students,
    String? targetClass,
    String? targetSession,
  }) async {
    try {
      if (students.isEmpty) return [];

      final studentIds = students
          .map((row) => row['id'])
          .whereType<int>()
          .toList();

      final resultsRows = await _client
          .from('student_results')
          .select(
            'student_id, total_score, moyenne_devoirs, class_work_score, weighted_score',
          )
          .inFilter('student_id', studentIds);

      final statsByStudent = <int, List<double>>{};
      for (final row in List<Map<String, dynamic>>.from(resultsRows)) {
        final studentId = row['student_id'] as int?;
        if (studentId == null) continue;

        final values = [
          (row['total_score'] as num?)?.toDouble(),
          (row['moyenne_devoirs'] as num?)?.toDouble(),
          (row['class_work_score'] as num?)?.toDouble(),
          (row['weighted_score'] as num?)?.toDouble(),
        ].whereType<double>().where((value) => value > 0).toList();

        if (values.isEmpty) continue;
        statsByStudent.putIfAbsent(studentId, () => []);
        statsByStudent[studentId]!.add(values.first);
      }

      return students.map((student) {
        final studentId = student['id'] as int?;
        final grades = studentId == null ? <double>[] : (statsByStudent[studentId] ?? <double>[]);
        final average = grades.isEmpty
            ? null
            : grades.reduce((a, b) => a + b) / grades.length;
        final recommendation = _getPromotionRecommendation(average);

        return {
          ...student,
          'target_class': targetClass,
          'target_session': targetSession,
          'calculated_average': average,
          'recommendation': recommendation,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching promotion preview: $e');
      return students
          .map(
            (student) => {
              ...student,
              'target_class': targetClass,
              'target_session': targetSession,
              'calculated_average': null,
              'recommendation': 'A verifier',
            },
          )
          .toList();
    }
  }

  Future<Map<String, dynamic>> promoteStudents({
    required List<int> studentIds,
    required String targetClass,
    required String targetSession,
    required bool transferBalance,
  }) async {
    try {
      if (studentIds.isEmpty) {
        return {'success': false, 'error': 'Aucun etudiant selectionne.'};
      }

      await _client
          .from('students')
          .update({
            'classe': targetClass,
            'session': targetSession,
          })
          .inFilter('id', studentIds);

      final session = locator<SessionManager>();
      final userId = int.tryParse(await session.getEmployeeId() ?? '');
      final username = await session.getEmail() ?? 'mobile';
      final preview = await getPromotionPreview(
        students: (await getStudentsList())
            .where((row) => studentIds.contains(row['id']))
            .toList(),
        targetClass: targetClass,
        targetSession: targetSession,
      );

      try {
        await _client.from('activity_logs').insert({
          'user_id': userId,
          'username': username,
          'action_type': 'student_promotion',
          'entity_type': 'promotion',
          'entity_id': '${DateTime.now().millisecondsSinceEpoch}',
          'details': jsonEncode({
            'student_ids': studentIds,
            'target_class': targetClass,
            'target_session': targetSession,
            'transfer_balance': transferBalance,
            'students_count': studentIds.length,
            'preview': preview
                .map(
                  (row) => {
                    'id': row['id'],
                    'name': row['nom_etudiant'],
                    'average': row['calculated_average'],
                    'recommendation': row['recommendation'],
                  },
                )
                .toList(),
          }),
        });
      } catch (logError) {
        debugPrint('Error logging promotion history: $logError');
      }

      return {
        'success': true,
        'message':
            '${studentIds.length} etudiants ont ete promus avec succes.',
        'transferBalance': transferBalance,
      };
    } catch (e) {
      debugPrint('Error promoting students: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  String _getPromotionRecommendation(double? average) {
    if (average == null) {
      return 'A verifier';
    }
    if (average >= 10) {
      return 'Promouvoir';
    }
    if (average >= 8) {
      return 'Sous reserve';
    }
    return 'Redoublement conseille';
  }
}
