import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class ExamsRepository {
  final MobileApiClient _apiClient;

  ExamsRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  // ─────────────────────────────────────────────────────────────────────────
  //  LIST & FORM OPTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExamsList() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getExamsList',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching exams list: $e');
      return [];
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> getExamFormOptions() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getExamFormOptions',
      );
      return {
        'classes': List<Map<String, dynamic>>.from(response['classes'] ?? []),
        'subjects': List<Map<String, dynamic>>.from(response['subjects'] ?? []),
        'periods': List<Map<String, dynamic>>.from(response['periods'] ?? []),
      };
    } catch (e) {
      debugPrint('Error fetching exam form options: $e');
      return {'classes': [], 'subjects': [], 'periods': []};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SINGLE EXAM DETAIL
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getExamDetails(int examId) async {
    try {
      final response = await _apiClient.getJson('/api/mobile/exams/$examId');
      return Map<String, dynamic>.from(response['data'] ?? {});
    } catch (e) {
      debugPrint('Error fetching exam details: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  RESULTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all results for a specific exam (admin / teacher use).
  Future<List<Map<String, dynamic>>> getExamResults(int examId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getExamResults&examId=$examId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching exam results: $e');
      return [];
    }
  }

  /// Fetch all exam results for a specific student (parent / student use).
  Future<List<Map<String, dynamic>>> getResultsByStudent(int studentId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams/results?studentId=$studentId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching results for student: $e');
      return [];
    }
  }

  /// Fetch results for a specific exam, filtered by student scope.
  Future<List<Map<String, dynamic>>> getResultsByExam(int examId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams/results?examId=$examId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching results for exam: $e');
      return [];
    }
  }

  /// Save results for a single student in a single exam.
  Future<Map<String, dynamic>> saveExamResult({
    required int examId,
    required int studentId,
    double? marksObtained,
    String? remarks,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/exams/results',
        {
          'examId': examId,
          'studentId': studentId,
          'marksObtained': marksObtained,
          'remarks': remarks,
        },
      );
      return response;
    } catch (e) {
      debugPrint('Error saving exam result: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BATCH RESULTS (for entering a full class at once)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveBatchExamResults({
    required int examId,
    required List<Map<String, dynamic>> results,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/exams',
        {
          'action': 'saveBatchExamResults',
          'payload': {
            'examId': examId,
            'results': results,
          },
        },
      );
      return response;
    } catch (e) {
      debugPrint('Error saving batch exam results: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STUDENTS FOR EXAM
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStudentsForExam({
    required int classId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getStudentsForExam&classId=$classId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching students for exam: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createExam({
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _apiClient.postJson(
        '/api/mobile/exams',
        {'action': 'createExam', 'payload': payload},
      );
    } catch (e) {
      debugPrint('Error creating exam: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateExam({
    required int examId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _apiClient.postJson(
        '/api/mobile/exams',
        {
          'action': 'updateExam',
          'payload': {'examId': examId, ...payload},
        },
      );
    } catch (e) {
      debugPrint('Error updating exam: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteExam(int examId) async {
    try {
      return await _apiClient.postJson(
        '/api/mobile/exams',
        {
          'action': 'deleteExam',
          'payload': {'examId': examId},
        },
      );
    } catch (e) {
      debugPrint('Error deleting exam: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
