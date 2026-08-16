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
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
  }) async {
    final pdf = pw.Document();

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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          const darkNavy = PdfColor.fromInt(0xFF0F172A);
          const primaryIndigo = PdfColor.fromInt(0xFF4F46E5);
          const emeraldGreen = PdfColor.fromInt(0xFF10B981);
          const textColor = PdfColor.fromInt(0xFF1E293B);
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
                        pw.Text(country, style: pw.TextStyle(font: amiriBold, fontSize: 8, color: darkNavy)),
                        pw.Text(ministry, style: pw.TextStyle(font: amiriFont, fontSize: 7.5, color: greyColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(school, style: pw.TextStyle(font: amiriBold, fontSize: 8.5, color: darkNavy)),
                        if (service.isNotEmpty) pw.Text(service, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: greyColor)),
                        pw.Text('Tél: $phone', style: pw.TextStyle(font: amiriFont, fontSize: 7, color: greyColor)),
                        pw.Text('Email: $email', style: pw.TextStyle(font: amiriFont, fontSize: 7, color: greyColor)),
                      ],
                    ),
                  ),

                  // Center Logo
                  if (centerLogoImage != null)
                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                      width: 48,
                      height: 48,
                      child: pw.Image(centerLogoImage),
                    )
                  else
                    pw.Container(width: 48, height: 48),

                  // Right Arabic
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(countryAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 8, color: darkNavy)),
                        pw.Text(ministryAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: 7.5, color: greyColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(schoolAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 8.5, color: darkNavy)),
                        pw.Text(phoneAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: greyColor)),
                        pw.Text(emailAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: 7, color: greyColor)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Title Banner: REÇU DE PAIEMENT
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: const pw.BoxDecoration(
                  color: darkNavy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'REÇU DE PAIEMENT',
                    style: pw.TextStyle(
                      font: amiriBold,
                      fontSize: 13,
                      color: PdfColors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 6),

              // Reference Badge
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1F5FF),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFC8D2FF)),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'RÉF : REC-$paymentId',
                    style: pw.TextStyle(
                      font: amiriBold,
                      fontSize: 8.5,
                      color: primaryIndigo,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 10),

              // Student Info + Date & Financial Situation Card (Combined)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
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
                            style: pw.TextStyle(font: amiriBold, fontSize: 8, color: primaryIndigo),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            studentName,
                            style: pw.TextStyle(font: amiriBold, fontSize: 12, color: darkNavy),
                          ),
                          pw.SizedBox(height: 6),
                          _buildDetailRow('Classe', className, amiriFont, amiriBold),
                          pw.SizedBox(height: 3),
                          _buildDetailRow('Matricule', admissionNo, amiriFont, amiriBold),
                          pw.SizedBox(height: 3),
                          _buildDetailRow('Année Scolaire', schoolYear, amiriFont, amiriBold),
                        ],
                      ),
                    ),

                    // Divider
                    pw.Container(
                      width: 1,
                      height: 75,
                      color: lightBorder,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                    ),

                    // Right Column: Date du reçu & Situation Financière
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DATE DU REÇU & SITUATION',
                            style: pw.TextStyle(font: amiriBold, fontSize: 8, color: emeraldGreen),
                          ),
                          pw.SizedBox(height: 4),
                          _buildDetailRow('Date du reçu', datePaidStr, amiriFont, amiriBold),
                          pw.SizedBox(height: 3),
                          _buildDetailRow('Total Attendu', _formatCfa(totalExpected), amiriFont, amiriBold),
                          pw.SizedBox(height: 3),
                          _buildDetailRow('Total Déjà Payé', _formatCfa(totalPaid), amiriFont, amiriBold),
                          pw.SizedBox(height: 4),
                          pw.Divider(color: lightBorder, thickness: 0.5),
                          pw.SizedBox(height: 2),
                          _buildDetailRow(
                            'Solde Restant',
                            _formatCfa(remainingBalance),
                            amiriFont,
                            amiriBold,
                            valueColor: isSolde ? emeraldGreen : primaryIndigo,
                            isBoldVal: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Table: HISTORIQUE DES VERSEMENTS
              pw.TableHelper.fromTextArray(
                headers: [
                  'Réf / N°',
                  'Date de Versement',
                  'Mode',
                  'Motif / Libellé',
                  'Montant Versé',
                ],
                data: paymentsList.map((p) {
                  final pId = p['id'] ?? 1;
                  final pDate = p['date_paid'] != null
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date_paid'].toString()))
                      : datePaidStr;
                  final pMode = p['payment_mode'] ?? 'Espèces';
                  final pMotif = p['month_concerned'] ?? p['remark'] ?? 'Frais de scolarité';
                  final pAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                  return [
                    'VER-$pId',
                    pDate,
                    pMode,
                    pMotif,
                    _formatCfa(pAmount),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 8.5,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: darkNavy),
                cellStyle: pw.TextStyle(font: amiriFont, fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                headerAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              ),

              // Table Footer Totals
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightBorder),
                  color: lightBg,
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL DÉJÀ VERSÉ', style: pw.TextStyle(font: amiriBold, fontSize: 8.5, color: darkNavy)),
                    pw.Text(_formatCfa(totalPaid), style: pw.TextStyle(font: amiriBold, fontSize: 9, color: darkNavy)),
                  ],
                ),
              ),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: primaryIndigo,
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SOLDE RESTANT À PAYER', style: pw.TextStyle(font: amiriBold, fontSize: 9, color: PdfColors.white)),
                    pw.Text(_formatCfa(remainingBalance), style: pw.TextStyle(font: amiriBold, fontSize: 10, color: PdfColors.white)),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Footer: Status Badge | Stamp | Signature & QR Code
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Status Badge
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: isSolde ? const PdfColor.fromInt(0xFFECFDF5) : const PdfColor.fromInt(0xFFFFFBEB),
                      border: pw.Border.all(
                        color: isSolde ? const PdfColor.fromInt(0xFFA7F3D0) : const PdfColor.fromInt(0xFFFDE68A),
                      ),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      isSolde ? '✓ SOLDÉ — COMPLET' : '⏳ EN COURS — DU',
                      style: pw.TextStyle(
                        font: amiriBold,
                        fontSize: 8.5,
                        color: isSolde ? const PdfColor.fromInt(0xFF065F46) : const PdfColor.fromInt(0xFF92400E),
                      ),
                    ),
                  ),

                  // Circular Stamp
                  pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: primaryIndigo.withOpacity(0.35), width: 1.5),
                    ),
                    child: pw.Center(
                      child: pw.Container(
                        width: 58,
                        height: 58,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: primaryIndigo.withOpacity(0.35), width: 0.8),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'ÉCOLE EXCELLENCE\nNIAMEY - NIGER',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: amiriBold, fontSize: 5, color: primaryIndigo.withOpacity(0.4)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Signature & Cachet
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Signature & Cachet',
                        style: pw.TextStyle(font: amiriFont, fontSize: 8, color: greyColor),
                      ),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 90, height: 0.5, color: greyColor),
                    ],
                  ),

                  // QR Code
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'REC-$paymentId|$studentName|$className|${_formatCfa(totalPaid)}|${_formatCfa(remainingBalance)}',
                    width: 48,
                    height: 48,
                  ),
                ],
              ),
            ],
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
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
      allPayments: allPayments,
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
    List<Map<String, dynamic>>? allPayments,
    Map<String, dynamic>? headerConfig,
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
      allPayments: allPayments,
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

  static pw.Widget _buildDetailRow(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont, {
    PdfColor? valueColor,
    bool isBoldVal = false,
  }) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 75,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 8, color: const PdfColor.fromInt(0xFF64748B)),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(font: font, fontSize: 8, color: const PdfColor.fromInt(0xFF94A3B8))),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: isBoldVal ? boldFont : boldFont,
              fontSize: isBoldVal ? 8.5 : 8,
              color: valueColor ?? const PdfColor.fromInt(0xFF1E293B),
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
