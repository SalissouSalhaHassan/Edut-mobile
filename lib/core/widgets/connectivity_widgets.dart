import 'package:flutter/material.dart';
import '../api/sync_engine.dart';
import '../di/injection.dart';

/// Shows a compact "données en cache" chip when the app is offline.
/// Wrap this around any screen header that may be showing cached data.
class CacheStatusChip extends StatefulWidget {
  const CacheStatusChip({super.key});

  @override
  State<CacheStatusChip> createState() => _CacheStatusChipState();
}

class _CacheStatusChipState extends State<CacheStatusChip> {
  late final SyncEngine _syncEngine;
  bool _isOnline = true;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _syncEngine = locator<SyncEngine>();
    _isOnline = _syncEngine.isOnlineNotifier.value;
    _lastSync = _syncEngine.lastSyncNotifier.value;
    _syncEngine.isOnlineNotifier.addListener(_onChanged);
    _syncEngine.lastSyncNotifier.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      _isOnline = _syncEngine.isOnlineNotifier.value;
      _lastSync = _syncEngine.lastSyncNotifier.value;
    });
  }

  @override
  void dispose() {
    _syncEngine.isOnlineNotifier.removeListener(_onChanged);
    _syncEngine.lastSyncNotifier.removeListener(_onChanged);
    super.dispose();
  }

  String _formatLastSync(DateTime? dt) {
    if (dt == null) return 'jamais';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    return 'il y a ${diff.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cached_rounded, size: 13, color: Color(0xFFB45309)),
          const SizedBox(width: 5),
          Text(
            'Données en cache · ${_formatLastSync(_lastSync)}',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A connectivity-aware wrapper for screen content.
/// Shows a banner with retry button if offline.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  late final SyncEngine _syncEngine;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _syncEngine = locator<SyncEngine>();
    _isOnline = _syncEngine.isOnlineNotifier.value;
    _syncEngine.isOnlineNotifier.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _isOnline = _syncEngine.isOnlineNotifier.value);
  }

  @override
  void dispose() {
    _syncEngine.isOnlineNotifier.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A styled error widget for connection failures with a retry button.
class ConnectionErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ConnectionErrorWidget({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Color(0xFFEA580C),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connexion indisponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Les données affichées peuvent être en cache. Vérifiez votre connexion.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Réessayer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
