import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/students_repository.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({
    super.key,
    this.initialData,
  });

  final Map<String, dynamic>? initialData;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final StudentsRepository _repository = locator<StudentsRepository>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _admissionController;
  late final TextEditingController _nameController;
  late final TextEditingController _arabicNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _fatherController;
  late final TextEditingController _monthlyController;
  late final TextEditingController _registrationController;
  late final TextEditingController _balanceController;
  late final TextEditingController _behaviorController;

  bool _isSaving = false;
  bool _isLoadingOptions = true;
  bool _hasFormPermission = false;
  List<String> _levels = [];
  List<String> _sections = [];
  List<String> _classes = [];

  String? _selectedLevel;
  String? _selectedSection;
  String? _selectedClass;
  String _selectedSexe = 'Garcon';
  String _selectedStatus = 'Actif';
  String _selectedCategory = 'General';

  bool get _isEdit => widget.initialData?['id'] != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _admissionController =
        TextEditingController(text: data['num_admission']?.toString() ?? '');
    _nameController =
        TextEditingController(text: data['nom_etudiant']?.toString() ?? '');
    _arabicNameController =
        TextEditingController(text: data['nom_arabe']?.toString() ?? '');
    _mobileController =
        TextEditingController(text: data['mobile']?.toString() ?? '');
    _whatsappController =
        TextEditingController(text: data['whatsapp']?.toString() ?? '');
    _fatherController =
        TextEditingController(text: data['nom_pere']?.toString() ?? '');
    _monthlyController =
        TextEditingController(text: data['frais_mensuels']?.toString() ?? '0');
    _registrationController = TextEditingController(
      text: data['frais_inscription']?.toString() ?? '0',
    );
    _balanceController =
        TextEditingController(text: data['ancien_solde']?.toString() ?? '0');
    _behaviorController =
        TextEditingController(text: data['behavior_score']?.toString() ?? '0');

    _selectedLevel = data['educational_level']?.toString();
    _selectedSection = data['section']?.toString();
    _selectedClass = data['classe']?.toString();
    _selectedSexe = _normalizeSexe(data['sexe']?.toString());
    _selectedStatus = data['statut']?.toString() ?? 'Actif';
    _selectedCategory = data['categorie']?.toString() ?? 'General';

    _loadOptions();
  }

  @override
  void dispose() {
    _admissionController.dispose();
    _nameController.dispose();
    _arabicNameController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _fatherController.dispose();
    _monthlyController.dispose();
    _registrationController.dispose();
    _balanceController.dispose();
    _behaviorController.dispose();
    super.dispose();
  }

  String _normalizeSexe(String? value) {
    final raw = (value ?? '').toLowerCase();
    if (raw.contains('f')) return 'Fille';
    return 'Garcon';
  }

  Future<void> _loadOptions() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    final options = await _repository.getStudentFormOptions();
    if (!mounted) return;
    setState(() {
      _hasFormPermission = _isEdit
          ? profile.permissions.contains(AppPermissions.studentsEdit)
          : profile.permissions.contains(AppPermissions.studentsCreate);
      _levels = options['levels'] ?? [];
      _sections = options['sections'] ?? [];
      _classes = options['classes'] ?? [];
      _selectedLevel ??= _levels.isNotEmpty ? _levels.first : null;
      _selectedSection ??= _sections.isNotEmpty ? _sections.first : null;
      _selectedClass ??= _classes.isNotEmpty ? _classes.first : null;
      _isLoadingOptions = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = {
      'num_admission': _admissionController.text.trim(),
      'nom_etudiant': _nameController.text.trim(),
      'nom_arabe': _arabicNameController.text.trim(),
      'sexe': _selectedSexe,
      'educational_level': _selectedLevel,
      'classe': _selectedClass,
      'section': _selectedSection,
      'categorie': _selectedCategory,
      'nom_pere': _fatherController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'whatsapp': _whatsappController.text.trim(),
      'frais_mensuels':
          double.tryParse(_monthlyController.text.trim().replaceAll(',', '.')) ??
              0,
      'frais_inscription': double.tryParse(
            _registrationController.text.trim().replaceAll(',', '.'),
          ) ??
          0,
      'ancien_solde':
          double.tryParse(_balanceController.text.trim().replaceAll(',', '.')) ??
              0,
      'behavior_score': double.tryParse(
            _behaviorController.text.trim().replaceAll(',', '.'),
          ) ??
          0,
      'statut': _selectedStatus,
    };

    final result = await _repository.saveStudent(
      studentId: widget.initialData?['id'] as int?,
      payload: payload,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Echec enregistrement')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: Text(_isEdit ? 'Modifier etudiant' : 'Ajouter etudiant'),
      ),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : !_hasFormPermission
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Vous n avez pas la permission de modifier cette fiche.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _section(
                    'Identite',
                    [
                      _textField(_admissionController, 'Numero admission'),
                      _textField(_nameController, 'Nom complet'),
                      _textField(_arabicNameController, 'Nom arabe', required: false),
                      _dropdown(
                        label: 'Sexe',
                        value: _selectedSexe,
                        items: const ['Garcon', 'Fille'],
                        onChanged: (value) => setState(() => _selectedSexe = value!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Academique',
                    [
                      _dropdown(
                        label: 'Niveau',
                        value: _selectedLevel,
                        items: _levels,
                        onChanged: (value) => setState(() => _selectedLevel = value),
                      ),
                      _dropdown(
                        label: 'Classe',
                        value: _selectedClass,
                        items: _classes,
                        onChanged: (value) => setState(() => _selectedClass = value),
                      ),
                      _dropdown(
                        label: 'Section',
                        value: _selectedSection,
                        items: _sections,
                        onChanged: (value) => setState(() => _selectedSection = value),
                      ),
                      _dropdown(
                        label: 'Categorie',
                        value: _selectedCategory,
                        items: const ['General', 'Boursier', 'Fils employe'],
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                      ),
                      _dropdown(
                        label: 'Statut',
                        value: _selectedStatus,
                        items: const ['Actif', 'En attente', 'Inactif', 'Diplome', 'Exclu'],
                        onChanged: (value) =>
                            setState(() => _selectedStatus = value!),
                      ),
                      _textField(_behaviorController, 'Conduite /20', keyboardType: TextInputType.number),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Famille et contact',
                    [
                      _textField(_fatherController, 'Nom du tuteur'),
                      _textField(
                        _mobileController,
                        'Mobile',
                        keyboardType: TextInputType.phone,
                      ),
                      _textField(
                        _whatsappController,
                        'WhatsApp',
                        keyboardType: TextInputType.phone,
                        required: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Finances',
                    [
                      _textField(_monthlyController, 'Frais mensuels', keyboardType: TextInputType.number),
                      _textField(_registrationController, 'Frais inscription', keyboardType: TextInputType.number),
                      _textField(_balanceController, 'Ancien solde', keyboardType: TextInputType.number),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving || !_hasFormPermission ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
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
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: required
          ? (value) => (value == null || value.trim().isEmpty) ? 'Champ requis' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
        ),
      ),
    );
  }
}
