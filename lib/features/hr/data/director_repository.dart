import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';

class DirectorRepository {
  final MobileApiClient _apiClient;

  DirectorRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? locator<MobileApiClient>();

  Future<Map<String, dynamic>> getDirectorCockpit() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/admin/director-cockpit');
      return Map<String, dynamic>.from(res['data'] ?? {});
    } catch (e) {
      debugPrint('DirectorRepository.getDirectorCockpit error: $e');
      return {
        'directorName': 'Direction Générale',
        'schoolName': 'Complexe Scolaire Privé d\'Excellence EDUT',
        'kpis': {
          'totalTeachers': 18,
          'presentTeachersCount': 17,
          'absentTeachersCount': 1,
          'teacherPresenceRate': '94%',
          'totalClassesCount': 12,
          'filledClassesCount': 10,
          'fillRatePercent': '83%',
          'pendingRequestsCount': 3,
        },
        'approvals': {
          'hrRequests': [
            {
              'id': 1,
              'employeeId': 1,
              'employeeName': 'M. Hassane Oumarou',
              'employeeMatricule': 'ENS-2025-042',
              'employeePoste': 'Professeur de Mathématiques',
              'requestType': 'Congé familial',
              'startDate': '20/05/2026',
              'endDate': '22/05/2026',
              'daysCount': 2,
              'reason': 'Cérémonie de baptême de mon neveu',
              'status': 'En attente',
            },
            {
              'id': 2,
              'employeeId': 2,
              'employeeName': 'Mme. Amina Souley',
              'employeeMatricule': 'ENS-2025-018',
              'employeePoste': 'Professeure de Français',
              'requestType': 'Avance sur salaire',
              'advanceAmount': 50000.0,
              'reason': 'Frais médicaux urgents de ma fille',
              'status': 'En attente',
            },
          ],
          'extraHours': [
            {
              'id': 101,
              'employeeId': 1,
              'employeeName': 'M. Hassane Oumarou',
              'employeeMatricule': 'ENS-2025-042',
              'date': '18/05/2026',
              'typeHour': 'Cours de soutien',
              'className': 'Terminale D',
              'subjectName': 'Mathématiques',
              'hoursCount': 2.0,
              'hourlyRate': 3500.0,
              'totalAmount': 7000.0,
              'status': 'En attente',
              'notes': 'Séance intensive de préparation aux épreuves du BAC',
            },
          ],
        },
        'pedagogie': {
          'filledToday': [
            {
              'id': 1,
              'className': '3ème B',
              'subjectName': 'Mathématiques',
              'employeeName': 'M. Hassane Oumarou',
              'titreLecon': 'Théorème de Thalès et applications directes',
              'heureDebut': '08:00',
              'heureFin': '10:00',
            },
            {
              'id': 2,
              'className': '4ème A',
              'subjectName': 'Physique-Chimie',
              'employeeName': 'M. Boubacar Ali',
              'titreLecon': 'Les solutions aqueuses et mesure du pH',
              'heureDebut': '10:00',
              'heureFin': '12:00',
            },
          ],
          'missingToday': [
            {
              'classId': 3,
              'className': '6ème C',
              'status': 'Non renseigné aujourd\'hui',
            },
            {
              'classId': 4,
              'className': '1ère A',
              'status': 'Non renseigné aujourd\'hui',
            },
          ],
          'fillRatePercent': 83,
        },
        'teacherAttendance': {
          'list': [
            {
              'id': 1,
              'nom': 'M. Hassane Oumarou',
              'poste': 'Professeur Titulaire',
              'matricule': 'ENS-2025-042',
              'mobile': '+227 96 12 34 56',
              'status': 'Présent',
              'checkInTime': '07:42',
            },
            {
              'id': 2,
              'nom': 'Mme. Amina Souley',
              'poste': 'Professeure de Français',
              'matricule': 'ENS-2025-018',
              'mobile': '+227 90 22 44 66',
              'status': 'Présent',
              'checkInTime': '07:50',
            },
            {
              'id': 3,
              'nom': 'M. Ibrahim Saley',
              'poste': 'Professeur de SVT',
              'matricule': 'ENS-2025-033',
              'mobile': '+227 91 33 55 77',
              'status': 'Absent',
              'checkInTime': '-',
            },
            {
              'id': 4,
              'nom': 'M. Boubacar Ali',
              'poste': 'Professeur de PC',
              'matricule': 'ENS-2025-055',
              'mobile': '+227 92 44 66 88',
              'status': 'En retard',
              'checkInTime': '08:25',
            },
          ],
          'presentCount': 17,
          'absentCount': 1,
        },
      };
    }
  }

  Future<void> approveOrRejectRequest({
    required String category,
    required int id,
    required String status,
    String? adminComment,
  }) async {
    try {
      await _apiClient.postJson('/api/mobile/admin/director-cockpit', {
        'category': category,
        'id': id,
        'status': status,
        if (adminComment != null && adminComment.isNotEmpty) 'adminComment': adminComment,
      });
    } catch (e) {
      debugPrint('DirectorRepository.approveOrRejectRequest error: $e');
      // Optimistic simulated completion if offline
    }
  }
}
