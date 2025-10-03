import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../services/cache_service.dart';
import '../../models/notification_service.dart';
import '../../services/clinic_service.dart';
import '../../services/chat_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/chat_provider.dart';
import '../../repositories/event_repository.dart';
import '../../pages/onboarding_pages.dart';
import '../../main.dart'; // For MyHomePage
import '../../pages/admin_dashboard.dart'; // For App Owner Dashboard
import 'email_verification_page.dart';
import 'auth_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          // Check if email verification is needed
          if (!user.emailVerified) {
            return EmailVerificationPage(user: user);
          }

          // User is authenticated and email verified
          return Consumer4<
            CacheService,
            NotificationService,
            ClinicService,
            ChatService
          >(
            builder:
                (
                  context,
                  cacheService,
                  notificationService,
                  clinicService,
                  chatService,
                  child,
                ) {
                  return MultiProvider(
                    providers: [
                      // UserProvider manages user profile and clinic connections
                      ChangeNotifierProvider(
                        create: (context) => UserProvider(clinicService),
                      ),
                      // EventProvider with user context
                      ChangeNotifierProvider(
                        create: (context) => EventProvider(
                          EventRepository(cacheService, snapshot.data!.uid),
                          notificationService,
                        ),
                      ),
                      // ChatProvider with chat service
                      ChangeNotifierProvider(
                        create: (context) => ChatProvider(chatService),
                      ),
                    ],
                    child: Consumer<UserProvider>(
                      builder: (context, userProvider, child) {
                        if (userProvider.isLoading) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (userProvider.error != null) {
                          return Scaffold(
                            body: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 64,
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: 16),
                                  Text('Error: ${userProvider.error}'),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      // Try to reload user profile
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        userProvider.refresh();
                                      }
                                    },
                                    child: Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Check if user needs onboarding
                        if (userProvider.currentUser == null) {
                          return const ClinicOnboardingPage();
                        }

                        // Check if user needs clinic connection (for pet owners)
                        if (userProvider.isPetOwner &&
                            !userProvider.hasClinicConnection &&
                            !userProvider
                                .currentUser!
                                .hasSkippedClinicSelection) {
                          return const ClinicSelectionPage();
                        }

                        // Route users based on their type
                        if (userProvider.isAppOwner) {
                          // App owners get the special admin dashboard
                          return const AdminDashboard();
                        } else {
                          // Regular users (pet owners, vets, clinic admins) get the normal app
                          return const MyHomePage(title: 'Peton');
                        }
                      },
                    ),
                  );
                },
          );
        }

        // Not authenticated or email not verified
        return const AuthPage();
      },
    );
  }
}
