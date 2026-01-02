import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'models/notification_service.dart';
import 'services/clinic_service.dart';
import 'services/cache_service.dart';
import 'services/chat_service.dart';
import 'services/media_cache_service.dart';

import 'core/auth/auth_wrapper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize services
  final cacheService = CacheService();
  await cacheService.init();

  // Initialize media cache (videos, voice, thumbnails, images)
  await MediaCacheService.instance.init();

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    MyApp(cacheService: cacheService, notificationService: notificationService),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.cacheService,
    required this.notificationService,
  });

  final CacheService cacheService;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => ThemeManager()),
            Provider<CacheService>.value(value: cacheService),
            Provider<NotificationService>.value(value: notificationService),
            Provider<ClinicService>(create: (context) => ClinicService()),
            Provider<ChatService>(create: (context) => ChatService()),
          ],
          child: Consumer<ThemeManager>(
            builder: (context, themeManager, child) {
              return MaterialApp(
                title: 'Peton',
                navigatorKey: navigatorKey,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeManager.themeMode,
                home: const AuthWrapper(),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        );
      },
    );
  }
}
