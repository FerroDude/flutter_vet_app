import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'calendar_page.dart' show CalendarPage, calendarPageKey;
import 'settings_page.dart';
import 'profile_page.dart';

class CalendarPageWrapper extends StatefulWidget {
  const CalendarPageWrapper({super.key});

  @override
  State<CalendarPageWrapper> createState() => _CalendarPageWrapperState();
}

class _CalendarPageWrapperState extends State<CalendarPageWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SettingsPage(injectedUserProvider: userProvider),
                    ),
                  );
                },
                tooltip: 'Settings',
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(injectedUserProvider: userProvider),
                    ),
                  );
                },
                tooltip: 'Profile',
              ),
            ],
          ),
          body: CalendarPage(key: calendarPageKey),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              calendarPageKey.currentState?.handleFabAction();
            },
            backgroundColor: AppTheme.neutral700,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}

