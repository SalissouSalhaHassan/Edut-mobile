import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/api/sync_engine.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection & Supabase
  await setupLocator();

  // Start Offline Sync Engine
  locator<SyncEngine>().start();

  // Initialize Mobile Push Notifications Service
  await locator<MobilePushNotificationService>().initialize();

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
    );
  }
}
