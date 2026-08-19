import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/finance_repository.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final FinanceRepository _repository = locator<FinanceRepository>();

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _canCollectFinance = false;
  String? _errorMessage;

  int _schoolId = 1;
  int? _selectedSessionId;
  String _selectedSessionName = '';

  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _fees = [];
  List<Map<String, dynamic>> _filteredFees = [];

  Map<String, dynamic> _stats = {
    'totalExpected': 0.0,
    'totalCollected': 0.0,
    'totalDebts': 0.0,
  };

  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'Tous'; // 'Tous' | 'Impayé' | 'Partiel' | 'Soldé'

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await locator<PermissionService>().getCurrentProfile();
      final sessionManager = locator<SessionManager>();
      final schoolIdStr = await sessionManager.getSchoolId();
      _schoolId = int.tryParse(schoolIdStr ?? '') ?? 1;
      _canCollectFinance =
          profile.permissions.contains(AppPermissions.financeCollect);

      // Fetch school sessions
      _sessions = await _repository.getSessions(_schoolId);

      if (_sessions.isNotEmpty) {
        // Find active session or default to the first one
        final activeSession = _sessions.firstWhere(
          (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
          orElse: () => _sessions.first,
        );
        _selectedSessionId = (activeSession['id'] as num?)?.toInt() ?? 1;
        _selectedSessionName = activeSession['session_name']?.toString() ?? '';

        await _fetchFinanceData();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Aucune session académique configurée.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur de chargement: $e";
      });
    }
  }

  Future<void> _fetchFinanceData() async {
    if (_selectedSessionId == null) return;

    try {
      // 1. Fetch stats
      final statsRes = await _repository.getFinanceStats(
        schoolId: _schoolId,
        sessionId: _selectedSessionId!,
      );

      // 2. Fetch student fees
      final feesList = await _repository.getStudentFeesList(
        schoolId: _schoolId,
        sessionId: _selectedSessionId!,
      );

      if (mounted) {
        setState(() {
          if (statsRes['success'] == true) {
            _stats = statsRes['stats'];
          }
          _fees = feesList;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur lors de la récupération des données: $e";
        });
      }
    }
  }

  String _clean(dynamic val) {
    if (val == null) return '';
    return val
        .toString()
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  void _applyFilters() {
    final query = _clean(_searchController.text);

    setState(() {
      _filteredFees = _fees.where((fee) {
        final student = fee['students'] as Map<String, dynamic>? ?? {};
        final name = _clean(student['nom_etudiant']);
        final code = _clean(student['num_admission']);
        final classe = _clean(student['classe']);
        final level = _clean(student['educational_level']);

        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            code.contains(query) ||
            classe.contains(query) ||
            level.contains(query);

        final rawStatus = _clean(fee['status']);
        final targetStatus = _clean(_statusFilter);

        bool matchesStatus = _statusFilter == 'Tous' || targetStatus.isEmpty;
        if (!matchesStatus) {
          if (targetStatus.contains('solde') || targetStatus.contains('paye')) {
            matchesStatus = rawStatus.contains('solde') || rawStatus.contains('paye');
          } else if (targetStatus.contains('partiel')) {
            matchesStatus = rawStatus.contains('partiel');
          } else if (targetStatus.contains('impay') || targetStatus.contains('retard')) {
            matchesStatus = rawStatus.contains('impay') || rawStatus.contains('retard');
          } else {
            matchesStatus = rawStatus == targetStatus;
          }
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _handleSync() async {
    if (_selectedSessionId == null) return;

    setState(() {
      _isSyncing = true;
    });

    final res = await _repository.syncStudentFees(
      schoolId: _schoolId,
      sessionId: _selectedSessionId!,
    );

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Dossiers synchronisés: ${res['inserted']} créés, ${res['updated']} mis à jour."),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchFinanceData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? "Une erreur est survenue lors de la synchronisation."),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showSessionSelector() {
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
                const SizedBox(height: 8),
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
                    "Sélectionner la Session",
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
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final item = _sessions[index];
                      final id = item['id'] as int;
                      final name = item['session_name'] as String;
                      final isActive = item['is_active'] == true;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? AppColors.success.withAlpha(25) : AppColors.slate100,
                          child: Icon(
                            Icons.calendar_today,
                            color: isActive ? AppColors.success : AppColors.slate500,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: id == _selectedSessionId ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: id == _selectedSessionId ? const Icon(Icons.check, color: AppColors.primary) : null,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedSessionId = id;
                            _selectedSessionName = name;
                            _isLoading = true;
                          });
                          _fetchFinanceData();
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Soldé':
        return AppColors.success;
      case 'Partiel':
        return AppColors.warning;
      case 'Impayé':
      default:
        return AppColors.danger;
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF0D9488),
      const Color(0xFF7C3AED),
      const Color(0xFF2563EB),
      const Color(0xFFEA580C),
      const Color(0xFFDB2777),
    ];
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text("Gestion Financière", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_rounded, color: Color(0xFF6366F1)),
            onPressed: () => context.push('/finance/forecast'),
            tooltip: "Prévisions de Trésorerie & Cashflow",
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            onPressed: _showSessionSelector,
            tooltip: "Changer de Session",
          ),
          if (!_isLoading && _canCollectFinance)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.sync, color: AppColors.primary),
              onPressed: _isSyncing ? null : _handleSync,
              tooltip: "Synchroniser les dossiers",
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
                        Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Overview Stats Card
                    _buildStatsCard(),

                    // Search & Filter Bar
                    _buildFilterSection(),

                    // Student list
                    Expanded(
                      child: _filteredFees.isEmpty
                          ? const Center(
                              child: Text(
                                "Aucun dossier financier trouvé.",
                                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _filteredFees.length,
                              itemBuilder: (context, index) {
                                final fee = _filteredFees[index];
                                final student = fee['students'] as Map<String, dynamic>? ?? {};
                                final name = student['nom_etudiant'] ?? 'Sans Nom';
                                final admissionNo = student['num_admission'] ?? 'N/A';
                                final className = student['classe'] ?? 'Non spécifiée';
                                final expected = (fee['total_expected'] as num?)?.toDouble() ?? 0.0;
                                final paid = (fee['total_paid'] as num?)?.toDouble() ?? 0.0;
                                final balance = (fee['balance'] as num?)?.toDouble() ?? 0.0;
                                final status = fee['status'] as String? ?? 'Impayé';

                                final initials = name.isNotEmpty
                                    ? name.trim().split(' ').map((e) => e.substring(0, 1)).take(2).join().toUpperCase()
                                    : '?';
                                final avatarColor = _getAvatarColor(name);

                                return _buildFeeCard(
                                  feeId: fee['id'] as int,
                                  name: name,
                                  admissionNo: admissionNo,
                                  className: className,
                                  expected: expected,
                                  paid: paid,
                                  balance: balance,
                                  status: status,
                                  initials: initials,
                                  avatarColor: avatarColor,
                                  feeData: fee,
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsCard() {
    final double expected = (_stats['totalExpected'] as num?)?.toDouble() ?? 0.0;
    final double collected = (_stats['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final double debts = (_stats['totalDebts'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "SESSION : $_selectedSessionName",
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem("Attendu", expected, Colors.white),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMetricItem("Recouvré", collected, AppColors.success),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMetricItem("Solde/Dettes", debts, const Color(0xFFFCA5A5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, double val, Color valueColor) {
    return Column(
      children: [
        Text(
          "${val.toStringAsFixed(0)} F",
          style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Search box
          TextField(
            controller: _searchController,
            onChanged: (v) => _applyFilters(),
            decoration: InputDecoration(
              hintText: "Rechercher par élève ou matricule...",
              prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal filter chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Tous', 'Impayé', 'Partiel', 'Soldé'].map((filter) {
              final isSelected = _statusFilter == filter;
              return ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _statusFilter = filter;
                    });
                    _applyFilters();
                  }
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.slate700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFeeCard({
    required int feeId,
    required String name,
    required String admissionNo,
    required String className,
    required double expected,
    required double paid,
    required double balance,
    required String status,
    required String initials,
    required Color avatarColor,
    required Map<String, dynamic> feeData,
  }) {
    final statusColor = _getStatusColor(status);
    final progress = expected > 0 ? paid / expected : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          context.push('/finance/fee-details', extra: feeData).then((_) {
            // Refresh data when returning from details
            _fetchFinanceData();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                      style: TextStyle(color: avatarColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          "Matricule: $admissionNo • $className",
                          style: const TextStyle(color: AppColors.slate500, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${paid.toStringAsFixed(0)} F / ${expected.toStringAsFixed(0)} F", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                      const Text("Montant Payé / Expected", style: TextStyle(color: AppColors.slate400, fontSize: 9)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${balance.toStringAsFixed(0)} F", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: balance > 0 ? AppColors.danger : AppColors.slate700)),
                      const Text("Solde restant", style: TextStyle(color: AppColors.slate400, fontSize: 9)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.slate100,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
