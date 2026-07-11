import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sync_status_banner.dart';
import '../../auth/data/auth_repository.dart';
import '../data/family_repository.dart';
import '../../messaging/data/messaging_repository.dart';

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final FamilyRepository _repository = locator<FamilyRepository>();

  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;
  int _unreadNotificationsCount = 0;

  String _role = 'student';
  int? _studentId;
  int? _schoolId;
  String _studentName = '';
  String _studentClass = '';

  List<Map<String, dynamic>> _sessions = [];
  int? _selectedSessionId;
  String _selectedSessionName = '';

  Map<String, dynamic> _student = {};
  List<Map<String, dynamic>> _timetable = [];
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _homework = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = locator<SessionManager>();
      _role = await session.getRole() ?? 'student';
      _studentId = int.tryParse(await session.getStudentId() ?? '');
      _schoolId = int.tryParse(await session.getSchoolId() ?? '');
      _studentName = await session.getStudentName() ?? '';
      _studentClass = await session.getStudentClass() ?? '';

      if (_studentId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Aucun profil élève lié à ce compte. Vérifiez le rattachement du compte.";
        });
        return;
      }

      _student = await _repository.getStudentSnapshot(studentId: _studentId!);
      _studentName = (_student['nom_etudiant'] as String?) ?? _studentName;
      _studentClass = (_student['classe'] as String?) ?? _studentClass;
      _schoolId ??= (_student['school_id'] as num?)?.toInt();

      if (_schoolId != null) {
        _sessions = await _repository.getSessions(_schoolId!);
        if (_sessions.isNotEmpty) {
          final active = _sessions.firstWhere(
            (s) => s['is_active'] == true,
            orElse: () => _sessions.first,
          );
          _selectedSessionId = active['id'] as int;
          _selectedSessionName = active['session_name'] as String? ?? '';
        }
      }

      int unreadNotificationsCount = 0;
      try {
        final notifs = await locator<MessagingRepository>().getNotifications();
        unreadNotificationsCount = (notifs['unreadCount'] as num?)?.toInt() ?? 0;
      } catch (e) {
        debugPrint('Failed to load notifications count in family: $e');
      }

      await Future.wait([
        _loadTimetable(),
        _loadGrades(),
        _loadAttendance(),
        _loadHomework(),
      ]);

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadNotificationsCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur de chargement: $e";
        });
      }
    }
  }

  Future<void> _loadTimetable() async {
    if (_schoolId == null || _studentClass.isEmpty) return;
    _timetable = await _repository.getTimetable(
      schoolId: _schoolId!,
      className: _studentClass,
      sessionId: _selectedSessionId,
    );
  }

  Future<void> _loadGrades() async {
    if (_studentId == null || _schoolId == null) return;
    _grades = await _repository.getGrades(
      studentId: _studentId!,
      schoolId: _schoolId!,
      sessionId: _selectedSessionId,
    );
  }

  Future<void> _loadAttendance() async {
    if (_studentId == null) return;
    _attendance = await _repository.getAttendance(studentId: _studentId!);
  }

  Future<void> _loadHomework() async {
    if (_studentClass.isEmpty) return;
    _homework = await _repository.getHomework(className: _studentClass);
  }

  Future<void> _changeSession(int? sessionId) async {
    if (sessionId == null) return;
    final match = _sessions.firstWhere((s) => s['id'] == sessionId);
    setState(() {
      _selectedSessionId = sessionId;
      _selectedSessionName = match['session_name'] as String? ?? '';
      _isLoading = true;
    });
    await Future.wait([
      _loadTimetable(),
      _loadGrades(),
      _loadAttendance(),
      _loadHomework(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await locator<AuthRepository>().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  List<Map<String, dynamic>> get _todayTimetable {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final now = DateTime.now();
    final todayName = days[now.weekday - 1];
    final items = _timetable
        .where((item) => item['day_name'] == todayName)
        .toList();
    items.sort(
      (a, b) => ((a['period_number'] as num?)?.toInt() ?? 0).compareTo(
        (b['period_number'] as num?)?.toInt() ?? 0,
      ),
    );
    return items;
  }

  Map<String, double> get _gradeSummary {
    if (_grades.isEmpty) {
      return {'average': 0, 'best': 0, 'risk': 0};
    }
    double total = 0;
    double best = 0;
    int risk = 0;
    for (final row in _grades) {
      final score = (row['total_score'] as num?)?.toDouble() ?? 0;
      total += score;
      if (score > best) best = score;
      if (score < 10) risk++;
    }
    return {
      'average': total / _grades.length,
      'best': best,
      'risk': risk.toDouble(),
    };
  }

  Map<String, int> get _attendanceSummary {
    int justified = 0;
    int unjustified = 0;
    int late = 0;
    for (final row in _attendance) {
      final status = (row['status'] as String? ?? '').toLowerCase();
      final remark = (row['remark'] as String? ?? '').toLowerCase();
      if (status.contains('retard')) {
        late++;
      } else if (status.contains('abs')) {
        if (remark.contains('just')) {
          justified++;
        } else {
          unjustified++;
        }
      }
    }
    return {'justified': justified, 'unjustified': unjustified, 'late': late};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        title: Text(
          _role == 'parent' ? 'Espace Parent' : 'Espace Élève',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  await context.push('/notifications');
                  _loadData();
                },
                tooltip: 'Notifications',
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (_sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSessionId,
                  borderRadius: BorderRadius.circular(16),
                  items: _sessions
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(
                            s['session_name'] as String? ?? 'Session',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _changeSession,
                ),
              ),
            ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  )
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildOverviewTab(),
                      _buildGradesTab(),
                      _buildAttendanceTab(),
                      _buildHomeworkTab(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Emploi'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph), label: 'Notes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check),
            label: 'Absences',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Devoirs',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final todayCourses = _todayTimetable;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('Programme du jour', Icons.today),
          const SizedBox(height: 12),
          if (todayCourses.isEmpty)
            _buildEmptyCard('Aucun cours planifié pour aujourd’hui.')
          else
            ...todayCourses.map(_buildTimetableCard),
          const SizedBox(height: 24),
          _buildSectionTitle('Aperçu rapide', Icons.insights),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Moyenne',
                  _gradeSummary['average']!.toStringAsFixed(1),
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  'Retards',
                  _attendanceSummary['late']!.toString(),
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Services scolaires', Icons.dashboard_customize),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _buildServiceCard(
                title: 'Finance',
                subtitle: 'Frais, paiements et recus PDF',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF0F766E),
                onTap: () => context.push('/family/finance'),
              ),
              _buildServiceCard(
                title: 'Transport',
                subtitle: 'Bus, GPS et ramassage',
                icon: Icons.directions_bus_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => context.push('/family/transport'),
              ),
              _buildServiceCard(
                title: 'Bibliotheque',
                subtitle: 'Livres, reservations et retours',
                icon: Icons.local_library_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => context.push('/family/library'),
              ),
              _buildServiceCard(
                title: 'Notifications',
                subtitle: 'Messages de l ecole',
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFFF43F5E),
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradesTab() {
    final avg = _gradeSummary['average'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('Résultats & bulletins', Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        _buildLineChartCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                'Moyenne générale',
                avg.toStringAsFixed(2),
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStat(
                'Meilleure note',
                (_gradeSummary['best'] ?? 0).toStringAsFixed(1),
                AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_grades.isEmpty)
          _buildEmptyCard(
            'Aucune note disponible pour la session sélectionnée.',
          )
        else
          ..._grades.map(_buildGradeCard),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle(
          'Suivi des absences et retards',
          Icons.stacked_bar_chart,
        ),
        const SizedBox(height: 12),
        _buildAttendanceChartCard(),
        const SizedBox(height: 16),
        if (_attendance.isEmpty)
          _buildEmptyCard('Aucun enregistrement de présence disponible.')
        else
          ..._attendance.take(20).map(_buildAttendanceCard),
      ],
    );
  }

  Widget _buildHomeworkTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('Homework Hub', Icons.menu_book_rounded),
        const SizedBox(height: 12),
        if (_homework.isEmpty)
          _buildEmptyCard('Aucun devoir publié pour cette classe.')
        else
          ..._homework.map(_buildHomeworkCard),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _role == 'parent'
                  ? 'Vue parent connectée'
                  : 'Vue élève connectée',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _studentName.isEmpty ? 'Élève' : _studentName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _studentClass.isEmpty ? 'Classe non définie' : _studentClass,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (_selectedSessionName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Session: $_selectedSessionName',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineChartCard() {
    final bars = <FlSpot>[];
    for (var i = 0; i < _grades.length; i++) {
      final score = (_grades[i]['total_score'] as num?)?.toDouble() ?? 0;
      bars.add(FlSpot(i.toDouble(), score));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution par matière', style: AppTextStyles.bodyBold),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _grades.isEmpty
                ? const Center(child: Text('Pas encore de notes'))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 20,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppColors.slate100, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 5,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= _grades.length) {
                                return const SizedBox.shrink();
                              }
                              final subject =
                                  _grades[index]['school_subjects']?['subject_code']
                                      as String? ??
                                  (_grades[index]['school_subjects']?['subject_name']
                                          as String? ??
                                      'M');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  subject.length > 4
                                      ? subject.substring(0, 4)
                                      : subject,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: bars,
                          isCurved: true,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                          ),
                          barWidth: 4,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2563EB).withValues(alpha: 0.2),
                                const Color(0xFF10B981).withValues(alpha: 0.02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChartCard() {
    final summary = _attendanceSummary;
    final sections = [
      PieChartSectionData(
        value: summary['justified']!.toDouble(),
        title: 'Abs. just.',
        color: AppColors.info,
        radius: 58,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: summary['unjustified']!.toDouble(),
        title: 'Abs. non just.',
        color: AppColors.danger,
        radius: 62,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: summary['late']!.toDouble(),
        title: 'Retards',
        color: AppColors.warning,
        radius: 54,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition des incidents', style: AppTextStyles.bodyBold),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: sections,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        'Absences justifiées',
                        summary['justified']!,
                        AppColors.info,
                      ),
                      const SizedBox(height: 10),
                      _buildLegendItem(
                        'Absences non justifiées',
                        summary['unjustified']!,
                        AppColors.danger,
                      ),
                      const SizedBox(height: 10),
                      _buildLegendItem(
                        'Retards',
                        summary['late']!,
                        AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label • $value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableCard(Map<String, dynamic> row) {
    final subject = row['school_subjects']?['subject_name'] ?? 'Matière';
    final teacher = row['employees']?['nom'] ?? 'Professeur';
    final period = (row['period_number'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'P$period',
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: AppTextStyles.bodyBold),
                const SizedBox(height: 4),
                Text(
                  'Salle: ${row['room_name'] ?? 'Non définie'} • $teacher',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> row) {
    final subject = row['school_subjects']?['subject_name'] ?? 'Matière';
    final devoir = (row['class_work_score'] as num?)?.toDouble() ?? 0;
    final exam = (row['exam_score'] as num?)?.toDouble() ?? 0;
    final total = (row['total_score'] as num?)?.toDouble() ?? 0;
    final appreciation = row['appreciation'] ?? '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subject, style: AppTextStyles.bodyBold)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: total >= 10
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  total.toStringAsFixed(1),
                  style: TextStyle(
                    color: total >= 10 ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock('Devoirs', devoir.toStringAsFixed(1)),
              ),
              Expanded(
                child: _buildMetricBlock('Examen', exam.toStringAsFixed(1)),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Appréciation',
                  appreciation.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? 'Présent';
    final date = row['date'] as String? ?? '';
    final remark = row['remark'] as String? ?? 'Aucune remarque';
    final subject = row['school_subjects']?['subject_name'] ?? 'Général';
    final color = status.toLowerCase().contains('retard')
        ? AppColors.warning
        : status.toLowerCase().contains('abs')
        ? AppColors.danger
        : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$status • $subject', style: AppTextStyles.bodyBold),
                const SizedBox(height: 4),
                Text(date, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(remark, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> row) {
    final dueDate = row['date_due'] as String? ?? '';
    final assignedDate = row['date_assigned'] as String? ?? '';
    final subject = row['school_subjects']?['subject_name'] ?? 'Matière';
    final isDelivered = (row['attachment_path'] as String?)?.isNotEmpty == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row['title'] as String? ?? 'Devoir',
                  style: AppTextStyles.bodyBold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDelivered
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isDelivered ? 'Pièce jointe' : 'À suivre',
                  style: TextStyle(
                    color: isDelivered ? AppColors.info : AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subject, style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Text(
            row['description'] as String? ?? 'Aucune description fournie.',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Publié',
                  assignedDate.isEmpty ? '-' : assignedDate.split('T').first,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Échéance',
                  dueDate.isEmpty ? '-' : dueDate.split('T').first,
                ),
              ),
              Expanded(child: _buildMetricBlock('Suivi', 'En attente')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.slate400),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.heading3),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Text(
        message,
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBF0F5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
