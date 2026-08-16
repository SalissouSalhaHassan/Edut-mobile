import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../auth/role_redirect.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/family/presentation/family_dashboard_screen.dart';
import '../../features/family/presentation/family_finance_screen.dart';
import '../../features/family/presentation/family_library_screen.dart';
import '../../features/family/presentation/family_transport_screen.dart';
import '../../features/family/presentation/family_hostel_screen.dart';
import '../../features/students/presentation/students_management_screen.dart';
import '../../features/students/presentation/student_details_screen.dart';
import '../../features/students/presentation/student_form_screen.dart';
import '../../features/students/presentation/student_promotion_screen.dart';
import '../../features/attendance/presentation/qr_scan_screen.dart';
import '../../features/attendance/presentation/teacher_attendance_screen.dart';
import '../../features/attendance/presentation/student_attendance_screen.dart';
import '../../features/academics/presentation/saisie_notes_screen.dart';
import '../../features/academics/presentation/gestion_devoirs_screen.dart';
import '../../features/finance/presentation/finance_dashboard_screen.dart';
import '../../features/finance/presentation/student_fee_details_screen.dart';
import '../../features/finance/presentation/record_payment_screen.dart';
import '../../features/exams/presentation/exams_dashboard_screen.dart';
import '../../features/exams/presentation/exam_results_screen.dart';
import '../../features/exams/presentation/exam_form_screen.dart';
import '../../features/hostel/presentation/hostel_dashboard_screen.dart';
import '../../features/hr/presentation/hr_dashboard_screen.dart';
import '../../features/owner/presentation/owner_dashboard_screen.dart';
import '../../features/owner/presentation/owner_platform_admin_screen.dart';
import '../../features/owner/presentation/owner_audit_screen.dart';
import '../../features/owner/presentation/owner_subscription_screen.dart';
import '../../features/owner/presentation/owner_legacy_console_screen.dart';
import '../../features/owner/presentation/owner_register_school_screen.dart';
import '../../features/owner/presentation/owner_permissions_screen.dart';
import '../../features/messaging/presentation/messaging_screen.dart';
import '../../features/messaging/presentation/notifications_screen.dart';
import '../../features/ministry/presentation/ministry_dashboard_screen.dart';
import '../di/injection.dart';
import '../auth/session_manager.dart';
import '../../features/pedagogie/presentation/cahier_textes_screen.dart';
import '../../features/pedagogie/presentation/planification_screen.dart';
import '../../features/pedagogie/presentation/progression_screen.dart';
import '../permissions/permission_service.dart';
import 'guarded_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/ministry/dashboard',
        builder: (context, state) => const MinistryDashboardScreen(),
      ),
      GoRoute(
        path: '/owner/dashboard',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerPlatformView,
          child: OwnerDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/owner/platform-admin',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerPlatformView,
          child: OwnerPlatformAdminScreen(),
        ),
      ),
      GoRoute(
        path: '/owner/audit',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerPlatformView,
          child: OwnerAuditScreen(),
        ),
      ),
      GoRoute(
        path: '/owner/subscription',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerPlatformView,
          child: OwnerSubscriptionScreen(),
        ),
      ),
      GoRoute(
        path: '/owner/legacy-console',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerPlatformView,
          child: OwnerLegacyConsoleScreen(),
        ),
      ),
      GoRoute(
        path: '/owner/register-school',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerSchoolsManage,
          child: OwnerRegisterSchoolScreen(),
        ),
      ),
      GoRoute(
        path: '/owner/permissions',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.ownerPlatformView,
          child: OwnerPermissionsScreen(),
        ),
      ),
      GoRoute(
        path: '/family/dashboard',
        builder: (context, state) => const FamilyDashboardScreen(),
      ),
      GoRoute(
        path: '/family/finance',
        builder: (context, state) => const FamilyFinanceScreen(),
      ),
      GoRoute(
        path: '/family/transport',
        builder: (context, state) => const FamilyTransportScreen(),
      ),
      GoRoute(
        path: '/family/library',
        builder: (context, state) => const FamilyLibraryScreen(),
      ),
      GoRoute(
        path: '/family/hostel',
        builder: (context, state) => const FamilyHostelScreen(),
      ),
      GoRoute(
        path: '/students',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.studentsView,
          child: StudentsManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/students/details',
        builder: (context, state) {
          final studentId = state.extra as int;
          return GuardedScreen(
            permission: AppPermissions.studentsView,
            child: StudentDetailsScreen(studentId: studentId),
          );
        },
      ),
      GoRoute(
        path: '/students/form',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return GuardedScreen(
            permission: AppPermissions.studentsEdit,
            child: StudentFormScreen(initialData: extra),
          );
        },
      ),
      GoRoute(
        path: '/students/promotion',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.studentsPromote,
          child: StudentPromotionScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance/qr-scan',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.attendanceManage,
          child: QRScanScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance/teacher-reports',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.attendanceView,
          child: TeacherAttendanceScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance/student-roll',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final classId = extra['classId'] as int;
          final className = extra['className'] as String;
          final subjectId = extra['subjectId'] as int?;
          final subjectName = extra['subjectName'] as String?;
          final initialDateStr = extra['initialDateStr'] as String?;

          return GuardedScreen(
            permission: AppPermissions.attendanceView,
            child: StudentAttendanceScreen(
              classId: classId,
              className: className,
              subjectId: subjectId,
              subjectName: subjectName,
              initialDateStr: initialDateStr,
            ),
          );
        },
      ),
      GoRoute(
        path: '/academics/saisie-notes',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final classId = extra['classId'] as int;
          final className = extra['className'] as String;
          final subjectId = extra['subjectId'] as int;
          final subjectName = extra['subjectName'] as String;

          return GuardedScreen(
            permission: AppPermissions.saisieNotesView,
            child: SaisieNotesScreen(
              classId: classId,
              className: className,
              subjectId: subjectId,
              subjectName: subjectName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/academics/gestion-devoirs',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final classId = extra['classId'] as int;
          final className = extra['className'] as String;
          final subjectId = extra['subjectId'] as int;
          final subjectName = extra['subjectName'] as String;

          return GuardedScreen(
            permission: AppPermissions.gestionDevoirsView,
            child: GestionDevoirsScreen(
              classId: classId,
              className: className,
              subjectId: subjectId,
              subjectName: subjectName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/finance/dashboard',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.financeView,
          child: FinanceDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/exams',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.examsView,
          child: ExamsDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/exams/results',
        builder: (context, state) {
          final exam = state.extra as Map<String, dynamic>;
          return GuardedScreen(
            permission: AppPermissions.examsView,
            child: ExamResultsScreen(exam: exam),
          );
        },
      ),
      GoRoute(
        path: '/exams/form',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return GuardedScreen(
            permission: AppPermissions.examsManage,
            child: ExamFormScreen(initialData: extra),
          );
        },
      ),
      GoRoute(
        path: '/hostel',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.hostelView,
          child: HostelDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/hr',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.hrView,
          child: HrDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/finance/fee-details',
        builder: (context, state) {
          final fee = state.extra as Map<String, dynamic>;
          return GuardedScreen(
            permission: AppPermissions.financeView,
            child: StudentFeeDetailsScreen(feeData: fee),
          );
        },
      ),
      GoRoute(
        path: '/finance/record-payment',
        builder: (context, state) {
          final fee = state.extra as Map<String, dynamic>;
          return GuardedScreen(
            permission: AppPermissions.financeCollect,
            child: RecordPaymentScreen(feeData: fee),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/messaging',
        builder: (context, state) => const GuardedScreen(
          permission: AppPermissions.messagingView,
          child: MessagingScreen(),
        ),
      ),
      GoRoute(
        path: '/pedagogie/cahier-textes',
        builder: (context, state) => const CahierTextesScreen(),
      ),
      GoRoute(
        path: '/pedagogie/planification',
        builder: (context, state) => const PlanificationScreen(),
      ),
      GoRoute(
        path: '/pedagogie/progression',
        builder: (context, state) => const ProgressionScreen(),
      ),
    ],
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _sessionCheckTimer;

  @override
  void initState() {
    super.initState();
    _sessionCheckTimer = Timer(const Duration(seconds: 2), _checkSession);
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final sessionManager = locator<SessionManager>();
    final isLoggedIn = await sessionManager.isLoggedIn();
    if (!mounted) return;
    if (isLoggedIn) {
      final role = await sessionManager.getRole() ?? 'staff';
      if (!mounted) return;
      context.go(getHomeRouteForRole(role));
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Colors.indigo),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
