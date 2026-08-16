import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptGenerator {
  static Future<Uint8List> generatePdfBytes({
    required Map<String, dynamic> student,
    required Map<String, dynamic> payment,
    required double totalExpected,
    required double remainingBalance,
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
    PdfPageFormat pageFormat = PdfPageFormat.a5,
  }) async {
    final pdf = pw.Document();
    final isA5 = pageFormat == PdfPageFormat.a5;

    // Load custom fonts to support Arabic/Unicode text
    final amiriFont = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();

    final studentName = student['nom_etudiant'] ?? student['name'] ?? 'Élève';
    final admissionNo = student['num_admission'] ?? student['matricule'] ?? '—';
    final className = student['classe'] ?? '—';
    final schoolYear = student['session_name'] ?? student['school_year'] ?? '2024–2025';

    final paymentId = payment['id'] ?? 1;
    final totalPaid = totalExpected - remainingBalance > 0
        ? totalExpected - remainingBalance
        : (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final isSolde = remainingBalance <= 0;

    final datePaidStr = payment['date_paid'] != null
        ? DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(payment['date_paid'].toString()))
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Prepare payments list for the History table
    final paymentsList = (allPayments != null && allPayments.isNotEmpty)
        ? allPayments
        : [payment];

    // Decode logos
    pw.MemoryImage? centerLogoImage;
    final logoSource = headerConfig?['centerLogo'] ?? headerConfig?['leftLogo'] ?? headerConfig?['logoPath'];
    if (logoSource != null && logoSource.toString().startsWith('data:image/')) {
      try {
        final base64Str = logoSource.toString().split(',').last;
        centerLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (e) {
        debugPrint("Error decoding receipt logo: $e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(isA5 ? 16 : 26),
        build: (context) {
          const darkNavy = PdfColor.fromInt(0xFF0F172A);
          const primaryIndigo = PdfColor.fromInt(0xFF4F46E5);
          const emeraldGreen = PdfColor.fromInt(0xFF10B981);
          const royalBlue = PdfColor.fromInt(0xFF2563EB);
          const greyColor = PdfColor.fromInt(0xFF64748B);
          const lightBorder = PdfColor.fromInt(0xFFE2E8F0);
          const lightBg = PdfColor.fromInt(0xFFF8FAFC);

          // 1. Header layout
          final country = headerConfig?['country'] ?? 'RÉPUBLIQUE DU NIGER';
          final ministry = headerConfig?['ministry'] ?? 'MINISTÈRE DE L\'ÉDUCATION NATIONALE';
          final school = headerConfig?['schoolName'] ?? 'ÉCOLE EXCELLENCE';
          final service = headerConfig?['service'] ?? 'Service de la Scolarité';
          final phone = headerConfig?['schoolPhone'] ?? '+227 90 12 34 56';
          final email = headerConfig?['schoolEmail'] ?? 'contact@edutacademy.ne';

          final countryAr = headerConfig?['countryAr'] ?? 'جمهورية النيجر';
          final ministryAr = headerConfig?['ministryAr'] ?? 'وزارة التربية الوطنية';
          final schoolAr = headerConfig?['schoolNameAr'] ?? 'ÉCOLE EXCELLENCE';
          final phoneAr = headerConfig?['schoolPhoneAr'] ?? 'الهاتف: 56 34 12 90 227+';
          final emailAr = headerConfig?['schoolEmailAr'] ?? 'البريد: contact@edutacademy.ne';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Top Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left French
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(country, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: darkNavy)),
                        pw.Text(ministry, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 7, color: greyColor)),
                        pw.SizedBox(height: 1),
                        pw.Text(school, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy)),
                        if (service.isNotEmpty) pw.Text(service, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor)),
                        pw.Text('Tél: $phone', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor)),
                        pw.Text('Email: $email', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor)),
                      ],
                    ),
                  ),

                  // Center Logo
                  if (centerLogoImage != null)
                    pw.Container(
                      margin: pw.EdgeInsets.symmetric(horizontal: isA5 ? 6 : 10),
                      width: isA5 ? 36 : 46,
                      height: isA5 ? 36 : 46,
                      child: pw.Image(centerLogoImage),
                    )
                  else
                    pw.Container(width: isA5 ? 36 : 46, height: isA5 ? 36 : 46),

                  // Right Arabic
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(countryAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: darkNavy)),
                        pw.Text(ministryAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 7, color: greyColor)),
                        pw.SizedBox(height: 1),
                        pw.Text(schoolAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy)),
                        pw.Text(phoneAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor)),
                        pw.Text(emailAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: isA5 ? 6 : 8),

              // Title Banner: REÇU DE PAIEMENT + ORIGINAL Badge
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 8 : 12, vertical: isA5 ? 5 : 7),
                decoration: const pw.BoxDecoration(
                  color: darkNavy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REÇU DE PAIEMENT',
                          style: pw.TextStyle(
                            font: amiriBold,
                            fontSize: isA5 ? 10 : 12,
                            color: PdfColors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.Text(
                          'Preuve officielle de paiement des frais scolaires',
                          style: pw.TextStyle(
                            font: amiriFont,
                            fontSize: isA5 ? 6 : 7,
                            color: const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 8 : 10, vertical: isA5 ? 2 : 3),
                      decoration: const pw.BoxDecoration(
                        color: royalBlue,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                      ),
                      child: pw.Text(
                        'ORIGINAL',
                        style: pw.TextStyle(
                          font: amiriBold,
                          fontSize: isA5 ? 6 : 7.5,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: isA5 ? 4 : 6),

              // Reference Badge
              pw.Center(
                child: pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 16 : 22, vertical: isA5 ? 2.5 : 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1F5FF),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFC8D2FF)),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'RÉFÉRENCE : REC-$paymentId',
                    style: pw.TextStyle(
                      font: amiriBold,
                      fontSize: isA5 ? 7 : 8.5,
                      color: primaryIndigo,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: isA5 ? 6 : 8),

              // Student Info + Date & Financial Situation (2 Cards side by side)
              pw.Container(
                padding: pw.EdgeInsets.all(isA5 ? 8 : 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: lightBorder),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Column: Student Info
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INFORMATIONS ÉLÈVE',
                            style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 7.5, color: primaryIndigo),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            studentName,
                            style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 9.5 : 11, color: darkNavy),
                          ),
                          pw.SizedBox(height: 3),
                          _buildDetailRow('Classe', className, amiriFont, amiriBold, isA5: isA5),
                          pw.SizedBox(height: 1.5),
                          _buildDetailRow('Matricule', admissionNo, amiriFont, amiriBold, isA5: isA5),
                          pw.SizedBox(height: 1.5),
                          _buildDetailRow('Année Scolaire', schoolYear, amiriFont, amiriBold, isA5: isA5),
                        ],
                      ),
                    ),

                    // Divider
                    pw.Container(
                      width: 1,
                      height: isA5 ? 58 : 68,
                      color: lightBorder,
                      margin: pw.EdgeInsets.symmetric(horizontal: isA5 ? 6 : 10),
                    ),

                    // Right Column: Date du reçu & Situation Financière
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DATE DU REÇU',
                            style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 7.5, color: emeraldGreen),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            datePaidStr,
                            style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 9.5 : 11, color: darkNavy),
                          ),
                          pw.SizedBox(height: 3),
                          _buildDetailRow('Total Attendu (Frais annuels)', _formatCfa(totalExpected), amiriFont, amiriBold, isA5: isA5),
                          pw.SizedBox(height: 1.5),
                          _buildDetailRow('Total Déjà Payé', _formatCfa(totalPaid), amiriFont, amiriBold, isA5: isA5),
                          pw.SizedBox(height: 2.5),
                          pw.Container(
                            padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 5 : 8, vertical: isA5 ? 2 : 3),
                            decoration: const pw.BoxDecoration(
                              color: royalBlue,
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('SOLDE RESTANT', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5, color: PdfColors.white)),
                                pw.Text(_formatCfa(remainingBalance), style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: PdfColors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: isA5 ? 6 : 8),

              // Table: HISTORIQUE DES VERSEMENTS (6 Columns)
              pw.TableHelper.fromTextArray(
                headers: [
                  'N°',
                  'Date de Paiement',
                  'Référence Paiement',
                  'Mode de Paiement',
                  'Montant (CFA)',
                  'Reçu par',
                ],
                data: paymentsList.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final p = entry.value;
                  final pId = p['id'] ?? idx;
                  final pDate = p['date_paid'] != null
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date_paid'].toString()))
                      : datePaidStr;
                  final pRef = 'PAY-${pId.toString().padLeft(6, '0')}';
                  final pMode = p['payment_mode'] ?? 'Espèces';
                  final pAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                  final pRec = p['recorded_by'] ?? 'Admin Scolarité';
                  return [
                    '$idx',
                    pDate,
                    pRef,
                    pMode,
                    _formatCfa(pAmount).replaceAll(' CFA', ''),
                    pRec,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  font: amiriBold,
                  fontSize: isA5 ? 6.5 : 7.5,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: darkNavy),
                cellStyle: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 6 : 7.5),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
                headerAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
                cellPadding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 4 : 6, vertical: isA5 ? 3 : 4),
              ),

              // Table Footer Row: Total Versé
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightBorder),
                  color: lightBg,
                ),
                padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 8 : 10, vertical: isA5 ? 3.5 : 5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL VERSÉ', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy)),
                    pw.Text(_formatCfa(totalPaid), style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7.5 : 9, color: darkNavy)),
                  ],
                ),
              ),

              pw.SizedBox(height: isA5 ? 8 : 10),

              // Footer: 3 Cards (Certification | Stamp | QR Code)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Left Card: Certification
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      height: isA5 ? 64 : 76,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: lightBorder),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('CERTIFICATION', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7, color: royalBlue)),
                          pw.Text(
                            'Nous certifions que le montant indiqué ci-dessus a été reçu de l\'élève mentionné.',
                            style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor),
                          ),
                          pw.Center(
                            child: pw.Text('Signature & Cachet', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 8),

                  // Center: Circular Official Stamp
                  pw.Container(
                    width: isA5 ? 56 : 70,
                    height: isA5 ? 56 : 70,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: const PdfColor(0.06, 0.09, 0.16, 0.35), width: 1.2),
                    ),
                    child: pw.Center(
                      child: pw.Container(
                        width: isA5 ? 46 : 58,
                        height: isA5 ? 46 : 58,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: const PdfColor(0.06, 0.09, 0.16, 0.35), width: 0.8),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '★ ${school.toUpperCase()} ★\nSERVICE SCOLARITÉ',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 4 : 5, color: const PdfColor(0.06, 0.09, 0.16, 0.45)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 8),

                  // Right Card: QR Code
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      height: isA5 ? 64 : 76,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: lightBorder),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'REC-$paymentId|$studentName|$className|${_formatCfa(totalPaid)}|${_formatCfa(remainingBalance)}',
                            width: isA5 ? 38 : 46,
                            height: isA5 ? 38 : 46,
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text('Scannez pour vérifier l\'authenticité', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                                pw.SizedBox(height: 2),
                                pw.Text('REC-$paymentId', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7, color: royalBlue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: isA5 ? 6 : 8),

              // Security & Legal Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Émis le : $datePaidStr', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  pw.Text('Ce reçu est généré électroniquement et ne nécessite pas de signature manuscrite.', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  pw.Text('Merci pour votre confiance. $school', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> showFormatAndActionDialog({
    required BuildContext context,
    required Map<String, dynamic> student,
    required Map<String, dynamic> payment,
    required double totalExpected,
    required double remainingBalance,
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
  }) async {
    PdfPageFormat selectedFormat = PdfPageFormat.a5;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Exporter / Imprimer le Reçu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Format du papier :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text('A5 — Reçu standard (Défaut)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          selected: selectedFormat == PdfPageFormat.a5,
                          selectedColor: const Color(0xFF4F46E5),
                          labelStyle: TextStyle(
                            color: selectedFormat == PdfPageFormat.a5 ? Colors.white : const Color(0xFF1E293B),
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedFormat = PdfPageFormat.a5);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text('A4 — Reçu détaillé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          selected: selectedFormat == PdfPageFormat.a4,
                          selectedColor: const Color(0xFF4F46E5),
                          labelStyle: TextStyle(
                            color: selectedFormat == PdfPageFormat.a4 ? Colors.white : const Color(0xFF1E293B),
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedFormat = PdfPageFormat.a4);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Imprimer', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await generateAndPrint(
                              student: student,
                              payment: payment,
                              totalExpected: totalExpected,
                              remainingBalance: remainingBalance,
                              allPayments: allPayments,
                              headerConfig: headerConfig,
                              pageFormat: selectedFormat,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFFC8D2FF)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await generateAndShare(
                              student: student,
                              payment: payment,
                              totalExpected: totalExpected,
                              remainingBalance: remainingBalance,
                              allPayments: allPayments,
                              headerConfig: headerConfig,
                              pageFormat: selectedFormat,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> generateAndPrint({
    required Map<String, dynamic> student,
    required Map<String, dynamic> payment,
    required double totalExpected,
    required double remainingBalance,
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
    PdfPageFormat pageFormat = PdfPageFormat.a5,
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
      allPayments: allPayments,
      headerConfig: headerConfig,
      pageFormat: pageFormat,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'recu_paiement_REC-$paymentId.pdf',
    );
  }

  static Future<void> generateAndShare({
    required Map<String, dynamic> student,
    required Map<String, dynamic> payment,
    required double totalExpected,
    required double remainingBalance,
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
    PdfPageFormat pageFormat = PdfPageFormat.a5,
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
      allPayments: allPayments,
      headerConfig: headerConfig,
      pageFormat: pageFormat,
    );

    await SharePlus.instance.share(
      ShareParams(
        text: 'Recu de paiement scolaire',
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: 'recu_paiement_REC-$paymentId.pdf',
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont, {
    bool isA5 = false,
  }) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: isA5 ? 68 : 80,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: isA5 ? 5.5 : 7, color: const PdfColor.fromInt(0xFF64748B)),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(font: font, fontSize: isA5 ? 5.5 : 7, color: const PdfColor.fromInt(0xFF94A3B8))),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: isA5 ? 6 : 7.5,
              color: const PdfColor.fromInt(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatCfa(double amount) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return '${formatter.format(amount).replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ')} CFA';
  }
}
