import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/attendance_repository.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectName;
  final String? initialDateStr;

  const StudentAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectName,
    this.initialDateStr,
  });

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final AttendanceRepository _repository = locator<AttendanceRepository>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageAttendance = false;
  String? _errorMessage;
  
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  
  // Maps to track current UI changes before saving
  final Map<int, String> _statuses = {}; // studentId -> status ('Présent', 'Absent', 'En Retard', 'Excusé')
  final Map<int, String> _remarks = {};  // studentId -> remark string
  
  late DateTime _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  // Notification switches
  bool _sendSMS = false;
  bool _sendWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDateStr != null
        ? DateTime.tryParse(widget.initialDateStr!) ?? DateTime.now()
        : DateTime.now();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employeeIdStr = await locator<SessionManager>().getEmployeeId();
      final employeeId = int.tryParse(employeeIdStr ?? '');

      // 1. Fetch active students in class (filtered by schoolId via repository)
      final studentsList = await _repository.getStudentsByClass(widget.className, employeeId);
      
      // 2. Fetch existing records for this date and subject
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final recordsList = await _repository.getStudentAttendanceRecords(
        classId: widget.classId,
        dateStr: dateStr,
        subjectId: widget.subjectId,
      );

      final Map<int, String> existingStatuses = {};
      final Map<int, String> existingRemarks = {};

      for (var record in recordsList) {
        final sId = (record['student_id'] as num).toInt();
        existingStatuses[sId] = record['status'] as String? ?? 'Présent';
        if (record['remark'] != null && (record['remark'] as String).isNotEmpty) {
          existingRemarks[sId] = record['remark'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _canManageAttendance =
              profile.permissions.contains(AppPermissions.attendanceManage);
          _students = studentsList;
          _filteredStudents = studentsList;
          
          // Populate status map: default to 'Présent' if no existing status
          _statuses.clear();
          _remarks.clear();
          for (var s in _students) {
            final sId = s['id'] as int;
            _statuses[sId] = existingStatuses[sId] ?? 'Présent';
            if (existingRemarks.containsKey(sId)) {
              _remarks[sId] = existingRemarks[sId]!;
            }
          }
          
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

  // Bulk actions
  void _setAllStatus(String status) {
    setState(() {
      for (var s in _students) {
        final sId = s['id'] as int;
        _statuses[sId] = status;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Tous les élèves ont été marqués: $status"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Edit single student remark in dialog
  void _showRemarkDialog(int studentId, String studentName) {
    final controller = TextEditingController(text: _remarks[studentId] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Remarque : $studentName", style: AppTextStyles.heading3),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Saisir une remarque...",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler", style: TextStyle(color: AppColors.slate500)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (controller.text.trim().isEmpty) {
                    _remarks.remove(studentId);
                  } else {
                    _remarks[studentId] = controller.text.trim();
                  }
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Valider", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Save student attendance records
  Future<void> _saveAttendance() async {
    setState(() {
      _isSaving = true;
    });

    final employeeIdStr = await locator<SessionManager>().getEmployeeId();
    final employeeId = int.tryParse(employeeIdStr ?? '');
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Format records for repository API
    final List<Map<String, dynamic>> recordsToSave = [];
    for (var s in _students) {
      final sId = s['id'] as int;
      recordsToSave.add({
        'student_id': sId,
        'status': _statuses[sId] ?? 'Présent',
        'remark': _remarks[sId],
      });
    }

    final result = await _repository.saveStudentBatchAttendance(
      classId: widget.classId,
      dateStr: dateStr,
      subjectId: widget.subjectId,
      employeeId: employeeId,
      records: recordsToSave,
      sendSMS: _sendSMS,
      sendWhatsApp: _sendWhatsApp,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Appel enregistré avec succès !"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Erreur"),
            content: Text(result['error'] ?? "Une erreur est survenue lors de l'enregistrement."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  // Change date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.slate800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchData();
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF0D9488), // Teal
      const Color(0xFF7C3AED), // Purple
      const Color(0xFF2563EB), // Blue
      const Color(0xFFEA580C), // Orange
      const Color(0xFFDB2777), // Pink
      const Color(0xFF0284C7), // Sky
    ];
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final total = _students.length;
    final presentCount = _statuses.values.where((v) => v == 'Présent').length;
    final absentCount = _statuses.values.where((v) => v == 'Absent').length;
    final lateCount = _statuses.values.where((v) => v == 'En Retard').length;
    final excusedCount = _statuses.values.where((v) => v == 'Excusé').length;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text("Appel : ${widget.className}", style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: _selectDate,
            tooltip: 'Changer la date',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
               ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Class & Date Header Info Card
                    _buildHeaderCard(dateStr: DateFormat('dd MMMM yyyy').format(_selectedDate)),

                    // Stats Dashboard Grid
                    _buildStatsRow(
                      total: total,
                      presents: presentCount,
                      absents: absentCount,
                      lates: lateCount,
                      excused: excusedCount,
                    ),

                    // Quick Bulk Actions Bar
                    _buildBulkActionsBar(),

                    // Search field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterStudents,
                        decoration: InputDecoration(
                          hintText: "Rechercher un élève...",
                          hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterStudents('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // Student List
                    Expanded(
                      child: _filteredStudents.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isNotEmpty
                                    ? "Aucun résultat trouvé pour votre recherche."
                                    : "Aucun élève actif trouvé dans cette classe.",
                                style: AppTextStyles.caption,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                final studentId = student['id'] as int;
                                final studentName = student['nom_etudiant'] as String? ?? '';
                                final admissionNo = student['num_admission'] as String? ?? '';
                                final currentStatus = _statuses[studentId] ?? 'Présent';
                                final hasRemark = _remarks.containsKey(studentId);

                                return _buildStudentCard(
                                  studentId: studentId,
                                  studentName: studentName,
                                  admissionNo: admissionNo,
                                  currentStatus: currentStatus,
                                  hasRemark: hasRemark,
                                );
                              },
                            ),
                    ),

                    // Floating Bottom Saving Container
                    _buildSaveButtonContainer(),
                  ],
                ),
    );
  }

  Widget _buildHeaderCard({required String dateStr}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary.withAlpha(220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                "Classe : ${widget.className}",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (widget.subjectName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 16),
                const SizedBox(width: 10),
                Text(
                  "Matière : ${widget.subjectName}",
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int presents,
    required int absents,
    required int lates,
    required int excused,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildStatBox(title: "Élèves", value: "$total", color: AppColors.slate700),
          const SizedBox(width: 6),
          _buildStatBox(title: "Présents", value: "$presents", color: AppColors.success),
          const SizedBox(width: 6),
          _buildStatBox(title: "Absents", value: "$absents", color: AppColors.danger),
          const SizedBox(width: 6),
          _buildStatBox(title: "Retards", value: "$lates", color: AppColors.warning),
          const SizedBox(width: 6),
          _buildStatBox(title: "Excusés", value: "$excused", color: AppColors.info),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(45), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _canManageAttendance
                  ? () => _setAllStatus('Présent')
                  : null,
              icon: const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              label: const Text("Tout Présent", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.success, width: 1.5),
                backgroundColor: AppColors.success.withAlpha(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _canManageAttendance ? () => _setAllStatus('Absent') : null,
              icon: const Icon(Icons.cancel, size: 16, color: AppColors.danger),
              label: const Text("Tout Absent", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                backgroundColor: AppColors.danger.withAlpha(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard({
    required int studentId,
    required String studentName,
    required String admissionNo,
    required String currentStatus,
    required bool hasRemark,
  }) {
    final initials = studentName.isNotEmpty
        ? studentName.trim().split(' ').map((e) => e.substring(0, 1)).take(2).join().toUpperCase()
        : '?';

    final avatarColor = _getAvatarColor(studentName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor.withAlpha(30),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: avatarColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(color: AppColors.slate900, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "N° Adm: $admissionNo",
                        style: const TextStyle(color: AppColors.slate500, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    hasRemark ? Icons.comment : Icons.comment_outlined,
                    color: hasRemark ? AppColors.primary : AppColors.slate400,
                    size: 20,
                  ),
                  onPressed: _canManageAttendance
                      ? () => _showRemarkDialog(studentId, studentName)
                      : null,
                  tooltip: 'Ajouter une remarque',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(studentId, 'Présent', AppColors.success),
                const SizedBox(width: 6),
                _buildStatusChip(studentId, 'Absent', AppColors.danger),
                const SizedBox(width: 6),
                _buildStatusChip(studentId, 'En Retard', AppColors.warning),
                const SizedBox(width: 6),
                _buildStatusChip(studentId, 'Excusé', AppColors.info),
              ],
            ),
            if (hasRemark) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _remarks[studentId]!,
                        style: const TextStyle(color: AppColors.slate700, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int studentId, String statusLabel, Color activeColor) {
    final isSelected = _statuses[studentId] == statusLabel;
    
    return Expanded(
      child: GestureDetector(
        onTap: !_canManageAttendance
            ? null
            : () {
          setState(() {
            _statuses[studentId] = statusLabel;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppColors.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              statusLabel == 'En Retard' ? 'Retard' : (statusLabel == 'Excusé' ? 'Excusé' : statusLabel),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButtonContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option Toggles Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sendSMS ? AppColors.info.withAlpha(20) : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sendSMS ? AppColors.info.withAlpha(60) : const Color(0xFFEEF2F6)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sms_outlined, size: 18, color: _sendSMS ? AppColors.info : AppColors.slate500),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text("Alerte SMS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                        ),
                        Switch.adaptive(
                          value: _sendSMS,
                          thumbColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.info : null,
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.info.withAlpha(80) : null,
                          ),
                          onChanged: !_canManageAttendance
                              ? null
                              : (val) {
                            setState(() {
                              _sendSMS = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sendWhatsApp ? AppColors.success.withAlpha(20) : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sendWhatsApp ? AppColors.success.withAlpha(60) : const Color(0xFFEEF2F6)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18, color: _sendWhatsApp ? AppColors.success : AppColors.slate500),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text("WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                        ),
                        Switch.adaptive(
                          value: _sendWhatsApp,
                          thumbColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.success : null,
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.success.withAlpha(80) : null,
                          ),
                          onChanged: !_canManageAttendance
                              ? null
                              : (val) {
                            setState(() {
                              _sendWhatsApp = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  _isSaving || !_canManageAttendance ? null : _saveAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Enregistrer l'appel",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
