import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/api/mobile_api_client.dart';

class LibraryRepository {
  final MobileApiClient _apiClient;
  static const String boxLibraryName = 'offline_library_box';

  LibraryRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Fetches digital library catalog
  Future<Map<String, dynamic>?> getCatalog({String? category, String? query}) async {
    try {
      final queryParams = <String>[
        if (category != null && category.isNotEmpty) 'category=${Uri.encodeComponent(category)}',
        if (query != null && query.isNotEmpty) 'q=${Uri.encodeComponent(query)}',
      ].join('&');

      final res = await _apiClient.getJson('/api/mobile/e-library/catalog?$queryParams');
      if (res['success'] == true && res['data'] != null) {
        final data = Map<String, dynamic>.from(res['data']);
        // Cache in Hive
        _cacheCatalogLocally(data);
        return data;
      }
    } catch (e) {
      debugPrint("LibraryRepository.getCatalog network error: $e");
    }

    // Fallback to local offline cache
    return _getCachedCatalogLocally();
  }

  Future<void> _cacheCatalogLocally(Map<String, dynamic> data) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      await box.put('cached_catalog', data);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getCachedCatalogLocally() async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      final raw = box.get('cached_catalog');
      if (raw != null) {
        return Map<String, dynamic>.from(raw as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Mark book as downloaded offline
  Future<void> markBookDownloaded(int bookId, String localPath) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      await box.put('book_download_$bookId', localPath);
    } catch (_) {}
  }

  /// Check if book is saved locally
  Future<String?> getDownloadedBookPath(int bookId) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      final val = box.get('book_download_$bookId');
      return val?.toString();
    } catch (_) {}
    return null;
  }
}
