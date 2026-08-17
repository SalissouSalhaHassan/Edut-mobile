import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/inactivity_lock_service.dart';
import '../data/auth_repository.dart';

class InactivityLockWrapper extends StatefulWidget {
  final Widget child;

  const InactivityLockWrapper({super.key, required this.child});

  @override
  State<InactivityLockWrapper> createState() => _InactivityLockWrapperState();
}

class _InactivityLockWrapperState extends State<InactivityLockWrapper> {
  final InactivityLockService _lockService = locator<InactivityLockService>();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _lockService.recordActivity(),
      onPointerMove: (_) => _lockService.recordActivity(),
      onPointerUp: (_) => _lockService.recordActivity(),
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          ValueListenableBuilder<bool>(
            valueListenable: _lockService.isLocked,
            builder: (context, isLocked, _) {
              if (!isLocked) return const SizedBox.shrink();
              return const _AppLockScreenOverlay();
            },
          ),
        ],
      ),
    );
  }
}

class _AppLockScreenOverlay extends StatefulWidget {
  const _AppLockScreenOverlay();

  @override
  State<_AppLockScreenOverlay> createState() => _AppLockScreenOverlayState();
}

class _AppLockScreenOverlayState extends State<_AppLockScreenOverlay> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String _displayName = 'Utilisateur';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final sessionManager = locator<SessionManager>();
    final studentName = await sessionManager.getStudentName();
    final email = await sessionManager.getEmail();

    if (mounted) {
      setState(() {
        _email = email ?? '';
        _displayName = (studentName != null && studentName.isNotEmpty)
            ? studentName
            : (_email.isNotEmpty ? _email : 'Utilisateur');
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez saisir votre mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionManager = locator<SessionManager>();
      
      // 1. First check local password hash
      bool isValid = await sessionManager.validateCurrentPassword(password);

      // 2. If not verified locally, try online authentication
      if (!isValid && _email.isNotEmpty) {
        final authRepo = locator<AuthRepository>();
        final loginRes = await authRepo.login(email: _email, password: password);
        if (loginRes.success) {
          isValid = true;
        }
      }

      if (isValid) {
        if (mounted) {
          _passwordController.clear();
          locator<InactivityLockService>().unlock();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Mot de passe incorrect. Veuillez réessayer.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de vérification: $e';
        });
      }
    }
  }

  Future<void> _logout() async {
    locator<InactivityLockService>().unlock();
    await locator<AuthRepository>().logout();
    if (!mounted) return;
    try {
      GoRouter.of(context).go('/login');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: const Color(0xFF0F172A).withValues(alpha: 0.88),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock icon with glowing gradient badge
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Session Verrouillée',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pour votre sécurité après 3 minutes d\'inactivité, veuillez entrer votre mot de passe pour déverrouiller.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Password input field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _unlock(),
                        decoration: InputDecoration(
                          hintText: 'Votre mot de passe',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          prefixIcon: const Icon(Icons.password_rounded, color: Color(0xFF0F766E)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Unlock button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _unlock,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_open_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Déverrouiller',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Logout button
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                      ),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text(
                        'Changer de compte / Se déconnecter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
