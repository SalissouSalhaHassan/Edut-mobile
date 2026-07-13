import '../../../core/api/mobile_api_client.dart';

class DashboardStatsRepository {
  DashboardStatsRepository({MobileApiClient? apiClient})
    : _apiClient = apiClient ?? MobileApiClient();

  final MobileApiClient _apiClient;

  Future<Map<String, dynamic>> getSummary() async {
    final body = await _apiClient.getJson('/api/mobile/dashboard-stats');
    return Map<String, dynamic>.from(body['stats'] ?? const {});
  }
}
