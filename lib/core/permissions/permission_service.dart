import 'package:flutter/foundation.dart';

import '../api/supabase_client.dart';
import '../auth/session_manager.dart';

class AppPermissions {
  static const ownerPlatformView = 'owner.platform.view';
  static const ownerSchoolsManage = 'owner.schools.manage';
  static const studentsView = 'students.view';
  static const studentsCreate = 'students.create';
  static const studentsEdit = 'students.edit';
  static const studentsDelete = 'students.delete';
  static const studentsPromote = 'students.promote';
  static const financeView = 'finance.view';
  static const financeCollect = 'finance.collect';
  static const hrView = 'hr.view';
  static const hrManage = 'hr.manage';
  static const hostelView = 'hostel.view';
  static const hostelManage = 'hostel.manage';
  static const examsView = 'exams.view';
  static const examsManage = 'exams.manage';
  static const attendanceView = 'attendance.view';
  static const attendanceManage = 'attendance.manage';
  static const academicsView = 'academics.view';
  static const academicsManage = 'academics.manage';
}

class UserAccessProfile {
  const UserAccessProfile({required this.role, required this.permissions});

  final String role;
  final Set<String> permissions;
}

class PermissionService {
  PermissionService({required SessionManager sessionManager})
    : _sessionManager = sessionManager;

  final SessionManager _sessionManager;
  final _client = SupabaseClientManager().client;
  UserAccessProfile? _cachedProfile;
  String? _cachedCacheKey;

  Future<UserAccessProfile> getCurrentProfile() async {
    final role = ((await _sessionManager.getRole()) ?? 'staff')
        .toLowerCase()
        .trim();
    final userId = await _sessionManager.getUserId();
    final email =
        (await _sessionManager.getEmail())?.toLowerCase().trim() ?? '';
    final cacheKey = '$userId|$email|$role';

    if (_cachedProfile != null && _cachedCacheKey == cacheKey) {
      return _cachedProfile!;
    }

    final sessionPermissions = await _sessionManager.getPermissions();
    if (sessionPermissions.isNotEmpty) {
      final profile = UserAccessProfile(
        role: role,
        permissions: sessionPermissions.toSet(),
      );
      _cachedProfile = profile;
      _cachedCacheKey = cacheKey;
      return profile;
    }

    try {
      final profile = await _loadProfileFromDatabase(
        fallbackRole: role,
        userId: userId,
        email: email,
      );
      _cachedProfile = profile;
      _cachedCacheKey = cacheKey;
      return profile;
    } catch (e) {
      debugPrint('PermissionService fallback to role mapping: $e');
      final profile = UserAccessProfile(
        role: role,
        permissions: _permissionsForRole(role),
      );
      _cachedProfile = profile;
      _cachedCacheKey = cacheKey;
      return profile;
    }
  }

  Future<bool> hasPermission(String permission) async {
    final profile = await getCurrentProfile();
    return profile.permissions.contains(permission);
  }

  Future<bool> hasAnyPermission(List<String> permissions) async {
    final profile = await getCurrentProfile();
    return permissions.any(profile.permissions.contains);
  }

  Future<bool> hasRole(String role) async {
    final profile = await getCurrentProfile();
    return profile.role == role.toLowerCase().trim();
  }

  Future<void> refresh() async {
    _cachedProfile = null;
    _cachedCacheKey = null;
    await getCurrentProfile();
  }

  Set<String> permissionsForRole(String role) => _permissionsForRole(role);

  Future<UserAccessProfile> _loadProfileFromDatabase({
    required String fallbackRole,
    required String? userId,
    required String email,
  }) async {
    final userRecord = await _fetchCurrentUserRecord(
      userId: userId,
      email: email,
    );

    if (userRecord == null) {
      return UserAccessProfile(
        role: fallbackRole,
        permissions: _permissionsForRole(fallbackRole),
      );
    }

    final isAdmin = userRecord['admin'] == true;
    final isSuperAdmin = userRecord['super_admin'] == true;
    final roleId = userRecord['role_id'];
    final dbRole = _normalizeRoleName(
      userRecord['roles']?['role_name']?.toString(),
      isAdmin: isAdmin,
      isSuperAdmin: isSuperAdmin,
      fallbackRole: fallbackRole,
    );

    var permissions = <String>{..._permissionsForRole(dbRole)};

    if (roleId != null) {
      final rows = await _client
          .from('role_permissions')
          .select('module_name, can_view, can_edit, can_delete')
          .eq('role_id', roleId);

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        permissions.addAll(_mapModulePermissionRow(row));
      }
    }

