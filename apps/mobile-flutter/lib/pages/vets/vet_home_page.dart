import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../shared/widgets/notification_badge.dart';
import 'vet_dashboard_page.dart';
import 'vet_patients_page.dart';
import '../petOwners/chat_page.dart';

class VetHomePage extends StatefulWidget {
  const VetHomePage({super.key});

  @override
  State<VetHomePage> createState() => VetHomePageState();
}

/// Made public so child widgets can access switchToChat()
class VetHomePageState extends State<VetHomePage> {
  int _selectedIndex = 0;
  bool _chatInitialized = false;

  final List<Widget> _pages = const [
    VetDashboardPage(),
    VetPatientsPage(),
    ChatPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeChatIfNeeded();
  }

  /// Switch to the Chat tab (index 2)
  void switchToChat() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  /// Initialize chat provider early so we can show unread badge
  void _initializeChatIfNeeded() {
    if (_chatInitialized) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (userProvider.isLoading) return;
    
    final clinicId = userProvider.connectedClinic?.id;
    if (clinicId != null) {
      _chatInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.initializeChatRooms(
          clinicId: clinicId,
          vetId: userProvider.isVet ? userProvider.currentUser?.id : null,
          isAdmin: userProvider.isClinicAdmin,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final unreadCount = chatProvider.totalUnreadCount;
        // Also count pending requests for vets
        final pendingCount = chatProvider.pendingRequests.length;
        final totalBadge = unreadCount + pendingCount;
        
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
                icon: BadgedIcon(
                  icon: Icons.chat,
                  badgeCount: totalBadge,
                ),
                activeIcon: BadgedIcon(
                  icon: Icons.chat,
                  badgeCount: totalBadge,
                ),
                label: 'Chats',
              ),
            ],
          ),
        );
      },
    );
  }
}
