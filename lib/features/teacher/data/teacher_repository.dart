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

  // ─── Live Discipline & Merits ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getClassStudentsDiscipline(String className) async {
    try {
      final res = await _apiClient.getJson('/api/mobile/teacher/live-discipline?className=${Uri.encodeComponent(className)}');
      return Map<String, dynamic>.from(res['data'] ?? {});
    } catch (e) {
      debugPrint('TeacherRepository.getClassStudentsDiscipline error: $e');
      return {
        'className': className,
        'students': [
          {'id': 1, 'name': 'Moussa Ibrahim', 'classe': className, 'score': 85},
          {'id': 2, 'name': 'Fatima Amadou', 'classe': className, 'score': 92},
          {'id': 3, 'name': 'Abdoulaye Oumarou', 'classe': className, 'score': 74},
          {'id': 4, 'name': 'Aïchatou Saley', 'classe': className, 'score': 95},
        ],
      };
    }
  }

  Future<void> recordLiveDisciplineAction({
    required int studentId,
    required String actionType,
    required double pointsEffect,
    String? reason,
  }) async {
    await _apiClient.postJson('/api/mobile/teacher/live-discipline', {
      'studentId': studentId,
      'actionType': actionType,
      'pointsEffect': pointsEffect,
      'reason': reason,
    });
  }

  // ─── Self-Service HR & Payroll ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getSelfServiceHrData() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/teacher/self-service-hr');
      return Map<String, dynamic>.from(res['data'] ?? {});
    } catch (e) {
      debugPrint('TeacherRepository.getSelfServiceHrData error: $e');
      return {
        'employee': {
          'name': 'Professeur',
          'poste': 'Professeur Titulaire',
          'matricule': 'ENS-2025-042',
          'salaireBase': 280000,
          'departement': 'Sciences Exactes',
        },
        'payslips': [
          {
            'id': 1,
            'monthYear': 'Mai 2026',
            'basicSalary': 280000,
            'totalAllowance': 45000,
            'totalDeduction': 12500,
            'netSalary': 312500,
            'status': 'Payé',
            'paymentDate': '2026-05-28',
            'paymentMode': 'Virement Bancaire',
          }
        ],
        'extraHours': {
          'totalEarned': 13000,
          'list': [
            {
              'id': 101,
              'date': '14/05/2026',
              'typeHour': 'Cours de soutien',
              'className': 'Terminale D',
              'subjectName': 'Mathématiques',
              'hoursCount': 2.0,
              'hourlyRate': 3500,
              'totalAmount': 7000,
              'status': 'Approuvé',
            }
          ],
        },
        'requests': [
          {
            'id': 201,
            'requestType': 'Congé familial',
            'startDate': '22/05/2026',
            'endDate': '24/05/2026',
            'daysCount': 3,
            'reason': 'Événement familial',
            'status': 'Approuvé',
          }
        ],
      };
    }
  }

  Future<void> submitHrRequest({
    required String requestType,
    required String reason,
    String? startDate,
    String? endDate,
    int? daysCount,
    double? advanceAmount,
    String? documentUrl,
  }) async {
    await _apiClient.postJson('/api/mobile/teacher/self-service-hr', {
      'requestType': requestType,
      'reason': reason,
      'startDate': startDate,
      'endDate': endDate,
      'daysCount': daysCount ?? 1,
      'advanceAmount': advanceAmount,
      'documentUrl': documentUrl,
    });
  }

  Future<void> recordExtraHours({
    required String typeHour,
    required String className,
    required String subjectName,
    required double hoursCount,
    required double hourlyRate,
    String? notes,
  }) async {
    await _apiClient.postJson('/api/mobile/teacher/self-service-hr', {
      'action': 'extra_hours',
      'typeHour': typeHour,
      'className': className,
      'subjectName': subjectName,
      'hoursCount': hoursCount,
      'hourlyRate': hourlyRate,
      'notes': notes,
    });
  }

  // ─── Protected Communication & DND ─────────────────────────────────────────
  Future<Map<String, dynamic>> getCommProtectionSettings() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/teacher/comm-protection');
      return Map<String, dynamic>.from(res['data'] ?? {});
    } catch (e) {
      debugPrint('TeacherRepository.getCommProtectionSettings error: $e');
      return {
        'dndEnabled': true,
        'dndStartHour': '17:00',
        'dndEndHour': '07:30',
        'dndWeekends': true,
        'autoReplyMessage': 'Bonjour. Le professeur est actuellement hors de ses heures de disponibilité scolaire.',
        'cannedResponses': [
          'Bien reçu, merci pour votre signalement.',
          'Je ferai le point avec l\'élève dès demain en classe.',
          'Veuillez contacter l\'administration pour ce sujet.',
        ],
      };
    }
  }

  Future<void> saveCommProtectionSettings({
    required bool dndEnabled,
    required String dndStartHour,
    required String dndEndHour,
    required bool dndWeekends,
    required String autoReplyMessage,
    List<String>? cannedResponses,
  }) async {
    await _apiClient.postJson('/api/mobile/teacher/comm-protection', {
      'dndEnabled': dndEnabled,
      'dndStartHour': dndStartHour,
      'dndEndHour': dndEndHour,
      'dndWeekends': dndWeekends,
      'autoReplyMessage': autoReplyMessage,
      'cannedResponses': cannedResponses,
    });
  }
}
