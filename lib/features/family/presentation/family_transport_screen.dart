import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/family_repository.dart';

class FamilyTransportScreen extends StatefulWidget {
  const FamilyTransportScreen({super.key});

  @override
  State<FamilyTransportScreen> createState() => _FamilyTransportScreenState();
}

class _FamilyTransportScreenState extends State<FamilyTransportScreen> {
  final FamilyRepository _repository = locator<FamilyRepository>();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final studentId =
        int.tryParse(await locator<SessionManager>().getStudentId() ?? '');
    if (studentId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Aucun abonnement transport rattache.';
      });
      return;
    }

    _subscription = await _repository.getTransportSubscription(
      studentId: studentId,
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = _subscription?['transport_routes'] as Map<String, dynamic>?;
    final lat = (route?['current_latitude'] as num?)?.toDouble() ??
        (route?['latitude'] as num?)?.toDouble() ??
        (route?['start_latitude'] as num?)?.toDouble();
    final lng = (route?['current_longitude'] as num?)?.toDouble() ??
        (route?['longitude'] as num?)?.toDouble() ??
        (route?['start_longitude'] as num?)?.toDouble();
    final hasMap = lat != null && lng != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Transport scolaire'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscription == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage ??
                          'Aucun trajet attribue. Ajoutez un abonnement transport dans l’interface web.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasMap
                          ? GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(lat, lng),
                                zoom: 14,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('bus'),
                                  position: LatLng(lat, lng),
                                  infoWindow: InfoWindow(
                                    title: route?['route_name']?.toString() ??
                                        'Bus scolaire',
                                  ),
                                ),
                              },
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Aucune coordonnee GPS en direct disponible. Le suivi temps reel apparaitra des que le chauffeur enverra sa position.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _infoCard(
                      title: route?['route_name']?.toString() ?? 'Trajet',
                      lines: [
                        'Vehicule: ${route?['vehicle_number'] ?? '-'}',
                        'Chauffeur: ${route?['driver_name'] ?? '-'}',
                        'Telephone: ${route?['driver_phone'] ?? '-'}',
                        'Point de ramassage: ${_subscription?['pickup_point'] ?? '-'}',
                        'Statut: ${_subscription?['status'] ?? '-'}',
                        'Mensualite: ${route?['monthly_fee'] ?? '-'} F',
                      ],
                    ),
                    const SizedBox(height: 16),
                    _infoCard(
                      title: 'Suivi GPS',
                      lines: [
                        'Le plan de route web peut etre affiche ici via les champs de coordonnees du trajet.',
                        'Le suivi en temps reel depend de l’envoi des positions GPS depuis l’application conducteur.',
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _infoCard({required String title, required List<String> lines}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: 10),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: AppTextStyles.body),
              )),
        ],
      ),
    );
  }
}
