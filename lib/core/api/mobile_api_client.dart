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

  Future<MobileApiProfile?> getMeProfile(String token) async {
    try {
      return await getCurrentProfile(accessToken: token);
    } catch (_) {
      return null;
    }
  }

  Future<void> register({
    required String role,
    required String schoolSlug,
    required String matriculeOrEmail,
    required String username,
    required String fullName,
    required String password,
    required String activationPin,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/mobile/register',
        data: {
          'role': role,
          'schoolSlug': schoolSlug,
          'matriculeOrEmail': matriculeOrEmail,
          'username': username,
          'fullName': fullName,
          'password': password,
          'activationPin': activationPin,
        },
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw MobileApiException(body?['error']?.toString() ?? 'Erreur lors de l\'inscription.');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?.toString() ?? 'Erreur lors de l\'inscription.';
      throw MobileApiException(errorMsg);
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String role,
    required String schoolSlug,
    required String matriculeOrEmail,
    required String verificationCodeOrPhone,
    String? newPassword,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/mobile/forgot-password',
        data: {
          'role': role,
          'schoolSlug': schoolSlug,
          'matriculeOrEmail': matriculeOrEmail,
          'verificationCodeOrPhone': verificationCodeOrPhone,
          if (newPassword != null && newPassword.isNotEmpty) 'newPassword': newPassword,
        },
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw MobileApiException(body?['error']?.toString() ?? 'Erreur lors de la réinitialisation.');
      }
      return Map<String, dynamic>.from(body['data'] as Map);
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?.toString() ?? 'Erreur lors de la réinitialisation.';
      throw MobileApiException(errorMsg);
    }
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      options: await _authOptions(),
    );
    return _parseBody(response.data);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: await _authOptions(),
    );
    return _parseBody(response.data);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      path,
      data: data,
      options: await _authOptions(),
    );
    return _parseBody(response.data);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      options: await _authOptions(),
    );
    return _parseBody(response.data);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      path,
      options: await _authOptions(),
    );
    return _parseBody(response.data);
  }

  Future<Options> _authOptions() async {
    final token = _supabaseClient.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const MobileApiException('Session mobile absente.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Map<String, dynamic> _parseBody(Map<String, dynamic>? body) {
    if (body == null) {
      throw const MobileApiException('Reponse Edut mobile vide.');
    }
    if (body['success'] == false) {
      throw MobileApiException(
        body['error']?.toString() ?? 'Erreur API Edut mobile.',
      );
    }
    return body;
  }
}
