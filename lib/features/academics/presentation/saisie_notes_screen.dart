import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/supabase_client.dart';
import '../data/academics_repository.dart';
import '../utils/calculations.dart';

class SaisieNotesScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;

  const SaisieNotesScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SaisieNotesScreen> createState() => _SaisieNotesScreenState();
}

class _SaisieNotesScreenState extends State<SaisieNotesScreen> {
  final AcademicsRepository _repository = locator<AcademicsRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageAcademics = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _periods = [];
  List<Map<String, dynamic>> _gradingScale = [];

  int? _selectedSessionId;
  String _selectedSessionName = '';
  String _selectedPeriodName = '';
  bool _isHigherEd = false;
  bool _isEditable = true;
  String? _lockReason;
  double _coefficient = 1.0;
  int _schoolId = 1; // stored to reuse in period/session changes

  final TextEditingController _searchController = TextEditingController();

  // Maps to store inputs in state
  final Map<int, TextEditingController> _classWorkControllers = {};
  final Map<int, TextEditingController> _examControllers = {};
  final Map<int, String> _observations = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _classWorkControllers.values) {
      controller.dispose();
    }
    for (var controller in _examControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final profile = await locator<PermissionService>().getCurrentProfile(forceRefresh: true);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canManageAcademics = profile.permissions.contains(AppPermissions.saisieNotesEdit);
    });

    try {
      final sessionManager = locator<SessionManager>();
      
      // Retrieve schoolId directly from SessionManager
      final schoolIdStr = await sessionManager.getSchoolId();
      int schoolId = int.tryParse(schoolIdStr ?? '') ?? 1;
      _schoolId = schoolId;
      debugPrint("✅ schoolId from session: $schoolId");

      // Fallback: If not found or defaults to 1, try querying database
      if (schoolId == 1) {
        final employeeIdStr = await sessionManager.getEmployeeId();
        final employeeId = int.tryParse(employeeIdStr ?? '');
        if (employeeId != null) {
          try {
            final client = SupabaseClientManager().client;
            final List<dynamic> empInfo = await client
                .from('employees')
                .select('school_id')
                .eq('id', employeeId);
            if (empInfo.isNotEmpty && empInfo.first['school_id'] != null) {
              schoolId = empInfo.first['school_id'] as int;
              _schoolId = schoolId; // store in state
              debugPrint("✅ schoolId from employee DB: $schoolId");
            }
          } catch (e) {
            debugPrint("⚠️ Failed to lookup schoolId in Supabase DB: $e");
          }
        }
      }

      // Fetch sessions and grading scales
      _sessions = await _repository.getSessions(schoolId);
      _gradingScale = await _repository.getGradingScale();
      
      debugPrint("📋 Sessions found: ${_sessions.length}");

      if (_sessions.isNotEmpty) {
        // Find active session or default to most recent (highest id)
        final activeSession = _sessions.firstWhere(
          (s) => s['is_active'] == true,
          orElse: () => _sessions.first, // already sorted by id DESC
        );
        _selectedSessionId = activeSession['id'] as int;
        _selectedSessionName = activeSession['session_name'] as String;
        debugPrint("✅ Active session: [$_selectedSessionId] $_selectedSessionName");

        // Fetch periods for this session
        _periods = await _repository.getPeriods(schoolId, _selectedSessionId!, classId: widget.classId);
        debugPrint("📋 Periods found: ${_periods.length}");
        
        if (_periods.isNotEmpty) {
          final activePeriod = _periods.firstWhere(
            (p) => p['is_active'] == true,
            orElse: () => _periods.first,
          );
          // Safe extraction of period name
          _selectedPeriodName = (activePeriod['name'] as String?)?.trim() ?? 
                                 activePeriod['period_type'] as String? ?? 
                                 '1er Trimestre';
          debugPrint("✅ Active period: $_selectedPeriodName");
        }
      }

      if (_selectedSessionId != null && _selectedPeriodName.isNotEmpty) {
        await _fetchGridData(schoolId);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Aucune session ou période académique trouvée. (sessions: ${_sessions.length})";
        });
      }
    } catch (e) {
      debugPrint("❌ _loadInitialData error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur d'initialisation: $e";
      });
    }
  }

  Future<void> _fetchGridData(int schoolId) async {
    if (_selectedSessionId == null || _selectedPeriodName.isEmpty) return;

    try {
      final result = await _repository.getGradingGrid(
        classId: widget.classId,
        subjectId: widget.subjectId,
        sessionId: _selectedSessionId!,
        term: _selectedPeriodName,
        schoolId: schoolId,
      );

      if (result['success'] == true) {
        final List rawData = result['data'] is List ? (result['data'] as List) : [];
        _students = rawData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _filteredStudents = _students;
        _isEditable = result['is_editable'] as bool? ?? true;
        _lockReason = result['lock_reason'] as String?;
        _isHigherEd = ["Licence", "Master", "Doctorat", "Supérieur", "Université"]
            .contains(result['level']);
        _coefficient = (result['coefficient'] as num?)?.toDouble() ?? 1.0;

        // Initialize controllers
        _classWorkControllers.clear();
        _examControllers.clear();
        _observations.clear();

        for (var student in _students) {
          final sId = student['student_id'] as int;
          
          final classWorkVal = student['class_work_score'] != null
              ? (student['class_work_score'] as num).toStringAsFixed(2).replaceAll('.00', '')
              : '';
          final examVal = student['exam_score'] != null
              ? (student['exam_score'] as num).toStringAsFixed(2).replaceAll('.00', '')
              : '';

          _classWorkControllers[sId] = TextEditingController(text: classWorkVal);
          _examControllers[sId] = TextEditingController(text: examVal);
          _observations[sId] = student['observation'] as String? ?? '';
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['error'] ?? "Une erreur est survenue.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur lors du chargement de la grille: $e";
      });
    }
  }

  void _filterStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _students;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = (s['nom_etudiant'] as String? ?? '').toLowerCase();
        final code = (s['num_admission'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || code.contains(lowerQuery);
      }).toList();
    });
  }

  // Get live stats
  Map<String, dynamic> _getCalculatedStats() {
    if (_students.isEmpty) return {'avg': 0.0, 'passed': 0, 'failed': 0};

    double totalSum = 0.0;
    int count = 0;
    int passed = 0;

    for (var s in _students) {
      final sId = s['student_id'] as int;
      final cw = double.tryParse(_classWorkControllers[sId]?.text ?? '') ?? 0.0;
      final ex = double.tryParse(_examControllers[sId]?.text ?? '') ?? 0.0;

      final metrics = StudentMetrics.calculate(
        classWork: cw,
        examNote: ex,
        coefficient: _coefficient,
        isHigherEd: _isHigherEd,
      );

      totalSum += metrics.average;
      count++;
      if (metrics.average >= 10) {
        passed++;
      }
    }

    final avg = count > 0 ? totalSum / count : 0.0;
    final failed = count - passed;

    return {
      'avg': avg,
      'passed': passed,
      'failed': failed,
    };
  }

  // Live calculation for a single student row
  Map<String, dynamic> _getRowMetrics(int studentId) {
    final cw = double.tryParse(_classWorkControllers[studentId]?.text ?? '') ?? 0.0;
    final ex = double.tryParse(_examControllers[studentId]?.text ?? '') ?? 0.0;

    final metrics = StudentMetrics.calculate(
      classWork: cw,
      examNote: ex,
      coefficient: _coefficient,
      isHigherEd: _isHigherEd,
    );

    final appreciation = getAppreciation(metrics.average, _gradingScale);

    return {
      'total': metrics.total,
      'average': metrics.average,
      'weighted': metrics.weighted,
      'appreciation': appreciation,
    };
  }

  // Calculate live ranks
  Map<int, int> _getLiveRanks() {
    final List<Map<String, dynamic>> list = [];
    for (var s in _students) {
      final sId = s['student_id'] as int;
      final cw = double.tryParse(_classWorkControllers[sId]?.text ?? '') ?? 0.0;
      final ex = double.tryParse(_examControllers[sId]?.text ?? '') ?? 0.0;

      final metrics = StudentMetrics.calculate(
        classWork: cw,
        examNote: ex,
        coefficient: _coefficient,
        isHigherEd: _isHigherEd,
      );

      list.add({
        'student_id': sId,
        'weighted_score': metrics.weighted,
      });
    }

    return calculateRanks(list);
  }

  Future<void> _saveGrades() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final ranksMap = _getLiveRanks();
      final List<Map<String, dynamic>> gradesToSave = [];

      for (var s in _students) {
        final sId = s['student_id'] as int;
        final classWorkStr = _classWorkControllers[sId]?.text ?? '';
        final examStr = _examControllers[sId]?.text ?? '';

        final cw = double.tryParse(classWorkStr);
        final ex = double.tryParse(examStr);

        // Calculate metrics
        final metrics = StudentMetrics.calculate(
          classWork: cw ?? 0.0,
          examNote: ex ?? 0.0,
          coefficient: _coefficient,
          isHigherEd: _isHigherEd,
        );

        final app = getAppreciation(metrics.average, _gradingScale);
        final rk = formatRank(ranksMap[sId] ?? 0);

        gradesToSave.add({
          'student_id': sId,
          'class_id': widget.classId,
          'subject_id': widget.subjectId,
          'session_id': _selectedSessionId!,
          'term': _selectedPeriodName,
          'class_work_score': cw,
          'exam_score': ex,
          'total_score': metrics.total,
          'coefficient': _coefficient.toInt(),
          'weighted_score': metrics.weighted,
          'absences': s['absences'] ?? 0,
          'observation': _observations[sId] ?? '',
          'appreciation': app,
          'rank': rk,
        });
      }

      final res = await _repository.saveStudentGrades(grades: gradesToSave);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notes enregistrées avec succès !'),
              backgroundColor: AppColors.success,
            ),
          );
          // Reload data to ensure sync under current selected session & period
          setState(() {
            _isLoading = true;
          });
          _fetchGridData(_schoolId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Erreur lors de la sauvegarde.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur critique: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showExtensionDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.assignment_late_outlined, color: AppColors.warning),
              SizedBox(width: 8),
              Text("Demande de dérogation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "La période est actuellement verrouillée. Vous pouvez transmettre une demande de réouverture à la direction.",
                style: AppTextStyles.caption.copyWith(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Motif / Raison (optionnel)",
                  hintText: "Ex: Retard d'évaluation pour raisons médicales...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (_selectedSessionId != null) {
                  final res = await _repository.requestPeriodExtension(
                    sessionId: _selectedSessionId!,
                    term: _selectedPeriodName,
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Demande transmise avec succès !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("Envoyer la demande"),
            ),
          ],
        );
      },
    );
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Sélectionner la période", style: AppTextStyles.heading3),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSessionId,
                      decoration: const InputDecoration(labelText: "Session Académique"),
                      items: _sessions.map((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(s['session_name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val == null) return;
                        final selected = _sessions.firstWhere((s) => s['id'] == val);
                        setModalState(() {
                          _selectedSessionId = val;
                          _selectedSessionName = selected['session_name'] as String;
                          _periods = [];
                        });
                        
                        // Load new periods using the correct schoolId
                        final pList = await _repository.getPeriods(_schoolId, val, classId: widget.classId);
                        setModalState(() {
                          _periods = pList;
                          if (_periods.isNotEmpty) {
                            _selectedPeriodName = _periods.first['name'] as String;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_periods.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPeriodName,
                        decoration: const InputDecoration(labelText: "Trimestre / Semestre"),
                        items: _periods.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['name'] as String,
                            child: Text(p['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setModalState(() {
                            _selectedPeriodName = val;
                          });
                        },
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _fetchGridData(_schoolId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "Appliquer les filtres",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showObservationDialog(int studentId, String studentName) {
    final controller = TextEditingController(text: _observations[studentId] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Observation : $studentName", style: AppTextStyles.heading3),
          content: TextField(
            controller: controller,
            enabled: _canManageAcademics,
            decoration: const InputDecoration(
              hintText: "Saisir une remarque...",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler", style: TextStyle(color: AppColors.slate500)),
            ),
            ElevatedButton(
              onPressed: !_canManageAcademics
                  ? null
                  : () {
                setState(() {
                  _observations[studentId] = controller.text.trim();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _getCalculatedStats();
    final liveRanks = _getLiveRanks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie des Notes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            onPressed: _showPeriodSelector,
            tooltip: 'Période académique',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header / Filter Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.slate100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.className} • ${widget.subjectName}",
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$_selectedSessionName • $_selectedPeriodName",
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Coef: ${_coefficient.toStringAsFixed(0)}",
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Overview Stats Panel
          _buildStatsPanel(stats),

          // Lock Banner if Period is Locked or Read-Only
          if (!_isEditable || !_canManageAcademics)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade600),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lockReason ?? (!_canManageAcademics 
                          ? 'Mode lecture seule (Droits d\'édition désactivés).'
                          : 'Période verrouillée : La date limite de saisie des notes est dépassée.'),
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showExtensionDialog,
                    icon: const Icon(Icons.send_rounded, size: 14, color: AppColors.primary),
                    label: const Text(
                      "Dérogation",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStudents,
              decoration: InputDecoration(
                hintText: "Rechercher un élève...",
                prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: AppColors.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Main Student List
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                    ),
                  )
                : _filteredStudents.isEmpty
                    ? const Center(child: Text("Aucun élève trouvé"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final sId = student['student_id'] as int;
                          final matricule = student['num_admission'] as String;
                          final name = student['nom_etudiant'] as String;
                          final rank = liveRanks[sId] ?? 0;

                          final rowMetrics = _getRowMetrics(sId);

                          return _buildStudentCard(
                            studentId: sId,
                            matricule: matricule,
                            name: name,
                            rank: rank,
                            metrics: rowMetrics,
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed:
                _isSaving || !_canManageAcademics || !_isEditable ? null : _saveGrades,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "ENREGISTRER LES NOTES",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel(Map<String, dynamic> stats) {
    final double avg = stats['avg'] as double;
    final int passed = stats['passed'] as int;
    final int failed = stats['failed'] as int;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            title: "Moyenne Classe",
            value: "${avg.toStringAsFixed(2)}/20",
            icon: Icons.analytics,
            color: AppColors.primary,
          ),
          Container(width: 1, height: 40, color: AppColors.slate100),
          _buildStatItem(
            title: "Admis",
            value: "$passed",
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          Container(width: 1, height: 40, color: AppColors.slate100),
          _buildStatItem(
            title: "Non Admis",
            value: "$failed",
            icon: Icons.cancel_outlined,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
      ],
    );
  }

  Widget _buildStudentCard({
    required int studentId,
    required String matricule,
    required String name,
    required int rank,
    required Map<String, dynamic> metrics,
  }) {
    final double avg = metrics['average'] as double;
    final String appreciation = metrics['appreciation'] as String;

    Color appreciationColor = AppColors.slate500;
    if (appreciation.contains("Excellent") || appreciation.contains("Bien")) {
      appreciationColor = AppColors.success;
    } else if (appreciation.contains("Passable")) {
      appreciationColor = AppColors.warning;
    } else if (appreciation.contains("Insuffisant") || appreciation.contains("Médiocre")) {
      appreciationColor = AppColors.danger;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.slate100),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student details row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.slate300),
                        ),
                        child: Text(
                          matricule,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate500),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRank(rank),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.warning),
                    ),
                    const Text("Rang", style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Score Entry Row
            Row(
              children: [
                if (!_isHigherEd) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Moy. Classe", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _classWorkControllers[studentId],
                          enabled: _canManageAcademics && _isEditable,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: "--",
                            fillColor: AppColors.slate50,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: !_canManageAcademics
                              ? null
                              : (v) {
                            if (v.isNotEmpty && double.tryParse(v) != null) {
                              final numVal = double.parse(v);
                              if (numVal > 20) {
                                _classWorkControllers[studentId]?.text = "20";
                              }
                            }
                            setState(() {}); // Recalculate stats
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isHigherEd ? "Note" : "Note Compo", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _examControllers[studentId],
                        enabled: _canManageAcademics && _isEditable,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "--",
                          fillColor: AppColors.slate50,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: !_canManageAcademics
                            ? null
                            : (v) {
                          if (v.isNotEmpty && double.tryParse(v) != null) {
                            final numVal = double.parse(v);
                            if (numVal > 20) {
                              _examControllers[studentId]?.text = "20";
                            }
                          }
                          setState(() {}); // Recalculate stats
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${avg.toStringAsFixed(2)}/20",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: avg >= 10 ? AppColors.success : AppColors.danger),
                    ),
                    const Text("Moyenne", style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Observation & Appreciation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_outline, size: 14, color: AppColors.slate400),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: appreciationColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appreciation,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: appreciationColor),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _canManageAcademics && _isEditable
                      ? () => _showObservationDialog(studentId, name)
                      : null,
                  icon: Icon(
                    _observations[studentId]?.isNotEmpty == true ? Icons.comment : Icons.comment_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    _observations[studentId]?.isNotEmpty == true ? "Obs: ${_observations[studentId]}" : "Ajouter Obs.",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
