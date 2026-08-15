import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum EducationalStage {
  primaire,
  college,
  lycee,
  universite,
}

class OfficialBulletinPdfGenerator {
  /// Detect the educational stage from student data or class name
  static EducationalStage detectStage({
    String? educationalLevel,
    String? className,
  }) {
    final lvl = (educationalLevel ?? '').toLowerCase().trim();
    final cls = (className ?? '').toLowerCase().trim();

    // 1. Check University / Higher Ed
    if (lvl.contains('universit') ||
        lvl.contains('licence') ||
        lvl.contains('master') ||
        lvl.contains('doctorat') ||
        lvl.contains('supérieur') ||
        lvl.contains('superieur') ||
        cls.startsWith('l1') ||
        cls.startsWith('l2') ||
        cls.startsWith('l3') ||
        cls.startsWith('m1') ||
        cls.startsWith('m2') ||
        cls.contains('licence') ||
        cls.contains('master')) {
      return EducationalStage.universite;
    }

    // 2. Check Lycée (High School)
    if (lvl.contains('lycée') ||
        lvl.contains('lycee') ||
        lvl.contains('secondaire') ||
        lvl.contains('second cycle') ||
        cls.contains('2nde') ||
        cls.contains('seconde') ||
        cls.contains('1ère') ||
        cls.contains('premiere') ||
        cls.contains('tle') ||
        cls.contains('terminale')) {
      return EducationalStage.lycee;
    }

    // 3. Check Primary / Kindergarten
    if (lvl.contains('primaire') ||
        lvl.contains('maternelle') ||
        lvl.contains('elementaire') ||
        lvl.contains('élémentaire') ||
        cls.contains('ci') ||
        cls.contains('cp') ||
        cls.contains('ce1') ||
        cls.contains('ce2') ||
        cls.contains('cm1') ||
        cls.contains('cm2') ||
        cls.contains('maternelle')) {
      return EducationalStage.primaire;
    }

    // 4. Default to Collège (Middle School)
    return EducationalStage.college;
  }

