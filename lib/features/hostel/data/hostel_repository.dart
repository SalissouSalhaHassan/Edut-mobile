import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/supabase_client.dart';

class HostelRepository {
  final SupabaseClient _client;

  HostelRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      final rows = await _client
          .from('hostel_rooms')
          .select(
            'id, room_number, building_name, room_type, capacity, occupied_beds, created_at',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching hostel rooms: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllocations() async {
    try {
      final rows = await _client
          .from('hostel_allocations')
          .select(
            'id, student_id, room_id, join_date, leave_date, status, '
            'students(id, nom_etudiant, num_admission, classe), '
            'hostel_rooms(id, room_number, building_name, room_type)',
          )
          .order('join_date', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching hostel allocations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableStudents() async {
    try {
      final allocated = await _client
          .from('hostel_allocations')
          .select('student_id, status');

      final occupiedIds = List<Map<String, dynamic>>.from(allocated)
          .where(
            (row) => (row['status'] ?? '').toString().toLowerCase().contains('occup'),
          )
          .map((row) => row['student_id'] as int?)
          .whereType<int>()
          .toSet();

      final students = await _client
          .from('students')
          .select('id, nom_etudiant, num_admission, classe, section, statut')
          .order('nom_etudiant');

      return List<Map<String, dynamic>>.from(students)
          .where(
            (student) =>
                !occupiedIds.contains(student['id']) &&
                (student['statut'] ?? 'Actif')
                    .toString()
                    .toLowerCase()
                    .contains('actif'),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching available students: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveRoom({
    int? roomId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final data = Map<String, dynamic>.from(payload);
      data.remove('cost');
      if (roomId == null) {
        await _client.from('hostel_rooms').insert(data);
      } else {
        await _client.from('hostel_rooms').update(data).eq('id', roomId);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error saving hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> allocateStudent({
    required int studentId,
    required int roomId,
  }) async {
    try {
      final room = await _client
          .from('hostel_rooms')
          .select('id, capacity, occupied_beds')
          .eq('id', roomId)
          .maybeSingle();

      if (room == null) {
        return {'success': false, 'error': 'Chambre introuvable.'};
      }

      final capacity = (room['capacity'] as num?)?.toInt() ?? 0;
      final occupied = (room['occupied_beds'] as num?)?.toInt() ?? 0;
      if (occupied >= capacity) {
        return {'success': false, 'error': 'Chambre complete.'};
      }

      await _client.from('hostel_allocations').insert({
        'student_id': studentId,
        'room_id': roomId,
        'status': 'Occupe',
      });

      await _client.from('hostel_rooms').update({
        'occupied_beds': occupied + 1,
      }).eq('id', roomId);

      return {'success': true};
    } catch (e) {
      debugPrint('Error allocating hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> vacateAllocation(int allocationId) async {
    try {
      final allocation = await _client
          .from('hostel_allocations')
          .select('id, room_id, status')
          .eq('id', allocationId)
          .maybeSingle();

      if (allocation == null) {
        return {'success': false, 'error': 'Affectation introuvable.'};
      }

      final roomId = allocation['room_id'] as int?;
      if (roomId == null) {
        return {'success': false, 'error': 'Chambre introuvable.'};
      }

      await _client.from('hostel_allocations').update({
        'status': 'Libere',
        'leave_date': DateTime.now().toIso8601String(),
      }).eq('id', allocationId);

      final room = await _client
          .from('hostel_rooms')
          .select('occupied_beds')
          .eq('id', roomId)
          .maybeSingle();
      final occupied = (room?['occupied_beds'] as num?)?.toInt() ?? 0;

      await _client.from('hostel_rooms').update({
        'occupied_beds': occupied > 0 ? occupied - 1 : 0,
      }).eq('id', roomId);

      return {'success': true};
    } catch (e) {
      debugPrint('Error vacating hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> deleteRoom(int roomId) async {
    try {
      final allocations = await _client
          .from('hostel_allocations')
          .select('id')
          .eq('room_id', roomId)
          .limit(1);

      if (List<Map<String, dynamic>>.from(allocations).isNotEmpty) {
        return {
          'success': false,
          'error': 'Impossible de supprimer une chambre avec des affectations.',
        };
      }

      await _client.from('hostel_rooms').delete().eq('id', roomId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
