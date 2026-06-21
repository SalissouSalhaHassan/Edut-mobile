import 'dart:typed_data';

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
  }) async {
    final pdf = pw.Document();

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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          const primaryColor = PdfColor.fromInt(0xFF4F46E5);
          const textColor = PdfColor.fromInt(0xFF1E293B);
          const greyColor = PdfColor.fromInt(0xFF64748B);
          const lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
          const borderGreyColor = PdfColor.fromInt(0xFFCBD5E1);

          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EDUT PRO',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Systeme de gestion scolaire ERP',
                          style: pw.TextStyle(fontSize: 10, color: greyColor),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'RECU DE PAIEMENT',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'No Recu: REC-$paymentId',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text('Date: $datePaidStr', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: primaryColor, thickness: 1.5),
                pw.SizedBox(height: 20),
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
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Nom: $studentName',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Matricule: $admissionNo', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Classe: $className', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Niveau: $level', style: const pw.TextStyle(fontSize: 10)),
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
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Mode: $paymentMode', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Reference: $reference', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Mois: $month', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Enregistre par: $recordedBy', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Description',
                    'Montant (FCFA)',
                    'Reduction (FCFA)',
                    'Total impute (FCFA)',
                  ],
                  data: [
                    [
                      'Frais de scolarite - Periode: $month',
                      amount.toStringAsFixed(0),
                      reduction.toStringAsFixed(0),
                      (amount + reduction).toStringAsFixed(0),
                    ],
                  ],
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: primaryColor),
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
                        _buildSummaryRow('Montant verse:', '${amount.toStringAsFixed(0)} FCFA', isBold: true),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Reduction:', '${reduction.toStringAsFixed(0)} FCFA'),
                        pw.SizedBox(height: 8),
                        pw.Divider(color: borderGreyColor),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Total attendu:', '${totalExpected.toStringAsFixed(0)} FCFA'),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow(
                          'Solde restant:',
                          '${remainingBalance.toStringAsFixed(0)} FCFA',
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
                          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
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
                          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
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
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
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
  }) async {
    final paymentId = payment['id'] ?? 0;
    final bytes = await generatePdfBytes(
      student: student,
      payment: payment,
      totalExpected: totalExpected,
      remainingBalance: remainingBalance,
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
    bool isBold = false,
    PdfColor color = const PdfColor.fromInt(0xFF1E293B),
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
