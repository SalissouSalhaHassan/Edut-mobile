import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class AiRepository {
  final MobileApiClient _apiClient;

  AiRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  Future<String> askAiTutor({
    required String question,
    String? subject,
    String? educationalLevel,
    String? studentName,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/tutor', {
        'question': question,
        'subject': subject ?? 'Général',
        'educationalLevel': educationalLevel ?? 'Secondaire',
        'studentName': studentName ?? '',
      });
      return response['answer']?.toString() ?? 'Aucune réponse générée.';
    } catch (e) {
      debugPrint("AiRepository.askAiTutor error: $e");
      return "Désolé, une erreur de connexion avec le tuteur IA est survenue. Veuillez vérifier votre réseau.";
    }
  }

  Future<Map<String, dynamic>?> getEarlyWarningAnalysis({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/ai/early-warning?studentId=$studentId',
      );
      return response['data'] != null ? Map<String, dynamic>.from(response['data']) : null;
    } catch (e) {
      debugPrint("AiRepository.getEarlyWarningAnalysis error: $e");
      return null;
    }
  }

  Future<String> generateGradeAppreciation({
    required String studentName,
    required String subjectName,
    required double score,
    String? className,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateAppreciation',
        'studentName': studentName,
        'subjectName': subjectName,
        'score': score,
        'className': className ?? '',
      });
      return response['appreciation']?.toString() ?? 'Bon travail.';
    } catch (e) {
      debugPrint("AiRepository.generateGradeAppreciation error: $e");
      return "Travail satisfaisant.";
    }
  }

  Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String lessonTitle,
    required String subjectName,
    String? className,
    int count = 3,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateQuiz',
        'lessonTitle': lessonTitle,
        'subjectName': subjectName,
        'className': className ?? '',
        'questionCount': count,
      });
      return List<Map<String, dynamic>>.from(response['questions'] ?? []);
    } catch (e) {
      debugPrint("AiRepository.generateQuizQuestions error: $e");
      return [];
    }
  }
}
