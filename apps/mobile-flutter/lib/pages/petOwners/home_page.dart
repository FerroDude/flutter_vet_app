import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'dashboard_page.dart';
import 'calendar_page_wrapper.dart';
import 'calendar_page.dart';
import 'chat_page_wrapper.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

final GlobalKey<MyHomePageState> homePageKey = GlobalKey<MyHomePageState>();

class MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const CalendarPageWrapper(),
    const ChatPageWrapper(),
  ];

  void switchToCalendarAndOpenAppointment() {
    setState(() {
      _selectedIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      calendarPageKey.currentState?.switchToAppointmentsTab();
      Future.delayed(const Duration(milliseconds: 100), () {
        calendarPageKey.currentState?.showAppointmentFormWithPetSelection();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homePageKey,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.neutral700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}
