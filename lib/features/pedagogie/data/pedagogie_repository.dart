import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';

class PedagogieRepository {
  final SupabaseClient _client;

  PedagogieRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  static const _selectFields =
      'id, class_id, subject_id, employee_id, session_date, heure_debut, heure_fin, '
      'titre_lecon, objectifs, contenu_realise, supports_utilises, devoir_donne, '
      'observation, statut, valide_par_id, valide_at, annee_scolaire, created_at, updated_at, '
      'school_classes(class_name), school_subjects(subject_name)';

  // ─── Fetch séances (cahier de textes) ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSeances({
    int? classId,
    int? subjectId,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    try {
      final session = locator<SessionManager>();
      final employeeIdStr = await session.getEmployeeId();
      final role = (await session.getRole() ?? 'staff').toLowerCase();
      final isTeacher = role.contains('teacher') ||
          role.contains('enseignant') ||
          role.contains('professeur');

      var q = _client.from('cahier_textes').select(_selectFields);

      // Build conditions list - apply via chained calls
      List<dynamic> result;

      // Teacher scope filter applied as the initial filter
      if (isTeacher) {
        final employeeId = int.tryParse(employeeIdStr ?? '');
        if (employeeId != null) {
          var filtered = q.eq('employee_id', employeeId);
          if (classId != null) filtered = filtered.eq('class_id', classId);
          if (subjectId != null) filtered = filtered.eq('subject_id', subjectId);
          if (statut != null && statut.isNotEmpty) {
            filtered = filtered.eq('statut', statut);
          }
          if (dateDebut != null && dateDebut.isNotEmpty) {
            filtered = filtered.gte('session_date', dateDebut);
          }
          if (dateFin != null && dateFin.isNotEmpty) {
            filtered = filtered.lte('session_date', dateFin);
          }
          result = await filtered.order('session_date', ascending: false);
        } else {
          result = await q.order('session_date', ascending: false);
        }
      } else {
        var filtered = q;
        if (classId != null) filtered = filtered.eq('class_id', classId);
        if (subjectId != null) filtered = filtered.eq('subject_id', subjectId);
        if (statut != null && statut.isNotEmpty) {
          filtered = filtered.eq('statut', statut);
        }
        if (dateDebut != null && dateDebut.isNotEmpty) {
          filtered = filtered.gte('session_date', dateDebut);
        }
        if (dateFin != null && dateFin.isNotEmpty) {
          filtered = filtered.lte('session_date', dateFin);
        }
        result = await filtered.order('session_date', ascending: false);
      }

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('PedagogieRepository.getSeances error: $e');
      rethrow;
    }
  }

  // ─── Get teacher classes for picker ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTeacherClassesAndSubjects() async {
    try {
      final session = locator<SessionManager>();
      final employeeIdStr = await session.getEmployeeId();
      final employeeId = int.tryParse(employeeIdStr ?? '');

      if (employeeId == null) return [];

      final List<dynamic> response = await _client
          .from('class_subjects')
          .select(
            'class_id, subject_id, school_classes(class_name), school_subjects(subject_name)',
          )
          .eq('employee_id', employeeId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('PedagogieRepository.getTeacherClassesAndSubjects error: $e');
      return [];
    }
  }

  // ─── CREATE séance ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createSeance({
    required int classId,
    required int subjectId,
    required int employeeId,
    required String sessionDate,
    required String titreLecon,
    String? heureDebut,
    String? heureFin,
    String? objectifs,
    String? contenuRealise,
    String? supportsUtilises,
    String? devoirDonne,
    String? observation,
    String? anneeScolaire,
  }) async {
    try {
      final session = locator<SessionManager>();
      final schoolIdStr = await session.getSchoolId();
      final schoolId = int.tryParse(schoolIdStr ?? '');

      final data = <String, dynamic>{
        'class_id': classId,
        'subject_id': subjectId,
        'employee_id': employeeId,
        'session_date': sessionDate,
        'titre_lecon': titreLecon,
        'statut': 'Brouillon',
      };

      if (schoolId != null) data['school_id'] = schoolId;
      if (heureDebut != null && heureDebut.isNotEmpty) {
        data['heure_debut'] = heureDebut;
      }
      if (heureFin != null && heureFin.isNotEmpty) {
        data['heure_fin'] = heureFin;
      }
      if (objectifs != null && objectifs.isNotEmpty) {
        data['objectifs'] = objectifs;
      }
      if (contenuRealise != null && contenuRealise.isNotEmpty) {
        data['contenu_realise'] = contenuRealise;
      }
      if (supportsUtilises != null && supportsUtilises.isNotEmpty) {
        data['supports_utilises'] = supportsUtilises;
      }
      if (devoirDonne != null && devoirDonne.isNotEmpty) {
        data['devoir_donne'] = devoirDonne;
      }
      if (observation != null && observation.isNotEmpty) {
        data['observation'] = observation;
      }
      if (anneeScolaire != null && anneeScolaire.isNotEmpty) {
        data['annee_scolaire'] = anneeScolaire;
      }

      final List<dynamic> response =
          await _client.from('cahier_textes').insert(data).select();

      return Map<String, dynamic>.from(response.first as Map);
    } catch (e) {
      debugPrint('PedagogieRepository.createSeance error: $e');
      rethrow;
    }
  }

  // ─── UPDATE séance ─────────────────────────────────────────────────────────
  Future<void> updateSeance(
    int id, {
    String? titreLecon,
    String? sessionDate,
    String? heureDebut,
    String? heureFin,
    String? objectifs,
    String? contenuRealise,
    String? supportsUtilises,
    String? devoirDonne,
    String? observation,
    String? statut,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (titreLecon != null) data['titre_lecon'] = titreLecon;
      if (sessionDate != null) data['session_date'] = sessionDate;
      if (heureDebut != null) data['heure_debut'] = heureDebut;
      if (heureFin != null) data['heure_fin'] = heureFin;
      if (objectifs != null) data['objectifs'] = objectifs;
      if (contenuRealise != null) data['contenu_realise'] = contenuRealise;
      if (supportsUtilises != null) {
        data['supports_utilises'] = supportsUtilises;
      }
      if (devoirDonne != null) data['devoir_donne'] = devoirDonne;
      if (observation != null) data['observation'] = observation;
      if (statut != null) data['statut'] = statut;

      await _client.from('cahier_textes').update(data).eq('id', id);
    } catch (e) {
      debugPrint('PedagogieRepository.updateSeance error: $e');
      rethrow;
    }
  }

  // ─── SUBMIT séance (Brouillon → Soumis) ───────────────────────────────────
  Future<void> submitSeance(int id) async {
    await updateSeance(id, statut: 'Soumis');
  }

  // ─── DELETE séance ─────────────────────────────────────────────────────────
  Future<void> deleteSeance(int id) async {
    try {
      await _client.from('cahier_textes').delete().eq('id', id);
    } catch (e) {
      debugPrint('PedagogieRepository.deleteSeance error: $e');
      rethrow;
    }
  }
}
