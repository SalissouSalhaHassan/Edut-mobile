import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../attendance/data/attendance_repository.dart';

class ExamsRepository {
  final SupabaseClient _client;

  ExamsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  Future<List<Map<String, dynamic>>> getExamsList() async {
    try {
      final schoolId = int.tryParse(
        await locator<SessionManager>().getSchoolId() ?? '',
      );
      final role = (await locator<SessionManager>().getRole() ?? 'staff')
          .toLowerCase()
          .trim();
      final employeeId =
          int.tryParse(await locator<SessionManager>().getEmployeeId() ?? '');

      dynamic query = _client.from('exams').select(
            'id, school_id, exam_name, class_id, subject_id, exam_date, period_id, '
            'max_marks, created_at, school_classes(class_name), '
            'school_subjects(subject_name), academic_periods(name)',
          );
      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }
      final rows = await query.order('created_at', ascending: false);

      var exams = List<Map<String, dynamic>>.from(rows);

      final isTeacher = role == 'teacher' ||
          role == 'enseignant' ||
          role == 'professeur' ||
          role.contains('teacher') ||
          role.contains('enseignant') ||
          role.contains('professeur');

      if (isTeacher && employeeId != null) {
        final assignments =
            await locator<AttendanceRepository>().getTeacherClassesAndSubjects(
          employeeId,
        );
        final allowedPairs = assignments
            .map(
              (item) => '${item['class_id']}_${item['subject_id']}',
            )
            .toSet();
        exams = exams.where((exam) {
          final pair = '${exam['class_id']}_${exam['subject_id']}';
          return allowedPairs.contains(pair);
        }).toList();
      }

      return exams;
    } catch (e) {
      debugPrint('Error fetching exams list: $e');
      return [];
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> getExamFormOptions() async {
    try {
      final session = locator<SessionManager>();
      final schoolId = int.tryParse(await session.getSchoolId() ?? '');

      var classesQuery = _client
          .from('school_classes')
          .select('id, class_name');
      if (schoolId != null) {
        classesQuery = classesQuery.eq('school_id', schoolId);
      }
      final classesRows = await classesQuery.order('class_name');

      var subjectsQuery = _client
          .from('school_subjects')
          .select('id, subject_name');
      if (schoolId != null) {
        subjectsQuery = subjectsQuery.eq('school_id', schoolId);
      }
      final subjectsRows = await subjectsQuery.order('subject_name');

      var sessionsQuery = _client
          .from('school_sessions')
          .select('id, session_name, is_active, status');
      if (schoolId != null) {
        sessionsQuery = sessionsQuery.eq('school_id', schoolId);
      }
      final sessionsRows = await sessionsQuery.order('id', ascending: false);

      List<Map<String, dynamic>> periods = [];
      if (schoolId != null && sessionsRows.isNotEmpty) {
        final activeSession = List<Map<String, dynamic>>.from(sessionsRows)
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (row) => row['is_active'] == true || row['status'] == 'active',
              orElse: () => Map<String, dynamic>.from(sessionsRows.first),
            );
        final activeSessionId = activeSession['id'] as int?;
        if (activeSessionId != null) {
          final periodRows = await _client
              .from('academic_periods')
              .select('id, name')
              .eq('session_id', activeSessionId)
              .order('id');
          periods = List<Map<String, dynamic>>.from(periodRows);
        }
      }

      return {
        'classes': List<Map<String, dynamic>>.from(classesRows),
        'subjects': List<Map<String, dynamic>>.from(subjectsRows),
        'periods': periods,
      };
    } catch (e) {
      debugPrint('Error fetching exam form options: $e');
      return {
        'classes': [],
        'subjects': [],
        'periods': [],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getExamResults(int examId) async {
    try {
      final rows = await _client
          .from('exam_results')
          .select(
            'id, exam_id, student_id, marks_obtained, remarks, '
            'students(id, nom_etudiant, num_admission)',
          )
          .eq('exam_id', examId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching exam results: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStudentsForExam({
    required int classId,
  }) async {
    try {
      final classRes = await _client
          .from('school_classes')
          .select('class_name')
          .eq('id', classId)
          .maybeSingle();
      final className = classRes?['class_name']?.toString();
      if (className == null || className.isEmpty) return [];

      final rows = await _client
          .from('students')
          .select('id, nom_etudiant, num_admission, classe, statut')
          .eq('classe', className)
          .order('nom_etudiant');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching students for exam: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveBatchExamResults({
    required int examId,
    required List<Map<String, dynamic>> results,
  }) async {
    try {
      for (final item in results) {
        final studentId = item['student_id'] as int;
        final marksObtained = item['marks_obtained'];
        final remarks = item['remarks'];

        final existing = await _client
            .from('exam_results')
            .select('id')
            .eq('exam_id', examId)
            .eq('student_id', studentId)
            .maybeSingle();

        final dbValues = {
          'exam_id': examId,
          'student_id': studentId,
          'marks_obtained': marksObtained,
          'remarks': remarks,
        };

        if (existing != null) {
          await _client
              .from('exam_results')
              .update(dbValues)
              .eq('id', existing['id']);
        } else {
          await _client.from('exam_results').insert(dbValues);
        }
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error saving exam results: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> createExam({
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
      await _client.from('exams').insert(data);
      return {'success': true};
    } catch (e) {
      debugPrint('Error creating exam: $e');
      final message = e.toString();
      if (message.contains('row-level security policy') ||
          message.contains('42501')) {
        return {
          'success': false,
          'error':
              'La creation de l examen est refusee par la politique de securite de la base. Verifiez la politique RLS de exams et school_id pour cet utilisateur.',
        };
      }
      return {'success': false, 'error': message};
    }
  }

  Future<Map<String, dynamic>> updateExam({
    required int examId,
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
      await _client.from('exams').update(data).eq('id', examId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating exam: $e');
      final message = e.toString();
      if (message.contains('row-level security policy') ||
          message.contains('42501')) {
        return {
          'success': false,
          'error':
              'La mise a jour de l examen est refusee par la politique de securite de la base. Verifiez la politique RLS de exams et school_id pour cet utilisateur.',
        };
      }
      return {'success': false, 'error': message};
    }
  }

  Future<Map<String, dynamic>> deleteExam(int examId) async {
    try {
      await _client.from('exams').delete().eq('id', examId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting exam: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
