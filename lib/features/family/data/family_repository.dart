import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';

class FamilyRepository {
  final SupabaseClient _client;

  FamilyRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  Future<Map<String, dynamic>> getStudentSnapshot({
    required int studentId,
  }) async {
    try {
      final student = await _client
          .from('students')
          .select('id, school_id, nom_etudiant, classe, educational_level, nom_pere, mobile, whatsapp, num_admission, behavior_score, photo_path')
          .eq('id', studentId)
          .single();

      return Map<String, dynamic>.from(student);
    } catch (e) {
      debugPrint("Error fetching student snapshot: $e");
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getSessions(int schoolId) async {
    try {
      final response = await _client
          .from('school_sessions')
          .select('id, session_name, is_active, status, school_id')
          .eq('school_id', schoolId)
          .order('id', ascending: false);

      if (response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }

      final fallback = await _client
          .from('school_sessions')
          .select('id, session_name, is_active, status, school_id')
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(fallback);
    } catch (e) {
      debugPrint("Error fetching family sessions: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTimetable({
    required int schoolId,
    required String className,
    int? sessionId,
  }) async {
    try {
      final classRes = await _client
          .from('school_classes')
          .select('id')
          .eq('class_name', className)
          .maybeSingle();
      if (classRes == null) return [];

      var query = _client
          .from('timetable_entries')
          .select('id, day_name, period_number, class_id, subject_id, employee_id, school_subjects(subject_name), employees(nom, poste)')
          .eq('class_id', classRes['id']);

      if (sessionId != null) {
        query = query.eq('session_id', sessionId);
      }

      final rows = await query.order('day_name').order('period_number');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching timetable: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGrades({
    required int studentId,
    required int schoolId,
    int? sessionId,
  }) async {
    try {
      var query = _client
          .from('student_results')
          .select('id, student_id, subject_id, class_id, session_id, term, class_work_score, exam_score, total_score, coefficient, weighted_score, rank, absences, observation, appreciation, school_subjects(subject_name, subject_code)')
          .eq('student_id', studentId);

      if (sessionId != null) {
        query = query.eq('session_id', sessionId);
      }

      final rows = await query.order('term').order('subject_id');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching grades: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAttendance({
    required int studentId,
  }) async {
    try {
      final rows = await _client
          .from('student_attendance')
          .select('id, student_id, class_id, subject_id, date, status, remark, school_subjects(subject_name)')
          .eq('student_id', studentId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHomework({
    required String className,
  }) async {
    try {
      final classRes = await _client
          .from('school_classes')
          .select('id')
          .eq('class_name', className)
          .maybeSingle();
      if (classRes == null) return [];

      final rows = await _client
          .from('homework')
          .select('id, title, description, class_id, subject_id, date_assigned, date_due, attachment_path, created_by, school_subjects(subject_name)')
          .eq('class_id', classRes['id'])
          .order('date_due', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching homework: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getFinanceOverview({
    required int studentId,
    int? schoolId,
  }) async {
    try {
      var feeQuery = _client
          .from('student_fees')
          .select('id, school_id, student_id, session_id, total_expected, total_paid, total_reduction, balance, status')
          .eq('student_id', studentId);
      if (schoolId != null) {
        feeQuery = feeQuery.eq('school_id', schoolId);
      }

      final fees = await feeQuery.order('session_id', ascending: false);
      final feeList = List<Map<String, dynamic>>.from(fees);

      final totalExpected = feeList.fold<double>(
        0,
        (sum, item) => sum + ((item['total_expected'] as num?)?.toDouble() ?? 0),
      );
      final totalPaid = feeList.fold<double>(
        0,
        (sum, item) => sum + ((item['total_paid'] as num?)?.toDouble() ?? 0),
      );
      final totalReduction = feeList.fold<double>(
        0,
        (sum, item) => sum + ((item['total_reduction'] as num?)?.toDouble() ?? 0),
      );
      final totalBalance = feeList.fold<double>(
        0,
        (sum, item) => sum + ((item['balance'] as num?)?.toDouble() ?? 0),
      );

      return {
        'fees': feeList,
        'summary': {
          'totalExpected': totalExpected,
          'totalPaid': totalPaid,
          'totalReduction': totalReduction,
          'totalBalance': totalBalance,
        }
      };
    } catch (e) {
      debugPrint("Error fetching finance overview: $e");
      return {
        'fees': <Map<String, dynamic>>[],
        'summary': {
          'totalExpected': 0.0,
          'totalPaid': 0.0,
          'totalReduction': 0.0,
          'totalBalance': 0.0,
        }
      };
    }
  }

  Future<List<Map<String, dynamic>>> getStudentPaymentsByFeeIds(
    List<int> feeIds,
  ) async {
    if (feeIds.isEmpty) return [];
    try {
      final rows = await _client
          .from('fee_payments')
          .select('*')
          .inFilter('fee_id', feeIds)
          .order('date_paid', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching fee payments for family: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTransportSubscription({
    required int studentId,
  }) async {
    try {
      final row = await _client
          .from('transport_subscriptions')
          .select('id, student_id, route_id, pickup_point, start_date, end_date, status, transport_routes(*)')
          .eq('student_id', studentId)
          .order('id', ascending: false)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint("Error fetching transport subscription: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLibraryBooks() async {
    try {
      final rows = await _client
          .from('library_books')
          .select('*')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching library books: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStudentLibraryIssues({
    required int studentId,
  }) async {
    try {
      final rows = await _client
          .from('library_issues')
          .select('id, book_id, student_id, issue_date, due_date, return_date, status, fine_amount, library_books(title, author, category)')
          .eq('student_id', studentId)
          .order('issue_date', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint("Error fetching library issues: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> reserveBook({
    required int bookId,
    required int studentId,
  }) async {
    try {
      final dueDate = DateTime.now().add(const Duration(days: 3));
      await _client.from('library_issues').insert({
        'book_id': bookId,
        'student_id': studentId,
        'due_date': dueDate.toIso8601String(),
        'status': 'Reservation',
        'fine_amount': '0',
      });
      return {'success': true};
    } catch (e) {
      debugPrint("Error reserving library book: $e");
      return {'success': false, 'error': '$e'};
    }
  }
}
