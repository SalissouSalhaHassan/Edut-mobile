import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/di/injection.dart';

class DashboardStatsRepository {
  DashboardStatsRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  final MobileApiClient _apiClient;
  static const String _cacheKey = "dashboard_summary_stats";

  Future<Map<String, dynamic>> getSummary() async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching dashboard summary from local cache.");
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _cacheKey,
      );
      if (cached.isNotEmpty) {
        return cached.first;
      }
      return _generateOfflineFallback(cacheManager);
    }

    try {
      final body = await _apiClient.getJson('/api/mobile/dashboard-stats');
      final stats = Map<String, dynamic>.from(body['stats'] ?? const {});

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _cacheKey,
        data: [stats],
      );

      return stats;
    } catch (e) {
      debugPrint("Error fetching dashboard stats: $e");
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: _cacheKey,
      );
      if (cached.isNotEmpty) {
        return cached.first;
      }
      return _generateOfflineFallback(cacheManager);
    }
  }

  Map<String, dynamic> _generateOfflineFallback(OfflineStoreManager cacheManager) {
    final cachedStudents = cacheManager.getDataList(
      boxName: OfflineStoreManager.boxStudents,
      key: "students_list",
    );
    final activeStudentsCount = cachedStudents.length;

    final cachedClasses = cacheManager.getDataList(
      boxName: OfflineStoreManager.boxClassSubjects,
      key: "all_classes_1",
    );

    return {
      'totalStudents': activeStudentsCount,
      'activeStudents': activeStudentsCount,
      'newStudentsThisMonth': 0,
      'activeClasses': cachedClasses.length,
      'attendanceRate': 95,
      'teacherAttendanceRate': 98,
      'activeExamsCount': 0,
      'pendingFeesCount': 0,
    };
  }
}
