import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';

class LmsQuizScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final int? studentId;

  const LmsQuizScreen({
    super.key,
    required this.quiz,
    this.studentId,
  });

  @override
  State<LmsQuizScreen> createState() => _LmsQuizScreenState();
}

class _LmsQuizScreenState extends State<LmsQuizScreen> {
  final LmsRepository _repo = LmsRepository();

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // questionId -> answerId
  bool _isSubmitting = false;
  Map<String, dynamic>? _quizResult;

  int _remainingSeconds = 1200; // 20 minutes default
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final duration = widget.quiz['durationMin'] ?? 20;
    _remainingSeconds = duration * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitQuiz();
      }
    });
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _quizResult != null) return;
    _timer?.cancel();
    setState(() => _isSubmitting = true);

    final res = await _repo.submitQuiz(
      quizId: widget.quiz['id'],
      answers: _selectedAnswers,
      studentId: widget.studentId,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _quizResult = res;
      });
    }
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.quiz['title']?.toString() ?? 'Évaluation';
    final questions = (widget.quiz['questions'] as List<dynamic>?) ?? [];

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
          if (_quizResult == null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300
                    ? AppColors.error.withOpacity(0.15)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _remainingSeconds < 300 ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _remainingSeconds < 300 ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _quizResult != null
          ? _buildResultsView()
          : questions.isEmpty
              ? const Center(child: Text('Aucune question disponible dans ce quiz.'))
              : _buildQuizQuestionsView(questions),
    );
  }

  Widget _buildQuizQuestionsView(List<dynamic> questions) {
    final q = questions[_currentQuestionIndex];
    final qId = q['id'];
    final qText = q['questionText']?.toString() ?? 'Question';
    final answers = (q['answers'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Index Progress
          Text(
            'Question ${_currentQuestionIndex + 1} sur ${questions.length}',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            backgroundColor: const Color(0xFFE2E8F0),
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 20),

          // Question Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              qText,
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Answer Choices
          Expanded(
            child: ListView.builder(
              itemCount: answers.length,
              itemBuilder: (context, index) {
                final ans = answers[index];
                final ansId = ans['id'];
                final ansText = ans['answerText']?.toString() ?? '';
                final isSelected = _selectedAnswers[qId] == ansId;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAnswers[qId] = ansId;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.black12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            ansText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation Controls
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _currentQuestionIndex--);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Précédent'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentQuestionIndex < questions.length - 1
                      ? () {
                          setState(() => _currentQuestionIndex++);
                        }
                      : _submitQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentQuestionIndex < questions.length - 1 ? 'Suivant' : 'Terminer & Soumettre',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final isPassed = _quizResult?['isPassed'] == true;
    final percentage = _quizResult?['percentage'] ?? 0;
    final scoreOn20 = _quizResult?['scoreOn20'] ?? 0.0;
    final certCode = _quizResult?['certificateCode']?.toString();
    final breakdown = (_quizResult?['questions'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trophy / Result Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPassed
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  isPassed ? Icons.emoji_events_rounded : Icons.cancel_rounded,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  isPassed ? 'Félicitations ! Vous avez réussi !' : 'Score insuffisant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '$scoreOn20 / 20 ($percentage%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (certCode != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🎓 Certificat délivré : $certCode',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Question Breakdown
          Text(
            'Détail des Réponses',
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...breakdown.map((item) {
            final isCorrect = item['isCorrect'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCorrect ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['questionText']?.toString() ?? 'Question',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (!isCorrect && item['correctAnswerText'] != null)
                          Text(
                            'Bonne réponse : ${item['correctAnswerText']}',
                            style: const TextStyle(color: AppColors.success, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Retour au cours'),
          ),
        ],
      ),
    );
  }
}
