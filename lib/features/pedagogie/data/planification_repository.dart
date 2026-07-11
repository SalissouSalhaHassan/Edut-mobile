import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';

class PlanificationRepository {
  final SupabaseClient _client;

  PlanificationRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  static const _selectFields =
      'id, class_id, subject_id, employee_id, type_plan, periode, chapitre, '
      'lecon_prevue, competence_visee, date_prevue, statut, observation, '
      'annee_scolaire, created_at, updated_at, '
      'school_classes(class_name), school_subjects(subject_name)';

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Future<int?> _getEmployeeId() async {
    final session = locator<SessionManager>();
    final str = await session.getEmployeeId();
    return int.tryParse(str ?? '');
  }

  Future<bool> _isTeacher() async {
    final session = locator<SessionManager>();
    final role = (await session.getRole() ?? 'staff').toLowerCase();
    return role.contains('teacher') ||
        role.contains('enseignant') ||
        role.contains('professeur');
  }

  // ─── READ planifications ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPlanifications({
    int? classId,
    int? subjectId,
    String? statut,
    String? typePlan,
  }) async {
    try {
      final isTeacher = await _isTeacher();
      final employeeId = isTeacher ? await _getEmployeeId() : null;

      var q = _client.from('pedagogie_planifications').select(_selectFields);
      List<dynamic> result;

      if (isTeacher && employeeId != null) {
        var filtered = q.eq('employee_id', employeeId);
        if (classId != null) filtered = filtered.eq('class_id', classId);
        if (subjectId != null) filtered = filtered.eq('subject_id', subjectId);
        if (statut != null && statut.isNotEmpty) {
          filtered = filtered.eq('statut', statut);
        }
        if (typePlan != null && typePlan.isNotEmpty) {
          filtered = filtered.eq('type_plan', typePlan);
        }
        result = await filtered.order('created_at', ascending: false);
      } else {
        var filtered = q;
        if (classId != null) filtered = filtered.eq('class_id', classId);
        if (subjectId != null) filtered = filtered.eq('subject_id', subjectId);
        if (statut != null && statut.isNotEmpty) {
          filtered = filtered.eq('statut', statut);
        }
        if (typePlan != null && typePlan.isNotEmpty) {
          filtered = filtered.eq('type_plan', typePlan);
        }
        result = await filtered.order('created_at', ascending: false);
      }

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('PlanificationRepository.getPlanifications error: $e');
      rethrow;
    }
  }

  // ─── CREATE ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createPlanification({
    required int classId,
    required int subjectId,
    required int employeeId,
    required String typePlan,
    required String chapitre,
    required String leconPrevue,
    String? periode,
    String? competenceVisee,
    String? datePrevue,
    String? statut,
    String? observation,
    String? anneeScolaire,
  }) async {
    try {
      final session = locator<SessionManager>();
      final schoolId = int.tryParse(await session.getSchoolId() ?? '');

      final data = <String, dynamic>{
        'class_id': classId,
        'subject_id': subjectId,
        'employee_id': employeeId,
        'type_plan': typePlan,
        'chapitre': chapitre,
        'lecon_prevue': leconPrevue,
        'statut': statut ?? 'Planifié',
      };

      if (schoolId != null) data['school_id'] = schoolId;
      if (periode != null && periode.isNotEmpty) data['periode'] = periode;
      if (competenceVisee != null && competenceVisee.isNotEmpty) {
        data['competence_visee'] = competenceVisee;
      }
      if (datePrevue != null && datePrevue.isNotEmpty) {
        data['date_prevue'] = datePrevue;
      }
      if (observation != null && observation.isNotEmpty) {
        data['observation'] = observation;
      }
      if (anneeScolaire != null && anneeScolaire.isNotEmpty) {
        data['annee_scolaire'] = anneeScolaire;
      }

      final List<dynamic> response =
          await _client.from('pedagogie_planifications').insert(data).select();
      return Map<String, dynamic>.from(response.first as Map);
    } catch (e) {
      debugPrint('PlanificationRepository.createPlanification error: $e');
      rethrow;
    }
  }

  // ─── UPDATE ────────────────────────────────────────────────────────────────
  Future<void> updatePlanification(
    int id, {
    String? typePlan,
    String? chapitre,
    String? leconPrevue,
    String? periode,
    String? competenceVisee,
    String? datePrevue,
    String? statut,
    String? observation,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (typePlan != null) data['type_plan'] = typePlan;
      if (chapitre != null) data['chapitre'] = chapitre;
      if (leconPrevue != null) data['lecon_prevue'] = leconPrevue;
      if (periode != null) data['periode'] = periode;
      if (competenceVisee != null) data['competence_visee'] = competenceVisee;
      if (datePrevue != null) data['date_prevue'] = datePrevue;
      if (statut != null) data['statut'] = statut;
      if (observation != null) data['observation'] = observation;

      await _client
          .from('pedagogie_planifications')
          .update(data)
          .eq('id', id);
    } catch (e) {
      debugPrint('PlanificationRepository.updatePlanification error: $e');
      rethrow;
    }
  }

  // ─── DELETE ────────────────────────────────────────────────────────────────
  Future<void> deletePlanification(int id) async {
    try {
      await _client
          .from('pedagogie_planifications')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('PlanificationRepository.deletePlanification error: $e');
      rethrow;
    }
  }

  // ─── PROGRESSION: compare planned vs realised per class/subject ────────────
  Future<List<Map<String, dynamic>>> getProgressionBySubject() async {
    try {
      final isTeacher = await _isTeacher();
      final employeeId = isTeacher ? await _getEmployeeId() : null;

      // Fetch planned lessons
      List<dynamic> plannedRaw;
      List<dynamic> realisedRaw;

      if (isTeacher && employeeId != null) {
        plannedRaw = await _client
            .from('pedagogie_planifications')
            .select(
              'subject_id, statut, school_subjects(subject_name), '
              'school_classes(class_name), class_id',
            )
            .eq('employee_id', employeeId);

        realisedRaw = await _client
            .from('cahier_textes')
            .select('subject_id, statut, school_subjects(subject_name), class_id')
            .eq('employee_id', employeeId);
      } else {
        plannedRaw = await _client
            .from('pedagogie_planifications')
            .select(
              'subject_id, statut, school_subjects(subject_name), '
              'school_classes(class_name), class_id',
            );
        realisedRaw = await _client
            .from('cahier_textes')
            .select('subject_id, statut, school_subjects(subject_name), class_id');
      }

      // Group by subject
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final p in plannedRaw) {
        final subId = p['subject_id']?.toString() ?? '';
        final subName =
            (p['school_subjects'] as Map?)?['subject_name'] ?? 'Inconnue';
        final classId = p['class_id']?.toString() ?? '';
        final className =
            (p['school_classes'] as Map?)?['class_name'] ?? '';
        final key = '${subId}_$classId';
        grouped.putIfAbsent(
          key,
          () => {
            'subjectId': subId,
            'subjectName': subName,
            'classId': classId,
            'className': className,
            'planned': 0,
            'realised': 0,
            'enRetard': 0,
          },
        );
        grouped[key]!['planned'] = (grouped[key]!['planned'] as int) + 1;
        if ((p['statut'] ?? '') == 'En retard') {
          grouped[key]!['enRetard'] =
              (grouped[key]!['enRetard'] as int) + 1;
        }
      }

      for (final r in realisedRaw) {
        final subId = r['subject_id']?.toString() ?? '';
        final classId = r['class_id']?.toString() ?? '';
        final key = '${subId}_$classId';
        if (grouped.containsKey(key)) {
          grouped[key]!['realised'] =
              (grouped[key]!['realised'] as int) + 1;
        }
      }

      // Compute progress rate
      return grouped.values.map((item) {
        final planned = item['planned'] as int;
        final realised = item['realised'] as int;
        final rate = planned > 0 ? (realised / planned * 100).round() : 0;
        return {...item, 'progressRate': rate};
      }).toList()
        ..sort((a, b) =>
            (b['progressRate'] as int).compareTo(a['progressRate'] as int));
    } catch (e) {
      debugPrint('PlanificationRepository.getProgressionBySubject error: $e');
      rethrow;
    }
  }

  // ─── Get teacher classes/subjects for picker ───────────────────────────────
  Future<List<Map<String, dynamic>>> getTeacherClassesAndSubjects() async {
    try {
      final employeeId = await _getEmployeeId();
      if (employeeId == null) return [];

      final List<dynamic> response = await _client
          .from('class_subjects')
          .select(
            'class_id, subject_id, school_classes(class_name), school_subjects(subject_name)',
          )
          .eq('employee_id', employeeId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint(
          'PlanificationRepository.getTeacherClassesAndSubjects error: $e');
      return [];
    }
  }
}
