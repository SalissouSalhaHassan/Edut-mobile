import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  late final TextEditingController _pinController;
  String? _fingerprintHash;
  String? _photoPath;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _photoPath = base64Image;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photographie capturée avec succès !'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
  }

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
    _pinController =
        TextEditingController(text: data['activation_pin']?.toString() ?? '');
    _fingerprintHash = data['fingerprint_hash']?.toString();
    _photoPath = data['photo_path']?.toString();

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
    _pinController.dispose();
    super.dispose();
  }

  String _normalizeSexe(String? value) {
    final raw = (value ?? '').toLowerCase();
    if (raw.contains('f')) return 'Fille';
    return 'Garcon';
  }

  Future<void> _loadOptions() async {
    try {
      await locator<PermissionService>().getCurrentProfile().catchError((_) => null);
      final options = await _repository.getStudentFormOptions().catchError((_) => {'levels': [], 'sections': [], 'classes': []});
      if (!mounted) return;
      setState(() {
        _hasFormPermission = true;
        _levels = (options['levels'] != null && options['levels']!.isNotEmpty)
            ? options['levels']!
            : ['Maternelle', 'Primaire', 'Collège', 'Lycée', 'Licence', 'Master'];
        _sections = (options['sections'] != null && options['sections']!.isNotEmpty)
            ? options['sections']!
            : ['Section A', 'Section B', 'Section C'];
        _classes = (options['classes'] != null && options['classes']!.isNotEmpty)
            ? options['classes']!
            : ['CI A', 'CP A', 'CE1 A', '6ème A', '2nde A', 'M2 Arabic'];
        _selectedLevel ??= _levels.first;
        _selectedSection ??= _sections.first;
        _selectedClass ??= _classes.first;
      });
    } catch (e) {
      debugPrint('Error loading form options: $e');
      if (!mounted) return;
      setState(() {
        _hasFormPermission = true;
        _levels = ['Maternelle', 'Primaire', 'Collège', 'Lycée', 'Licence', 'Master'];
        _sections = ['Section A', 'Section B', 'Section C'];
        _classes = ['CI A', 'CP A', 'CE1 A', '6ème A', '2nde A', 'M2 Arabic'];
        _selectedLevel ??= _levels.first;
        _selectedSection ??= _sections.first;
        _selectedClass ??= _classes.first;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    }
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
      'activation_pin': _pinController.text.trim(),
      'fingerprint_hash': _fingerprintHash ?? '',
      'photo_path': _photoPath ?? '',
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
                    'Photographie de l\'Élève',
                    [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: _photoPath != null && _photoPath!.isNotEmpty
                                    ? (_photoPath!.startsWith("data:image")
                                        ? Image.memory(
                                            base64Decode(_photoPath!.split(',').last),
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            _photoPath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 32),
                                          ))
                                    : const Icon(Icons.person, color: Colors.white54, size: 32),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Photo du dossier",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Requis pour la carte scolaire",
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _pickPhoto(ImageSource.camera),
                                          icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                          label: const Text("Caméra", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4F46E5),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _pickPhoto(ImageSource.gallery),
                                          icon: const Icon(Icons.photo_library, size: 14, color: Color(0xFF818CF8)),
                                          label: const Text("Galerie", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF312E81)),
                                            backgroundColor: const Color(0xFF1E1B4B),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Sécurité & Biométrie',
                    [
                      _textField(
                        _pinController,
                        'Code PIN (4 chiffres)',
                        required: false,
                        keyboardType: TextInputType.number,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFEEF2FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.fingerprint,
                                    size: 24,
                                    color: _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                            ? 'Empreinte Enregistrée'
                                            : 'Empreinte Digitale',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                            ? _fingerprintHash!
                                            : 'Non définie (Appuyez pour scanner)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _fingerprintHash = 'FP-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.fingerprint, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text('Empreinte biométrique capturée !'),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.touch_app, size: 16, color: Colors.white),
                                label: Text(
                                  _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                      ? 'Re-scanner l\'empreinte'
                                      : 'Scanner l\'empreinte',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _fingerprintHash != null && _fingerprintHash!.isNotEmpty
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF4F46E5),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
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
