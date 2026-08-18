import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PastExamsScreen extends StatefulWidget {
  const PastExamsScreen({super.key});

  @override
  State<PastExamsScreen> createState() => _PastExamsScreenState();
}

class _PastExamsScreenState extends State<PastExamsScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _selectedExamType = "Tous";
  String _selectedSubject = "Toutes";
  String _selectedYear = "Toutes";

  List<String> _examTypes = ["Tous", "BEPC", "BAC D", "BAC C", "BAC A"];
  List<String> _subjects = ["Toutes", "Mathématiques", "Physique-Chimie", "SVT", "Français", "Philosophie", "Histoire-Géo"];
  List<String> _years = ["Toutes", "2025", "2024", "2023", "2022", "2021"];
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson(
        '/api/mobile/e-library/past-exams?examType=$_selectedExamType&subject=$_selectedSubject&year=$_selectedYear',
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _examTypes = List<String>.from(data['examTypes'] ?? _examTypes);
          _subjects = List<String>.from(data['subjects'] ?? _subjects);
          _years = List<String>.from(data['years'] ?? _years);
          _exams = List<Map<String, dynamic>>.from(data['exams'] ?? []);
          _filtered = _exams;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _exams;
      } else {
        _filtered = _exams.where((e) {
          final t = (e['title'] ?? '').toString().toLowerCase();
          final s = (e['subject'] ?? '').toString().toLowerCase();
          return t.contains(q) || s.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Annales Nationales & Examens", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Sujets officiels BEPC & BAC avec corrigés types", style: TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: _filterSearch,
                  decoration: InputDecoration(
                    hintText: "Rechercher une épreuve ou matière...",
                    hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Exam Type selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _examTypes.map((type) {
                      final isSel = type == _selectedExamType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSel,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() => _selectedExamType = type);
                              _loadExams();
                            }
                          },
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.white : AppColors.slate700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Exams list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book_rounded, color: AppColors.slate400, size: 40),
                            const SizedBox(height: 12),
                            Text("Aucune annale trouvée pour ces critères.", style: AppTextStyles.caption),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final exam = _filtered[index];
                          return _buildExamCard(exam);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final title = exam['title'] ?? 'Épreuve officielle';
    final subject = exam['subject'] ?? 'Matière';
    final year = exam['year']?.toString() ?? '2025';
    final examType = exam['examType'] ?? 'BEPC';
    final size = exam['fileSize'] ?? '1.5 MB';
    final hasKey = exam['hasAnswerKey'] == true;
    final desc = exam['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$examType • Session $year',
                  style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ),
              if (hasKey)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                      SizedBox(width: 4),
                      Text('Corrigé type inclus', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 10.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 11.5, color: AppColors.slate600)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taille PDF : $size', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ouverture du sujet PDF : $title'), backgroundColor: const Color(0xFF2563EB)),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                    label: const Text('Consulter', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Téléchargement hors-ligne terminé : $title'), backgroundColor: AppColors.success),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                    label: const Text('Télécharger', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
