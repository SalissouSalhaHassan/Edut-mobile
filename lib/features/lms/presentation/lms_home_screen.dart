import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';
import 'lms_lesson_player_screen.dart';
import 'lms_quiz_screen.dart';

class LmsHomeScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;

  const LmsHomeScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  State<LmsHomeScreen> createState() => _LmsHomeScreenState();
}

class _LmsHomeScreenState extends State<LmsHomeScreen> with SingleTickerProviderStateMixin {
  final LmsRepository _repo = LmsRepository();
  late TabController _tabController;

  bool _isLoading = true;
  String _searchQuery = '';

  List<dynamic> _courses = [];
  List<dynamic> _virtualClasses = [];
  List<dynamic> _assignments = [];
  List<dynamic> _certificates = [];

  int? _selectedCourseId;
  Map<String, dynamic>? _selectedCourseDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getCourses(studentId: widget.studentId),
        _repo.getVirtualClasses(studentId: widget.studentId),
        _repo.getAssignments(studentId: widget.studentId),
        _repo.getCertificates(studentId: widget.studentId),
      ]);

      if (mounted) {
        final coursesRes = results[0] as Map<String, dynamic>?;
        final virtualClassesRes = results[1] as List<dynamic>;
        final assignmentsRes = results[2] as List<dynamic>;
        final certificatesRes = results[3] as List<dynamic>;

        setState(() {
          _isLoading = false;
          _courses = (coursesRes?['data'] as List<dynamic>?) ?? [];
          _virtualClasses = virtualClassesRes;
          _assignments = assignmentsRes;
          _certificates = certificatesRes;

          if (_courses.isNotEmpty && _selectedCourseId == null) {
            _selectCourse(_courses.first['id']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectCourse(int courseId) async {
    setState(() => _selectedCourseId = courseId);
    final res = await _repo.getCourses(
      studentId: widget.studentId,
      courseId: courseId,
    );
    if (mounted && res?['data'] != null) {
      setState(() {
        _selectedCourseDetails = Map<String, dynamic>.from(res!['data']);
      });
    }
  }

  Future<void> _launchMeetingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir le lien de la classe virtuelle')),
          );
        }
      }
    }
  }

  void _showSubmitAssignmentDialog(Map<String, dynamic> assignment) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.upload_file_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remettre le devoir',
                style: AppTextStyles.titleMedium,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignment['title'] ?? 'Devoir',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Rédigez votre réponse ou ajoutez un lien vers votre travail...',
                filled: true,
                fillColor: AppColors.slate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final success = await _repo.submitAssignment(
                assignmentId: assignment['id'],
                studentId: widget.studentId,
                textResponse: text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '✅ Devoir soumis avec succès !' : 'Erreur lors de la remise'),
                    backgroundColor: success ? AppColors.success : AppColors.danger,
                  ),
                );
                if (success) _loadAllData();
              }
            },
            child: const Text('Envoyer mon devoir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'E-Learning & LMS',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
            ),
            if (widget.studentName != null)
              Text(
                widget.studentName!,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadAllData,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.slate500,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              text: 'Cours (${_courses.length})',
            ),
            Tab(
              icon: const Icon(Icons.videocam_rounded, size: 18),
              text: 'Directs (${_virtualClasses.length})',
            ),
            Tab(
              icon: const Icon(Icons.assignment_rounded, size: 18),
              text: 'Devoirs (${_assignments.length})',
            ),
            Tab(
              icon: const Icon(Icons.quiz_rounded, size: 18),
              text: 'Quiz',
            ),
            Tab(
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              text: 'Certificats (${_certificates.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCoursesTab(),
                _buildVirtualClassesTab(),
                _buildAssignmentsTab(),
                _buildQuizzesTab(),
                _buildCertificatesTab(),
              ],
            ),
    );
  }

  // -------------------- TAB 1: COURS --------------------
  Widget _buildCoursesTab() {
    if (_courses.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.menu_book_rounded,
        title: 'Aucun cours disponible',
        subtitle: 'Les cours en ligne et modules de formation seront ajoutés prochainement.',
      );
    }

    final filtered = _courses.filterByQuery(_searchQuery);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Rechercher un cours, une matière...',
              prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black12),
              ),
            ),
          ),
        ),

        // Courses List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final course = filtered[index];
              final isSelected = course['id'] == _selectedCourseId;
              final modulesCount = (course['modules'] as List?)?.length ?? 0;
              final subjectName = course['subject']?['subjectName'] ?? 'Général';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.black12,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  key: PageStorageKey('course_${course['id']}'),
                  initiallyExpanded: isSelected,
                  onExpansionChanged: (expanded) {
                    if (expanded) _selectCourse(course['id']);
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 24),
                  ),
                  title: Text(
                    course['title'] ?? 'Cours',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subjectName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$modulesCount modules',
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                    ],
                  ),
                  children: [
                    if (_selectedCourseDetails != null && _selectedCourseDetails!['id'] == course['id'])
                      _buildCourseModulesContent(_selectedCourseDetails!)
                    else
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCourseModulesContent(Map<String, dynamic> details) {
    final modules = (details['modules'] as List<dynamic>?) ?? [];
    final completionPercentage = details['completionPercentage'] ?? 0;
    final totalLessons = details['totalLessons'] ?? 0;
    final completedLessons = details['completedLessons'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: completionPercentage / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.slate100,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedLessons/$totalLessons ($completionPercentage%)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.slate600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Modules list
          ...modules.map((mod) {
            final modTitle = mod['title'] ?? 'Module';
            final lessons = (mod['lessons'] as List<dynamic>?) ?? [];

            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  modTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${lessons.length} leçons',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
                children: lessons.map((l) {
                  final isDone = l['isCompleted'] == true;
                  final type = l['contentType']?.toString() ?? 'Text';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isDone ? Icons.check_circle : (type == 'Video' ? Icons.play_circle_fill : Icons.article),
                      color: isDone ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      l['title'] ?? 'Leçon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                        color: isDone ? AppColors.slate800 : AppColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LmsLessonPlayerScreen(
                            lesson: l,
                            studentId: widget.studentId,
                          ),
                        ),
                      );
                      _selectCourse(_selectedCourseId!);
                    },
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------- TAB 2: DIRECTS & LIVES --------------------
  Widget _buildVirtualClassesTab() {
    if (_virtualClasses.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.videocam_off_rounded,
        title: 'Aucun direct en cours ou programmé',
        subtitle: 'Les liens des classes virtuelles (Jitsi Meet, Teams, Google Meet) apparaîtront ici.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _virtualClasses.length,
      itemBuilder: (context, index) {
        final v = _virtualClasses[index];
        final isUpcoming = v['status'] == 'À venir';
        final hasAttended = v['hasAttended'] == true;
        final dateStr = v['sessionDate'] != null
            ? DateTime.tryParse(v['sessionDate'])?.toLocal().toString().split('.').first ?? ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUpcoming ? AppColors.primary.withOpacity(0.3) : Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpcoming ? AppColors.success.withOpacity(0.12) : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUpcoming)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                        Text(
                          v['status'] ?? 'Statut',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUpcoming ? AppColors.success : AppColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      v['platform'] ?? 'En direct',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                v['title'] ?? 'Séance en direct',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Matière : ${v['subjectName']} | Enseignant : ${v['teacherName']}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate600),
              ),
              const SizedBox(height: 4),
              Text(
                '📅 $dateStr (${v['duration'] ?? 45} min)',
                style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUpcoming ? AppColors.primary : AppColors.slate700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.launch_rounded, size: 16, color: Colors.white),
                      label: Text(
                        isUpcoming ? 'Rejoindre la séance' : 'Ouvrir l\'enregistrement',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        final url = v['meetingUrl'] ?? v['recordingUrl'] ?? '';
                        if (url.isNotEmpty) _launchMeetingUrl(url);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: hasAttended ? AppColors.success : AppColors.slate300,
                      ),
                    ),
                    icon: Icon(
                      hasAttended ? Icons.check_circle : Icons.how_to_reg,
                      size: 16,
                      color: hasAttended ? AppColors.success : AppColors.slate700,
                    ),
                    label: Text(
                      hasAttended ? 'Présent' : 'Valider',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasAttended ? AppColors.success : AppColors.slate700,
                      ),
                    ),
                    onPressed: hasAttended
                        ? null
                        : () async {
                            final success = await _repo.markVirtualClassAttendance(
                              virtualClassId: v['id'],
                              studentId: widget.studentId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? '✅ Présence confirmée !' : 'Erreur enregistrement'),
                                  backgroundColor: success ? AppColors.success : AppColors.danger,
                                ),
                              );
                              if (success) _loadAllData();
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- TAB 3: DEVOIRS --------------------
  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Aucun devoir pour le moment',
        subtitle: 'Les exercices et travaux maison de vos enseignants seront répertoriés ici.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final a = _assignments[index];
        final sub = a['submission'];
        final isGraded = sub?['isGraded'] == true;
        final hasSubmitted = sub != null;
        final dueDateStr = a['dueDate'] != null
            ? DateTime.tryParse(a['dueDate'])?.toLocal().toString().split(' ').first ?? ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a['subjectName'] ?? 'Matière',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGraded
                          ? AppColors.success.withOpacity(0.12)
                          : hasSubmitted
                              ? AppColors.info.withOpacity(0.12)
                              : AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isGraded
                          ? 'Note : ${sub['score']}/${a['maxScore']}'
                          : hasSubmitted
                              ? '⏳ En attente de correction'
                              : 'À rendre',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isGraded
                            ? AppColors.success
                            : hasSubmitted
                                ? AppColors.info
                                : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                a['title'] ?? 'Devoir',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              if (a['description'] != null && a['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  a['description'],
                  style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Text(
                    'Date limite : $dueDateStr',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    'Barème : /${a['maxScore'] ?? 20}',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate700, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (isGraded && sub['comment'] != null && sub['comment'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.feedback_outlined, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Remarque : ${sub['comment']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate800, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Button to submit work
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSubmitted ? AppColors.slate800 : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(hasSubmitted ? Icons.edit_note : Icons.file_upload_outlined, size: 16, color: Colors.white),
                  label: Text(
                    hasSubmitted ? 'Modifier ma réponse' : 'Remettre mon devoir',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () => _showSubmitAssignmentDialog(a),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- TAB 4: QUIZ & TESTS --------------------
  Widget _buildQuizzesTab() {
    // Collect quizzes across all courses
    final allQuizzes = <Map<String, dynamic>>[];
    for (final c in _courses) {
      final qList = c['quizzes'] as List?;
      if (qList != null) {
        for (final q in qList) {
          allQuizzes.add({
            ...Map<String, dynamic>.from(q),
            'courseTitle': c['title'],
          });
        }
      }
    }

    if (allQuizzes.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.quiz_rounded,
        title: 'Aucun quiz actif',
        subtitle: 'Les évaluations et QCM en ligne seront affichés dès leur activation par les professeurs.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allQuizzes.length,
      itemBuilder: (context, index) {
        final q = allQuizzes[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      q['courseTitle'] ?? 'Formation',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Requis : ${q['passingScore'] ?? 10}/20',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                q['title'] ?? 'Quiz',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              if (q['description'] != null && q['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  q['description'],
                  style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Text(
                    'Durée : ${q['durationMin'] ?? 20} minutes',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Commencer le test',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LmsQuizScreen(
                          quiz: q,
                          studentId: widget.studentId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- TAB 5: CERTIFICATS --------------------
  Widget _buildCertificatesTab() {
    if (_certificates.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.workspace_premium_rounded,
        title: 'Aucun certificat obtenu',
        subtitle: 'Terminez vos cours et réussissez vos examens pour débloquer vos attestations officielles.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        final code = cert['certificateCode'] ?? 'CERT-LMS';
        final dateStr = cert['issueDate'] != null
            ? DateTime.tryParse(cert['issueDate'])?.toLocal().toString().split(' ').first ?? ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1B4B).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
                  ),
                  Text(
                    'Délivré le : $dateStr',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'CERTIFICAT DE RÉUSSITE',
                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                cert['courseTitle'] ?? 'Formation complète',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Code de vérification : $code',
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.amber, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code du certificat copié !')),
                        );
                      },
                      tooltip: 'Copier le code',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyWidget({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

extension CourseFilterExtension on List<dynamic> {
  List<dynamic> filterByQuery(String query) {
    if (query.trim().isEmpty) return this;
    final q = query.toLowerCase().trim();
    return where((c) {
      final title = c['title']?.toString().toLowerCase() ?? '';
      final subject = c['subject']?['subjectName']?.toString().toLowerCase() ?? '';
      return title.contains(q) || subject.contains(q);
    }).toList();
  }
}
