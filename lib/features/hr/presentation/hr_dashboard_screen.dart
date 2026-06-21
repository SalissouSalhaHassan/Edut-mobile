import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/hr_repository.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen>
    with SingleTickerProviderStateMixin {
  final HrRepository _repository = locator<HrRepository>();
  final TextEditingController _employeeSearchController =
      TextEditingController();
  final TextEditingController _payrollMonthController = TextEditingController(
    text: DateFormat('MMMM yyyy').format(DateTime.now()),
  );

  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isComputingPayroll = false;
  bool _canManageHr = false;
  final DateTime _attendanceDate = DateTime.now();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _salaryRecords = [];
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic> _payrollRules = {};
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _employeeSearchController.dispose();
    _payrollMonthController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    setState(() => _isLoading = true);
    final dashboard = await _repository.getHrDashboardData();
    final rules = await _repository.getPayrollRules();

    if (!mounted) return;
    setState(() {
      _employees = List<Map<String, dynamic>>.from(dashboard['employees'] ?? []);
      _salaryRecords =
          List<Map<String, dynamic>>.from(dashboard['salaryRecords'] ?? []);
      _attendance = List<Map<String, dynamic>>.from(dashboard['attendance'] ?? []);
      _stats = Map<String, dynamic>.from(dashboard['stats'] ?? {});
      _payrollRules = Map<String, dynamic>.from(rules);
      _canManageHr = profile.permissions.contains(AppPermissions.hrManage);
      _isLoading = false;
    });
    _applyEmployeeSearch();
  }

  void _applyEmployeeSearch() {
    final query = _employeeSearchController.text.trim().toLowerCase();
    final filtered = _employees.where((employee) {
      final name = (employee['nom'] ?? '').toString().toLowerCase();
      final empId = (employee['emp_id'] ?? '').toString().toLowerCase();
      final poste = (employee['poste'] ?? '').toString().toLowerCase();
      final department = (employee['departement'] ?? '').toString().toLowerCase();
      return query.isEmpty ||
          name.contains(query) ||
          empId.contains(query) ||
          poste.contains(query) ||
          department.contains(query);
    }).toList();

    setState(() => _filteredEmployees = filtered);
  }

  Future<void> _openEmployeeForm([Map<String, dynamic>? employee]) async {
    final empIdController =
        TextEditingController(text: employee?['emp_id']?.toString() ?? '');
    final nameController =
        TextEditingController(text: employee?['nom']?.toString() ?? '');
    final posteController =
        TextEditingController(text: employee?['poste']?.toString() ?? '');
    final departmentController =
        TextEditingController(text: employee?['departement']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: employee?['mobile']?.toString() ?? '');
    final emailController =
        TextEditingController(text: employee?['email']?.toString() ?? '');
    final salaryController = TextEditingController(
      text: ((employee?['salaire_base'] as num?)?.toDouble() ?? 0).toString(),
    );
    var status = (employee?['statut'] ?? 'Actif').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee == null ? 'Nouvel employe' : 'Modifier employe',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 16),
                      _textField('Matricule', empIdController),
                      const SizedBox(height: 10),
                      _textField('Nom complet', nameController),
                      const SizedBox(height: 10),
                      _textField('Poste', posteController),
                      const SizedBox(height: 10),
                      _textField('Departement', departmentController),
                      const SizedBox(height: 10),
                      _textField('Telephone', phoneController),
                      const SizedBox(height: 10),
                      _textField('Email', emailController),
                      const SizedBox(height: 10),
                      _textField(
                        'Salaire de base',
                        salaryController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const ['Actif', 'Inactif', 'En conge']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => status = value ?? 'Actif');
                        },
                        decoration: _decoration('Statut'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  final result = await _repository.saveEmployee(
                                    employeeId: employee?['id'] as int?,
                                    payload: {
                                      'emp_id': empIdController.text.trim(),
                                      'nom': nameController.text.trim(),
                                      'poste': posteController.text.trim(),
                                      'departement':
                                          departmentController.text.trim(),
                                      'mobile': phoneController.text.trim(),
                                      'email': emailController.text.trim(),
                                      'salaire_base': double.tryParse(
                                            salaryController.text.trim(),
                                          ) ??
                                          0,
                                      'statut': status,
                                    },
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  _showMessage(
                                    result['success'] == true
                                        ? 'Employe enregistre.'
                                        : (result['error']?.toString() ??
                                            'Erreur employe'),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEmployee(int employeeId) async {
    final result = await _repository.deleteEmployee(employeeId);
    if (!mounted) return;
    _showMessage(
      result['success'] == true
          ? 'Employe supprime.'
          : (result['error']?.toString() ?? 'Erreur suppression'),
    );
    if (result['success'] == true) {
      await _load();
    }
  }

  Future<void> _openAttendanceSheet() async {
    final attendanceRows = await _repository.getEmployeeAttendance(
      DateFormat('yyyy-MM-dd').format(_attendanceDate),
    );
    if (!mounted) return;

    final records = {
      for (final row in attendanceRows) row['employee_id'] as int: row,
    };
    final draft = _employees
        .map(
          (employee) => {
            'employee_id': employee['id'],
            'name': employee['nom'],
            'status':
                _normalizeAttendanceStatus(
                  (records[employee['id']]?['status'] ?? 'Present').toString(),
                ),
          },
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pointage du jour', style: AppTextStyles.heading2),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_attendanceDate),
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: draft.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = draft[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEBF0F5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (row['name'] ?? 'Employe').toString(),
                                    style: AppTextStyles.bodyBold,
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: row['status'] as String,
                                  items: const [
                                    'Present',
                                    'Absent',
                                    'En Retard',
                                    'Conge',
                                  ]
                                      .map(
                                        (status) => DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(status),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      row['status'] = _normalizeAttendanceStatus(
                                        value ?? 'Present',
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                final result =
                                    await _repository.saveEmployeeAttendance(
                                  dateStr: DateFormat('yyyy-MM-dd')
                                      .format(_attendanceDate),
                                  records: draft
                                      .map(
                                        (row) => {
                                          'employee_id': row['employee_id'],
                                          'status': row['status'],
                                        },
                                      )
                                      .toList(),
                                );
                                if (!mounted) return;
                                setState(() => _isSaving = false);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                _showMessage(
                                  result['success'] == true
                                      ? 'Pointage enregistre.'
                                      : (result['error']?.toString() ??
                                          'Erreur pointage'),
                                );
                                if (result['success'] == true) {
                                  await _load();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _isSaving ? 'Enregistrement...' : 'Valider le pointage',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPayrollForm([Map<String, dynamic>? initialRecord]) async {
    Map<String, dynamic>? record = initialRecord == null
        ? null
        : Map<String, dynamic>.from(initialRecord);
    int? selectedEmployeeId =
        record?['employee_id'] as int? ??
            (_employees.isNotEmpty ? _employees.first['id'] as int : null);
    final monthController = TextEditingController(
      text: record?['month_year']?.toString() ?? _payrollMonthController.text,
    );
    final allowanceController = TextEditingController(
      text: ((record?['total_allowance'] as num?)?.toDouble() ?? 0).toString(),
    );
    final deductionController = TextEditingController(
      text: ((record?['total_deduction'] as num?)?.toDouble() ?? 0).toString(),
    );
    var status = _normalizeSalaryStatus(
      (record?['status'] ?? 'Unpaid').toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final employee = _employees.firstWhere(
              (row) => row['id'] == selectedEmployeeId,
              orElse: () => <String, dynamic>{},
            );
            final baseSalary =
                (employee['salaire_base'] as num?)?.toDouble() ?? 0;
            final attendanceSummary = _salaryAttendanceSummaryFromRecord(record);
            final latePenalty =
                (_payrollRules['late_penalty'] as num?)?.toDouble() ?? 0;
            final halfPenalty =
                (_payrollRules['half_day_penalty'] as num?)?.toDouble() ?? 0;
            final absentDays = attendanceSummary['absent'] ?? 0;
            final lateDays = attendanceSummary['late'] ?? 0;
            final leaveDays = attendanceSummary['leave'] ?? 0;
            final computedDeduction = absentDays * latePenalty * 10 +
                lateDays * latePenalty +
                leaveDays * halfPenalty;
            final extraAllowance =
                double.tryParse(allowanceController.text.trim()) ?? 0;
            final extraDeduction =
                double.tryParse(deductionController.text.trim()) ?? 0;
            final netSalary =
                (baseSalary + extraAllowance) - (computedDeduction + extraDeduction);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fiche de paie', style: AppTextStyles.heading2),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedEmployeeId,
                        items: _employees
                            .map(
                              (employee) => DropdownMenuItem<int>(
                                value: employee['id'] as int,
                                child: Text(
                                  '${employee['nom']} - ${employee['poste'] ?? '-'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => selectedEmployeeId = value);
                        },
                        decoration: _decoration('Employe'),
                      ),
                      const SizedBox(height: 10),
                      _textField('Mois', monthController),
                      const SizedBox(height: 10),
                      _textField(
                        'Prime',
                        allowanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        'Retenue additionnelle',
                        deductionController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const ['Unpaid', 'Paid']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => status = value ?? 'Unpaid');
                        },
                        decoration: _decoration('Statut'),
                      ),
                      const SizedBox(height: 16),
                      _summaryCard([
                        'Salaire de base: ${baseSalary.toStringAsFixed(0)} CFA',
                        'Absences: $absentDays',
                        'Retards: $lateDays',
                        'Conges: $leaveDays',
                        'Retenue calculee: ${computedDeduction.toStringAsFixed(0)} CFA',
                        'Net estime: ${netSalary.toStringAsFixed(0)} CFA',
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isComputingPayroll
                              ? null
                              : () async {
                                  if (selectedEmployeeId == null) {
                                    _showMessage('Selectionnez un employe.');
                                    return;
                                  }
                                  setState(() => _isComputingPayroll = true);
                                  final summary = await _repository
                                      .getEmployeeAttendanceSummary(
                                    employeeId: selectedEmployeeId!,
                                    monthYear: monthController.text.trim(),
                                  );
                                  if (!mounted) return;
                                  setState(() => _isComputingPayroll = false);
                                  setModalState(() {
                                    record = {
                                      ...?record,
                                      'absent_days': summary['absents'] ?? 0,
                                      'late_days': summary['retards'] ?? 0,
                                      'leave_taken': summary['conges'] ?? 0,
                                    };
                                  });
                                },
                          icon: const Icon(Icons.calculate_outlined),
                          label: Text(
                            _isComputingPayroll
                                ? 'Calcul en cours...'
                                : 'Charger le resume du mois',
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  if (selectedEmployeeId == null) {
                                    _showMessage('Selectionnez un employe.');
                                    return;
                                  }
                                  setState(() => _isSaving = true);
                                  final result = await _repository.saveSalaryRecord(
                                    recordId: record?['id'] as int?,
                                    payload: {
                                      'employee_id': selectedEmployeeId,
                                      'month_year': monthController.text.trim(),
                                      'absent_days': absentDays,
                                      'leave_taken': leaveDays,
                                      'late_days': lateDays,
                                      'half_days': 0,
                                      'basic_salary': baseSalary,
                                      'calculated_basic': baseSalary,
                                      'total_allowance': extraAllowance,
                                      'total_deduction':
                                          computedDeduction + extraDeduction,
                                      'net_salary': netSalary,
                                      'status': _normalizeSalaryStatus(status),
                                      if (_normalizeSalaryStatus(status) == 'Paid')
                                        'payment_date':
                                            DateTime.now().toIso8601String(),
                                    },
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  _showMessage(
                                    result['success'] == true
                                        ? 'Fiche de paie enregistree.'
                                        : (result['error']?.toString() ??
                                            'Erreur paie'),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, int> _salaryAttendanceSummaryFromRecord(
    Map<String, dynamic>? record,
  ) {
    return {
      'absent': (record?['absent_days'] as num?)?.toInt() ?? 0,
      'late': (record?['late_days'] as num?)?.toInt() ?? 0,
      'leave': (record?['leave_taken'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> _savePayrollRules() async {
    final leaveController = TextEditingController(
      text: ((_payrollRules['leave_allow_per_month'] as num?)?.toInt() ?? 1)
          .toString(),
    );
    final lateController = TextEditingController(
      text: ((_payrollRules['late_penalty'] as num?)?.toDouble() ?? 0.5)
          .toString(),
    );
    final halfController = TextEditingController(
      text: ((_payrollRules['half_day_penalty'] as num?)?.toDouble() ?? 0.5)
          .toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Regles de paie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(
                  'Conges/mois',
                  leaveController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _textField(
                  'Penalite retard',
                  lateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 10),
                _textField(
                  'Penalite demi-jour',
                  halfController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await _repository.savePayrollRules({
                  'leave_allow_per_month':
                      int.tryParse(leaveController.text.trim()) ?? 1,
                  'late_penalty':
                      double.tryParse(lateController.text.trim()) ?? 0.5,
                  'half_day_penalty':
                      double.tryParse(halfController.text.trim()) ?? 0.5,
                });
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                _showMessage(
                  result['success'] == true
                      ? 'Regles enregistrees.'
                      : (result['error']?.toString() ?? 'Erreur regles'),
                );
                if (result['success'] == true) {
                  await _load();
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _normalizeAttendanceStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('present') || normalized.contains('présent')) {
      return 'Present';
    }
    if (normalized.contains('absent')) {
      return 'Absent';
    }
    if (normalized.contains('retard') || normalized.contains('late')) {
      return 'En Retard';
    }
    if (normalized.contains('conge') || normalized.contains('congé')) {
      return 'Conge';
    }
    if (normalized.contains('non pointe')) {
      return 'Non pointe';
    }
    return value.trim().isEmpty ? 'Absent' : value.trim();
  }

  String _normalizeSalaryStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'paid' || normalized == 'paye' || normalized == 'payé') {
      return 'Paid';
    }
    return 'Unpaid';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Ressources Humaines'),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/teacher-reports'),
            icon: const Icon(Icons.timeline_rounded),
            tooltip: 'Rapports presence enseignant',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vue'),
            Tab(text: 'Employes'),
            Tab(text: 'Paie'),
            Tab(text: 'Rapports'),
          ],
        ),
      ),
      floatingActionButton: _canManageHr
          ? FloatingActionButton.extended(
              onPressed: () {
                switch (_tabController.index) {
                  case 1:
                    _openEmployeeForm();
                    break;
                  case 2:
                    _openPayrollForm();
                    break;
                  default:
                    _openAttendanceSheet();
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icon(
                _tabController.index == 2
                    ? Icons.payments_outlined
                    : _tabController.index == 1
                        ? Icons.person_add_alt_1_rounded
                        : Icons.playlist_add_check_circle_outlined,
              ),
              label: Text(
                _tabController.index == 2
                    ? 'Paie'
                    : _tabController.index == 1
                        ? 'Employe'
                        : 'Pointage',
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildEmployeesTab(),
                _buildPayrollTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _statCard(
                'Actifs',
                '${_stats['activeEmployees'] ?? 0}',
                Icons.groups_rounded,
              ),
              _statCard(
                'Presents',
                '${_stats['presentToday'] ?? 0}',
                Icons.fact_check_rounded,
              ),
              _statCard(
                'Paiee',
                _money(_stats['paidAmount']),
                Icons.paid_rounded,
              ),
              _statCard(
                'A payer',
                _money(_stats['unpaidAmount']),
                Icons.money_off_csred_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Operations rapides',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _actionChip(
                  'Pointage du jour',
                  Icons.how_to_reg_rounded,
                  _openAttendanceSheet,
                ),
                _actionChip(
                  'Regles de paie',
                  Icons.rule_folder_outlined,
                  _savePayrollRules,
                ),
                _actionChip(
                  'Rapports enseignant',
                  Icons.school_outlined,
                  () => context.push('/attendance/teacher-reports'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Presence du jour',
            child: Column(
              children: _employees.take(6).map((employee) {
                final matches = _attendance
                    .where((row) => row['employee_id'] == employee['id'])
                    .toList();
                final status = matches.isEmpty
                    ? 'Non pointe'
                    : _normalizeAttendanceStatus(
                        (matches.first['status'] ?? 'Non pointe').toString(),
                      );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2FF),
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    (employee['nom'] ?? 'Employe').toString(),
                    style: AppTextStyles.bodyBold,
                  ),
                  subtitle: Text((employee['poste'] ?? '-').toString()),
                  trailing: _statusPill(status),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _employeeSearchController,
            onChanged: (_) => _applyEmployeeSearch(),
            decoration: _decoration('Rechercher un employe').copyWith(
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _filteredEmployees.isEmpty
              ? _emptyState('Aucun employe trouve.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _filteredEmployees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final employee = _filteredEmployees[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEBF0F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFEEF2FF),
                                child: Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (employee['nom'] ?? 'Employe').toString(),
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    Text(
                                      '${employee['emp_id'] ?? '-'} - ${employee['poste'] ?? '-'}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              _statusPill(
                                (employee['statut'] ?? 'Actif').toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _infoChip(employee['departement'] ?? '-'),
                              _infoChip(employee['mobile'] ?? '-'),
                              _infoChip(employee['email'] ?? '-'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Salaire: ${_money(employee['salaire_base'])}',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_canManageHr)
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _openEmployeeForm(employee),
                                  child: const Text('Modifier'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    _payrollMonthController.text =
                                        DateFormat('MMMM yyyy')
                                            .format(DateTime.now());
                                    await _openPayrollForm({
                                      'employee_id': employee['id'],
                                      'month_year':
                                          _payrollMonthController.text,
                                    });
                                  },
                                  child: const Text('Paie'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _deleteEmployee(employee['id'] as int),
                                  child: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPayrollTab() {
    final filtered = _salaryRecords
        .where(
          (row) =>
              _payrollMonthController.text.trim().isEmpty ||
              (row['month_year'] ?? '').toString() ==
                  _payrollMonthController.text.trim(),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              TextField(
                controller: _payrollMonthController,
                onChanged: (_) => setState(() {}),
                decoration: _decoration('Filtrer par mois'),
              ),
              const SizedBox(height: 10),
              if (_canManageHr)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _savePayrollRules,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Regles de paie'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState('Aucune fiche de paie.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    final employee = record['employees'] as Map<String, dynamic>?;
                    final paid = _normalizeSalaryStatus(
                          (record['status'] ?? '').toString(),
                        ) ==
                        'Paid';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEBF0F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (employee?['nom'] ?? 'Employe').toString(),
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    Text(
                                      (record['month_year'] ?? '-').toString(),
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              _statusPill(paid ? 'Paid' : 'Unpaid'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Net: ${_money(record['net_salary'])}',
                            style: AppTextStyles.heading3,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Retenue: ${_money(record['total_deduction'])} | Prime: ${_money(record['total_allowance'])}',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 10),
                          if (_canManageHr)
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _openPayrollForm(record),
                                  child: const Text('Modifier'),
                                ),
                                if (!paid)
                                  TextButton(
                                    onPressed: () async {
                                      final result = await _repository
                                          .markSalaryAsPaid(
                                            record['id'] as int,
                                          );
                                      if (!mounted) return;
                                      _showMessage(
                                        result['success'] == true
                                            ? 'Salaire marque comme paye.'
                                            : (result['error']?.toString() ??
                                                'Erreur paiement'),
                                      );
                                      if (result['success'] == true) {
                                        await _load();
                                      }
                                    },
                                    child: const Text('Marquer paye'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final totalEmployees = _employees.length;
    final active = _employees
        .where(
          (employee) => (employee['statut'] ?? '')
              .toString()
              .toLowerCase()
              .contains('actif'),
        )
        .length;
    final inactive = totalEmployees - active;
    final paidCount = _salaryRecords
        .where(
          (row) =>
              _normalizeSalaryStatus((row['status'] ?? '').toString()) ==
              'Paid',
        )
        .length;
    final unpaidCount = _salaryRecords.length - paidCount;
    final departments = <String, int>{};

    for (final employee in _employees) {
      final dept = (employee['departement'] ?? 'Non defini').toString();
      departments[dept] = (departments[dept] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionCard(
          title: 'Repartition du personnel',
          child: Column(
            children: [
              _reportLine('Total employes', '$totalEmployees'),
              _reportLine('Actifs', '$active'),
              _reportLine('Inactifs', '$inactive'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Etat de la paie',
          child: Column(
            children: [
              _reportLine('Fiches payees', '$paidCount'),
              _reportLine('Fiches impayees', '$unpaidCount'),
              _reportLine('Montant verse', _money(_stats['paidAmount'])),
              _reportLine('Montant restant', _money(_stats['unpaidAmount'])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Rapports de presence',
          child: Column(
            children: [
              _reportLine('Pointages du jour', '${_attendance.length}'),
              _reportLine(
                'Presents aujourd\'hui',
                '${_stats['presentToday'] ?? 0}',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/attendance/teacher-reports'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ouvrir le rapport enseignant'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Repartition par departement',
          child: Column(
            children: departments.entries
                .map((entry) => _reportLine(entry.key, '${entry.value}'))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _summaryCard(List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: AppTextStyles.body),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading3),
        ],
      ),
    );
  }

  Widget _statusPill(String text) {
    final lower = text.toLowerCase();
    final positive = lower.contains('actif') ||
        lower.contains('paid') ||
        lower.contains('present');
    final waiting = lower.contains('unpaid') || lower.contains('retard');
    final color = positive
        ? const Color(0xFF059669)
        : waiting
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    final bg = positive
        ? const Color(0xFFECFDF5)
        : waiting
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFFEF2F2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _reportLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }

  Widget _infoChip(dynamic value) {
    final text = value?.toString().trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Text(
        text == null || text.isEmpty ? '-' : text,
        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 48,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.heading3),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: _decoration(label),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
      ),
    );
  }

  String _money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(0)} CFA';
  }
}
