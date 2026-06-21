import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  final _storage = const FlutterSecureStorage();

  static const String _keyToken = 'auth_token';
  static const String _keyEmail = 'auth_email';
  static const String _keyRole = 'auth_role';
  static const String _keyEmployeeId = 'auth_employee_id';
  static const String _keySchoolId = 'auth_school_id';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyStudentId = 'auth_student_id';
  static const String _keyStudentName = 'auth_student_name';
  static const String _keyStudentClass = 'auth_student_class';

  Future<void> saveSession({
    required String token,
    required String email,
    required String role,
    required String employeeId,
    String? userId,
    String? schoolId,
    String? studentId,
    String? studentName,
    String? studentClass,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyEmail, value: email);
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
  }

  Future<String?> getToken() async => await _storage.read(key: _keyToken);
  Future<String?> getEmail() async => await _storage.read(key: _keyEmail);
  Future<String?> getRole() async => await _storage.read(key: _keyRole);
  Future<String?> getEmployeeId() async => await _storage.read(key: _keyEmployeeId);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getSchoolId() async => await _storage.read(key: _keySchoolId);
  Future<String?> getStudentId() async => await _storage.read(key: _keyStudentId);
  Future<String?> getStudentName() async => await _storage.read(key: _keyStudentName);
  Future<String?> getStudentClass() async => await _storage.read(key: _keyStudentClass);

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyRole);
    await _storage.delete(key: _keyEmployeeId);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keySchoolId);
    await _storage.delete(key: _keyStudentId);
    await _storage.delete(key: _keyStudentName);
    await _storage.delete(key: _keyStudentClass);
  }
}
