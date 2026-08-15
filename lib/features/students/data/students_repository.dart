import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/sync_engine.dart';

class StudentsRepository {
  final MobileApiClient _apiClient;
  final SupabaseClient _client;

  StudentsRepository({MobileApiClient? apiClient, SupabaseClient? client})
      : _apiClient = apiClient ?? MobileApiClient(),
        _client = client ?? SupabaseClientManager().client;

  static const String _studentsCacheKey = "students_list";

  Future<List<Map<String, dynamic>>> getStudentsList() async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching students list from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _studentsCacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson('/api/mobile/students');
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _studentsCacheKey,
        data: list,
      );
      
      return list;
    } catch (e) {
      debugPrint('Error fetching students list: $e');
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _studentsCacheKey,
      );
    }
  }

  Future<Map<String, dynamic>?> getStudentDetails(int studentId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "student_detail_$studentId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching student details from local cache.");
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cached.isNotEmpty) {
        return cached.first;
      }
      
      // Fallback search in cached students list
      final allStudents = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _studentsCacheKey,
      );
      try {
        final match = allStudents.firstWhere((s) => (s['id'] as num?)?.toInt() == studentId);
        return match;
      } catch (_) {}
      return null;
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/students/$studentId',
      );
      final details = Map<String, dynamic>.from(response['data'] ?? {});
      if (details.isNotEmpty) {
        await cacheManager.saveDataList(
          boxName: OfflineStoreManager.boxStudents,
          key: cacheKey,
          data: [details],
        );
      }
      return details;
    } catch (e) {
      debugPrint('Error fetching student details: $e');
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cached.isNotEmpty) return cached.first;
      return null;
    }
  }

  Future<Map<String, List<String>>> getStudentFormOptions() async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    const cacheKey = "student_form_options";

    if (!syncEngine.isOnlineNotifier.value) {
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cached.isNotEmpty && cached.first.containsKey('levels')) {
        final item = cached.first;
        return {
          'levels': List<String>.from(item['levels'] ?? []),
          'sections': List<String>.from(item['sections'] ?? []),
          'classes': List<String>.from(item['classes'] ?? []),
        };
      }
      return {
        'levels': ['Collège', 'Lycée', 'Primaire'],
        'sections': ['Générale'],
        'classes': ['6ème A', '5ème A', '4ème A', '3ème A', '2nde A', '1ère A', 'Tle A'],
      };
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/students/0/summary?action=getStudentFormOptions',
      );

      final levels = List<String>.from(response['levels'] ?? []);
      final sections = List<String>.from(response['sections'] ?? []);
      final classes = List<String>.from(response['classes'] ?? []);

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: [
          {'levels': levels, 'sections': sections, 'classes': classes}
        ],
      );

      return {
        'levels': levels,
        'sections': sections,
        'classes': classes,
      };
    } catch (e) {
      debugPrint('Error fetching student form options: $e');
      return {
        'levels': ['Collège', 'Lycée', 'Primaire'],
        'sections': ['Générale'],
        'classes': ['6ème A', '5ème A', '4ème A', '3ème A', '2nde A', '1ère A', 'Tle A'],
      };
    }
  }

  Future<Map<String, dynamic>> saveStudent({
    int? studentId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final dataToSend = Map<String, dynamic>.from(payload);
      if (studentId != null) {
        dataToSend['id'] = studentId;
      }
      final response = await _apiClient.postJson(
        '/api/mobile/students',
        {
          'action': 'saveStudent',
          'payload': dataToSend,
        },
      );
      return response;
    } catch (e) {
      debugPrint('Error saving student: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> getPromotionOptions() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/students/0/summary?action=getPromotionOptions',
      );
      final classes = List<Map<String, dynamic>>.from(response['classes'] ?? []);
      final sessions = List<Map<String, dynamic>>.from(response['sessions'] ?? []);

      return {
        'classes': classes,
        'sessions': sessions,
      };
    } catch (e) {
      debugPrint('Error fetching promotion options: $e');
      return {
        'classes': <Map<String, dynamic>>[],
        'sessions': <Map<String, dynamic>>[],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getPromotionHistory({
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/students/0/summary?action=getPromotionHistory&limit=$limit',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching promotion history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPromotionPreview({
    required List<Map<String, dynamic>> students,
    String? targetClass,
    String? targetSession,
  }) async {
    try {
      if (students.isEmpty) return [];

      final studentIds = students
          .map((row) => row['id'])
          .whereType<int>()
          .toList();

      final response = await _apiClient.getJson(
        '/api/mobile/students/0/summary?action=getPromotionPreview&studentIds=${studentIds.join(',')}',
      );

      final previewList = List<Map<String, dynamic>>.from(response['data'] ?? []);
      final statsMap = {
        for (var p in previewList)
          (p['id'] as num).toInt(): p
      };

      return students.map((student) {
        final studentId = student['id'] as int?;
        final stats = statsMap[studentId];
        final average = (stats?['calculated_average'] as num?)?.toDouble();
        final recommendation = stats?['recommendation']?.toString() ?? 'A verifier';

        return {
          ...student,
          'target_class': targetClass,
          'target_session': targetSession,
          'calculated_average': average,
          'recommendation': recommendation,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching promotion preview: $e');
      return students
          .map(
            (student) => {
              ...student,
              'target_class': targetClass,
              'target_session': targetSession,
              'calculated_average': null,
              'recommendation': 'A verifier',
            },
          )
          .toList();
    }
  }

  Future<Map<String, dynamic>> promoteStudents({
    required List<int> studentIds,
    required String targetClass,
    required String targetSession,
    required bool transferBalance,
  }) async {
    try {
      if (studentIds.isEmpty) {
        return {'success': false, 'error': 'Aucun etudiant selectionne.'};
      }

      final response = await _apiClient.postJson(
        '/api/mobile/students',
        {
          'action': 'promoteStudents',
          'payload': {
            'studentIds': studentIds,
            'targetClass': targetClass,
            'targetSession': targetSession,
            'transferBalance': transferBalance,
          },
        },
      );
      return response;
    } catch (e) {
      debugPrint('Error promoting students: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
