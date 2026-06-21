import 'package:flutter/material.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/family_repository.dart';

class FamilyLibraryScreen extends StatefulWidget {
  const FamilyLibraryScreen({super.key});

  @override
  State<FamilyLibraryScreen> createState() => _FamilyLibraryScreenState();
}

class _FamilyLibraryScreenState extends State<FamilyLibraryScreen> {
  final FamilyRepository _repository = locator<FamilyRepository>();
  bool _isLoading = true;
  int? _studentId;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _issues = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _studentId =
        int.tryParse(await locator<SessionManager>().getStudentId() ?? '');
    _books = await _repository.getLibraryBooks();
    if (_studentId != null) {
      _issues = await _repository.getStudentLibraryIssues(studentId: _studentId!);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reserveBook(Map<String, dynamic> book) async {
    if (_studentId == null) return;
    final result = await _repository.reserveBook(
      bookId: (book['id'] as num).toInt(),
      studentId: _studentId!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Reservation enregistree.'
              : 'Reservation impossible: ${result['error']}',
        ),
      ),
    );
    if (result['success'] == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Bibliotheque'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Livres disponibles', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  if (_books.isEmpty)
                    _empty('Aucun livre disponible pour le moment.')
                  else
                    ..._books.map(_bookCard),
                  const SizedBox(height: 20),
                  Text('Mes emprunts et retours', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  if (_issues.isEmpty)
                    _empty('Aucun emprunt actif ou historique.')
                  else
                    ..._issues.map(_issueCard),
                ],
              ),
            ),
    );
  }

  Widget _bookCard(Map<String, dynamic> book) {
    final available = (book['available_quantity'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(book['title']?.toString() ?? 'Livre', style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          Text('${book['author'] ?? 'Auteur inconnu'} • ${book['category'] ?? 'General'}'),
          const SizedBox(height: 8),
          Text('Rayon: ${book['shelf_location'] ?? '-'}'),
          Text('Disponibles: $available / ${(book['total_quantity'] as num?)?.toInt() ?? 0}'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: available > 0 ? () => _reserveBook(book) : null,
              icon: const Icon(Icons.bookmark_add, color: Colors.white),
              label: const Text('Reserver', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _issueCard(Map<String, dynamic> issue) {
    final book = issue['library_books'] as Map<String, dynamic>? ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(book['title']?.toString() ?? 'Livre', style: AppTextStyles.bodyBold),
          const SizedBox(height: 6),
          Text('Statut: ${issue['status'] ?? '-'}'),
          Text('Echeance: ${issue['due_date']?.toString().split('T').first ?? '-'}'),
          Text('Retour: ${issue['return_date']?.toString().split('T').first ?? '-'}'),
          Text('Amende: ${issue['fine_amount'] ?? '0'}'),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoration(),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  BoxDecoration _decoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBF0F5)),
    );
  }
}
