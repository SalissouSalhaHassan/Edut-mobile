import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/auth/role_redirect.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sync_status_banner.dart';
import '../../auth/data/auth_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../../core/api/supabase_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userEmail = '';
  String _userRole = 'staff';
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isDarkMode = false;
  bool _hasFinanceAccess = false;
  bool _hasOwnerAccess = false;
  bool _hasStudentsAccess = false;
  bool _hasStudentPromotionAccess = false;
  bool _hasHostelAccess = false;
  bool _hasHrAccess = false;

  /// Returns true if the current user is a teacher
  bool get _isTeacher {
    final r = _userRole.toLowerCase().trim();
    return r == 'teacher' ||
        r == 'enseignant' ||
        r == 'professeur' ||
        r.contains('teacher') ||
        r.contains('enseignant') ||
        r.contains('professeur');
  }

  /// Returns true if the user can manage finances (admin, director, accountant, secretary, super_admin, finance)
  // ignore: unused_element
  bool get _canManageFinance {
    final r = _userRole.toLowerCase().trim();
    return r == 'admin' ||
        r == 'owner' ||
        r == 'super_admin' ||
        r == 'director' ||
        r == 'accountant' ||
        r == 'comptable' ||
        r == 'secretary' ||
        r == 'secretaire' ||
        r == 'secrétaire' ||
        r == 'finance' ||
        r.contains('admin') ||
        r.contains('director') ||
        r.contains('comptable') ||
        r.contains('accountant') ||
        r.contains('finance');
  }

  // ignore: unused_element
  bool get _canAccessOwnerSpace {
    final r = _userRole.toLowerCase().trim();
    return r == 'owner' ||
        r == 'super_admin' ||
        r == 'admin' ||
        r.contains('owner') ||
        r.contains('admin');
  }

  /// Returns a human-readable label for the role
  String _getRoleLabel(String role) {
    final r = role.toLowerCase().trim();
    if (r.isEmpty || r == 'staff') {
      return 'Rôle non défini';
    }
    if (r == 'super_admin') {
      return 'Super Admin';
    }
    if (r == 'admin') {
      return 'Administrateur';
    }
    if (r == 'owner' ||
        r == 'proprietaire' ||
        r == 'propriétaire' ||
        r.contains('owner') ||
        r.contains('proprietaire') ||
        r.contains('propriétaire')) {
      return 'Proprietaire';
    }
    if (r == 'director' ||
        r == 'general_director' ||
        r == 'school_director' ||
        r == 'level_director' ||
        r == 'directeur' ||
        r.contains('director') ||
        r.contains('directeur')) {
      return 'Directeur';
    }
    if (r == 'teacher' ||
        r == 'enseignant' ||
        r == 'professeur' ||
        r.contains('teacher') ||
        r.contains('enseignant') ||
        r.contains('professeur')) {
      return 'Professeur';
    }
    if (r == 'student' || r == 'eleve' || r == 'élève' || r.contains('student') || r.contains('eleve') || r.contains('élève')) {
      return 'Élève';
    }
    if (r == 'parent' || r.contains('parent')) {
      return 'Parent';
    }
    if (r == 'accountant' || r == 'comptable' || r == 'finance' || r.contains('comptable') || r.contains('accountant') || r.contains('finance')) {
      return 'Comptable';
    }
    if (r == 'secretary' || r == 'secretaire' || r == 'secrétaire' || r.contains('secretaire') || r.contains('secretary')) {
      return 'Secrétaire';
    }
    if (r == 'personnel' || r.contains('personnel')) {
      return 'Personnel';
    }
    if (role.length > 1) {
      return role[0].toUpperCase() + role.substring(1);
    }
    return role.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final session = locator<SessionManager>();
    final permissionService = locator<PermissionService>();
    final email = await session.getEmail();
    final role = await session.getRole();
    final profile = await permissionService.getCurrentProfile();

    if (mounted) {
      if (email == null || email.isEmpty) {
        context.go('/login');
        return;
      }
      final normalizedRole = (role ?? 'staff').toLowerCase().trim();
      if (normalizedRole == 'student' ||
          normalizedRole == 'parent' ||
          normalizedRole == 'owner') {
        context.go(getHomeRouteForRole(normalizedRole));
        return;
      }
      setState(() {
        _userEmail = email;
        _userRole = profile.role;
        final permissions = profile.permissions;
        _hasFinanceAccess = permissions.contains(AppPermissions.financeView);
        _hasOwnerAccess = permissions.contains(AppPermissions.ownerPlatformView);
        _hasStudentsAccess = permissions.contains(AppPermissions.studentsView);
        _hasStudentPromotionAccess =
            permissions.contains(AppPermissions.studentsPromote);
        _hasHostelAccess = permissions.contains(AppPermissions.hostelView);
        _hasHrAccess = permissions.contains(AppPermissions.hrView);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await locator<AuthRepository>().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _handleStudentRollAction() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final session = locator<SessionManager>();
    final employeeIdStr = await session.getEmployeeId();
    final employeeId = int.tryParse(employeeIdStr ?? '');
    final role = await session.getRole() ?? 'staff';

    final roleStr = role.toLowerCase().trim();
    final isTeacher = roleStr == 'teacher' || roleStr == 'enseignant' || roleStr == 'professeur' ||
        roleStr.contains('teacher') || roleStr.contains('enseignant') || roleStr.contains('professeur');

    List<Map<String, dynamic>> classes = [];
    final client = SupabaseClientManager().client;

    try {
      if (isTeacher) {
        if (employeeId != null) {
          classes = await locator<AttendanceRepository>().getTeacherClassesAndSubjects(employeeId);
        }
      } else {
        final List<dynamic> allClassList = await client
            .from('school_classes')
            .select('id, class_name');
        
        classes = allClassList.map((c) => {
          'class_id': c['id'],
          'subject_id': null,
          'school_classes': {'class_name': c['class_name']},
          'school_subjects': null,
        }).toList();
      }
    } catch (e) {
      debugPrint("Error loading classes for roll: $e");
    }

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (classes.isEmpty) {
        final errorMsg = isTeacher
            ? 'Aucune classe ou matière n’est assignée à ce compte enseignant.'
            : 'Aucune classe disponible';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "Sélectionner une classe",
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final item = classes[index];
                        final classId = item['class_id'] as int;
                        final className = item['school_classes']?['class_name'] ?? 'Classe';
                        final subjectId = item['subject_id'] as int?;
                        final subjectName = item['school_subjects']?['subject_name'] as String?;

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.class_, color: AppColors.primary, size: 20),
                          ),
                          title: Text(className, style: AppTextStyles.bodyBold),
                          subtitle: subjectName != null ? Text(subjectName) : const Text("Appel Général Journée"),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(
                              '/attendance/student-roll',
                              extra: {
                                'classId': classId,
                                'className': className,
                                'subjectId': subjectId,
                                'subjectName': subjectName,
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _handleAcademicsAction({required bool isDevoirs}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final session = locator<SessionManager>();
    final employeeIdStr = await session.getEmployeeId();
    final employeeId = int.tryParse(employeeIdStr ?? '');
    final role = await session.getRole() ?? 'staff';

    final roleStr2 = role.toLowerCase().trim();
    final isTeacher = roleStr2 == 'teacher' || roleStr2 == 'enseignant' || roleStr2 == 'professeur' ||
        roleStr2.contains('teacher') || roleStr2.contains('enseignant') || roleStr2.contains('professeur');
    
    List<Map<String, dynamic>> classes = [];
    final client = SupabaseClientManager().client;

    try {
      if (isTeacher) {
        if (employeeId != null) {
          classes = await locator<AttendanceRepository>().getTeacherClassesAndSubjects(employeeId);
        }
      } else {
        final List<dynamic> allClassSubjects = await client
            .from('class_subjects')
            .select('class_id, subject_id, school_classes(class_name), school_subjects(subject_name)');
        
        classes = List<Map<String, dynamic>>.from(allClassSubjects);
      }
    } catch (e) {
      debugPrint("Error loading classes for academics: $e");
    }

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      final validClasses = classes.where((c) => c['subject_id'] != null).toList();

      if (validClasses.isEmpty) {
        final errorMsg = isTeacher
            ? 'Aucune classe ou matière n’est assignée à ce compte enseignant.'
            : 'Aucune classe/matière disponible';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "Sélectionner Classe & Matière",
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: validClasses.length,
                      itemBuilder: (context, index) {
                        final item = validClasses[index];
                        final classId = item['class_id'] as int;
                        final className = item['school_classes']?['class_name'] ?? 'Classe';
                        final subjectId = item['subject_id'] as int;
                        final subjectName = item['school_subjects']?['subject_name'] as String? ?? 'Matière';

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.class_, color: AppColors.primary, size: 20),
                          ),
                          title: Text(className, style: AppTextStyles.bodyBold),
                          subtitle: Text(subjectName),
                          onTap: () {
                            Navigator.pop(context);
                            final path = isDevoirs ? '/academics/gestion-devoirs' : '/academics/saisie-notes';
                            context.push(
                              path,
                              extra: {
                                'classId': classId,
                                'className': className,
                                'subjectId': subjectId,
                                'subjectName': subjectName,
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  // Drawers list
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            accountName: Text(
              _userEmail.split('@')[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(_userEmail),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Color(0xFF6D28D9)),
                  title: const Text('Tableau de bord'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                ),
                if (_hasOwnerAccess)
                  ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Color(0xFF7C3AED)),
                    title: const Text('PROPRIÉTAIRE'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/owner/dashboard');
                    },
                  ),
                if (_hasOwnerAccess)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF4F46E5)),
                    title: const Text('Permissions'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/owner/permissions');
                    },
                  ),
                if (_hasStudentsAccess)
                  ListTile(
                    leading: const Icon(Icons.school, color: Color(0xFF4F46E5)),
                    title: const Text('Gestion des etudiants'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/students');
                    },
                  ),
                if (_hasStudentPromotionAccess)
                  ListTile(
                    leading: const Icon(Icons.arrow_upward, color: Color(0xFF059669)),
                    title: const Text('Promotion des etudiants'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/students/promotion');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.assignment_turned_in, color: Color(0xFFF59E0B)),
                  title: const Text("Faire l'appel"),
                  onTap: () {
                    Navigator.pop(context);
                    _handleStudentRollAction();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF4F46E5)),
                  title: const Text('Scanner QR Code'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/attendance/qr-scan');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.grade, color: Color(0xFF9333EA)),
                  title: const Text('Saisie des Notes'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleAcademicsAction(isDevoirs: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.fact_check, color: Color(0xFF4338CA)),
                  title: const Text('Examens & Resultats'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/exams');
                  },
                ),
                if (_hasHostelAccess)
                  ListTile(
                    leading: const Icon(Icons.home_work_outlined, color: Color(0xFF0D9488)),
                    title: const Text('Internat & Dortoirs'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/hostel');
                    },
                  ),
                if (_hasHrAccess)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: Color(0xFF7C3AED)),
                    title: const Text('Ressources Humaines'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/hr');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.assignment, color: Color(0xFF2563EB)),
                  title: const Text('Devoirs & DS'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleAcademicsAction(isDevoirs: true);
                  },
                ),
                if (_hasFinanceAccess)
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)),
                    title: const Text('Gestion Financière'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/finance/dashboard');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.insert_chart, color: Color(0xFF0D9488)),
                  title: const Text('Rapports HR'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/attendance/teacher-reports');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Déconnexion'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Edut Mobile v1.0.0',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  // Welcome card inside dashboard
  Widget _buildWelcomeCard() {
    final isTeacher = _isTeacher;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bienvenue,',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail.split('@')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Text(
                    _getRoleLabel(_userRole),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: isTeacher
                ? [
                    _buildStatItem(Icons.check_circle_outline, '94%', 'Présences'),
                    _buildStatItem(Icons.timer_outlined, '36h', 'Planifiées'),
                    _buildStatItem(Icons.class_, '8', 'Classes Actives'),
                    _buildStatItem(Icons.assignment, '5', 'Examens'),
                  ]
                : [
                    _buildStatItem(Icons.people_outline, '342', 'Élèves Actifs'),
                    _buildStatItem(Icons.analytics_outlined, '91%', 'Présence Ens.'),
                    _buildStatItem(Icons.class_, '28', 'Classes Actives'),
                    _buildStatItem(Icons.assignment, '15', 'Examens'),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6D28D9), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF0F0E26),
          selectedItemColor: const Color(0xFF8B5CF6),
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Analyses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }

  // Accueil tab view
  Widget _buildAccueilView() {
    final isTeacher = _isTeacher;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 28),

          _buildSectionTitle('Actions rapides', Icons.grid_view_rounded),
          const SizedBox(height: 16),

          _buildQuickActionsGrid(isTeacher),
          const SizedBox(height: 28),

          _buildSectionTitle('Aperçu global', Icons.analytics_outlined),
          const SizedBox(height: 16),

          isTeacher ? _buildTeacherOverview() : _buildAdminOverview(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isTeacher) {
    final List<Widget> quickActions = [
      if (_hasStudentsAccess)
        _buildQuickActionCard(
          title: 'Etudiants',
          description: 'Liste et suivi des profils',
          icon: Icons.school_outlined,
          color: const Color(0xFF4338CA),
          onTap: () => context.push('/students'),
        ),
      if (_hasStudentPromotionAccess)
        _buildQuickActionCard(
          title: 'Promotion',
          description: 'Passage classe suivante',
          icon: Icons.arrow_upward_outlined,
          color: const Color(0xFF059669),
          onTap: () => context.push('/students/promotion'),
        ),
      _buildQuickActionCard(
        title: 'Scanner QR Code',
        description: 'Présence Classe',
        icon: Icons.qr_code_scanner,
        color: const Color(0xFF4F46E5),
        onTap: () => context.push('/attendance/qr-scan'),
      ),
      _buildQuickActionCard(
        title: isTeacher ? 'Mon Calendrier' : 'Rapports HR',
        description: isTeacher ? 'Emploi du temps' : 'Présences Enseignants',
        icon: isTeacher ? Icons.calendar_today : Icons.insert_chart_outlined,
        color: const Color(0xFF0D9488),
        onTap: () => context.push('/attendance/teacher-reports'),
      ),
      _buildQuickActionCard(
        title: "Faire l'appel",
        description: "Présence des élèves",
        icon: Icons.assignment_turned_in_outlined,
        color: const Color(0xFFF59E0B),
        onTap: _handleStudentRollAction,
      ),
      _buildQuickActionCard(
        title: "Saisie des Notes",
        description: "Moy. Classe & Examens",
        icon: Icons.grade_outlined,
        color: const Color(0xFF9333EA),
        onTap: () => _handleAcademicsAction(isDevoirs: false),
      ),
      _buildQuickActionCard(
        title: "Examens",
        description: "Epreuves & resultats",
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF4338CA),
        onTap: () => context.push('/exams'),
      ),
      if (_hasHostelAccess)
        _buildQuickActionCard(
          title: "Internat",
          description: "Chambres & residents",
          icon: Icons.home_work_outlined,
          color: const Color(0xFF0D9488),
          onTap: () => context.push('/hostel'),
        ),
      if (_hasHrAccess)
        _buildQuickActionCard(
          title: "RH",
          description: "Employes, paie, rapports",
          icon: Icons.badge_outlined,
          color: const Color(0xFF7C3AED),
          onTap: () => context.push('/hr'),
        ),
      _buildQuickActionCard(
        title: "Devoirs & DS",
        description: "Devoirs & Distributions",
        icon: Icons.assignment_outlined,
        color: const Color(0xFF2563EB),
        onTap: () => _handleAcademicsAction(isDevoirs: true),
      ),
    ];

    if (_hasFinanceAccess) {
      quickActions.add(
        _buildQuickActionCard(
          title: 'Finances',
          description: 'Frais & Recouvrements',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF10B981),
          onTap: () => context.push('/finance/dashboard'),
        ),
      );
    }

    if (_hasOwnerAccess) {
      quickActions.insert(
        0,
        _buildQuickActionCard(
          title: 'PROPRIÉTAIRE',
          description: 'Pilotage central',
          icon: Icons.workspace_premium_outlined,
          color: const Color(0xFF6D28D9),
          onTap: () => context.push('/owner/dashboard'),
        ),
      );
      quickActions.insert(
        1,
        _buildQuickActionCard(
          title: 'Permissions',
          description: 'Roles et acces',
          icon: Icons.admin_panel_settings_outlined,
          color: const Color(0xFF4F46E5),
          onTap: () => context.push('/owner/permissions'),
        ),
      );
    }

    quickActions.add(
      _buildQuickActionCard(
        title: 'Messages',
        description: 'Communications internes',
        icon: Icons.chat_bubble_outline,
        color: const Color(0xFFF43F5E),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Module de messagerie disponible bientôt')),
          );
        },
      ),
    );

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.25,
      children: quickActions,
    );
  }

  Widget _buildTeacherOverview() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMiniOverviewCard(Icons.check_circle_outline, '94%', 'Présence', const Color(0xFF10B981)),
        _buildMiniOverviewCard(Icons.timer_outlined, '36h', 'Planifiées', const Color(0xFF3B82F6)),
        _buildMiniOverviewCard(Icons.class_, '8', 'Classes', const Color(0xFF8B5CF6)),
        _buildMiniOverviewCard(Icons.assignment, '5', 'Examens', const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildAdminOverview() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMiniOverviewCard(Icons.people_outline, '342', 'Élèves Actifs', const Color(0xFF4F46E5)),
        _buildMiniOverviewCard(Icons.analytics_outlined, '91%', 'Présence Ens.', const Color(0xFFF59E0B)),
        _buildMiniOverviewCard(Icons.class_, '28', 'Classes Actives', const Color(0xFF10B981)),
        _buildMiniOverviewCard(Icons.assignment, '15', 'Examens En cours', const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildMiniOverviewCard(IconData icon, String value, String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  // Analyses tab view
  Widget _buildAnalysesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Analyses de l'établissement",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            "Rapports de performance globale",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildAnalyticCard("Taux de présence global", "95.4%", 0.954, Colors.green),
          _buildAnalyticCard("Moyenne des évaluations", "14.2 / 20", 0.71, Colors.blue),
          _buildAnalyticCard("Devoirs rendus à temps", "88%", 0.88, Colors.amber),
          _buildAnalyticCard("Utilisation de l'application mobile", "92%", 0.92, Colors.purple),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate100),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Activités Extrascolaires", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Clubs actifs"),
                    Text("12", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Événements planifiés"),
                    Text("4 ce mois-ci", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalyticCard(String title, String value, double percent, Color progressColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: progressColor)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          )
        ],
      ),
    );
  }

  // Paramètres tab view
  Widget _buildParametresView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Mon Profil & Parametres",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF8B5CF6),
                  child: Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userEmail.split('@')[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Role: ${_userRole.toUpperCase()}",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Preferences",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Mode Sombre"),
                  secondary: const Icon(
                    Icons.dark_mode,
                    color: Color(0xFF6D28D9),
                  ),
                  value: _isDarkMode,
                  onChanged: (val) {
                    setState(() {
                      _isDarkMode = val;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.language,
                    color: Color(0xFF6D28D9),
                  ),
                  title: const Text("Langue"),
                  trailing: const Text(
                    "Francais",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Color(0xFF6D28D9),
                  ),
                  title: const Text("Notifications push"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              "Se deconnecter",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              "Edut Mobile - Version 1.0.0",
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'EDUT MOBILE',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: SafeArea(
              top: false,
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildAccueilView(),
                  _buildAnalysesView(),
                  _buildParametresView(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}
