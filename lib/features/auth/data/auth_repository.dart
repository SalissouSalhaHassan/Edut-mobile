import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';

class LoginResult {
  final bool success;
  final String? message;

  const LoginResult._({required this.success, this.message});

  const LoginResult.success() : this._(success: true);

  const LoginResult.failure(String message)
    : this._(success: false, message: message);
}

class AuthRepository {
  final SupabaseClient _client;
  final SessionManager _sessionManager;
  final MobileApiClient _mobileApiClient;

  AuthRepository({
    SupabaseClient? client,
    SessionManager? sessionManager,
    MobileApiClient? mobileApiClient,
  }) : _client = client ?? SupabaseClientManager().client,
       _sessionManager = sessionManager ?? SessionManager(),
       _mobileApiClient = mobileApiClient ?? MobileApiClient();

  Future<Map<String, dynamic>?> _resolveStudentProfile({
    required String role,
    required String loginEmail,
    required String? schoolIdStr,
    Map<String, dynamic>? userData,
  }) async {
    final normalizedRole = role.toLowerCase().trim();
    if (normalizedRole != 'student' && normalizedRole != 'parent') {
      return null;
    }

    final username = loginEmail.split('@').first.toLowerCase();
    final schoolId = int.tryParse(schoolIdStr ?? '');

    Future<Map<String, dynamic>?> queryStudentByField(
      String field,
      dynamic value,
    ) async {
      try {
        var query = _client
            .from('students')
            .select(
              'id, school_id, nom_etudiant, classe, num_admission, nom_pere, mobile, whatsapp, educational_level',
            )
            .eq(field, value);
        if (schoolId != null) {
          query = query.eq('school_id', schoolId);
        }
        return await query.maybeSingle();
      } catch (_) {
        return null;
      }
    }

    if (normalizedRole == 'student') {
      final candidates = <Future<Map<String, dynamic>?>>[
        queryStudentByField('num_admission', username),
        queryStudentByField('num_admission', username.toUpperCase()),
        queryStudentByField('mobile', username),
        queryStudentByField('whatsapp', username),
      ];

      for (final candidate in candidates) {
        final data = await candidate;
        if (data != null) return data;
      }
    }

    if (normalizedRole == 'parent') {
      final phoneCandidates = [username, loginEmail, userData?['utilisateur']];
      for (final value in phoneCandidates) {
        if (value == null || value.toString().trim().isEmpty) continue;
        final mobileMatch = await queryStudentByField('mobile', value);
        if (mobileMatch != null) return mobileMatch;
        final whatsappMatch = await queryStudentByField('whatsapp', value);
        if (whatsappMatch != null) return whatsappMatch;
      }

      final parentName = (userData?['nom_prenom'] as String?)?.trim();
      if (parentName != null && parentName.isNotEmpty) {
        try {
          var query = _client
              .from('students')
              .select(
                'id, school_id, nom_etudiant, classe, num_admission, nom_pere, mobile, whatsapp, educational_level',
              )
              .ilike('nom_pere', parentName);
          if (schoolId != null) {
            query = query.eq('school_id', schoolId);
          }
          final rows = await query.limit(1);
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first);
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Normalize role name to canonical values: 'teacher', 'admin', 'super_admin', 'director', 'owner', 'student', 'parent', 'accountant', 'secretary', 'staff'
  String _normalizeRole(String? rawRole, bool isAdmin, bool isSuperAdmin) {
    if (isSuperAdmin) {
      return 'super_admin';
    }
    if (isAdmin) {
      return 'admin';
    }

    final r = (rawRole ?? '').toLowerCase().trim();
    if (r == 'owner' ||
        r == 'proprietaire' ||
        r == 'propriétaire' ||
        r == 'proprietor' ||
        r.contains('proprietaire') ||
        r.contains('propriétaire') ||
        r.contains('proprietor') ||
        r.contains('owner')) {
      return 'owner';
    }
    if (r == 'teacher' ||
        r == 'enseignant' ||
        r == 'professeur' ||
        r.contains('teacher') ||
        r.contains('enseignant') ||
        r.contains('professeur')) {
      return 'teacher';
    }
    if (r == 'director' ||
        r == 'general_director' ||
        r == 'school_director' ||
        r == 'level_director' ||
        r == 'directeur' ||
        r.contains('director') ||
        r.contains('directeur')) {
      return 'director';
    }
    if (r == 'admin' || r == 'super_admin' || r.contains('admin')) {
      return 'admin';
    }
    if (r == 'student' ||
        r == 'eleve' ||
        r == 'élève' ||
        r.contains('student') ||
        r.contains('eleve') ||
        r.contains('élève')) {
      return 'student';
    }
    if (r == 'parent' || r.contains('parent')) {
      return 'parent';
    }
    if (r == 'accountant' ||
        r == 'comptable' ||
        r.contains('comptable') ||
        r.contains('accountant')) {
      return 'accountant';
    }
    if (r == 'secretary' ||
        r == 'secretaire' ||
        r.contains('secrétaire') ||
        r.contains('secretaire') ||
        r.contains('secretary')) {
      return 'secretary';
    }
    if (r == 'personnel' || r.contains('personnel')) {
      return 'personnel';
    }

    if (r.isNotEmpty) {
      return r;
    }

    return 'staff';
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final loginEmail = normalizedEmail.contains('@')
        ? normalizedEmail
        : '$normalizedEmail@test.com';

    debugPrint("DEBUG LOGIN: Attempting login for $loginEmail");

    try {
      final response = await _client.auth.signInWithPassword(
        email: loginEmail,
        password: password,
      );

      if (response.session == null) {
        debugPrint("DEBUG LOGIN: Session was null");
        return const LoginResult.failure(
          'Session non créée. Veuillez réessayer.',
        );
      }

      debugPrint("DEBUG LOGIN: Auth success. User ID: ${response.user?.id}");

      try {
        final canonicalProfile = await _mobileApiClient.getCurrentProfile(
          accessToken: response.session!.accessToken,
        );

        await _sessionManager.saveSession(
          token: response.session!.accessToken,
          email: canonicalProfile.email.isNotEmpty
              ? canonicalProfile.email
              : loginEmail,
          role: canonicalProfile.role,
          employeeId: canonicalProfile.employeeId ?? '',
          userId: canonicalProfile.userId,
          schoolId: canonicalProfile.schoolId,
          studentId: canonicalProfile.studentId,
          studentName: canonicalProfile.studentName,
          studentClass: canonicalProfile.studentClass,
          permissions: canonicalProfile.permissions,
        );

        debugPrint(
          "DEBUG LOGIN: Session resolved through Edut web API -> Role: ${canonicalProfile.role}, SchoolId: ${canonicalProfile.schoolId}",
        );
        return const LoginResult.success();
      } catch (e, stack) {
        debugPrint(
          "DEBUG LOGIN: Edut web API profile unavailable, using legacy Supabase fallback: $e\n$stack",
        );
      }

      String role = 'staff';
      String? schoolIdStr;
      Map<String, dynamic>? userData;

      // 1. Fetch user profile with role join
      try {
        userData = await _fetchUserProfile(
          userId: response.session!.user.id,
          email: loginEmail,
          select:
              'id, utilisateur, nom_prenom, admin, super_admin, school_id, role_id, roles(role_name)',
        );

        debugPrint("DEBUG LOGIN: Profile data fetched: $userData");

        if (userData != null) {
          final isSuperAdmin = userData['super_admin'] == true;
          final isAdmin = userData['admin'] == true;
          final rawRoleName = userData['roles']?['role_name'] as String?;
          schoolIdStr = userData['school_id']?.toString();

          role = _normalizeRole(rawRoleName, isAdmin, isSuperAdmin);
          debugPrint("DEBUG LOGIN: Normalized role from profile: $role");

          // If role still unresolved and role_id exists, fetch separately
          if (role == 'staff' &&
              userData['role_id'] != null &&
              !isAdmin &&
              !isSuperAdmin) {
            try {
              final roleData = await _client
                  .from('roles')
                  .select('role_name')
                  .eq('id', userData['role_id'])
                  .maybeSingle();
              debugPrint("DEBUG LOGIN: Separate role fetch result: $roleData");
              if (roleData != null) {
                role = _normalizeRole(
                  roleData['role_name'] as String?,
                  false,
                  false,
                );
                debugPrint("DEBUG LOGIN: Normalized separate role: $role");
              }
            } catch (e) {
              debugPrint("DEBUG LOGIN: Separate role fetch failed: $e");
            }
          }
        }
      } catch (e, stack) {
        debugPrint(
          "DEBUG LOGIN: Error fetching user profile with join: $e\n$stack",
        );
        // Fallback: query without roles join
        try {
          userData = await _fetchUserProfile(
            userId: response.session!.user.id,
            email: loginEmail,
            select:
                'id, utilisateur, nom_prenom, admin, super_admin, school_id, role_id',
          );

          debugPrint("DEBUG LOGIN: Fallback profile data: $userData");

          if (userData != null) {
            final isSuperAdmin = userData['super_admin'] == true;
            final isAdmin = userData['admin'] == true;
            schoolIdStr = userData['school_id']?.toString();

            if (isSuperAdmin) {
              role = 'super_admin';
            } else if (isAdmin) {
              role = 'admin';
            } else {
              final roleId = userData['role_id'];
              if (roleId != null) {
                try {
                  final roleData = await _client
                      .from('roles')
                      .select('role_name')
                      .eq('id', roleId)
                      .maybeSingle();
                  debugPrint(
                    "DEBUG LOGIN: Fallback separate role data: $roleData",
                  );
                  if (roleData != null) {
                    role = _normalizeRole(
                      roleData['role_name'] as String?,
                      false,
                      false,
                    );
                  }
                } catch (_) {}
              }
            }
            debugPrint("DEBUG LOGIN: Role resolved in fallback: $role");
          }
        } catch (err, st) {
          debugPrint("DEBUG LOGIN: Fallback profile fetch failed: $err\n$st");
        }
      }

      // 2. Query employees table to get employee ID
      String employeeId = '';
      try {
        final employeeData = await _client
            .from('employees')
            .select('id, school_id')
            .eq('email', loginEmail)
            .maybeSingle();

        debugPrint("DEBUG LOGIN: Employee query result: $employeeData");

        if (employeeData != null) {
          employeeId = employeeData['id'].toString();
          // If school_id was not fetched from users, get from employees
          schoolIdStr ??= employeeData['school_id']?.toString();
          // If role is still generic 'staff' and we found in employees → teacher
          if (role == 'staff') {
            role = 'teacher';
            debugPrint(
              "DEBUG LOGIN: Role set to teacher since employee record exists",
            );
          }
        }
      } catch (e, stack) {
        debugPrint("DEBUG LOGIN: Employee fetch failed: $e\n$stack");
      }

      final studentProfile = await _resolveStudentProfile(
        role: role,
        loginEmail: loginEmail,
        schoolIdStr: schoolIdStr,
        userData: userData,
      );

      if ((role == 'student' || role == 'parent') && studentProfile == null) {
        debugPrint(
          "WARNING: $role account logged in but no linked student record was found.",
        );
      }

      if (studentProfile != null && schoolIdStr == null) {
        schoolIdStr = studentProfile['school_id']?.toString();
      }

      if (role == 'staff') {
        debugPrint(
          "WARNING: User logged in but no specific role was found (defaults to 'staff').",
        );
        debugPrint("Full Auth Response - User ID: ${response.user?.id}");
        debugPrint("Full Auth Response - User Email: ${response.user?.email}");
        debugPrint(
          "Full Auth Response - User Metadata: ${response.user?.userMetadata}",
        );
      }

      debugPrint(
        "DEBUG LOGIN: Final resolved values for SessionManager -> Email: $loginEmail, Role: $role, EmployeeId: $employeeId, SchoolId: $schoolIdStr",
      );

      await _sessionManager.saveSession(
        token: response.session!.accessToken,
        email: loginEmail,
        role: role,
        employeeId: employeeId,
        userId: userData?['id']?.toString(),
        schoolId: schoolIdStr,
        studentId: studentProfile?['id']?.toString(),
        studentName: studentProfile?['nom_etudiant'] as String?,
        studentClass: studentProfile?['classe'] as String?,
      );

      return const LoginResult.success();
    } on AuthException catch (e) {
      debugPrint("DEBUG LOGIN: AuthException during login: $e");
      final message = e.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return const LoginResult.failure('Email ou mot de passe incorrect.');
      }
      if (message.contains('email not confirmed')) {
        return const LoginResult.failure(
          'Veuillez confirmer cet email avant de vous connecter.',
        );
      }
      return LoginResult.failure('Erreur d\'authentification: ${e.message}');
    } catch (e, stack) {
      debugPrint("DEBUG LOGIN: Unexpected error during login: $e\n$stack");
      return const LoginResult.failure(
        'Problème de connexion. Vérifiez internet puis réessayez.',
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProfile({
    required String userId,
    required String email,
    required String select,
  }) async {
    final username = email.split('@').first;

    final bySupabaseId = await _client
        .from('users')
        .select(select)
        .eq('supabase_id', userId)
        .maybeSingle();
    if (bySupabaseId != null) return bySupabaseId;

    final byEmail = await _client
        .from('users')
        .select(select)
        .eq('utilisateur', email)
        .maybeSingle();
    if (byEmail != null) return byEmail;

    return _client
        .from('users')
        .select(select)
        .eq('utilisateur', username)
        .maybeSingle();
  }

  Future<LoginResult> register({
    required String role,
    required String schoolSlug,
    required String matriculeOrEmail,
    required String username,
    required String fullName,
    required String password,
    required String activationPin,
  }) async {
    try {
      await _mobileApiClient.register(
        role: role,
        schoolSlug: schoolSlug,
        matriculeOrEmail: matriculeOrEmail,
        username: username,
        fullName: fullName,
        password: password,
        activationPin: activationPin,
      );
      return const LoginResult.success();
    } on MobileApiException catch (e) {
      return LoginResult.failure(e.message);
    } catch (e) {
      return LoginResult.failure(e.toString());
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    await _sessionManager.clearSession();
  }
}
