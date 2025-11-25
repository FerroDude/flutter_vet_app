import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'calendar_page.dart' show CalendarPage, calendarPageKey;

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
        return CalendarPage(key: calendarPageKey);
      },
    );
  }
}

