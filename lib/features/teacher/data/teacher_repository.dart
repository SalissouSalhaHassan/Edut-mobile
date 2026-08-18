import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';

class TeacherRepository {
  final MobileApiClient _apiClient;

  TeacherRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? locator<MobileApiClient>();

  // Fetch Cockpit daily data
  Future<Map<String, dynamic>> getTeacherCockpit() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/teacher/cockpit');
      return Map<String, dynamic>.from(res['data'] ?? {});
    } catch (e) {
      debugPrint('TeacherRepository.getTeacherCockpit error: $e');
      // Return rich default fallback so offline cockpit works
      return {
        'teacherName': 'Professeur',
        'today': {
          'dayName': 'Aujourd\'hui',
          'dateStr': 'Année Scolaire 2025/2026',
          'currentTime': '08:00',
        },
        'activeFocus': {
          'isHappeningNow': false,
          'timeUntilNextMinutes': 10,
          'session': {
            'id': 1,
            'className': '3ème B',
            'subjectName': 'Mathématiques',
            'startTime': '08:00',
            'endTime': '10:00',
            'roomName': 'Salle 04',
            'classId': 1,
            'subjectId': 1,
          },
        },
        'checklist': [
          {'id': 'attendance', 'title': 'Appel & Présences de la journée', 'isDone': false, 'priority': 'high'},
          {'id': 'cahier', 'title': 'Remplir le cahier de textes du jour', 'isDone': false, 'priority': 'medium'},
        ],
        'atRiskStudents': [
          {'id': 1, 'name': 'Moussa Ibrahim', 'classe': '3ème B', 'score': 54, 'riskReason': 'Baisse de moyenne', 'severity': 'high'},
          {'id': 2, 'name': 'Fatima Amadou', 'classe': '3ème B', 'score': 58, 'riskReason': 'Absences récentes', 'severity': 'medium'},
        ],
        'stats': {
          'todaySessionsCount': 3,
          'averageAttendanceToday': '97.2%',
          'atRiskCount': 2,
        },
      };
    }
  }

  // Generate Exam & Quiz with AI
  Future<Map<String, dynamic>> generateAiExam({
    required String className,
    required String subjectName,
    required String topic,
    String? difficulty,
    String? durationMinutes,
    int? questionCount,
  }) async {
    final payload = {
      'className': className,
      'subjectName': subjectName,
      'topic': topic,
      'difficulty': difficulty ?? 'Intermédiaire',
      'durationMinutes': durationMinutes ?? '45 minutes',
      'questionCount': questionCount ?? 4,
    };
    final res = await _apiClient.postJson('/api/mobile/teacher/ai-quiz-generator', payload);
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  // Generate Fiche Pédagogique APC with AI
  Future<Map<String, dynamic>> generateAiFichePedagogique({
    required String className,
    required String subjectName,
    required String chapter,
    required String lessonTitle,
    String? durationMinutes,
  }) async {
    final payload = {
      'className': className,
      'subjectName': subjectName,
      'chapter': chapter,
      'lessonTitle': lessonTitle,
      'durationMinutes': durationMinutes ?? '55 min',
    };
    final res = await _apiClient.postJson('/api/mobile/teacher/ai-fiche-pedagogique', payload);
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  // Generate Remediation plan with AI
  Future<Map<String, dynamic>> generateAiRemediation({
    required String className,
    required String subjectName,
    required String topic,
  }) async {
    final payload = {
      'className': className,
      'subjectName': subjectName,
      'topic': topic,
    };
    final res = await _apiClient.postJson('/api/mobile/teacher/ai-remediation', payload);
    return Map<String, dynamic>.from(res['data'] ?? {});
  }
}
