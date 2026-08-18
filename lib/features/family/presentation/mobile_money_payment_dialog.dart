import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/payment_gateway_service.dart';

class MobileMoneyPaymentDialog extends StatefulWidget {
  final int studentId;
  final String studentName;
  final double defaultAmount;
  final Function(MobileMoneyPaymentResult result) onPaymentSuccess;

  const MobileMoneyPaymentDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.defaultAmount,
    required this.onPaymentSuccess,
  });

  @override
  State<MobileMoneyPaymentDialog> createState() => _MobileMoneyPaymentDialogState();
}

class _MobileMoneyPaymentDialogState extends State<MobileMoneyPaymentDialog> {
  final PaymentGatewayService _service = PaymentGatewayService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedProviderId = 'AIRTEL_MONEY';
  String _selectedProviderName = 'Airtel Money 🇳🇪';
  String _selectedPurpose = 'Scolarité';
  bool _isProcessing = false;
  MobileMoneyPaymentResult? _successResult;

  final List<Map<String, String>> _providers = [
    {'id': 'AIRTEL_MONEY', 'name': 'Airtel Money 🇳🇪', 'sub': 'Paiement direct Airtel'},
    {'id': 'ORANGE_MONEY', 'name': 'Orange Money 🌍', 'sub': 'Paiement Mobile Orange'},
    {'id': 'AMANA', 'name': 'Amana Ta Tsabta 🇳🇪', 'sub': 'Transfert express Niger'},
    {'id': 'NITA', 'name': 'Nita / Al-Izza 🇳🇪', 'sub': 'Transfert national instantané'},
    {'id': 'WAVE', 'name': 'Wave Mobile 🌊', 'sub': 'Transfert direct sans frais'},
    {'id': 'MOOV_MONEY', 'name': 'Moov / Flooz 🇳🇪', 'sub': 'Niger (Moov)'},
    {'id': 'BANK_CARD', 'name': 'Carte Bancaire 💳', 'sub': 'Visa / Mastercard'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.defaultAmount > 0 
        ? widget.defaultAmount.toStringAsFixed(0) 
        : '25000';
    _phoneController.text = '90123456';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide.')),
      );
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro de téléphone.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _service.executeMobileMoneyPayment(
        studentId: widget.studentId,
        amount: amount,
        providerId: _selectedProviderId,
        providerName: _selectedProviderName,
        phoneNumber: _phoneController.text.trim(),
        purpose: _selectedPurpose,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _successResult = result;
        });
        widget.onPaymentSuccess(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du paiement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _successResult != null 
              ? _buildSuccessView() 
              : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.smartphone, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paiement Mobile Money', style: AppTextStyles.heading3),
                    Text(widget.studentName, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Provider Selector
        Text('Choix de l\'opérateur', style: AppTextStyles.bodyBold),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _providers.map((p) {
            final isSelected = _selectedProviderId == p['id'];
            return ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.white : AppColors.slate900)),
                  Text(p['sub']!, style: TextStyle(fontSize: 9, color: isSelected ? Colors.white70 : AppColors.slate500)),
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFFF1F5F9),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedProviderId = p['id']!;
                    _selectedProviderName = p['name']!;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Purpose Dropdown
        Text('Motif du réglement', style: AppTextStyles.bodyBold),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedPurpose,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(value: 'Scolarité', child: Text('Frais de Scolarité / Mensualités')),
            DropdownMenuItem(value: 'COGES', child: Text('Cotisation Annuelle COGES')),
            DropdownMenuItem(value: 'Inscription', child: Text('Frais d\'Inscription / Réinscription')),
            DropdownMenuItem(value: 'Autre', child: Text('Transport / Cantine / Autre')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedPurpose = val);
          },
        ),
        const SizedBox(height: 16),

        // Amount Field
        Text('Montant à payer (FCFA)', style: AppTextStyles.bodyBold),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.payments_outlined),
            suffixText: 'FCFA',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),

        // Phone Field
        Text('Numéro de téléphone Mobile Money', style: AppTextStyles.bodyBold),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_android),
            hintText: '+227 90 00 00 00',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _isProcessing ? null : _processPayment,
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Traitement Mobile Money...', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                : Text(
                    'Confirmer & Payer ${_amountController.text} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final res = _successResult!;
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(res.timestamp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFD1FAE5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 48),
        ),
        const SizedBox(height: 16),
        Text('Paiement Validé avec Succès !', style: AppTextStyles.heading3),
        const SizedBox(height: 6),
        Text(res.message ?? 'Transaction effectuée.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _receiptRow('Référence:', res.reference),
              const Divider(height: 16),
              _receiptRow('Montant:', '${res.amount.toStringAsFixed(0)} FCFA'),
              const Divider(height: 16),
              _receiptRow('Opérateur:', res.providerName),
              const Divider(height: 16),
              _receiptRow('Motif:', res.purpose),
              const Divider(height: 16),
              _receiptRow('Date:', formattedDate),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PDF Receipt Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => _printOfficialReceiptPdf(res, formattedDate),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF0D9488)),
          label: const Text('Télécharger Reçu Officiel PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer et Actualiser', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _printOfficialReceiptPdf(MobileMoneyPaymentResult res, String formattedDate) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RÉPUBLIQUE DU NIGER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('MINISTÈRE DE L\'ÉDUCATION NATIONALE', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('COMPLEXE SCOLAIRE PRIVÉ EDUT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal800)),
                        pw.Text('Caisse Numérique & Paiements Mobile Money', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.teal800, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('QUITTANCE DE PAIEMENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal900)),
                          pw.Text('Réf: ${res.reference}', style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(thickness: 1, color: PdfColors.teal800),
                pw.SizedBox(height: 10),

                // Payment Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Élève Bénéficiaire : ${widget.studentName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 3),
                          pw.Text('Motif / Rubrique : ${res.purpose}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 3),
                          pw.Text('Opérateur : ${res.providerName}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Date & Heure : $formattedDate', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Statut : Payé & Validé', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.teal800)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Amount Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.teal700, width: 1.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('MONTANT TOTAL REÇU :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.teal900)),
                      pw.Text('${res.amount.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.teal900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 35),

                // Signatures & Stamp
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Le Payeur / Tuteur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 30),
                        pw.Text('Reçu électronique', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Pour la Direction de l\'Établissement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          width: 85,
                          height: 35,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.teal700, style: pw.BorderStyle.dashed),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('[ Cachet Numérique & QR ]', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.teal800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Quittance_Paiement_${res.reference}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération reçu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: AppColors.slate900, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
