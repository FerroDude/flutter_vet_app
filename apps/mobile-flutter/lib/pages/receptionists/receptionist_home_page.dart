import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../shared/widgets/notification_badge.dart';
import 'receptionist_dashboard_page.dart';
import 'receptionist_clinic_page.dart';
import '../vets/vet_patients_page.dart';

class ReceptionistHomePage extends StatefulWidget {
  const ReceptionistHomePage({super.key});

  @override
  State<ReceptionistHomePage> createState() => ReceptionistHomePageState();
}

/// Made public so child widgets can access navigation methods
class ReceptionistHomePageState extends State<ReceptionistHomePage> {
  int _selectedIndex = 0;
  bool _providersInitialized = false;

  final List<Widget> _pages = const [
    ReceptionistDashboardPage(),
    VetPatientsPage(), // Reuse the patients page from vets
    ReceptionistClinicPage(), // Unified chats + appointments
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeProvidersIfNeeded();
  }

  /// Switch to the Clinic tab (index 2)
  void switchToClinic() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  /// Switch to the Patients tab (index 1)
  void switchToPatients() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  /// Initialize chat and appointment providers early so we can show badges
  void _initializeProvidersIfNeeded() {
    if (_providersInitialized) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final appointmentProvider = Provider.of<AppointmentRequestProvider>(
      context,
      listen: false,
    );

    if (userProvider.isLoading) return;

    final clinicId = userProvider.connectedClinic?.id;
    final userId = userProvider.currentUser?.id;
    if (clinicId != null && userId != null) {
      _providersInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.initializeChatRooms(
          clinicId: clinicId,
          // Receptionists see their own accepted chats + pending requests
          vetId: userId,
        );
        appointmentProvider.initializeForReceptionist(clinicId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, AppointmentRequestProvider>(
      builder: (context, chatProvider, appointmentProvider, child) {
        final unreadCount = chatProvider.totalUnreadCount;
        // Count pending chat requests
        final pendingChatCount = chatProvider.pendingRequests.length;
        // Count pending appointment requests
        final pendingAppointmentCount = appointmentProvider.pendingCount;
        final totalBadge =
            unreadCount + pendingChatCount + pendingAppointmentCount;

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
            backgroundColor: AppTheme.primary,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withValues(alpha: 0.6),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.pets),
                label: 'Patients',
              ),
              BottomNavigationBarItem(
                icon: BadgedIcon(icon: Icons.business, badgeCount: totalBadge),
                activeIcon: BadgedIcon(
                  icon: Icons.business,
                  badgeCount: totalBadge,
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
