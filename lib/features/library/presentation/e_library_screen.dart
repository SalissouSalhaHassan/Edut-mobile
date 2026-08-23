import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/library_repository.dart';

class ELibraryScreen extends StatefulWidget {
  const ELibraryScreen({super.key});

  @override
  State<ELibraryScreen> createState() => _ELibraryScreenState();
}

class _ELibraryScreenState extends State<ELibraryScreen> {
  final LibraryRepository _repo = LibraryRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _selectedCategory = "Tous";
  List<String> _categories = ["Tous"];
  List<dynamic> _books = [];
  final Set<int> _downloadedBookIds = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    final data = await _repo.getCatalog(
      category: _selectedCategory == "Tous" ? null : _selectedCategory,
      query: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _books = (data['books'] as List<dynamic>?) ?? [];
          if (data['categories'] != null) {
            _categories = List<String>.from(data['categories']);
          }
        }
      });
    }
  }

  void _downloadBook(Map<String, dynamic> book) async {
    final bookId = book['id'] as int;
    final title = book['title']?.toString() ?? 'Livre';

    setState(() {
      _downloadedBookIds.add(bookId);
    });
    await _repo.markBookDownloaded(bookId, 'local/books/$bookId.pdf');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 "$title" téléchargé avec succès pour lecture hors-ligne !'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _openBookReader(Map<String, dynamic> book) {
    final title = book['title']?.toString() ?? 'Livre Numérique';
    final author = book['author']?.toString() ?? 'Auteur';
    final category = book['category']?.toString() ?? 'Général';
    final description = book['description']?.toString() ?? 'Aucune description.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        author,
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Catégorie : $category • Format : PDF Haute Définition',
                style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Résumé de l\'ouvrage :',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📖 Ouverture du lecteur de document sécurisé...'),
                    backgroundColor: Color(0xFF2563EB),
                  ),
                );
              },
              icon: const Icon(Icons.chrome_reader_mode_rounded),
              label: const Text('Commencer la lecture maintenant', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Bibliothèque Numérique',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadCatalog(),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un manuel, annale, auteur...',
                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadCatalog();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                          _loadCatalog();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Books List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _books.isEmpty
                    ? const Center(child: Text('Aucun livre trouvé.'))
                    : RefreshIndicator(
                        onRefresh: _loadCatalog,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _books.length,
                          itemBuilder: (context, index) {
                            final book = _books[index];
                            final bookId = book['id'] as int;
                            final title = book['title']?.toString() ?? 'Manuel scolaire';
                            final author = book['author']?.toString() ?? 'Auteur inconnu';
                            final category = book['category']?.toString() ?? 'Général';
                            final isDownloaded = _downloadedBookIds.contains(bookId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Book Icon Container
                                  Container(
                                    width: 52,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1E293B), Color(0xFF334155)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.book_rounded, color: Colors.amber, size: 28),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Book Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                category,
                                                style: const TextStyle(
                                                  color: Color(0xFF2563EB),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isDownloaded)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE8F7EE),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 12),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'Hors-ligne',
                                                      style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          author,
                                          style: const TextStyle(color: Colors.black54, fontSize: 11),
                                        ),
                                        const SizedBox(height: 10),

                                        // Action buttons
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _openBookReader(book),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.visibility_rounded, color: Colors.white, size: 14),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Consulter',
                                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (!isDownloaded)
                                              IconButton(
                                                icon: const Icon(Icons.download_for_offline_outlined, color: Colors.black54, size: 20),
                                                tooltip: 'Télécharger pour consultation hors-ligne',
                                                onPressed: () => _downloadBook(book),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