    return UserAccessProfile(role: dbRole, permissions: permissions);
  }

  Future<Map<String, dynamic>?> _fetchCurrentUserRecord({
    required String? userId,
    required String email,
  }) async {
    final currentSupabaseUser = _client.auth.currentUser;
    final username = email.contains('@') ? email.split('@').first : email;
    const select =
        'id, utilisateur, admin, super_admin, role_id, roles(role_name)';

    if (userId != null && userId.isNotEmpty) {
      try {
        final byId = await _client
            .from('users')
            .select(select)
            .eq('id', int.parse(userId))
            .maybeSingle();
        if (byId != null) {
          return byId;
        }
      } catch (_) {}
    }

    if (currentSupabaseUser != null) {
      try {
        final bySupabaseId = await _client
            .from('users')
            .select(select)
            .eq('supabase_id', currentSupabaseUser.id)
            .maybeSingle();
        if (bySupabaseId != null) {
          return bySupabaseId;
        }
      } catch (_) {}
    }

    if (email.isNotEmpty) {
      try {
        final byEmail = await _client
            .from('users')
            .select(select)
            .eq('utilisateur', email)
            .maybeSingle();
        if (byEmail != null) {
          return byEmail;
        }
      } catch (_) {}
    }

    if (username.isNotEmpty) {
      try {
        return await _client
            .from('users')
            .select(select)
            .eq('utilisateur', username)
            .maybeSingle();
      } catch (_) {}
    }

    return null;
  }

  String _normalizeRoleName(
    String? roleName, {
    required bool isAdmin,
    required bool isSuperAdmin,
    required String fallbackRole,
  }) {
    if (isSuperAdmin) return 'super_admin';
    if (isAdmin) return 'admin';

    final role = (roleName ?? fallbackRole).toLowerCase().trim();
    if (role.contains('owner') || role.contains('propriet')) return 'owner';
    if (role.contains('teacher') ||
        role.contains('enseignant') ||
        role.contains('professeur')) {
      return 'teacher';
    }
    if (role.contains('director') || role.contains('directeur')) {
      return 'director';
    }
    if (role.contains('comptable') || role.contains('accountant')) {
      return 'accountant';
    }
    if (role.contains('secret')) return 'secretary';
    if (role.contains('personnel') || role == 'hr') return 'personnel';
    return role.isEmpty ? fallbackRole : role;
  }

  Set<String> _mapModulePermissionRow(Map<String, dynamic> row) {
    final moduleName = (row['module_name'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final canView = row['can_view'] == true;
    final canEdit = row['can_edit'] == true;
    final canDelete = row['can_delete'] == true;

    final permissions = <String>{};

    if (_matchesModule(moduleName, const ['students', 'student', 'eleves'])) {
      if (canView) permissions.add(AppPermissions.studentsView);
      if (canEdit) {
        permissions.addAll({
          AppPermissions.studentsCreate,
          AppPermissions.studentsEdit,
          AppPermissions.studentsPromote,
        });
      }
      if (canDelete) permissions.add(AppPermissions.studentsDelete);
    }

    if (_matchesModule(moduleName, const ['finance', 'finances'])) {
      if (canView) permissions.add(AppPermissions.financeView);
      if (canEdit) permissions.add(AppPermissions.financeCollect);
    }

    if (_matchesModule(moduleName, const [
      'hr',
      'human resources',
      'ressources humaines',
    ])) {
      if (canView) permissions.add(AppPermissions.hrView);
      if (canEdit || canDelete) permissions.add(AppPermissions.hrManage);
    }

    if (_matchesModule(moduleName, const [
      'hostel',
      'internat',
      'dortoirs',
      'dormitory',
    ])) {
      if (canView) permissions.add(AppPermissions.hostelView);
      if (canEdit || canDelete) permissions.add(AppPermissions.hostelManage);
    }

    if (_matchesModule(moduleName, const [
      'owner',
      'platform',
      'schools',
      'security',
    ])) {
      if (canView) permissions.add(AppPermissions.ownerPlatformView);
      if (canEdit || canDelete) {
        permissions.add(AppPermissions.ownerSchoolsManage);
      }
    }

    if (_matchesModule(moduleName, const ['exam', 'exams', 'resultats'])) {
      if (canView) permissions.add(AppPermissions.examsView);
      if (canEdit || canDelete) permissions.add(AppPermissions.examsManage);
    }

    if (_matchesModule(moduleName, const ['attendance', 'appel', 'presence'])) {
      if (canView) permissions.add(AppPermissions.attendanceView);
      if (canEdit || canDelete) {
        permissions.add(AppPermissions.attendanceManage);
      }
    }

    if (_matchesModule(moduleName, const [
      'academics',
      'notes',
      'devoirs',
      'homework',
    ])) {
      if (canView) permissions.add(AppPermissions.academicsView);
      if (canEdit || canDelete) permissions.add(AppPermissions.academicsManage);
    }

    return permissions;
  }

  bool _matchesModule(String moduleName, List<String> aliases) {
    for (final alias in aliases) {
      if (moduleName == alias || moduleName.contains(alias)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _permissionsForRole(String rawRole) {
    final role = rawRole.toLowerCase().trim();

    if (role == 'super_admin' || role == 'owner') {
      return {
        AppPermissions.ownerPlatformView,
        AppPermissions.ownerSchoolsManage,
        AppPermissions.studentsView,
        AppPermissions.studentsCreate,
        AppPermissions.studentsEdit,
        AppPermissions.studentsDelete,
        AppPermissions.studentsPromote,
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.hrView,
        AppPermissions.hrManage,
        AppPermissions.hostelView,
        AppPermissions.hostelManage,
        AppPermissions.examsView,
        AppPermissions.examsManage,
        AppPermissions.attendanceView,
        AppPermissions.attendanceManage,
        AppPermissions.academicsView,
        AppPermissions.academicsManage,
      };
    }

    if (role == 'admin' || role == 'director') {
      return {
        AppPermissions.studentsView,
        AppPermissions.studentsCreate,
        AppPermissions.studentsEdit,
        AppPermissions.studentsDelete,
        AppPermissions.studentsPromote,
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.hrView,
        AppPermissions.hrManage,
        AppPermissions.hostelView,
        AppPermissions.hostelManage,
        AppPermissions.examsView,
        AppPermissions.examsManage,
        AppPermissions.attendanceView,
        AppPermissions.attendanceManage,
        AppPermissions.academicsView,
        AppPermissions.academicsManage,
      };
    }

    if (role == 'accountant' || role == 'comptable' || role == 'finance') {
      return {
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.studentsView,
      };
    }

    if (role == 'hr' || role == 'personnel') {
      return {AppPermissions.hrView, AppPermissions.hrManage};
    }

    if (role == 'teacher' || role == 'enseignant' || role == 'professeur') {
      return {
        AppPermissions.studentsView,
        AppPermissions.examsView,
        AppPermissions.examsManage,
        AppPermissions.attendanceView,
        AppPermissions.attendanceManage,
        AppPermissions.academicsView,
        AppPermissions.academicsManage,
      };
    }

    if (role == 'secretary' || role == 'secretaire') {
      return {
        AppPermissions.studentsView,
        AppPermissions.studentsCreate,
        AppPermissions.studentsEdit,
        AppPermissions.financeView,
        AppPermissions.examsView,
        AppPermissions.attendanceView,
      };
    }

    return <String>{};
  }
}
