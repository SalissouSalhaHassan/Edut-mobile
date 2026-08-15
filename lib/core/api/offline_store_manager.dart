import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineStoreManager {
  static const String boxStudents = 'students_cache';
  static const String boxStudentFees = 'student_fees_cache';
  static const String boxFeePayments = 'fee_payments_cache';
  static const String boxStudentResults = 'student_results_cache';
  static const String boxClassSubjects = 'class_subjects_cache';
  static const String boxSchoolSessions = 'school_sessions_cache';
  static const String boxAcademicPeriods = 'academic_periods_cache';

  final List<String> _boxes = [
    boxStudents,
    boxStudentFees,
    boxFeePayments,
    boxStudentResults,
    boxClassSubjects,
    boxSchoolSessions,
    boxAcademicPeriods,
  ];

  /// Initialize all boxes
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      
      for (var boxName in _boxes) {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox(boxName);
        }
      }
      debugPrint("✅ OfflineStoreManager: All Hive boxes initialized successfully.");
    } catch (e) {
      debugPrint("❌ OfflineStoreManager Initialization Error: $e");
    }
  }

  /// Save raw JSON data list for a specific key in a box
  Future<void> saveDataList({
    required String boxName,
    required String key,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      final box = Hive.box(boxName);
      // Clean maps to ensure they are compatible with Hive (deep convert keys if necessary)
      final cleanData = data.map((item) => _cleanMap(item)).toList();
      await box.put(key, cleanData);
      debugPrint("💾 Cache Saved -> Box: $boxName, Key: $key, Count: ${data.length}");
    } catch (e) {
      debugPrint("❌ Error saving data list in box $boxName: $e");
    }
  }

  /// Get cached data list for a specific key
  List<Map<String, dynamic>> getDataList({
    required String boxName,
    required String key,
  }) {
    try {
      if (!Hive.isBoxOpen(boxName)) return [];
      final box = Hive.box(boxName);
      final rawData = box.get(key);
      if (rawData == null) return [];

      if (rawData is List) {
        return rawData.map((item) {
          if (item is Map) {
            return _cleanMap(item);
          }
          return <String, dynamic>{};
        }).where((element) => element.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ Error reading data list from box $boxName: $e");
      return [];
    }
  }

  /// Clear a specific cache box
  Future<void> clearBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
      }
    } catch (e) {
      debugPrint("❌ Error clearing box $boxName: $e");
    }
  }

  /// Clean recursive map types to satisfy Hive
  Map<String, dynamic> _cleanMap(Map<dynamic, dynamic> map) {
    final Map<String, dynamic> clean = {};
    map.forEach((k, v) {
      final String keyStr = k.toString();
      if (v is Map) {
        clean[keyStr] = _cleanMap(v);
      } else if (v is List) {
        clean[keyStr] = v.map((item) {
          if (item is Map) {
            return _cleanMap(item);
          }
          return item;
        }).toList();
      } else {
        clean[keyStr] = v;
      }
    });
    return clean;
  }
}
