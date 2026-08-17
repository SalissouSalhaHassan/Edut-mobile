import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/api/sync_engine.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/inactivity_lock_service.dart';
import 'features/auth/presentation/inactivity_lock_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection & Supabase
  await setupLocator();

  // Start Offline Sync Engine
  locator<SyncEngine>().start();

  // Initialize Mobile Push Notifications Service
  await locator<MobilePushNotificationService>().initialize();

  // Initialize Auto-Lock Inactivity Service (3 minutes timeout)
  await locator<InactivityLockService>().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Edut Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return InactivityLockWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
