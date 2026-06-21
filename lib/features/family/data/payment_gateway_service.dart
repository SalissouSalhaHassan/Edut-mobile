import 'package:url_launcher/url_launcher.dart';

class PaymentGatewayOption {
  final String id;
  final String label;
  final String description;

  const PaymentGatewayOption({
    required this.id,
    required this.label,
    required this.description,
  });
}

class PaymentGatewayService {
  static const List<PaymentGatewayOption> gateways = [
    PaymentGatewayOption(
      id: 'stripe',
      label: 'Stripe',
      description: 'Paiement carte ou wallet via page securisee.',
    ),
    PaymentGatewayOption(
      id: 'cinetpay',
      label: 'CinetPay',
      description: 'Paiement local mobile money et cartes.',
    ),
    PaymentGatewayOption(
      id: 'local',
      label: 'Paiement local',
      description: 'Lien personnalisable pour votre integrateur national.',
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
}
