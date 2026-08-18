import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
  GoogleMapController? _mapController;

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
    try {
      final studentId =
          int.tryParse(await locator<SessionManager>().getStudentId() ?? '');
      if (studentId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aucun profil élève rattaché pour le transport.';
        });
        return;
      }

      _subscription = await _repository.getTransportSubscription(
        studentId: studentId,
      );
    } catch (e) {
      _errorMessage = "Erreur: $e";
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro du chauffeur non renseigné.')),
      );
      return;
    }
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lancer l\'appel vers $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _subscription?['transport_routes'] as Map<String, dynamic>?;
    final lat = (route?['current_latitude'] as num?)?.toDouble() ??
        (route?['latitude'] as num?)?.toDouble() ??
        13.5136; // Niamey default center
    final lng = (route?['current_longitude'] as num?)?.toDouble() ??
        (route?['longitude'] as num?)?.toDouble() ??
        2.1098;

    final driverPhone = route?['driver_phone']?.toString();
    final driverName = route?['driver_name']?.toString() ?? 'Chauffeur de ligne';
    final vehicleNumber = route?['vehicle_number']?.toString() ?? 'Bus Scolaire';
    final routeName = route?['route_name']?.toString() ?? 'Circuit Principal';
    final pickupPoint = _subscription?['pickup_point']?.toString() ?? 'Arrêt de ramassage';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Suivi du Transport Scolaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscription == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF2563EB), size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ??
                              'Aucun abonnement transport actif pour le moment.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.slate600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Live Status Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'CIRCUIT EN DIRECT',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  routeName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Véhicule: $vehicleNumber',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Interactive Google Map Card
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(lat, lng),
                              zoom: 14.5,
                            ),
                            onMapCreated: (ctrl) => _mapController = ctrl,
                            markers: {
                              Marker(
                                markerId: const MarkerId('bus_position'),
                                position: LatLng(lat, lng),
                                infoWindow: InfoWindow(
                                  title: 'Bus: $vehicleNumber',
                                  snippet: 'Chauffeur: $driverName',
                                ),
                              ),
                              Marker(
                                markerId: const MarkerId('pickup_position'),
                                position: LatLng(lat + 0.003, lng + 0.002),
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                                infoWindow: InfoWindow(
                                  title: 'Arrêt de l\'élève',
                                  snippet: pickupPoint,
                                ),
                              ),
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: true,
                          ),
                          // ETA Badge
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_filled_rounded, color: Color(0xFF2563EB), size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'Arrivée estimée : ~7 min',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Driver Contact Card with Direct Call Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Chauffeur assigné • $vehicleNumber',
                                  style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _callDriver(driverPhone),
                            icon: const Icon(Icons.phone_rounded, size: 16, color: Colors.white),
                            label: const Text('Appeler', style: TextStyle(fontSize: 12, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route details
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Détails de l\'arrêt', style: AppTextStyles.bodyBold),
                          const SizedBox(height: 12),
                          _detailItem(Icons.place_rounded, 'Point de montée :', pickupPoint, const Color(0xFF2563EB)),
                          _detailItem(Icons.check_circle_outline_rounded, 'Statut de l\'abonnement :', _subscription?['status'] ?? 'Actif', const Color(0xFF10B981)),
                          _detailItem(Icons.calendar_month_rounded, 'Période :', 'Année Scolaire 2025/2026', const Color(0xFF6366F1)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                Text(value, style: const TextStyle(color: AppColors.slate900, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
