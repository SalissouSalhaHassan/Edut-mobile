import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class SessionManager {
  final _storage = const FlutterSecureStorage();

  static const String _keyToken = 'auth_token';
  static const String _keyEmail = 'auth_email';
  static const String _keyPasswordHash = 'auth_password_hash';
  static const String _keyRole = 'auth_role';
  static const String _keyEmployeeId = 'auth_employee_id';
  static const String _keySchoolId = 'auth_school_id';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyStudentId = 'auth_student_id';
  static const String _keyStudentName = 'auth_student_name';
  static const String _keyStudentClass = 'auth_student_class';
  static const String _keyPermissions = 'auth_permissions';

  Future<void> saveSession({
    required String token,
    required String email,
    required String role,
    required String employeeId,
    String? password,
    String? userId,
    String? schoolId,
    String? studentId,
    String? studentName,
    String? studentClass,
    List<String>? permissions,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyEmail, value: email.toLowerCase().trim());
    if (password != null && password.isNotEmpty) {
      final hash = sha256.convert(utf8.encode(password)).toString();
      await _storage.write(key: _keyPasswordHash, value: hash);
    }
    await _storage.write(key: _keyRole, value: role);
    await _storage.write(key: _keyEmployeeId, value: employeeId);
    if (userId != null) {
      await _storage.write(key: _keyUserId, value: userId);
    }
    if (schoolId != null) {
      await _storage.write(key: _keySchoolId, value: schoolId);
    }
    if (studentId != null) {
      await _storage.write(key: _keyStudentId, value: studentId);
    }
    if (studentName != null) {
      await _storage.write(key: _keyStudentName, value: studentName);
    }
    if (studentClass != null) {
      await _storage.write(key: _keyStudentClass, value: studentClass);
    }
    if (permissions != null) {
      await _storage.write(
        key: _keyPermissions,
        value: jsonEncode(permissions),
      );
    }
  }

  Future<String?> getToken() async => await _storage.read(key: _keyToken);
  Future<String?> getEmail() async => await _storage.read(key: _keyEmail);
  Future<String?> getRole() async => await _storage.read(key: _keyRole);
  Future<String?> getEmployeeId() async =>
      await _storage.read(key: _keyEmployeeId);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getSchoolId() async => await _storage.read(key: _keySchoolId);
  Future<String?> getStudentId() async =>
      await _storage.read(key: _keyStudentId);
  Future<String?> getStudentName() async =>
      await _storage.read(key: _keyStudentName);
  Future<String?> getStudentClass() async =>
      await _storage.read(key: _keyStudentClass);

  Future<void> savePermissions(List<String> permissions) async {
    await _storage.write(
      key: _keyPermissions,
      value: jsonEncode(permissions),
    );
  }

  Future<List<String>> getPermissions() async {
    final rawValue = await _storage.read(key: _keyPermissions);
    if (rawValue == null || rawValue.isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {}

    return const [];
  }

  Future<bool> validateOfflineCredentials(String email, String password) async {
    final cachedEmail = await getEmail();
    if (cachedEmail == null || cachedEmail.isEmpty) return false;

    final normalizedInput = email.toLowerCase().trim();
    final inputUsername = normalizedInput.split('@').first;
    final cachedUsername = cachedEmail.toLowerCase().split('@').first;

    final emailMatches = normalizedInput == cachedEmail || inputUsername == cachedUsername;
    if (!emailMatches) return false;

    final cachedHash = await _storage.read(key: _keyPasswordHash);
    if (cachedHash == null || cachedHash.isEmpty) {
      // If no password hash stored yet but email matches cached user on device, allow offline login
      return true;
    }

    final inputHash = sha256.convert(utf8.encode(password)).toString();
    return cachedHash == inputHash;
  }

  Future<bool> validateCurrentPassword(String password) async {
    final cachedHash = await _storage.read(key: _keyPasswordHash);
    if (cachedHash != null && cachedHash.isNotEmpty) {
      final inputHash = sha256.convert(utf8.encode(password)).toString();
      return cachedHash == inputHash;
    }
    return false;
  }

  Future<int> getInactivityTimeoutMinutes() async {
    final raw = await _storage.read(key: 'auth_inactivity_minutes');
    if (raw != null) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 3; // Default 3 minutes as requested
  }

  Future<void> setInactivityTimeoutMinutes(int minutes) async {
    await _storage.write(key: 'auth_inactivity_minutes', value: minutes.toString());
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPasswordHash);
    await _storage.delete(key: _keyRole);
    await _storage.delete(key: _keyEmployeeId);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keySchoolId);
    await _storage.delete(key: _keyStudentId);
    await _storage.delete(key: _keyStudentName);
    await _storage.delete(key: _keyStudentClass);
    await _storage.delete(key: _keyPermissions);
  }
}
