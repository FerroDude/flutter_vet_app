import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vet_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../petOwners/profile_page.dart';
import '../petOwners/settings_page.dart';
import 'vet_patients_page.dart';
import '../petOwners/chat_page.dart';

class VetHomePage extends StatelessWidget {
  const VetHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final clinic = userProvider.connectedClinic;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vet Home'),
            backgroundColor: AppTheme.neutral700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(injectedUserProvider: userProvider),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(injectedUserProvider: userProvider),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${userProvider.currentUser?.displayName ?? 'Vet'}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (clinic != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_hospital),
                      title: Text(clinic.name),
                      subtitle: Text(clinic.address),
                    ),
                  )
                else
                  const Text('No clinic linked yet'),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickTile(
                      icon: Icons.pets,
                      label: 'Patients',
                      onTap: () {
                        final userProv = Provider.of<UserProvider>(
                          context,
                          listen: false,
                        );
                        final vetProv = Provider.of<VetProvider>(
                          context,
                          listen: false,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MultiProvider(
                              providers: [
                                ChangeNotifierProvider.value(value: userProv),
                                ChangeNotifierProvider.value(value: vetProv),
                              ],
                              child: const VetPatientsPage(),
                            ),
                          ),
                        );
                      },
                    ),
                    _QuickTile(
                      icon: Icons.chat_bubble,
                      label: 'Chats',
                      onTap: () {
                        final userProv = Provider.of<UserProvider>(
                          context,
                          listen: false,
                        );
                        final chatProv = Provider.of<ChatProvider>(
                          context,
                          listen: false,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MultiProvider(
                              providers: [
                                ChangeNotifierProvider.value(value: userProv),
                                ChangeNotifierProvider.value(value: chatProv),
                              ],
                              child: const ChatPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 100,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.neutral700),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
