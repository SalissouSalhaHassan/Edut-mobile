import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/finance_repository.dart';
import '../utils/receipt_generator.dart';

class StudentFeeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> feeData;

  const StudentFeeDetailsScreen({
    super.key,
    required this.feeData,
  });

  @override
  State<StudentFeeDetailsScreen> createState() => _StudentFeeDetailsScreenState();
}

class _StudentFeeDetailsScreenState extends State<StudentFeeDetailsScreen> {
  final FinanceRepository _repository = locator<FinanceRepository>();

  late Map<String, dynamic> _currentFee;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  bool _canCollectFinance = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentFee = Map<String, dynamic>.from(widget.feeData);
    _fetchPaymentsAndFeeState();
  }

  Future<void> _fetchPaymentsAndFeeState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await locator<PermissionService>().getCurrentProfile();
      final feeId = _currentFee['id'] as int;

      // 1. Fetch payments
      final paymentsList = await _repository.getFeePayments(feeId);

      // 2. Fetch fresh state of this fee row to keep UI synchronized
      Map<String, dynamic> freshFee = Map<String, dynamic>.from(_currentFee);
      try {
        final client = SupabaseClientManager().client;
        final res = await client
            .from('student_fees')
            .select('id, school_id, student_id, session_id, total_expected, total_paid, total_reduction, balance, status')
            .eq('id', feeId)
            .maybeSingle();
        if (res != null) {
          freshFee = Map<String, dynamic>.from(res);
        }
      } catch (_) {}

      // Re-calculate totals from payments if payments exist to guarantee 100% sync
      if (paymentsList.isNotEmpty) {
        double paidSum = 0.0;
        double reductionSum = 0.0;
        for (var p in paymentsList) {
          paidSum += (p['amount'] as num?)?.toDouble() ?? 0.0;
          reductionSum += (p['reduction'] as num?)?.toDouble() ?? 0.0;
        }
        final expected = (freshFee['total_expected'] as num?)?.toDouble() ?? 0.0;
        final balance = (expected - paidSum - reductionSum).clamp(0.0, double.infinity);
        final status = balance <= 0 ? 'Soldé' : paidSum > 0 ? 'Partiel' : 'Impayé';

        freshFee['total_paid'] = paidSum;
        freshFee['total_reduction'] = reductionSum;
        freshFee['balance'] = balance;
        freshFee['status'] = status;
      }

      if (mounted) {
        setState(() {
          _canCollectFinance =
              profile.permissions.contains(AppPermissions.financeCollect);
          _payments = paymentsList;
          // Merge student data from widget's feeData back into the fresh fee map
          final Map<String, dynamic> merged = Map<String, dynamic>.from(freshFee);
          merged['students'] = _currentFee['students'];
          _currentFee = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur de chargement des détails: $e";
        });
      }
    }
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

  Future<void> _printReceipt(Map<String, dynamic> payment) async {
    final student = _currentFee['students'] as Map<String, dynamic>? ?? {};
    final expected = (_currentFee['total_expected'] as num?)?.toDouble() ?? 0.0;
    final balance = (_currentFee['balance'] as num?)?.toDouble() ?? 0.0;
    final schoolId = _currentFee['school_id'] as int?;

    Map<String, dynamic>? headerConfig;
    if (schoolId != null) {
      try {
        final res = await _repository.getDocumentHeader(schoolId);
        if (res['success'] == true) {
          headerConfig = res['data'] as Map<String, dynamic>?;
        }
      } catch (e) {
        debugPrint("Error fetching document header: $e");
      }
    }

    final allPaymentsList = _currentFee['payments'] != null
        ? List<Map<String, dynamic>>.from(_currentFee['payments'])
        : null;

    if (!mounted) return;
    await ReceiptGenerator.showFormatAndActionDialog(
      context: context,
      student: student,
      payment: payment,
      totalExpected: expected,
      remainingBalance: balance,
      allPayments: allPaymentsList,
      headerConfig: headerConfig,
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = _currentFee['students'] as Map<String, dynamic>? ?? {};
    final name = student['nom_etudiant'] ?? 'Sans Nom';
    final admissionNo = student['num_admission'] ?? 'N/A';
    final className = student['classe'] ?? 'Non spécifiée';
    final level = student['educational_level'] ?? 'Secteur';

    final double expected = (_currentFee['total_expected'] as num?)?.toDouble() ?? 0.0;
    final double paid = (_currentFee['total_paid'] as num?)?.toDouble() ?? 0.0;
    final double reduction = (_currentFee['total_reduction'] as num?)?.toDouble() ?? 0.0;
    final double balance = (_currentFee['balance'] as num?)?.toDouble() ?? 0.0;
    final String status = _currentFee['status'] as String? ?? 'Impayé';
    final statusColor = _getStatusColor(status);
    final progress = expected > 0 ? (paid + reduction) / expected : 0.0;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text("Dossier Financier", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                          onPressed: _fetchPaymentsAndFeeState,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Student Info Card
                    _buildStudentProfileHeader(
                      name: name,
                      admissionNo: admissionNo,
                      className: className,
                      level: level,
                      status: status,
                      statusColor: statusColor,
                    ),

                    // Expected, Paid, Balance summary
                    _buildFinancialSummaryBlock(
                      expected: expected,
                      paid: paid,
                      reduction: reduction,
                      balance: balance,
                      progress: progress,
                      statusColor: statusColor,
                    ),

                    // Payments History title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text("Historique des Versements", style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
                          const Spacer(),
                          Text("${_payments.length} versement(s)", style: AppTextStyles.caption),
                        ],
                      ),
                    ),

                    // Payments History List
                    Expanded(
                      child: _payments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.payment_outlined, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Aucun versement enregistré pour le moment.",
                                    style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _payments.length,
                              itemBuilder: (context, index) {
                                final p = _payments[index];
                                final pAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                                final pReduction = (p['reduction'] as num?)?.toDouble() ?? 0.0;
                                final mode = p['payment_mode'] ?? 'Espèces';
                                final ref = p['reference'] ?? '';
                                final month = p['month_concerned'] ?? '';
                                final datePaid = p['date_paid'] != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(p['date_paid'] as String))
                                    : 'N/A';

                                return _buildPaymentTile(
                                  amount: pAmount,
                                  reduction: pReduction,
                                  mode: mode,
                                  reference: ref,
                                  month: month,
                                  dateStr: datePaid,
                                  paymentData: p,
                                );
                              },
                            ),
                    ),

                    // Record Payment Action Container
                    if (balance > 0 && _canCollectFinance)
                      _buildActionButtonContainer(),
                  ],
                ),
    );
  }

  Widget _buildStudentProfileHeader({
    required String name,
    required String admissionNo,
    required String className,
    required String level,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withAlpha(25),
            child: const Icon(Icons.person, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.heading3.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  "Classe: $className • Matricule: $admissionNo",
                  style: const TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Niveau: $level",
                  style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryBlock({
    required double expected,
    required double paid,
    required double reduction,
    required double balance,
    required double progress,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryField("Total Attendu", expected, AppColors.slate800),
              _buildSummaryField("Total Réglé", paid, AppColors.success),
              _buildSummaryField("Réduction", reduction, AppColors.info),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Reste à Payer / Balance:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate500),
              ),
              Text(
                "${balance.toStringAsFixed(0)} FCFA",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: balance > 0 ? AppColors.danger : AppColors.slate800,
                ),
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
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryField(String title, double val, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "${val.toStringAsFixed(0)} F",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _buildPaymentTile({
    required double amount,
    required double reduction,
    required String mode,
    required String reference,
    required String month,
    required String dateStr,
    required Map<String, dynamic> paymentData,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.success.withAlpha(20),
              child: const Icon(Icons.check, color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${amount.toStringAsFixed(0)} FCFA${reduction > 0 ? " (+ ${reduction.toStringAsFixed(0)} F Réd.)" : ""}",
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Mode: $mode${reference.isNotEmpty ? " • Réf: $reference" : ""}",
                    style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                  ),
                  if (month.isNotEmpty)
                    Text(
                      "Mois: $month",
                      style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                    ),
                  Text(
                    dateStr,
                    style: const TextStyle(color: AppColors.slate400, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (_canCollectFinance)
              IconButton(
                icon: const Icon(Icons.print, color: AppColors.primary, size: 20),
                onPressed: () => _printReceipt(paymentData),
                tooltip: "Imprimer le reçu",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () {
            context.push('/finance/record-payment', extra: _currentFee).then((success) {
              if (success == true) {
                _fetchPaymentsAndFeeState();
              }
            });
          },
          icon: const Icon(Icons.add_card, color: Colors.white),
          label: const Text(
            "ENREGISTRER UN VERSEMENT",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
        ),
      ),
    );
  }
}
