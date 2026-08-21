import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../data/admissions_repository.dart';

class OnlineAdmissionSheet extends StatefulWidget {
  final String? defaultParentPhone;

  const OnlineAdmissionSheet({
    super.key,
    this.defaultParentPhone,
  });

  static Future<void> show(
    BuildContext context, {
    String? defaultParentPhone,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OnlineAdmissionSheet(
        defaultParentPhone: defaultParentPhone,
      ),
    );
  }

  @override
  State<OnlineAdmissionSheet> createState() => _OnlineAdmissionSheetState();
}

class _OnlineAdmissionSheetState extends State<OnlineAdmissionSheet> {
  final AdmissionsRepository _repository = locator<AdmissionsRepository>();

  int _selectedTabIndex = 0; // 0: Nouvelle Inscription, 1: Suivi Dossier

  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _previousSchoolController = TextEditingController();
  final _medicalNotesController = TextEditingController();

  String _gender = 'M';
  String _targetClass = '6ème A';
  String _parentRelation = 'Père';
  bool _isSubmitting = false;
  String? _successAppNumber;

  // Tracking List
  final _trackingPhoneController = TextEditingController();
  bool _isLoadingTracking = false;
  List<Map<String, dynamic>> _trackedApplications = [];

  final List<String> _classesList = [
    'CI', 'CP', 'CE1', 'CE2', 'CM1', 'CM2',
    '6ème A', '6ème B', '5ème A', '5ème B', '4ème A', '4ème B', '3ème A', '3ème B',
    '2nde C', '2nde A', '1ère D', '1ère A', 'Terminale D', 'Terminale A', 'Terminale C'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.defaultParentPhone != null) {
      _parentPhoneController.text = widget.defaultParentPhone!;
      _trackingPhoneController.text = widget.defaultParentPhone!;
      _loadTrackedApplications();
    }
  }

  Future<void> _submitAdmission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final res = await _repository.submitApplication(
      studentFirstName: _firstNameController.text.trim(),
      studentLastName: _lastNameController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      gender: _gender,
      targetClass: _targetClass,
      parentName: _parentNameController.text.trim(),
      parentRelation: _parentRelation,
      parentPhone: _parentPhoneController.text.trim(),
      previousSchool: _previousSchoolController.text.trim(),
      medicalNotes: _medicalNotesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      setState(() {
        _successAppNumber = res['applicationNumber']?.toString() ?? 'ADM-2026';
      });
      _trackingPhoneController.text = _parentPhoneController.text.trim();
      _loadTrackedApplications();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Erreur lors de la soumission.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTrackedApplications() async {
    final phone = _trackingPhoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoadingTracking = true);

    final list = await _repository.checkApplicationStatus(phone: phone);

    if (mounted) {
      setState(() {
        _trackedApplications = list;
        _isLoadingTracking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF059669),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Inscriptions & Admissions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Dépôt de candidature & Suivi en temps réel 🇳🇪",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Tab Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedTabIndex == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        "📝 Nouvelle Inscription",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedTabIndex = 1);
                      _loadTrackedApplications();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedTabIndex == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        "🔍 Suivi des Dossiers",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 1 ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildNewApplicationForm()
                : _buildTrackingView(),
          ),
        ],
      ),
    );
  }

  Widget _buildNewApplicationForm() {
    if (_successAppNumber != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              "Candidature Enregistrée ! 🎉",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              "Numéro de dossier : $_successAppNumber",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Un accusé de réception a été envoyé par SMS/WhatsApp. Vous recevrez une notification dès validation de l'admission.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _successAppNumber = null;
                  _firstNameController.clear();
                  _lastNameController.clear();
                  _dobController.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Inscrire un autre élève", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "1. Informations de l'Élève",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: "Nom de famille *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: "Prénom(s) *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dobController,
                  decoration: InputDecoration(
                    labelText: "Date de naissance (JJ/MM/AAAA) *",
                    hintText: "2012-05-14",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: InputDecoration(
                    labelText: "Genre",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text("Masculin")),
                    DropdownMenuItem(value: 'F', child: Text("Féminin")),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'M'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _targetClass,
            decoration: InputDecoration(
              labelText: "Classe demandée *",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: _classesList
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _targetClass = v ?? '6ème A'),
          ),
          const SizedBox(height: 20),

          const Text(
            "2. Coordonnées du Responsable Légal",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _parentNameController,
                  decoration: InputDecoration(
                    labelText: "Nom du Parent *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _parentRelation,
                  decoration: InputDecoration(
                    labelText: "Lien",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Père', child: Text("Père")),
                    DropdownMenuItem(value: 'Mère', child: Text("Mère")),
                    DropdownMenuItem(value: 'Tuteur', child: Text("Tuteur")),
                  ],
                  onChanged: (v) => setState(() => _parentRelation = v ?? 'Père'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _parentPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Téléphone Principal (SMS / WhatsApp) *",
              hintText: "+227 90 00 00 00",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _previousSchoolController,
            decoration: InputDecoration(
              labelText: "École de provenance",
              hintText: "Nom de l'ancien établissement",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _medicalNotesController,
            decoration: InputDecoration(
              labelText: "Remarques médicales ou allergies",
              hintText: "Asthme, groupe sanguin, etc.",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitAdmission,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Envoyer la demande d'admission ✨",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _trackingPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Numéro de téléphone du parent",
                    hintText: "+227 90 00 00 00",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadTrackedApplications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.search_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _isLoadingTracking
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
              : _trackedApplications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "Aucun dossier trouvé pour ce numéro. Entrez le numéro utilisé lors de la soumission.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trackedApplications.length,
                      itemBuilder: (context, index) {
                        final app = _trackedApplications[index];
                        final status = app['status']?.toString() ?? 'En attente';
                        final matricule = app['generated_matricule'] ?? app['generatedMatricule'];

                        final isAccepted = status == 'Admis / Accepté';
                        final isRejected = status == 'Refusé';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isAccepted ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isAccepted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    app['application_number'] ?? app['applicationNumber'] ?? 'Dossier',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAccepted
                                          ? const Color(0xFFDCFCE7)
                                          : isRejected
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isAccepted
                                            ? const Color(0xFF16A34A)
                                            : isRejected
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "${app['student_last_name'] ?? app['studentLastName']} ${app['student_first_name'] ?? app['studentFirstName']} • Classe : ${app['target_class'] ?? app['targetClass']}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                              ),
                              if (matricule != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.badge_rounded, color: Color(0xFF059669), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Matricule Officiel : $matricule",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
}
