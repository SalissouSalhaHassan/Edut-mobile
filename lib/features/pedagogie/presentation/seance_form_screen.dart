import 'package:flutter/material.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../data/pedagogie_repository.dart';

/// Form screen for creating or editing a Séance in the Cahier de Textes.
class SeanceFormScreen extends StatefulWidget {
  /// When null, we are in create mode. Otherwise, edit mode.
  final Map<String, dynamic>? existingSeance;

  const SeanceFormScreen({super.key, this.existingSeance});

  @override
  State<SeanceFormScreen> createState() => _SeanceFormScreenState();
}

class _SeanceFormScreenState extends State<SeanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PedagogieRepository();

  final _titreCtr = TextEditingController();
  final _objectifsCtr = TextEditingController();
  final _contenuCtr = TextEditingController();
  final _supportsCtr = TextEditingController();
  final _devoirCtr = TextEditingController();
  final _observationCtr = TextEditingController();
  final _heureDebutCtr = TextEditingController();
  final _heureFinCtr = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedClassId;
  String? _selectedClassName;
  int? _selectedSubjectId;
  String? _selectedSubjectName;

  List<Map<String, dynamic>> _classSubjects = [];
  bool _isLoading = false;
  bool _isSaving = false;
  int? _employeeId;

  bool get _isEditMode => widget.existingSeance != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    setState(() => _isLoading = true);
    try {
      // Load employee id
      final session = locator<SessionManager>();
      final employeeIdStr = await session.getEmployeeId();
      _employeeId = int.tryParse(employeeIdStr ?? '');

      // Load classes/subjects
      _classSubjects = await _repo.getTeacherClassesAndSubjects();

      // If edit mode, populate fields
      if (_isEditMode) {
        final s = widget.existingSeance!;
        _titreCtr.text = s['titre_lecon'] ?? '';
        _objectifsCtr.text = s['objectifs'] ?? '';
        _contenuCtr.text = s['contenu_realise'] ?? '';
        _supportsCtr.text = s['supports_utilises'] ?? '';
        _devoirCtr.text = s['devoir_donne'] ?? '';
        _observationCtr.text = s['observation'] ?? '';
        _heureDebutCtr.text = s['heure_debut'] ?? '';
        _heureFinCtr.text = s['heure_fin'] ?? '';

        if (s['session_date'] != null) {
          _selectedDate = DateTime.tryParse(s['session_date']) ?? DateTime.now();
        }

        _selectedClassId = s['class_id'] as int?;
        _selectedSubjectId = s['subject_id'] as int?;

        // Get names from nested
        final cls = s['school_classes'];
        if (cls != null && cls is Map) {
          _selectedClassName = cls['class_name'] as String?;
        }
        final sub = s['school_subjects'];
        if (sub != null && sub is Map) {
          _selectedSubjectName = sub['subject_name'] as String?;
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titreCtr.dispose();
    _objectifsCtr.dispose();
    _contenuCtr.dispose();
    _supportsCtr.dispose();
    _devoirCtr.dispose();
    _observationCtr.dispose();
    _heureDebutCtr.dispose();
    _heureFinCtr.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une classe et une matière.'),
        ),
      );
      return;
    }
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID employé introuvable.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dateStr = _selectedDate.toIso8601String().split('T').first;

      if (_isEditMode) {
        final id = widget.existingSeance!['id'] as int;
        await _repo.updateSeance(
          id,
          titreLecon: _titreCtr.text.trim(),
          sessionDate: dateStr,
          heureDebut: _heureDebutCtr.text.trim(),
          heureFin: _heureFinCtr.text.trim(),
          objectifs: _objectifsCtr.text.trim(),
          contenuRealise: _contenuCtr.text.trim(),
          supportsUtilises: _supportsCtr.text.trim(),
          devoirDonne: _devoirCtr.text.trim(),
          observation: _observationCtr.text.trim(),
        );
      } else {
        await _repo.createSeance(
          classId: _selectedClassId!,
          subjectId: _selectedSubjectId!,
          employeeId: _employeeId!,
          sessionDate: dateStr,
          titreLecon: _titreCtr.text.trim(),
          heureDebut: _heureDebutCtr.text.trim(),
          heureFin: _heureFinCtr.text.trim(),
          objectifs: _objectifsCtr.text.trim(),
          contenuRealise: _contenuCtr.text.trim(),
          supportsUtilises: _supportsCtr.text.trim(),
          devoirDonne: _devoirCtr.text.trim(),
          observation: _observationCtr.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Séance mise à jour avec succès.'
                  : 'Séance créée avec succès.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true); // signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
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
        appBar: AppBar(title: Text(_isEditMode ? 'Modifier la séance' : 'Nouvelle séance')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        title: Text(
          _isEditMode ? 'Modifier la séance' : 'Nouvelle séance',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Padding(
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
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Enregistrer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
              // ── Classe & Matière ───────────────────────────────────────────
              _sectionCard(
                title: 'Classe & Matière',
                icon: Icons.class_,
                children: [
                  if (_classSubjects.isEmpty)
                    _buildInfoText(
                      _isEditMode
                          ? '${_selectedClassName ?? ''} — ${_selectedSubjectName ?? ''}'
                          : 'Aucune assignation trouvée.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      decoration: _inputDec('Classe — Matière'),
                      initialValue: (_selectedClassId != null && _selectedSubjectId != null)
                          ? '${_selectedClassId}_$_selectedSubjectId'
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
                        final cId = int.parse(parts[0]);
                        final sId = int.parse(parts[1]);
                        final match = _classSubjects.firstWhere(
                          (cs) =>
                              cs['class_id'] == cId && cs['subject_id'] == sId,
                          orElse: () => {},
                        );
                        setState(() {
                          _selectedClassId = cId;
                          _selectedSubjectId = sId;
                          _selectedClassName =
                              (match['school_classes'] as Map?)?['class_name'];
                          _selectedSubjectName =
                              (match['school_subjects'] as Map?)?['subject_name'];
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Sélectionnez une classe et matière' : null,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Date & Horaires ────────────────────────────────────────────
              _sectionCard(
                title: 'Date & Horaires',
                icon: Icons.calendar_today,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: _inputDec('Date de la séance'),
                      child: Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/'
                        '${_selectedDate.month.toString().padLeft(2, '0')}/'
                        '${_selectedDate.year}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heureDebutCtr,
                          decoration: _inputDec('Début (HH:MM)'),
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _heureFinCtr,
                          decoration: _inputDec('Fin (HH:MM)'),
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Contenu pédagogique ────────────────────────────────────────
              _sectionCard(
                title: 'Contenu pédagogique',
                icon: Icons.menu_book,
                children: [
                  TextFormField(
                    controller: _titreCtr,
                    decoration: _inputDec('Titre de la leçon *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _objectifsCtr,
                    decoration: _inputDec('Objectifs'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contenuCtr,
                    decoration: _inputDec('Contenu réalisé'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _supportsCtr,
                    decoration: _inputDec('Supports utilisés'),
                    maxLines: 2,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Devoirs & Observations ─────────────────────────────────────
              _sectionCard(
                title: 'Devoirs & Observations',
                icon: Icons.assignment,
                children: [
                  TextFormField(
                    controller: _devoirCtr,
                    decoration: _inputDec('Devoir donné'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observationCtr,
                    decoration: _inputDec('Observation'),
                    maxLines: 2,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save button
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
                  _isEditMode ? 'Mettre à jour' : 'Créer la séance',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
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

  Widget _sectionCard({
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
              Icon(icon, color: const Color(0xFF6D28D9), size: 18),
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

  InputDecoration _inputDec(String label) {
    return InputDecoration(
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
            const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    );
  }
}
