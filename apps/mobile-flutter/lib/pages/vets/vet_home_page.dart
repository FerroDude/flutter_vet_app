import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'vet_dashboard_page.dart';
import 'vet_patients_page.dart';
import '../petOwners/chat_page.dart';

class VetHomePage extends StatefulWidget {
  const VetHomePage({super.key});

  @override
  State<VetHomePage> createState() => _VetHomePageState();
}

class _VetHomePageState extends State<VetHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    VetDashboardPage(),
    VetPatientsPage(),
    ChatPage(),
  ];

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
        ],
      ),
    );
  }
}
