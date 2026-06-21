import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/finance_repository.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> feeData;

  const RecordPaymentScreen({
    super.key,
    required this.feeData,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final FinanceRepository _repository = locator<FinanceRepository>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reductionController = TextEditingController(text: '0');
  final TextEditingController _referenceController = TextEditingController();

  String _paymentMode = 'Espèces';
  String _monthConcerned = 'Général';
  bool _isSaving = false;
  bool _canCollectFinance = false;

  late double _expected;
  late double _paid;
  late double _reduction;
  late double _balance;
  late int _feeId;
  late int _schoolId;

  final List<String> _paymentModes = ['Espèces', 'Chèque', 'Virement', 'Mobile Money'];
  final List<String> _months = [
    'Général', 'Inscription', 'Septembre', 'Octobre', 'Novembre', 'Décembre', 
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin'
  ];

  @override
  void initState() {
    super.initState();
    _feeId = widget.feeData['id'] as int;
    _schoolId = widget.feeData['school_id'] as int;
    _expected = (widget.feeData['total_expected'] as num?)?.toDouble() ?? 0.0;
    _paid = (widget.feeData['total_paid'] as num?)?.toDouble() ?? 0.0;
    _reduction = (widget.feeData['total_reduction'] as num?)?.toDouble() ?? 0.0;
    _balance = (widget.feeData['balance'] as num?)?.toDouble() ?? 0.0;
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canCollectFinance =
          profile.permissions.contains(AppPermissions.financeCollect);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reductionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double get _currentAmountInput => double.tryParse(_amountController.text) ?? 0.0;
  double get _currentReductionInput => double.tryParse(_reductionController.text) ?? 0.0;
  double get _newBalance => _balance - _currentAmountInput - _currentReductionInput;

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final double amount = _currentAmountInput;
    final double reduction = _currentReductionInput;

    if (amount + reduction > _balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le montant total (Versement + Réduction) dépasse le solde restant."),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final session = locator<SessionManager>();
      final email = await session.getEmail() ?? 'Admin';
      final recordedBy = email.split('@').first.toUpperCase();

      final res = await _repository.recordPayment(
        feeId: _feeId,
        schoolId: _schoolId,
        amount: amount,
        reduction: reduction,
        paymentMode: _paymentMode,
        reference: _referenceController.text.trim(),
        monthConcerned: _monthConcerned,
        recordedBy: recordedBy,
        currentPaid: _paid,
        currentReduction: _reduction,
        totalExpected: _expected,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Versement enregistré avec succès !"),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true); // Returns true to trigger refresh in caller screen
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? "Une erreur est survenue lors de la sauvegarde."),
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
            content: Text("Erreur: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.feeData['students'] as Map<String, dynamic>? ?? {};
    final studentName = student['nom_etudiant'] ?? 'Sans Nom';
    final admissionNo = student['num_admission'] ?? 'N/A';
    final className = student['classe'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text("Enregistrer un Versement", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: !_canCollectFinance
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Vous n avez pas la permission d enregistrer un versement.',
                  textAlign: TextAlign.center,
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryLight,
                      child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                          Text(
                            "Matricule: $admissionNo • $className",
                            style: const TextStyle(color: AppColors.slate500, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Balance Display Box
              _buildLiveBalanceWidget(),
              const SizedBox(height: 24),

              // Input: Amount
              Text("Montant versé (FCFA)", style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.slate700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Saisir le montant...",
                  prefixIcon: Icon(Icons.monetization_on, color: AppColors.primary),
                ),
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Le montant est obligatoire.";
                  }
                  final val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return "Veuillez entrer un montant valide supérieur à 0.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Input: Reduction
              Text("Réduction accordée (FCFA)", style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.slate700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reductionController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Saisir la réduction (facultatif)...",
                  prefixIcon: Icon(Icons.card_giftcard, color: AppColors.primary),
                ),
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final val = double.tryParse(value);
                    if (val == null || val < 0) {
                      return "Veuillez entrer une réduction valide positive.";
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Dropdown: Payment Mode
              Text("Mode de Paiement", style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.slate700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.credit_card, color: AppColors.primary),
                ),
                items: _paymentModes.map((mode) {
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Text(mode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _paymentMode = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Dropdown: Month concerned
              Text("Mois concerné", style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.slate700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _monthConcerned,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_month, color: AppColors.primary),
                ),
                items: _months.map((m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _monthConcerned = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Input: Reference
              Text("Référence / N° de pièce", style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.slate700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  hintText: "N° chèque, virement ou transaction Mobile Money...",
                  prefixIcon: Icon(Icons.bookmark_border, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving || !_canCollectFinance ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "VALIDER LE VERSEMENT",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBalanceWidget() {
    final double remaining = _newBalance;
    final bool isOverpaid = remaining < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverpaid ? AppColors.danger.withAlpha(20) : AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverpaid ? AppColors.danger.withAlpha(50) : AppColors.primary.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Solde initial:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.slate500)),
              Text("${_balance.toStringAsFixed(0)} F", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.slate800)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.white70),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOverpaid ? "Excédent (Non autorisé):" : "Nouveau Solde Reste à Payer:",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isOverpaid ? AppColors.danger : AppColors.primary,
                ),
              ),
              Text(
                "${remaining.abs().toStringAsFixed(0)} F",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isOverpaid ? AppColors.danger : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
