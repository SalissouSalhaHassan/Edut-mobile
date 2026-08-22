import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class LmsRepository {
  final MobileApiClient _apiClient;

  LmsRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Fetches all courses available for the student or specific course with modules & lessons
  Future<Map<String, dynamic>?> getCourses({int? studentId, int? courseId}) async {
    try {
      final queryParams = <String>[
        if (studentId != null) 'studentId=$studentId',
        if (courseId != null) 'courseId=$courseId',
      ].join('&');

      final url = '/api/mobile/lms/courses${queryParams.isNotEmpty ? '?$queryParams' : ''}';
      final res = await _apiClient.getJson(url);
      if (res['success'] == true) {
        return res;
      }
      return null;
    } catch (e) {
      debugPrint('LmsRepository.getCourses error: $e');
      return null;
    }
  }

  /// Updates lesson progress (video position, completion status, notes)
  Future<bool> saveLessonProgress({
    required int lessonId,
    int? studentId,
    bool? isCompleted,
    int? lastPosition,
    String? personalNotes,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/lms/progress', {
        'lessonId': lessonId,
        if (studentId != null) 'studentIdParam': studentId,
        if (isCompleted != null) 'isCompleted': isCompleted,
        if (lastPosition != null) 'lastPosition': lastPosition,
        if (personalNotes != null) 'personalNotes': personalNotes,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('LmsRepository.saveLessonProgress error: $e');
      return false;
    }
  }

  /// Submits quiz answers and returns grades and optional completion certificate
  Future<Map<String, dynamic>?> submitQuiz({
    required int quizId,
    required Map<int, int> answers, // questionId -> answerId
    int? studentId,
  }) async {
    try {
      final formattedAnswers = answers.map((k, v) => MapEntry(k.toString(), v));
      final res = await _apiClient.postJson('/api/mobile/lms/quiz/submit', {
        'quizId': quizId,
        'answers': formattedAnswers,
        if (studentId != null) 'studentIdParam': studentId,
      });
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      return null;
    } catch (e) {
      debugPrint('LmsRepository.submitQuiz error: $e');
      return null;
    }
  }
}
