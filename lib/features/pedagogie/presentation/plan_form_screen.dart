import 'package:flutter/material.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../data/planification_repository.dart';

const _typeOptions = ['Annuel', 'Mensuel', 'Hebdomadaire', 'Officiel'];
const _statutOptions = [
  'Planifié',
  'En cours',
  'Réalisé',
  'En retard',
  'Reporté',
];

const _statutColors = {
  'Planifié': Color(0xFF3B82F6),
  'En cours': Color(0xFFF59E0B),
  'Réalisé': Color(0xFF10B981),
  'En retard': Color(0xFFEF4444),
  'Reporté': Color(0xFF94A3B8),
};

class PlanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPlan;
  const PlanFormScreen({super.key, this.existingPlan});

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PlanificationRepository();

  final _chapCtr = TextEditingController();
  final _leconCtr = TextEditingController();
  final _competenceCtr = TextEditingController();
  final _periodeCtr = TextEditingController();
  final _observationCtr = TextEditingController();

  int? _classId, _subjectId, _employeeId;
  String? _className, _subjectName;
  String _typePlan = 'Annuel';
  String _statut = 'Planifié';
  DateTime? _datePrevue;
  List<Map<String, dynamic>> _classSubjects = [];
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      final session = locator<SessionManager>();
      _employeeId = int.tryParse(await session.getEmployeeId() ?? '');
      _classSubjects = await _repo.getTeacherClassesAndSubjects();

      if (_isEdit) {
        final p = widget.existingPlan!;
        _chapCtr.text = p['chapitre'] ?? '';
        _leconCtr.text = p['lecon_prevue'] ?? '';
        _competenceCtr.text = p['competence_visee'] ?? '';
        _periodeCtr.text = p['periode'] ?? '';
        _observationCtr.text = p['observation'] ?? '';
        _typePlan = p['type_plan'] ?? 'Annuel';
        _statut = p['statut'] ?? 'Planifié';
        _classId = p['class_id'] as int?;
        _subjectId = p['subject_id'] as int?;
        final cls = p['school_classes'];
        if (cls is Map) _className = cls['class_name'] as String?;
        final sub = p['school_subjects'];
        if (sub is Map) _subjectName = sub['subject_name'] as String?;
        if (p['date_prevue'] != null) {
          _datePrevue = DateTime.tryParse(p['date_prevue']);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _chapCtr.dispose();
    _leconCtr.dispose();
    _competenceCtr.dispose();
    _periodeCtr.dispose();
    _observationCtr.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePrevue ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) setState(() => _datePrevue = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null || _subjectId == null || _employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez une classe et une matière.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await _repo.updatePlanification(
          widget.existingPlan!['id'] as int,
          typePlan: _typePlan,
          chapitre: _chapCtr.text.trim(),
          leconPrevue: _leconCtr.text.trim(),
          periode: _periodeCtr.text.trim(),
          competenceVisee: _competenceCtr.text.trim(),
          datePrevue: _datePrevue?.toIso8601String().split('T').first,
          statut: _statut,
          observation: _observationCtr.text.trim(),
        );
      } else {
        await _repo.createPlanification(
          classId: _classId!,
          subjectId: _subjectId!,
          employeeId: _employeeId!,
          typePlan: _typePlan,
          chapitre: _chapCtr.text.trim(),
          leconPrevue: _leconCtr.text.trim(),
          periode: _periodeCtr.text.trim(),
          competenceVisee: _competenceCtr.text.trim(),
          datePrevue: _datePrevue?.toIso8601String().split('T').first,
          statut: _statut,
          observation: _observationCtr.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'Planification mise à jour.' : 'Planification créée.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Modifier le plan' : 'Nouveau plan'),
          backgroundColor: const Color(0xFF0D9488),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'Modifier le plan' : 'Nouveau plan',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Classe & Matière
              _card(
                title: 'Classe & Matière',
                icon: Icons.class_,
                children: [
                  if (_classSubjects.isEmpty)
                    Text(
                      _isEdit
                          ? '${_className ?? ''} — ${_subjectName ?? ''}'
                          : 'Aucune assignation.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    DropdownButtonFormField<String>(
                      decoration: _dec('Classe — Matière'),
                      initialValue:
                          (_classId != null && _subjectId != null)
                              ? '${_classId}_$_subjectId'
                              : null,
                      items: _classSubjects.map((cs) {
                        final cId = cs['class_id'] as int;
                        final sId = cs['subject_id'] as int;
                        final cName =
                            (cs['school_classes'] as Map?)?['class_name'] ?? '';
                        final sName =
                            (cs['school_subjects'] as Map?)?['subject_name'] ?? '';
                        return DropdownMenuItem(
                          value: '${cId}_$sId',
                          child: Text('$cName — $sName'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final parts = val.split('_');
                        setState(() {
                          _classId = int.parse(parts[0]);
                          _subjectId = int.parse(parts[1]);
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Requis' : null,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Type & Statut
              _card(
                title: 'Type & Statut',
                icon: Icons.tune,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _dec('Type'),
                          initialValue: _typePlan,
                          items: _typeOptions
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _typePlan = v ?? 'Annuel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _dec('Statut'),
                          initialValue: _statut,
                          items: _statutOptions
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        color: _statutColors[s] ??
                                            Colors.grey,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _statut = v ?? 'Planifié'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _periodeCtr,
                    decoration: _dec('Période (ex: Trimestre 1, Semaine 5)'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: _dec('Date prévue (optionnel)'),
                      child: Text(
                        _datePrevue != null
                            ? '${_datePrevue!.day.toString().padLeft(2, '0')}/'
                                '${_datePrevue!.month.toString().padLeft(2, '0')}/'
                                '${_datePrevue!.year}'
                            : 'Sélectionner une date',
                        style: TextStyle(
                          color: _datePrevue != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contenu pédagogique
              _card(
                title: 'Contenu pédagogique',
                icon: Icons.menu_book,
                children: [
                  TextFormField(
                    controller: _chapCtr,
                    decoration: _dec('Chapitre *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _leconCtr,
                    decoration: _dec('Leçon prévue *'),
                    maxLines: 2,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _competenceCtr,
                    decoration: _dec('Compétences visées'),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Observation
              _card(
                title: 'Observation',
                icon: Icons.notes,
                children: [
                  TextFormField(
                    controller: _observationCtr,
                    decoration: _dec('Observation'),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isEdit ? 'Mettre à jour' : 'Créer le plan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0D9488), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF0D9488), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