  /// Generate Official Multi-Stage Bulletin PDF
  static Future<Uint8List> generateBulletinBytes({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> summary,
    required String period,
    required String sessionName,
    Map<String, dynamic>? headerConfig,
  }) async {
    final pdf = pw.Document();

    // Fonts for Unicode / Arabic
    final amiriRegular = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();

    final studentName = student['nom_etudiant']?.toString() ?? 'Sans Nom';
    final matricule = student['num_admission']?.toString() ??
        student['matricule']?.toString() ??
        'N/A';
    final className = student['classe']?.toString() ?? 'Classe';
    final rawLevel = student['educational_level']?.toString() ?? '';
    final birthDate = student['date_naissance']?.toString() ?? '-';
    final birthPlace = student['lieu_naissance']?.toString() ?? '-';
    final gender = student['sexe']?.toString() ?? 'M';

    final stage = detectStage(educationalLevel: rawLevel, className: className);

    // School Header Logos
    pw.MemoryImage? leftLogoImage;
    if (headerConfig?['leftLogo'] != null &&
        headerConfig!['leftLogo'].toString().startsWith('data:image/')) {
      try {
        final base64Str = headerConfig['leftLogo'].toString().split(',').last;
        leftLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (_) {}
    }

    final schoolName = headerConfig?['schoolName']?.toString() ?? 'ÉCOLE EXCELLENCE';
    final country = headerConfig?['country']?.toString() ?? 'RÉPUBLIQUE DU NIGER';
    final ministry = headerConfig?['ministry']?.toString() ??
        (stage == EducationalStage.universite
            ? 'MINISTÈRE DE L\'ENSEIGNEMENT SUPÉRIEUR ET DE LA RECHERCHE'
            : 'MINISTÈRE DE L\'ÉDUCATION NATIONALE');
    final address = headerConfig?['address']?.toString() ?? '';
    final phone = headerConfig?['phone']?.toString() ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Header (School & Republic)
              _buildHeader(
                country: country,
                ministry: ministry,
                schoolName: schoolName,
                address: address,
                phone: phone,
                sessionName: sessionName,
                logo: leftLogoImage,
                amiriBold: amiriBold,
              ),

              pw.SizedBox(height: 10),

              // 2. Stage Specific Title Banner
              _buildStageTitleBanner(stage, period),

              pw.SizedBox(height: 10),

              // 3. Student Identification Card
              _buildStudentInfoBox(
                name: studentName,
                matricule: matricule,
                className: className,
                rawLevel: rawLevel,
                birthDate: birthDate,
                birthPlace: birthPlace,
                gender: gender,
                sessionName: sessionName,
                stage: stage,
              ),

              pw.SizedBox(height: 12),

              // 4. Stage Specific Grades Table
              _buildGradesTable(stage, grades),

              pw.SizedBox(height: 12),

              // 5. Summary & Decision Box
              _buildSummaryAndDecisionBox(stage, summary),

              pw.Spacer(),

              // 6. Signatures and Official Seals
              _buildSignaturesBlock(stage),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HEADER
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String country,
    required String ministry,
    required String schoolName,
    required String address,
    required String phone,
    required String sessionName,
    pw.MemoryImage? logo,
    required pw.Font amiriBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo900, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 50,
              height: 50,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  country.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  ministry.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  schoolName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (address.isNotEmpty || phone.isNotEmpty)
                  pw.Text(
                    [address, phone.isNotEmpty ? 'Tél: $phone' : ''].where((e) => e.isNotEmpty).join(' | '),
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                  ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.indigo200),
            ),
            child: pw.Column(
              children: [
                pw.Text('ANNÉE ACADÉMIQUE', style: const pw.TextStyle(fontSize: 6, color: PdfColors.indigo900)),
                pw.Text(sessionName.isNotEmpty ? sessionName : '2024-2025',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  STAGE SPECIFIC TITLE BANNER
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildStageTitleBanner(EducationalStage stage, String period) {
    String title;
    String subTitle;
    PdfColor bannerColor;

    switch (stage) {
      case EducationalStage.primaire:
        title = 'CARNET DE NOTES & COMPÉTENCES (PRIMAIRE)';
        subTitle = 'PÉRIODE : ${period.toUpperCase()}';
        bannerColor = PdfColors.teal800;
        break;
      case EducationalStage.college:
        title = 'BULLETIN DE NOTES DU PREMIER CYCLE (COLLÈGE)';
        subTitle = 'ÉVALUATION : ${period.toUpperCase()}';
        bannerColor = PdfColors.indigo900;
        break;
      case EducationalStage.lycee:
        title = 'BULLETIN DE NOTES DU SECOND CYCLE (LYCÉE)';
        subTitle = 'BILAN SEMESTRIEL / TRIMESTRIEL : ${period.toUpperCase()}';
        bannerColor = PdfColors.blue900;
        break;
      case EducationalStage.universite:
        title = 'RELEVÉ DE NOTES & RÉSULTATS ACADÉMIQUES (LMD)';
        subTitle = 'SEMESTRE : ${period.toUpperCase()}';
        bannerColor = PdfColors.purple900;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bannerColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10, letterSpacing: 0.8),
          ),
          pw.Text(
            subTitle,
            style: pw.TextStyle(color: PdfColors.amber200, fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  STUDENT INFO BOX
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildStudentInfoBox({
    required String name,
    required String matricule,
    required String className,
    required String rawLevel,
    required String birthDate,
    required String birthPlace,
    required String gender,
    required String sessionName,
    required EducationalStage stage,
  }) {
    final String levelLabel = stage == EducationalStage.universite
        ? 'Parcours / Filière'
        : stage == EducationalStage.lycee
            ? 'Série / Niveau'
            : 'Niveau d\'études';

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Nom & Prénom(s) : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.Text(name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.indigo900)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text('Matricule / ID : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(matricule, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(width: 12),
                    pw.Text('Sexe : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(gender, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(width: 1, height: 30, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Classe : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.Text(className, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.indigo900)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text('$levelLabel : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(rawLevel.isNotEmpty ? rawLevel : className, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  GRADES TABLES BY STAGE
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildGradesTable(EducationalStage stage, List<Map<String, dynamic>> grades) {
    switch (stage) {
      case EducationalStage.primaire:
        return _buildPrimaireTable(grades);
      case EducationalStage.college:
        return _buildCollegeTable(grades);
      case EducationalStage.lycee:
        return _buildLyceeTable(grades);
      case EducationalStage.universite:
        return _buildUniversiteTable(grades);
    }
  }

  /// 1. PRIMAIRE TABLE
  static pw.Widget _buildPrimaireTable(List<Map<String, dynamic>> grades) {
    final headers = ['Discipline / Domaine', 'Note / 20', 'Moy. Classe', 'Compétences & Appréciations'];

    final rows = grades.map((g) {
      final subject = g['subject_name']?.toString() ?? 'Discipline';
      final score = (g['total_score'] as num?)?.toDouble() ?? 0.0;
      final classAvg = (g['class_avg'] as num?)?.toDouble() ?? 12.5;
      final appreciation = score >= 16
          ? 'Très bien acquis'
          : score >= 13
              ? 'Bien acquis'
              : score >= 10
                  ? 'Acquis'
                  : 'En voie d\'acquisition';

      return [
        subject,
        score.toStringAsFixed(2),
        classAvg.toStringAsFixed(1),
        appreciation,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['Aucune matière', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(3.5),
      },
    );
  }

  /// 2. COLLÈGE TABLE
  static pw.Widget _buildCollegeTable(List<Map<String, dynamic>> grades) {
    final headers = ['Discipline', 'Devoir /20', 'Compo /20', 'Moy /20', 'Coef', 'Total', 'Rang', 'Appréciation Professeur'];

    final rows = grades.map((g) {
      final subject = g['subject_name']?.toString() ?? 'Discipline';
      final devoir = (g['devoir_score'] as num?)?.toDouble() ?? (g['total_score'] as num?)?.toDouble() ?? 0.0;
      final compo = (g['exam_score'] as num?)?.toDouble() ?? devoir;
      final score = (g['total_score'] as num?)?.toDouble() ?? ((devoir + compo) / 2);
      final coef = (g['coef'] as num?)?.toInt() ?? 2;
      final total = score * coef;
      final rank = g['rank']?.toString() ?? '1er';
      final appreciation = score >= 16 ? 'Excellent' : score >= 14 ? 'Très Bien' : score >= 12 ? 'Assez Bien' : score >= 10 ? 'Passable' : 'Insuffisant';

      return [
        subject,
        devoir.toStringAsFixed(1),
        compo.toStringAsFixed(1),
        score.toStringAsFixed(2),
        coef.toString(),
        total.toStringAsFixed(2),
        rank,
        appreciation,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['Aucune matière', '-', '-', '-', '-', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(0.8),
        7: const pw.FlexColumnWidth(2.6),
      },
    );
  }

  /// 3. LYCÉE TABLE
  static pw.Widget _buildLyceeTable(List<Map<String, dynamic>> grades) {
    final headers = ['Matière', 'Éval. Continue', 'Compo', 'Moyenne /20', 'Coef', 'Points', 'Rang', 'Min-Max Classe', 'Visa & Appréciation'];

    final rows = grades.map((g) {
      final subject = g['subject_name']?.toString() ?? 'Matière';
      final score = (g['total_score'] as num?)?.toDouble() ?? 0.0;
      final coef = (g['coef'] as num?)?.toInt() ?? 3;
      final points = score * coef;
      final rank = g['rank']?.toString() ?? '-';
      final minMax = '${(g['min_score'] ?? 8).toStringAsFixed(0)} - ${(g['max_score'] ?? 18).toStringAsFixed(0)}';
      final appreciation = score >= 16 ? 'Très satisfaisant' : score >= 12 ? 'Bon travail' : score >= 10 ? 'Travail convenable' : 'Doit redoubler d\'efforts';

      return [
        subject,
        score.toStringAsFixed(1),
        score.toStringAsFixed(1),
        score.toStringAsFixed(2),
        coef.toString(),
        points.toStringAsFixed(2),
        rank,
        minMax,
        appreciation,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['Aucune matière', '-', '-', '-', '-', '-', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(1.3),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(0.8),
        7: const pw.FlexColumnWidth(1.3),
        8: const pw.FlexColumnWidth(2.2),
      },
    );
  }

  /// 4. UNIVERSITÉ / LICENCE / MASTER (LMD) TABLE
  static pw.Widget _buildUniversiteTable(List<Map<String, dynamic>> grades) {
    final headers = ['Code UE', 'Intitulé de l\'Unité d\'Enseignement', 'CC /20', 'Examen /20', 'Moyenne /20', 'Crédits ECTS', 'Résultat UE', 'Session'];

    final rows = grades.map((g) {
      final code = g['subject_code']?.toString() ?? 'UE';
      final subject = g['subject_name']?.toString() ?? 'Enseignement';
      final cc = (g['cc_score'] as num?)?.toDouble() ?? (g['total_score'] as num?)?.toDouble() ?? 0.0;
      final exam = (g['exam_score'] as num?)?.toDouble() ?? cc;
      final moy = (g['total_score'] as num?)?.toDouble() ?? ((cc * 0.4) + (exam * 0.6));
      final credits = (g['credits'] as num?)?.toInt() ?? 6;
      final isValid = moy >= 10.0;
      final result = isValid ? 'VALIDÉ (V)' : 'NON VALIDÉ (NV)';

      return [
        code,
        subject,
        cc.toStringAsFixed(1),
        exam.toStringAsFixed(1),
        moy.toStringAsFixed(2),
        credits.toString(),
        result,
        'Normale',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['-', 'Aucune unité d\'enseignement', '-', '-', '-', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.purple900),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(3.8),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.3),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(1.8),
        7: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SUMMARY & DECISION BOX
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSummaryAndDecisionBox(EducationalStage stage, Map<String, dynamic> summary) {
    final avg = (summary['average'] as num?)?.toDouble() ?? 0.0;
    final totalPoints = (summary['totalPoints'] as num?)?.toDouble() ?? 0.0;
    final totalCoef = (summary['totalCoef'] as num?)?.toInt() ?? 1;
    final rank = summary['rank']?.toString() ?? '1er';
    final classAvg = (summary['classAvg'] as num?)?.toDouble() ?? 12.0;

    String mention = 'Passable';
    if (avg >= 16) {
      mention = 'Très Bien';
    } else if (avg >= 14) {
      mention = 'Bien';
    } else if (avg >= 12) {
      mention = 'Assez Bien';
    } else if (avg < 10) {
      mention = 'Ajourné / Insuffisant';
    }

    String decision = avg >= 10 ? 'Admis(e) en classe supérieure' : 'À surveiller / Rattrapage';
    if (stage == EducationalStage.universite) {
      decision = avg >= 10 ? 'Semestre Validé avec Mention' : 'Semestre Non Validé - Session de Rattrapage';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('MOYENNE GÉNÉRALE : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
                  pw.Text('${avg.toStringAsFixed(2)} / 20', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: avg >= 10 ? PdfColors.green800 : PdfColors.red800)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text('Moyenne de la classe : ${classAvg.toStringAsFixed(2)} / 20 | Rang : $rank', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  pw.Text('Mention : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                  pw.Text(mention, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.indigo900)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text('Décision : $decision', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: avg >= 10 ? PdfColors.green800 : PdfColors.red800)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SIGNATURES
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSignaturesBlock(EducationalStage stage) {
    String sig1 = 'Le Maître / Enseignant';
    String sig2 = 'Le Directeur de l\'École';

    if (stage == EducationalStage.college) {
      sig1 = 'Le Professeur Principal';
      sig2 = 'Le Principal du Collège';
    } else if (stage == EducationalStage.lycee) {
      sig1 = 'Le Professeur Principal';
      sig2 = 'Le Proviseur du Lycée';
    } else if (stage == EducationalStage.universite) {
      sig1 = 'Le Chef de Département';
      sig2 = 'Le Doyen / Directeur Académique';
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(sig1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 28),
              pw.Text('(Signature & Visa)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Fait le : $dateStr', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(sig2, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 20),
              pw.Text('(Sceau & Signature Officielle)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }
}
