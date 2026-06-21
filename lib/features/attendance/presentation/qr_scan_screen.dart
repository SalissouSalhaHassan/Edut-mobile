import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/attendance_repository.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final DevicePermissionService _permissionService =
      locator<DevicePermissionService>();
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isFlashOn = false;
  bool _isCheckingPermission = true;
  bool _hasCameraPermission = false;
  bool _isPermissionPermanentlyDenied = false;
  String? _permissionMessage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    setState(() {
      _isCheckingPermission = true;
      _permissionMessage = null;
      _isPermissionPermanentlyDenied = false;
    });

    final result = await _permissionService.ensureCameraPermission();
    if (!mounted) return;

    setState(() {
      _isCheckingPermission = false;
      _hasCameraPermission = result.isGranted;
      _permissionMessage = result.isGranted ? null : result.message;
      _isPermissionPermanentlyDenied =
          result.state == AppPermissionState.permanentlyDenied;
    });

    if (result.isGranted) {
      await _controller.start();
    } else {
      await _controller.stop();
    }
  }

  Future<void> _openAppSettings() async {
    await _permissionService.openSettings();
  }

  void _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing || !_hasCameraPermission) return;

    final barcode = capture.barcodes.first;
    final url = barcode.rawValue;

    if (url == null || url.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Traitement du scan...";
    });

    // Parse URL to find classId
    int? classId;
    try {
      final uri = Uri.parse(url);
      final classIdStr = uri.queryParameters['classId'] ?? uri.queryParameters['classroom'];
      if (classIdStr != null) {
        classId = int.tryParse(classIdStr);
      }
    } catch (_) {
      classId = int.tryParse(url);
    }

    if (classId == null) {
      _showResultSheet(
        success: false,
        message: "Code QR invalide. Veuillez scanner un QR code de classe valide.",
      );
      return;
    }

    final employeeIdStr = await locator<SessionManager>().getEmployeeId();
    final employeeId = int.tryParse(employeeIdStr ?? '');

    if (employeeId == null) {
      _showResultSheet(
        success: false,
        message: "Session utilisateur invalide. Veuillez vous reconnecter.",
      );
      return;
    }

    final result = await locator<AttendanceRepository>().recordTeacherSessionScan(
      classId: classId,
      employeeId: employeeId,
    );

    if (result['success'] == true) {
      final isAlready = result['alreadyRecorded'] == true;
      final entry = result['entry'];
      final String msg = isAlready
          ? "Présence déjà enregistrée aujourd'hui pour la période ${entry['periodNumber']} (${entry['subjectName']} en ${entry['className']})."
          : "Présence enregistrée avec succès pour la période ${entry['periodNumber']} (${entry['subjectName']} en ${entry['className']}).";
      
      _showResultSheet(
        success: true,
        message: msg,
      );
    } else {
      _showResultSheet(
        success: false,
        message: result['error'] ?? "Une erreur est survenue lors de l'enregistrement.",
      );
    }
  }

  void _showResultSheet({required bool success, required String message}) {
    if (!mounted) return;

    setState(() {
      _statusMessage = message;
    });

    _controller.stop();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                CircleAvatar(
                  radius: 38,
                  backgroundColor: success
                      ? AppColors.success.withAlpha(25)
                      : AppColors.danger.withAlpha(25),
                  child: Icon(
                    success ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: success ? AppColors.success : AppColors.danger,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  success ? "Scan Réussi" : "Échec du Scan",
                  style: const TextStyle(color: AppColors.slate900, fontSize: 20, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                Text(
                  message,
                  style: const TextStyle(color: AppColors.slate500, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        _isProcessing = false;
                        _statusMessage = null;
                      });
                      _controller.start();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success ? AppColors.success : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Continuer",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scanner QR Code", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_hasCameraPermission)
            MobileScanner(
              controller: _controller,
              onDetect: _handleDetect,
            )
          else
            Container(color: Colors.black),

          if (_hasCameraPermission)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Alignez le QR code dans le cadre",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(80),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            _buildPermissionFallback(),

          // Camera control options toolbar
          if (_hasCameraPermission)
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isFlashOn ? AppColors.warning : Colors.white,
                      ),
                      onPressed: () {
                        _controller.toggleTorch();
                        setState(() {
                          _isFlashOn = !_isFlashOn;
                        });
                      },
                    ),
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ),
                ],
              ),
            ),

          // Overlay scanner loader
          if (_isCheckingPermission)
            Container(
              color: Colors.black.withAlpha(220),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha(204),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              'Camera permission required',
              style: AppTextStyles.heading2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _permissionMessage ??
                  'Allow camera access to scan classroom QR codes.',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPermissionPermanentlyDenied
                    ? _openAppSettings
                    : _requestCameraPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _isPermissionPermanentlyDenied
                      ? 'Open settings'
                      : 'Allow camera',
                ),
              ),
            ),
            if (!_isPermissionPermanentlyDenied) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _requestCameraPermission,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
