import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import '../../../core/di/injection.dart';

class TeacherSelfServiceHrScreen extends StatefulWidget {
  const TeacherSelfServiceHrScreen({super.key});

  @override
  State<TeacherSelfServiceHrScreen> createState() => _TeacherSelfServiceHrScreenState();
}

class _TeacherSelfServiceHrScreenState extends State<TeacherSelfServiceHrScreen>
    with SingleTickerProviderStateMixin {
  final _teacherRepo = locator<TeacherRepository>();
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _hrData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _teacherRepo.getSelfServiceHrData();
      setState(() {
        _hrData = data;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewRequestDialog() {
    final reasonCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String reqType = 'Congé familial';
    int days = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nouvelle Demande Administrative', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      decoration: _inputDec('Type de demande'),
                      value: reqType,
                      items: ['Congé maladie', 'Congé familial', 'Absence autorisée', 'Avance sur salaire', 'Attestation de travail']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => reqType = v ?? reqType),
                    ),
                    const SizedBox(height: 10),
                    if (reqType == 'Avance sur salaire')
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDec('Montant souhaité (FCFA) *'),
                      )
                    else
                      Row(
                        children: [
                          const Text('Nombre de jours : ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('1 j'), selected: days == 1, onSelected: (_) => setModalState(() => days = 1)),
                          const SizedBox(width: 4),
                          ChoiceChip(label: const Text('2 j'), selected: days == 2, onSelected: (_) => setModalState(() => days = 2)),
                          const SizedBox(width: 4),
                          ChoiceChip(label: const Text('3 j'), selected: days == 3, onSelected: (_) => setModalState(() => days = 3)),
                          const SizedBox(width: 4),
                          ChoiceChip(label: const Text('+5 j'), selected: days == 5, onSelected: (_) => setModalState(() => days = 5)),
                        ],
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: _inputDec('Motif détaillé de la demande *'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (reasonCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          await _teacherRepo.submitHrRequest(
                            requestType: reqType,
                            reason: reasonCtrl.text.trim(),
                            daysCount: days,
                            advanceAmount: double.tryParse(amountCtrl.text.trim()),
                          );
                          _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Demande transmise avec succès à l\'administration !'), backgroundColor: Color(0xFF10B981)),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Soumettre la demande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showNewExtraHoursDialog() {
    final classCtrl = TextEditingController(text: '3ème B');
    final subjectCtrl = TextEditingController(text: 'Mathématiques');
    final hoursCtrl = TextEditingController(text: '2.0');
    final rateCtrl = TextEditingController(text: '3000');
    String typeH = 'Heure supplémentaire';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Déclaration de Séance d\'Heures Sup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      decoration: _inputDec('Type d\'intervention'),
                      value: typeH,
                      items: ['Heure supplémentaire', 'Cours de soutien', 'Remplacement/Intérim', 'Surveillance examen']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => typeH = v ?? typeH),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: classCtrl, decoration: _inputDec('Classe'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: subjectCtrl, decoration: _inputDec('Matière'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: hoursCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Nb Heures'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Tarif/h (FCFA)'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _teacherRepo.recordExtraHours(
                            typeHour: typeH,
                            className: classCtrl.text.trim(),
                            subjectName: subjectCtrl.text.trim(),
                            hoursCount: double.tryParse(hoursCtrl.text.trim()) ?? 2.0,
                            hourlyRate: double.tryParse(rateCtrl.text.trim()) ?? 3000.0,
                          );
                          _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Séance déclarée avec succès !'), backgroundColor: Color(0xFF10B981)),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Enregistrer la séance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final num val = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
    final str = val.toInt().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]} ');
  }

  @override
  Widget build(BuildContext context) {
    final emp = _hrData['employee'] as Map<String, dynamic>?;
    final smart = _hrData['smartInsights'] as Map<String, dynamic>? ?? {};
    final payslips = (_hrData['payslips'] as List?) ?? [];
    final extraHours = _hrData['extraHours'] as Map<String, dynamic>?;
    final extraList = (extraHours?['list'] as List?) ?? [];
    final requests = (_hrData['requests'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Espace RH & Paie Enseignant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : Column(
              children: [
                // Top Employee Info Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF115E59), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0D9488).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.badge_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(emp?['name'] ?? 'Professeur', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('${emp?['poste']} • ${emp?['matricule']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('Salaire base : ${_formatAmount(emp?['salaireBase'])} FCFA', style: const TextStyle(color: Color(0xFFA7F3D0), fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Est. Net: ${_formatAmount(smart['projectedNetSalary'] ?? emp?['salaireBase'])} FCFA',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          InkWell(
                            onTap: () => _generateAndPrintAttestationPdf(emp),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text('Attestation PDF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF0D9488),
                  unselectedLabelColor: AppColors.slate500,
                  indicatorColor: const Color(0xFF0D9488),
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Fiches Paie'),
                    Tab(icon: Icon(Icons.more_time_rounded), text: 'Heures Sup'),
                    Tab(icon: Icon(Icons.assignment_rounded), text: 'Demandes'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Payslips Tab
                      _buildPayslipsTab(payslips),

                      // 2. Extra Hours Tab
                      _buildExtraHoursTab(extraHours?['totalEarned'] ?? 0, extraHours?['totalApproved'] ?? 0, extraList),

                      // 3. Requests Tab
                      _buildRequestsTab(requests),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPayslipsTab(List<dynamic> payslips) {
    if (payslips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.slate400),
              const SizedBox(height: 12),
              const Text('Aucun bulletin de paie disponible.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate700)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payslips.length,
      itemBuilder: (context, i) {
        final p = payslips[i];
        final month = p['monthYear'] ?? '';
        final net = p['netSalary'] ?? 0;
        final base = p['basicSalary'] ?? 0;
        final primes = p['totalAllowance'] ?? 0;
        final status = p['status'] ?? 'Payé';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(status, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Base: ${_formatAmount(base)} FCFA', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  Text('Primes: +${_formatAmount(primes)} FCFA', style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net à Payer : ${_formatAmount(net)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F766E))),
                  ElevatedButton.icon(
                    onPressed: () => _generateAndPrintPayslipPdf(p, _hrData['employee']),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                    label: const Text('Fiche PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateAndPrintPayslipPdf(Map<String, dynamic> payslip, Map<String, dynamic>? employee) async {
    try {
      final pdf = pw.Document();
      final month = payslip['monthYear'] ?? 'Mois En Cours';
      final net = (payslip['netSalary'] as num?)?.toInt() ?? 0;
      final base = (payslip['basicSalary'] as num?)?.toInt() ?? 0;
      final primes = (payslip['totalAllowance'] as num?)?.toInt() ?? 0;
      final deductions = (payslip['totalDeduction'] as num?)?.toInt() ?? 0;
      final status = payslip['status'] ?? 'Payé';
      final paymentDate = payslip['paymentDate']?.toString().split('T').first ?? DateTime.now().toIso8601String().split('T').first;
      final paymentMode = payslip['paymentMode'] ?? 'Virement Bancaire';

      final empName = employee?['name'] ?? 'Professeur';
      final empPoste = employee?['poste'] ?? 'Professeur Titulaire';
      final empMatricule = employee?['matricule'] ?? 'ENS-2025-042';
      final empDept = employee?['departement'] ?? 'Sciences Exactes';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RÉPUBLIQUE DU NIGER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('MINISTÈRE DE L\'ÉDUCATION NATIONALE', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('COMPLEXE SCOLAIRE PRIVÉ D\'EXCELLENCE EDUT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal800)),
                        pw.Text('Système Intégré de Gestion Scolaire & RH', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.teal700, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('BULLETIN DE PAIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.teal900)),
                          pw.Text('Période : $month', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(thickness: 1, color: PdfColors.teal700),
                pw.SizedBox(height: 10),

                // Employee Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nom & Prénoms : $empName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Matricule : $empMatricule', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Emploi / Fonction : $empPoste', style: const pw.TextStyle(fontSize: 9.5)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Département : $empDept', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Mode de règlement : $paymentMode', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Date de paiement : $paymentDate', style: const pw.TextStyle(fontSize: 9.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // Earnings & Deductions Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.teal800),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rubrique / Désignation', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Gains (FCFA)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Retenues (FCFA)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10)),
                        ),
                      ],
                    ),
                    // Salaire de base
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Salaire de Base Contractuel', style: const pw.TextStyle(fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$base', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
                      ],
                    ),
                    // Primes
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Indemnités & Primes Pédagogiques', style: const pw.TextStyle(fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$primes', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
                      ],
                    ),
                    // Cotisations & Deductions
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Retenues Fiscales & Sociales (IUTS / CNSS)', style: const pw.TextStyle(fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$deductions', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
                      ],
                    ),
                    // Totaux
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('TOTAL BRUT & DÉDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${base + primes}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$deductions', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Net Pay Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.teal700, width: 1.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('NET À PAYER AU SALARIÉ :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal900)),
                          pw.Text('Statut : $status • Quittance certifiée conforme', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text('$net FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.teal900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 35),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Le Salarié / Titulaire', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 35),
                        pw.Text('Lu et approuvé', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Pour l\'Établissement (Direction)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: 90,
                          height: 35,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.teal700, style: pw.BorderStyle.dashed),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('[ Cachet Numérique & Signature ]', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.teal800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Bulletin_Paie_${month.replaceAll(' ', '_')}_$empMatricule.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateAndPrintAttestationPdf(Map<String, dynamic>? employee) async {
    try {
      final pdf = pw.Document();
      final empName = employee?['name'] ?? 'Professeur';
      final empPoste = employee?['poste'] ?? 'Professeur Titulaire';
      final empMatricule = employee?['matricule'] ?? 'ENS-2025-042';
      final empDept = employee?['departement'] ?? 'Corps Enseignant';
      final now = DateTime.now();
      final dateFormatted = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Official Republic Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RÉPUBLIQUE DU NIGER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('MINISTÈRE DE L\'ÉDUCATION NATIONALE', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('Direction Régionale de l\'Enseignement', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 6),
                        pw.Text('COMPLEXE SCOLAIRE PRIVÉ D\'EXCELLENCE EDUT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal800)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.teal800, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text('EDUT-RH\nREF: ATT-$empMatricule', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1.2, color: PdfColors.teal800),
                pw.SizedBox(height: 30),

                // Title
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.teal50,
                      border: pw.Border.all(color: PdfColors.teal800, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'ATTESTATION DE TRAVAIL & D\'EMPLOI',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.teal900),
                    ),
                  ),
                ),
                pw.SizedBox(height: 35),

                // Body text
                pw.Text(
                  'La Direction Générale du Complexe Scolaire Privé d\'Excellence EDUT certifie et atteste par la présente que :',
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
                ),
                pw.SizedBox(height: 16),

                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Nom & Prénoms : $empName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Text('Matricule Agent : $empMatricule', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('Fonction / Poste : $empPoste', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Département d\'Affectation : $empDept', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                pw.Text(
                  'Est employé(e) au sein de notre établissement scolaire d\'excellence et exerce ses fonctions pédagogiques et d\'encadrement avec régularité, compétence et professionnalisme conformément aux textes régissant l\'enseignement privé au Niger.',
                  style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'La présente attestation lui est délivrée à sa demande pour servir et valoir ce que de droit.',
                  style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5),
                ),
                pw.SizedBox(height: 40),

                // Date and Signature
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Fait à Niamey, le $dateFormatted', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                        pw.SizedBox(height: 20),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.teal700, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('Vérification Numérique EDUT-ID Validée', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.teal800)),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Pour la Direction Générale', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('Le Directeur Général des Études', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: 100,
                          height: 40,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.teal800, style: pw.BorderStyle.dashed),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('[ Cachet Officiel &\nSignature Électronique ]', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, color: PdfColors.teal900, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Attestation_Travail_${empMatricule}_$dateFormatted.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération attestation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildExtraHoursTab(num totalEarned, num totalApproved, List<dynamic> extraList) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Cumulé Heures Sup', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${_formatAmount(totalEarned)} FCFA', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  if (totalApproved > 0) ...[
                    const SizedBox(height: 2),
                    Text('Validé : ${_formatAmount(totalApproved)} FCFA', style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showNewExtraHoursDialog,
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Déclarer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
        if (extraList.isEmpty)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune heure supplémentaire déclarée.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate600)),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: extraList.length,
              itemBuilder: (context, i) {
                final ex = extraList[i];
                final type = ex['typeHour'] ?? 'Heure Sup';
                final cls = ex['className'] ?? '';
                final date = ex['date'] ?? '';
                final amount = ex['totalAmount'] ?? 0;
                final status = ex['status'] ?? 'En attente';
                final isApproved = status == 'Approuvé' || status == 'Payé';
                final isPending = status == 'En attente';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$type • $cls', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(date, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('+${_formatAmount(amount)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFECFDF5) : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isApproved ? const Color(0xFF065F46) : (isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                                fontWeight: FontWeight.bold,
                              ),
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

  Widget _buildRequestsTab(List<dynamic> requests) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _showNewRequestDialog,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Faire une demande (Congé / Avance)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ),
        if (requests.isEmpty)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune demande administrative enregistrée.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate600)),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: requests.length,
              itemBuilder: (context, i) {
                final r = requests[i];
                final type = r['requestType'] ?? '';
                final reason = r['reason'] ?? '';
                final status = r['status'] ?? 'En attente';
                final comment = r['adminComment'] ?? '';
                final isApproved = status == 'Approuvé';
                final isPending = status == 'En attente';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0D9488))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFECFDF5) : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isApproved ? const Color(0xFF065F46) : (isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Motif : $reason', style: const TextStyle(fontSize: 12, color: AppColors.slate800)),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Note Direction : $comment', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF047857))),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );
}
