import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class MobileApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'EDUT_WEB_API_BASE_URL',
    defaultValue: 'https://edut-web.vercel.app',
  );
}

class MobileApiException implements Exception {
  const MobileApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MobileApiProfile {
  const MobileApiProfile({
    required this.userId,
    required this.email,
    required this.role,
    required this.permissions,
    this.schoolId,
    this.employeeId,
    this.studentId,
    this.studentName,
    this.studentClass,
  });

  final String userId;
  final String email;
  final String role;
  final List<String> permissions;
  final String? schoolId;
  final String? employeeId;
  final String? studentId;
  final String? studentName;
  final String? studentClass;

  factory MobileApiProfile.fromJson(Map<String, dynamic> json) {
    final student = json['student'] is Map
        ? Map<String, dynamic>.from(json['student'] as Map)
        : null;

    return MobileApiProfile(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'staff',
      schoolId: json['schoolId']?.toString(),
      employeeId: json['employeeId']?.toString(),
      permissions: List<String>.from(json['permissions'] ?? const []),
      studentId: student?['id']?.toString(),
      studentName: student?['name']?.toString(),
      studentClass: student?['className']?.toString(),
    );
  }
}

class MobileApiClient {
  MobileApiClient({Dio? dio, SupabaseClient? supabaseClient})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _normalizeBaseUrl(MobileApiConfig.baseUrl),
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      _supabaseClient = supabaseClient ?? SupabaseClientManager().client;

  final Dio _dio;
  final SupabaseClient _supabaseClient;

  static String _normalizeBaseUrl(String rawValue) {
    final value = rawValue.trim();
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<MobileApiProfile> getCurrentProfile({String? accessToken}) async {
    final token =
        accessToken ?? _supabaseClient.auth.currentSession?.accessToken;

    if (token == null || token.isEmpty) {
      throw const MobileApiException('Session mobile absente.');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/api/mobile/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final body = response.data;
    if (body == null || body['success'] != true || body['profile'] is! Map) {
      throw const MobileApiException('Profil Edut mobile invalide.');
    }

    return MobileApiProfile.fromJson(
      Map<String, dynamic>.from(body['profile'] as Map),
    );
  }
}
