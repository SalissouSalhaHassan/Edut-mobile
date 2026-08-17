import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/session_manager.dart';
import '../di/injection.dart';

class InactivityLockService with WidgetsBindingObserver {
  static final InactivityLockService _instance = InactivityLockService._internal();
  factory InactivityLockService() => _instance;
  InactivityLockService._internal();

  final ValueNotifier<bool> isLocked = ValueNotifier<bool>(false);
  
  Timer? _timer;
  DateTime? _lastActivityTime;
  DateTime? _pausedTime;
  Duration _timeout = const Duration(minutes: 3);
  bool _isTracking = false;

  Duration get timeout => _timeout;
  DateTime? get lastActivityTime => _lastActivityTime;

  Future<void> initialize() async {
    final minutes = await locator<SessionManager>().getInactivityTimeoutMinutes();
    _timeout = Duration(minutes: minutes > 0 ? minutes : 3);
    
    if (!_isTracking) {
      _isTracking = true;
      WidgetsBinding.instance.addObserver(this);
      recordActivity();
    }
  }

  void updateTimeout(int minutes) {
    if (minutes > 0) {
      _timeout = Duration(minutes: minutes);
      locator<SessionManager>().setInactivityTimeoutMinutes(minutes);
      recordActivity();
    }
  }

  void recordActivity() {
    if (isLocked.value) return;
    _lastActivityTime = DateTime.now();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(_timeout, _onTimeout);
  }

  Future<void> _onTimeout() async {
    if (isLocked.value) return;

    final sessionManager = locator<SessionManager>();
    final loggedIn = await sessionManager.isLoggedIn();
    if (!loggedIn) return;

    lock();
  }

  void lock() {
    _timer?.cancel();
    isLocked.value = true;
    debugPrint('[InactivityLockService] App locked due to inactivity.');
  }

  void unlock() {
    isLocked.value = false;
    recordActivity();
    debugPrint('[InactivityLockService] App unlocked successfully.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _pausedTime = DateTime.now();
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        _pausedTime = null;

        if (elapsed >= _timeout && !isLocked.value) {
          locator<SessionManager>().isLoggedIn().then((loggedIn) {
            if (loggedIn) {
              lock();
            } else {
              recordActivity();
            }
          });
          return;
        }
      }
      recordActivity();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _isTracking = false;
  }
}
