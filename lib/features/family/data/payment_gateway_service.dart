import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentGatewayOption {
  final String id;
  final String label;
  final String description;
  final String iconAsset;

  const PaymentGatewayOption({
    required this.id,
    required this.label,
    required this.description,
    this.iconAsset = '',
  });
}

class MobileMoneyPaymentResult {
  final bool success;
  final String reference;
  final double amount;
  final String providerName;
  final String purpose;
  final DateTime timestamp;
  final String? message;

  MobileMoneyPaymentResult({
    required this.success,
    required this.reference,
    required this.amount,
    required this.providerName,
    required this.purpose,
    required this.timestamp,
    this.message,
  });
}

class PaymentGatewayService {
  static const List<PaymentGatewayOption> mobileMoneyOptions = [
    PaymentGatewayOption(
      id: 'AIRTEL_MONEY',
      label: 'Airtel Money 🇳🇪',
      description: 'Paiement direct via compte Airtel Money Niger',
    ),
    PaymentGatewayOption(
      id: 'MOOV_MONEY',
      label: 'Moov / Flooz 🇳🇪',
      description: 'Paiement direct via Moov Money (Flooz)',
    ),
    PaymentGatewayOption(
      id: 'ORANGE_MONEY',
      label: 'Orange Money',
      description: 'Paiement via portefeuille Orange Money',
    ),
    PaymentGatewayOption(
      id: 'WAVE',
      label: 'Wave Mobile',
      description: 'Transfert instantane via Wave',
    ),
    PaymentGatewayOption(
      id: 'NITA',
      label: 'Nita / Al-Izza 🇳🇪',
      description: 'Guichet de transfert de fonds regional Nita',
    ),
    PaymentGatewayOption(
      id: 'BANK_CARD',
      label: 'Carte Bancaire',
      description: 'Visa / Mastercard via passerelle securisee',
    ),
  ];

  static const List<PaymentGatewayOption> gateways = [
    PaymentGatewayOption(
      id: 'airtel_money',
      label: 'Airtel Money 🇳🇪',
      description: 'Guichet Mobile Money Niger.',
    ),
    PaymentGatewayOption(
      id: 'moov_money',
      label: 'Moov / Flooz 🇳🇪',
      description: 'Paiement Mobile Money Flooz.',
    ),
    PaymentGatewayOption(
      id: 'cinetpay',
      label: 'CinetPay',
      description: 'Paiement local mobile money et cartes.',
    ),
    PaymentGatewayOption(
      id: 'stripe',
      label: 'Stripe',
      description: 'Paiement carte ou wallet via page securisee.',
    ),
  ];

  Future<bool> launchGateway({
    required PaymentGatewayOption gateway,
    required int studentId,
    required double amount,
    required String studentName,
  }) async {
    final uri = Uri.parse(
      'https://pay.edut.app/checkout'
      '?provider=${gateway.id}'
      '&studentId=$studentId'
      '&amount=${amount.toStringAsFixed(0)}'
      '&name=${Uri.encodeComponent(studentName)}',
    );

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Process direct Mobile Money payment in app
  Future<MobileMoneyPaymentResult> executeMobileMoneyPayment({
    required int studentId,
    required double amount,
    required String providerId,
    required String providerName,
    required String phoneNumber,
    required String purpose,
  }) async {
    // Simulate mobile network API request processing delay (1.5 seconds)
    await Future.delayed(const Duration(milliseconds: 1500));

    final ref = 'TXN-MOB-${providerId.substring(0, 3)}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    return MobileMoneyPaymentResult(
      success: true,
      reference: ref,
      amount: amount,
      providerName: providerName,
      purpose: purpose,
      timestamp: DateTime.now(),
      message: 'Paiement de ${amount.toStringAsFixed(0)} FCFA confirme avec succes via $providerName',
    );
  }
}
