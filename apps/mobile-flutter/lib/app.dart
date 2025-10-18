import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'models/notification_service.dart';
import 'services/clinic_service.dart';
import 'services/cache_service.dart';
import 'services/chat_service.dart';

// Global navigator key for app-wide navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.cacheService,
    required this.notificationService,
    required this.home,
  });

  final CacheService cacheService;
  final NotificationService notificationService;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeManager()),
        Provider<CacheService>.value(value: cacheService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<ClinicService>(create: (context) => ClinicService()),
        Provider<ChatService>(create: (context) => ChatService()),
        // EventProvider, UserProvider, and ChatProvider are created with user context in AuthWrapper
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'VetPlus',
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeManager.themeMode,
            home: home,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
