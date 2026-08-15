import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    Map<String, dynamic>? headerConfig,
  }) async {
    final pdf = pw.Document();

    // Load custom fonts to support Arabic/Unicode text
    final amiriFont = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();

    final studentName = student['nom_etudiant'] ?? 'Sans Nom';
    final admissionNo = student['num_admission'] ?? 'N/A';
    final className = student['classe'] ?? 'Classe';
    final level = student['educational_level'] ?? 'Secteur';

    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final reduction = (payment['reduction'] as num?)?.toDouble() ?? 0.0;
    final datePaidStr = payment['date_paid'] != null
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format(DateTime.parse(payment['date_paid'] as String))
        : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final paymentMode = payment['payment_mode'] ?? 'Especes';
    final reference = payment['reference'] ?? 'N/A';
    final recordedBy = payment['recorded_by'] ?? 'Administration';
    final month = payment['month_concerned'] ?? 'General';
    final paymentId = payment['id'] ?? 0;

    // Decode logos
    pw.MemoryImage? leftLogoImage;
    if (headerConfig?['leftLogo'] != null && headerConfig!['leftLogo'].toString().startsWith('data:image/')) {
      try {
        final base64Str = headerConfig['leftLogo'].toString().split(',').last;
        leftLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (e) {
        debugPrint("Error decoding left logo: $e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          const primaryColor = PdfColor.fromInt(0xFF4F46E5);
          const textColor = PdfColor.fromInt(0xFF1E293B);
          const greyColor = PdfColor.fromInt(0xFF64748B);
          const lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
          const borderGreyColor = PdfColor.fromInt(0xFFCBD5E1);

          // Header layout: either official dual-logo or simple fallback
          pw.Widget headerWidget;
          if (headerConfig != null && headerConfig.isNotEmpty) {
            final country = headerConfig['country'] ?? 'RÉPUBLIQUE DU NIGER';
            final ministry = headerConfig['ministry'] ?? 'MINISTÈRE DE L\'ÉDUCATION NATIONALE';
            final regDir = headerConfig['regionalDirection'] ?? '';
            final deptDir = headerConfig['departmentalDirection'] ?? '';
            final school = headerConfig['schoolName'] ?? 'EDUT ACADEMY';
            final serv = headerConfig['service'] ?? '';

            final countryAr = headerConfig['countryAr'] ?? 'جمهورية النيجر';
            final ministryAr = headerConfig['ministryAr'] ?? 'وزارة التربية الوطنية';
            final regDirAr = headerConfig['regionalDirectionAr'] ?? '';
            final deptDirAr = headerConfig['departmentalDirectionAr'] ?? '';
            final schoolAr = headerConfig['schoolNameAr'] ?? '';
            final servAr = headerConfig['serviceAr'] ?? '';

            headerWidget = pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Column (French)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(country, style: pw.TextStyle(font: amiriBold, fontSize: 8, color: primaryColor)),
                      pw.Text(ministry, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                      if (regDir.isNotEmpty) pw.Text(regDir, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                      if (deptDir.isNotEmpty) pw.Text(deptDir, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                      pw.SizedBox(height: 3),
                      pw.Text(school, style: pw.TextStyle(font: amiriBold, fontSize: 10, color: primaryColor)),
                      if (serv.isNotEmpty) pw.Text(serv, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                    ],
                  ),
                ),
                
                // Center Column (Logo)
                if (leftLogoImage != null)
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    child: pw.Image(leftLogoImage!),
                  ),

                // Right Column (Arabic)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(countryAr, style: pw.TextStyle(font: amiriBold, fontSize: 8, color: primaryColor)),
                      pw.Text(ministryAr, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                      if (regDirAr.isNotEmpty) pw.Text(regDirAr, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                      if (deptDirAr.isNotEmpty) pw.Text(deptDirAr, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                      pw.SizedBox(height: 3),
                      if (schoolAr.isNotEmpty) pw.Text(schoolAr, style: pw.TextStyle(font: amiriBold, fontSize: 10, color: primaryColor)),
                      if (servAr.isNotEmpty) pw.Text(servAr, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: textColor)),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // Fallback (original simple header)
            final fallbackSchoolName = headerConfig?['schoolName'] ?? student['school_name'] ?? 'Établissement Scolaire';
            headerWidget = pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      fallbackSchoolName,
                      style: pw.TextStyle(
                        font: amiriBold,
                        fontSize: 18,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Système de Gestion Scolaire',
                      style: pw.TextStyle(font: amiriFont, fontSize: 10, color: greyColor),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'RECU DE PAIEMENT',
                      style: pw.TextStyle(
                        font: amiriBold,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'No Recu: REC-$paymentId',
                      style: pw.TextStyle(
                        font: amiriBold,
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text('Date: $datePaidStr', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                  ],
                ),
              ],
            );
          }

          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                headerWidget,
                pw.SizedBox(height: 15),
                pw.Divider(color: primaryColor, thickness: 1.5),
                pw.SizedBox(height: 15),
                
                if (headerConfig != null && headerConfig.isNotEmpty) ...[
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'RECU DE PAIEMENT',
                          style: pw.TextStyle(
                            font: amiriBold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'No Recu: REC-$paymentId',
                          style: pw.TextStyle(
                            font: amiriBold,
                            fontSize: 11,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text('Date: $datePaidStr', style: pw.TextStyle(font: amiriFont, fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Divider(color: borderGreyColor, thickness: 0.5),
                  pw.SizedBox(height: 15),
                ],

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ELEVE / STUDENT',
                            style: pw.TextStyle(
                              font: amiriBold,
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Nom: $studentName',
                            style: pw.TextStyle(
                              font: amiriBold,
                              fontSize: 11,
                            ),
                          ),
                          pw.Text('Matricule: $admissionNo', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                          pw.Text('Classe: $className', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                          pw.Text('Niveau: $level', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DETAILS DU PAIEMENT',
                            style: pw.TextStyle(
                              font: amiriBold,
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Mode: $paymentMode', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                          pw.Text('Reference: $reference', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                          pw.Text('Mois: $month', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                          pw.Text('Enregistre par: $recordedBy', style: pw.TextStyle(font: amiriFont, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                       pw.TableHelper.fromTextArray(
                  headers: const [
                    'Description',
                    'Montant',
                    'Réduction',
                    'Total imputé',
                  ],
                  data: [
                    [
                      'Frais de scolarite - Periode: $month',
                      _formatCfa(amount),
                      _formatCfa(reduction),
                      _formatCfa(amount + reduction),
                    ],
                  ],
                  headerStyle: pw.TextStyle(
                    font: amiriBold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: primaryColor),
                  cellStyle: pw.TextStyle(font: amiriFont),
                  cellHeight: 30,
                ),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: const pw.BoxDecoration(
                      color: lightBgColor,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryRow('Montant verse:', _formatCfa(amount), font: amiriFont, boldFont: amiriBold, isBold: true),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Reduction:', _formatCfa(reduction), font: amiriFont, boldFont: amiriBold),
                        pw.SizedBox(height: 8),
                        pw.Divider(color: borderGreyColor),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Total attendu:', _formatCfa(totalExpected), font: amiriFont, boldFont: amiriBold),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow(
                          'Solde restant:',
                          _formatCfa(remainingBalance),
                          font: amiriFont,
                          boldFont: amiriBold,
                          isBold: true,
                          color: const PdfColor.fromInt(0xFFC53030),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Signature eleve / parent',
                          style: pw.TextStyle(font: amiriFont, fontSize: 10, fontStyle: pw.FontStyle.italic),
                        ),
                        pw.SizedBox(height: 40),
                        pw.Container(width: 120, height: 1, color: borderGreyColor),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Le caissier / cachet',
                          style: pw.TextStyle(font: amiriFont, fontSize: 10, fontStyle: pw.FontStyle.italic),
                        ),
                        pw.SizedBox(height: 40),
                        pw.Container(width: 120, height: 1, color: borderGreyColor),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndPrint({
    required Map<String, dynamic> student,
    required Map<String, dynamic> payment,
    required double totalExpected,
    required double remainingBalance,
    Map<String, dynamic>? headerConfig,
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
      headerConfig: headerConfig,
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
    Map<String, dynamic>? headerConfig,
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
      headerConfig: headerConfig,
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

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    required pw.Font font,
    required pw.Font boldFont,
    bool isBold = false,
    PdfColor color = const PdfColor.fromInt(0xFF1E293B),
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: isBold ? boldFont : font,
            fontSize: 10,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: isBold ? boldFont : font,
            fontSize: 10,
            color: color,
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
