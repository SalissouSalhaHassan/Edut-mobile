import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/supabase_client.dart';
import '../data/academics_repository.dart';
import '../../ai/data/ai_repository.dart';

class GestionDevoirsScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;

  const GestionDevoirsScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<GestionDevoirsScreen> createState() => _GestionDevoirsScreenState();
}

class _GestionDevoirsScreenState extends State<GestionDevoirsScreen> {
  final AcademicsRepository _repository = locator<AcademicsRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageAcademics = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _periods = [];

  int? _selectedSessionId;
  String _selectedSessionName = '';
  String _selectedPeriodName = '';
  bool _isEditable = true;
  String? _lockReason;
  int _schoolId = 1;

  final TextEditingController _searchController = TextEditingController();

  // Map of studentId -> List of 5 Controllers (for devoir1 to devoir5)
  final Map<int, List<TextEditingController>> _devoirControllers = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controllersList in _devoirControllers.values) {
      for (var controller in controllersList) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final profile = await locator<PermissionService>().getCurrentProfile(forceRefresh: true);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canManageAcademics = profile.permissions.contains(AppPermissions.gestionDevoirsEdit);
    });

    try {
      final sessionManager = locator<SessionManager>();
      final employeeIdStr = await sessionManager.getEmployeeId();
      final employeeId = int.tryParse(employeeIdStr ?? '');
      
      // Default schoolId fallback
      int schoolId = 1;
      if (employeeId != null) {
        final client = SupabaseClientManager().client;
        final List<dynamic> empInfo = await client
            .from('employees')
            .select('school_id')
            .eq('id', employeeId);
        if (empInfo.isNotEmpty && empInfo.first['school_id'] != null) {
          schoolId = empInfo.first['school_id'] as int;
          _schoolId = schoolId;
        }
      }

      // Fetch sessions
      _sessions = await _repository.getSessions(schoolId);

      if (_sessions.isNotEmpty) {
        // Find active session
        final activeSession = _sessions.firstWhere(
          (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
          orElse: () => _sessions.first,
        );
        _selectedSessionId = (activeSession['id'] as num?)?.toInt() ?? 1;
        _selectedSessionName = activeSession['session_name']?.toString() ?? '';

        // Fetch periods
        _periods = await _repository.getPeriods(schoolId, _selectedSessionId!, classId: widget.classId);
        if (_periods.isNotEmpty) {
          final activePeriod = _periods.firstWhere(
            (p) => p['is_active'] == true,
            orElse: () => _periods.first,
          );
          _selectedPeriodName = activePeriod['name'] as String;
        }
      }

      if (_selectedSessionId != null && _selectedPeriodName.isNotEmpty) {
        await _fetchDevoirData(schoolId);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Aucune session ou période académique trouvée.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur d'initialisation: $e";
      });
    }
  }

  Future<void> _fetchDevoirData(int schoolId) async {
    if (_selectedSessionId == null || _selectedPeriodName.isEmpty) return;

    try {
      final result = await _repository.getDevoirGrid(
        classId: widget.classId,
        subjectId: widget.subjectId,
        sessionId: _selectedSessionId!,
        term: _selectedPeriodName,
        schoolId: schoolId,
      );

      if (result['success'] == true) {
        _isEditable = result['is_editable'] as bool? ?? true;
        _lockReason = result['lock_reason'] as String?;
        final List rawData = result['data'] is List ? (result['data'] as List) : [];
        _students = rawData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _filteredStudents = _students;

        // Initialize controllers for devoirs
        _devoirControllers.clear();

        for (var student in _students) {
          final sId = student['student_id'] as int;
          final List<dynamic> devoirsList = student['devoirs'] as List<dynamic>;

          final List<TextEditingController> controllers = [];
          for (int i = 0; i < 5; i++) {
            final devVal = (devoirsList[i] != null)
                ? (devoirsList[i] as num).toStringAsFixed(2).replaceAll('.00', '')
                : '';
            controllers.add(TextEditingController(text: devVal));
          }
          _devoirControllers[sId] = controllers;
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
        _errorMessage = "Erreur lors du chargement des devoirs: $e";
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

  // Calculate live devoir average for a student row
  double _getLiveAverage(int studentId) {
    final controllers = _devoirControllers[studentId];
    if (controllers == null) return 0.0;

    final values = controllers
        .map((c) => double.tryParse(c.text))
        .where((v) => v != null)
        .cast<double>()
        .toList();

    if (values.isEmpty) return 0.0;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  Future<void> _saveDevoirs() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final List<Map<String, dynamic>> devoirsToSave = [];

      for (var s in _students) {
        final sId = s['student_id'] as int;
        final controllers = _devoirControllers[sId]!;

        final List<double?> devoirsList = controllers.map((c) {
          final val = double.tryParse(c.text);
          return val;
        }).toList();

        final avg = _getLiveAverage(sId);

        devoirsToSave.add({
          'student_id': sId,
          'class_id': widget.classId,
          'subject_id': widget.subjectId,
          'session_id': _selectedSessionId!,
          'term': _selectedPeriodName,
          'devoirs': devoirsList,
          'moyenne_devoirs': avg,
        });
      }

      final res = await _repository.saveDevoirGrades(devoirsList: devoirsToSave);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Devoirs enregistrés avec succès !'),
              backgroundColor: AppColors.success,
            ),
          );
          // Reload under current selected session & period
          setState(() {
            _isLoading = true;
          });
          _fetchDevoirData(_schoolId);
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

  void _showAiQuizGeneratorDialog() {
    final lessonController = TextEditingController(text: 'Évaluation formative');
    bool isGenerating = false;
    List<Map<String, dynamic>> generatedQuestions = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text("Générateur de Quiz IA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Matière : ${widget.subjectName} • Classe : ${widget.className}",
                        style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: lessonController,
                        decoration: const InputDecoration(
                          labelText: "Titre de la leçon / Thème",
                          hintText: "Ex: Les équations du second degré...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: isGenerating
                            ? null
                            : () async {
                                setDialogState(() {
                                  isGenerating = true;
                                  generatedQuestions = [];
                                });
                                final questions = await locator<AiRepository>().generateQuizQuestions(
                                  lessonTitle: lessonController.text.trim(),
                                  subjectName: widget.subjectName,
                                  className: widget.className,
                                  count: 3,
                                );
                                setDialogState(() {
                                  isGenerating = false;
                                  generatedQuestions = questions;
                                });
                              },
                        icon: isGenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isGenerating ? 'Génération en cours...' : 'Générer les questions ✨',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      if (generatedQuestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Questions générées :",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                        ),
                        const SizedBox(height: 8),
                        ...generatedQuestions.map((q) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Q${q['id'] ?? '•'} : ${q['question']}",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (q['hint'] != null)
                                    Text(
                                      "Indice : ${q['hint']}",
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.slate500),
                                    ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Fermer"),
                ),
              ],
            );
          },
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
                        _fetchDevoirData(_schoolId);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Devoirs (DS)'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
            onPressed: _showAiQuizGeneratorDialog,
            tooltip: 'Générateur de questions IA',
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            onPressed: _showPeriodSelector,
            tooltip: 'Période académique',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter details
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
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Calcul Continu",
                    style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

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
                          : 'Période verrouillée : La date limite de saisie des devoirs est dépassée.'),
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

          // Devoir entry List
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

                          final liveAvg = _getLiveAverage(sId);

                          return _buildDevoirCard(
                            studentId: sId,
                            matricule: matricule,
                            name: name,
                            average: liveAvg,
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
                _isSaving || !_canManageAcademics || !_isEditable ? null : _saveDevoirs,
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
                        "ENREGISTRER LES DEVOIRS",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevoirCard({
    required int studentId,
    required String matricule,
    required String name,
    required double average,
  }) {
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
                      "${average.toStringAsFixed(2)}/20",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: average >= 10 ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const Text("Moy. DS", style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontal Scrollable Devoir Fields
            const Text("Notes des Devoirs (1 à 5)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    child: TextField(
                      controller: _devoirControllers[studentId]?[index],
                      enabled: _canManageAcademics && _isEditable,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Dev. ${index + 1}",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        labelStyle: const TextStyle(fontSize: 10, color: AppColors.slate400),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        fillColor: AppColors.slate50,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: !_canManageAcademics
                          ? null
                          : (v) {
                        if (v.isNotEmpty && double.tryParse(v) != null) {
                          final numVal = double.parse(v);
                          if (numVal > 20) {
                            _devoirControllers[studentId]?[index].text = "20";
                          }
                        }
                        setState(() {}); // Recalculate average live
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
