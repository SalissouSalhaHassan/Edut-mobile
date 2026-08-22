import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';

class LmsLessonPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final int? studentId;

  const LmsLessonPlayerScreen({
    super.key,
    required this.lesson,
    this.studentId,
  });

  @override
  State<LmsLessonPlayerScreen> createState() => _LmsLessonPlayerScreenState();
}

class _LmsLessonPlayerScreenState extends State<LmsLessonPlayerScreen> {
  final LmsRepository _repo = LmsRepository();
  late TextEditingController _notesController;

  bool _isCompleted = false;
  bool _isSaving = false;
  bool _isDownloadedOffline = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.lesson['isCompleted'] == true;
    _notesController = TextEditingController(
      text: widget.lesson['personalNotes']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _toggleCompleted() async {
    setState(() => _isSaving = true);
    final nextState = !_isCompleted;
    final success = await _repo.saveLessonProgress(
      lessonId: widget.lesson['id'],
      studentId: widget.studentId,
      isCompleted: nextState,
      personalNotes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isCompleted = nextState;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextState ? '✅ Leçon validée !' : 'Leçon marquée comme non terminée'),
            backgroundColor: nextState ? AppColors.success : AppColors.primary,
          ),
        );
      }
    }
  }

  void _toggleDownload() {
    setState(() {
      _isDownloadedOffline = !_isDownloadedOffline;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isDownloadedOffline
              ? '📥 Leçon enregistrée pour consultation hors-ligne !'
              : '🗑️ Fichier local supprimé',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lesson['title']?.toString() ?? 'Leçon';
    final content = widget.lesson['content']?.toString() ??
        'Bienvenue dans cette leçon. Lisez attentivement les explications fournies par votre enseignant ci-dessous.';
    final contentType = widget.lesson['contentType']?.toString() ?? 'Text';
    final videoUrl = widget.lesson['videoUrl']?.toString();
    final duration = widget.lesson['duration'] ?? 15;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDownloadedOffline ? Icons.download_done_rounded : Icons.download_rounded,
              color: _isDownloadedOffline ? AppColors.success : AppColors.textSecondary,
            ),
            tooltip: 'Télécharger pour consultation hors-ligne',
            onPressed: _toggleDownload,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Player Container if Video
            if (contentType == 'Video' || videoUrl != null) ...[
              Container(
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white),
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: 0.45,
                              backgroundColor: Colors.white24,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$duration:00',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contenu Pédagogique',
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$duration min',
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Personal Notes Box
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Mes Notes Personnelles',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Notez ici vos remarques et questions pour le professeur...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mark Completed Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _toggleCompleted,
              icon: _isSaving
                  ? const SizedBox(
                      size: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(_isCompleted ? Icons.check_circle : Icons.check_circle_outline),
              label: Text(
                _isCompleted ? 'Leçon Terminée (Cliquer pour annuler)' : 'Marquer comme Terminée',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCompleted ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
