import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/di/injection.dart';

class OfflineSyncScreen extends StatefulWidget {
  const OfflineSyncScreen({super.key});

  @override
  State<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen> {
  final SyncEngine _syncEngine = locator<SyncEngine>();
  final OfflineQueueManager _queueManager = locator<OfflineQueueManager>();

  bool _isManualSyncing = false;
  bool _isDownloadingCache = false;

  @override
  void initState() {
    super.initState();
    _syncEngine.isOnlineNotifier.addListener(_onStateChanged);
    _syncEngine.isSyncingNotifier.addListener(_onStateChanged);
    _syncEngine.lastSyncNotifier.addListener(_onStateChanged);
    _queueManager.pendingCountNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _syncEngine.isOnlineNotifier.removeListener(_onStateChanged);
    _syncEngine.isSyncingNotifier.removeListener(_onStateChanged);
    _syncEngine.lastSyncNotifier.removeListener(_onStateChanged);
    _queueManager.pendingCountNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleTriggerSync() async {
    if (!_syncEngine.isOnlineNotifier.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📵 Aucune connexion Internet. Les données restent sécurisées en local.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isManualSyncing = true);
    try {
      await _syncEngine.triggerSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Synchronisation terminée avec succès !'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  Future<void> _handleDownloadAllCache() async {
    if (!_syncEngine.isOnlineNotifier.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📵 Connexion requise pour télécharger les données récentes.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isDownloadingCache = true);
    try {
      await _syncEngine.preloadAllOfflineData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📦 Base locale hors-ligne mise à jour à 100% !'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncEngine.isOnlineNotifier.value;
    final isSyncing = _syncEngine.isSyncingNotifier.value || _isManualSyncing;
    final lastSync = _syncEngine.lastSyncNotifier.value;
    final pendingOps = _queueManager.getPendingOperations();
    final pendingCount = pendingOps.length;

    final lastSyncText = lastSync != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(lastSync)
        : 'Jamais';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Centre Hors-Ligne & Mégasynchro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOnline
                    ? [const Color(0xFF0369A1), const Color(0xFF0284C7)]
                    : [const Color(0xFFB45309), const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? const Color(0xFF0284C7) : const Color(0xFFD97706)).withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
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
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'MODE EN LIGNE CONNECTÉ' : 'MODE HORS-LIGNE ACTIF',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              isOnline ? 'Serveur Edut Cloud accessible' : 'Stockage local autonome sécurisé',
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dernière synchro: $lastSyncText', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                    Text(
                      '$pendingCount opération(s) en attente',
                      style: TextStyle(
                        color: pendingCount > 0 ? const Color(0xFFFDE047) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Primary Force Sync Action
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              onPressed: isSyncing ? null : _handleTriggerSync,
              icon: isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, size: 22),
              label: Text(
                isSyncing ? 'Synchronisation en cours...' : 'Synchroniser Maintenant ($pendingCount en file)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Preload All Cache Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0369A1),
                side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isDownloadingCache ? null : _handleDownloadAllCache,
              icon: _isDownloadingCache
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF0284C7), strokeWidth: 2))
                  : const Icon(Icons.download_for_offline_rounded, size: 20),
              label: Text(
                _isDownloadingCache ? 'Téléchargement de la base...' : 'Télécharger tout le Cache Hors-Ligne',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Pending Operations List
          const Row(
            children: [
              Icon(Icons.pending_actions_rounded, color: Color(0xFF0284C7), size: 20),
              SizedBox(width: 8),
              Text('File d\'Attente des Opérations Locales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),

          if (pendingOps.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 36),
                    SizedBox(height: 8),
                    Text('Toutes vos données sont synchronisées !', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Aucune modification en attente dans la file locale.', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                  ],
                ),
              ),
            )
          else
            ...pendingOps.map((op) {
              String label = op.table;
              IconData icon = Icons.storage_rounded;
              Color color = const Color(0xFF0284C7);

              if (op.table == 'student_attendance') {
                label = 'Appel / Présences Élèves';
                icon = Icons.fact_check_rounded;
                color = const Color(0xFF10B981);
              } else if (op.table == 'cahier_textes') {
                label = 'Séance Cahier de Textes';
                icon = Icons.menu_book_rounded;
                color = const Color(0xFF8B5CF6);
              } else if (op.table == 'student_results') {
                label = 'Saisie de Notes / Devoirs';
                icon = Icons.grade_rounded;
                color = const Color(0xFFF59E0B);
              } else if (op.table == 'fee_payments') {
                label = 'Paiement Encaissé';
                icon = Icons.payments_rounded;
                color = const Color(0xFF0D9488);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text('Action: ${op.action} • Répétitions: ${op.retryCount}', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('En attente', style: TextStyle(color: Color(0xFFB45309), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),

          // Modules Stored Locally
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: Color(0xFF0284C7), size: 20),
              SizedBox(width: 8),
              Text('Modules Disponibles Hors-Ligne à 100%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),

          _buildOfflineFeatureTile(
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF10B981),
            title: 'Appel et Présences en Classe',
            subtitle: 'Enregistrement des présences/absences sans réseau avec synchronisation automatique.',
          ),
          _buildOfflineFeatureTile(
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Cahier de Textes & Fiches Pédagogiques',
            subtitle: 'Rédaction et modification des séances de cours et devoirs à domicile hors-ligne.',
          ),
          _buildOfflineFeatureTile(
            icon: Icons.auto_graph_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Notes, Devoirs & Bulletins Trimestriels',
            subtitle: 'Consultation et saisie des évaluations disponibles à tout moment.',
          ),
          _buildOfflineFeatureTile(
            icon: Icons.local_hospital_rounded,
            color: const Color(0xFFEF4444),
            title: 'Fiches Médicales & Urgences Élèves',
            subtitle: 'Accès instantané aux allergies et contacts d\'urgence sans connexion.',
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOfflineFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
        ],
      ),
    );
  }
}
