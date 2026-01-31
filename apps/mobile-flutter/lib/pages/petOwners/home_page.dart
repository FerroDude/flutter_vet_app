import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../shared/widgets/notification_badge.dart';
import 'dashboard_page.dart';
import 'calendar_page_wrapper.dart';
import 'calendar_page.dart';
import 'clinic_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  bool _chatInitialized = false;

  final List<Widget> _pages = [
    const DashboardPage(),
    const CalendarPageWrapper(),
    const ClinicPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeChatIfNeeded();
  }

  /// Initialize providers early so we can show unread badge
  void _initializeChatIfNeeded() {
    if (_chatInitialized) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final appointmentProvider = Provider.of<AppointmentRequestProvider>(
      context,
      listen: false,
    );

    if (userProvider.isLoading) return;

    final petOwnerId = userProvider.currentUser?.id;
    if (petOwnerId != null && userProvider.hasClinicConnection) {
      _chatInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.initializeChatRooms(petOwnerId: petOwnerId);
        appointmentProvider.initializeForPetOwner(petOwnerId);
      });
    }
  }

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

  /// Switch to the Clinic tab (index 2)
  void switchToClinic() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final unreadCount = chatProvider.totalUnreadCount;

        return Scaffold(
          body: _pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            selectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.selectedItemColor,
            unselectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.unselectedItemColor,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: BadgedIcon(icon: Icons.business, badgeCount: unreadCount),
                activeIcon: BadgedIcon(
                  icon: Icons.business,
                  badgeCount: unreadCount,
                ),
                label: 'Clinic',
              ),
            ],
          ),
        );
      },
    );
  }
}
