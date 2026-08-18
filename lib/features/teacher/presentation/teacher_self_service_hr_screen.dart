import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final emp = _hrData['employee'] as Map<String, dynamic>?;
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
                  child: Row(
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
                            Text('Salaire base : ${emp?['salaireBase']} FCFA', style: const TextStyle(color: Color(0xFFA7F3D0), fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ],
                        ),
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
                      _buildExtraHoursTab(extraHours?['totalEarned'] ?? 0, extraList),

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
                  Text('Base: $base FCFA', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  Text('Primes: +$primes FCFA', style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net à Payer : $net FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F766E))),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📄 Téléchargement du bulletin de paie PDF...'), backgroundColor: Color(0xFF0D9488)),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Fiche PDF', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExtraHoursTab(num totalEarned, List<dynamic> extraList) {
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
                  Text('$totalEarned FCFA', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
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
                        Text('+$amount FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                        const SizedBox(height: 2),
                        Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
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
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
