import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/event_model.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'models/notification_service.dart';
import 'services/clinic_service.dart';
import 'pages/chat_page.dart';
import 'pages/pets_page.dart';
import 'widgets/appointments_page.dart';
import 'widgets/simple_event_forms.dart';
import 'providers/event_provider.dart';
import 'providers/user_provider.dart';
import 'services/cache_service.dart';
import 'services/chat_service.dart';
import 'pages/add_symptom_sheet.dart';
import 'pages/pet_symptoms_page.dart';
// import 'services/pet_service.dart';
// Removed profile-specific symptom imports

import 'core/auth/auth_wrapper.dart';
import 'widgets/theme_toggle_widget.dart';

// Global navigator key for app-wide navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize services
  final cacheService = CacheService();
  await cacheService.init();

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    MyApp(cacheService: cacheService, notificationService: notificationService),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.cacheService,
    required this.notificationService,
  });

  final CacheService cacheService;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeManager()),
        Provider<CacheService>.value(value: cacheService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<ClinicService>(create: (context) => ClinicService()),
        Provider<ChatService>(create: (context) => ChatService()),
        // EventProvider, UserProvider, and ChatProvider will be created with user context in AuthWrapper
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'VetPlus',
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeManager.themeMode,
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const PetsPage(),
    const AppointmentsPageWrapper(),
    const ChatPageWrapper(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: _pages[_selectedIndex],
      floatingActionButton:
          _selectedIndex ==
              1 // Show on Pets page
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PetFormPage()),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pets'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}

// Dashboard Page
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Set<String> _expandedSeries = {};

  void _toggleExpand(String seriesId) {
    setState(() {
      if (_expandedSeries.contains(seriesId)) {
        _expandedSeries.remove(seriesId);
      } else {
        _expandedSeries.add(seriesId);
      }
    });
  }

  void _showSeriesDeleteDialog(
    CalendarEvent firstEvent,
    List<CalendarEvent> seriesEvents,
  ) {
    final medicationEvents = seriesEvents.whereType<MedicationEvent>().toList();
    if (medicationEvents.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('Delete Medication Series'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete all ${medicationEvents.length} occurrences of "${firstEvent.title}"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently delete the entire medication schedule.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteSeriesEvents(medicationEvents);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete All (${medicationEvents.length})'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSeriesEvents(List<MedicationEvent> seriesItems) async {
    try {
      final eventProvider = context.read<EventProvider>();

      // Delete all events in the series
      for (final event in seriesItems) {
        await eventProvider.deleteEvent(event.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${seriesItems.length} medication reminders'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete medication series: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Gets appropriate icon for pet care appointment type
  IconData _getAppointmentTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'checkup':
      case 'routine':
      case 'vet visit':
        return Icons.medical_services;
      case 'vaccination':
      case 'vaccine':
        return Icons.vaccines;
      case 'grooming':
      case 'bath':
      case 'nail trim':
        return Icons.pets;
      case 'training':
      case 'behavior':
        return Icons.school;
      case 'emergency':
      case 'urgent':
        return Icons.emergency;
      case 'play date':
      case 'social':
        return Icons.group;
      default:
        return Icons.event;
    }
  }

  /// Builds an informative subtitle for recurring medications
  String _buildRecurringSubtitle(
    CalendarEvent firstEvent,
    List<CalendarEvent> allEvents,
    bool isFirstEventToday,
  ) {
    if (allEvents.isEmpty) return '';

    final now = DateTime.now();
    final firstEventDate = firstEvent.dateTime;
    final allEventsSorted = allEvents.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Find the next upcoming event (including today if not passed)
    CalendarEvent? nextEvent;
    for (final event in allEventsSorted) {
      if (event.dateTime.isAfter(now.subtract(const Duration(hours: 1)))) {
        nextEvent = event;
        break;
      }
    }

    // Calculate the pattern between doses
    String frequency = '';
    if (allEventsSorted.length >= 2) {
      final timeBetween = allEventsSorted[1].dateTime.difference(
        allEventsSorted[0].dateTime,
      );
      if (timeBetween.inDays >= 1) {
        if (timeBetween.inDays == 1) {
          frequency = 'Daily';
        } else if (timeBetween.inDays == 7) {
          frequency = 'Weekly';
        } else {
          frequency = 'Every ${timeBetween.inDays} days';
        }
      } else if (timeBetween.inHours >= 1) {
        frequency = 'Every ${timeBetween.inHours}h';
      }
    }

    // Build the subtitle based on what's most relevant
    if (nextEvent != null) {
      final nextEventTime = DateFormat('h:mm a').format(nextEvent.dateTime);
      if (DateFormat('yyyy-MM-dd').format(nextEvent.dateTime) ==
          DateFormat('yyyy-MM-dd').format(now)) {
        return frequency.isNotEmpty
            ? '$frequency • Next: $nextEventTime'
            : 'Next: $nextEventTime';
      } else {
        final nextEventDate = DateFormat(
          'MMM d • h:mm a',
        ).format(nextEvent.dateTime);
        return frequency.isNotEmpty
            ? '$frequency • Next: $nextEventDate'
            : 'Next: $nextEventDate';
      }
    } else {
      // All events are in the past
      final startDate = DateFormat('MMM d').format(firstEventDate);
      return frequency.isNotEmpty
          ? '$frequency • Started $startDate'
          : 'Started $startDate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
          Consumer<UserProvider>(
            builder: (context, userProvider, _) => IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider.value(
                      value: userProvider,
                      child: ProfilePage(injectedUserProvider: userProvider),
                    ),
                  ),
                );
              },
              icon: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                radius: 16,
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer<EventProvider>(
          builder: (context, eventProvider, _) {
            final now = DateTime.now();
            final start = DateTime(now.year, now.month, now.day);
            final endToday = start.add(const Duration(days: 1));
            final next7 = start.add(const Duration(days: 7));
            final upcomingAppointments =
                eventProvider.appointments
                    .where(
                      (e) =>
                          !e.dateTime.isBefore(endToday) &&
                          e.dateTime.isBefore(next7),
                    )
                    .toList()
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            final upcomingMeds =
                eventProvider.medications
                    .where(
                      (e) =>
                          !e.dateTime.isBefore(endToday) &&
                          e.dateTime.isBefore(next7),
                    )
                    .toList()
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            final upcomingEvents = <CalendarEvent>[
              ...upcomingAppointments,
              ...upcomingMeds,
            ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            // Today's events
            final todaysAppointments =
                eventProvider.appointments
                    .where(
                      (e) =>
                          !e.dateTime.isBefore(start) &&
                          e.dateTime.isBefore(endToday),
                    )
                    .toList()
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            final todaysMeds =
                eventProvider.medications
                    .where(
                      (e) =>
                          !e.dateTime.isBefore(start) &&
                          e.dateTime.isBefore(endToday),
                    )
                    .toList()
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            final todaysEvents = <CalendarEvent>[
              ...todaysAppointments,
              ...todaysMeds,
            ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            // Minimal, accessible event tile
            Widget buildEventItem(
              CalendarEvent e, {
              required bool isToday,
              int? seriesCount,
              List<CalendarEvent>? seriesEvents,
              Function(String)? onToggleExpand,
              bool isExpanded = false,
            }) {
              final bool isAppointment = e is AppointmentEvent;
              final bool isMedication = e is MedicationEvent;
              final IconData icon = isAppointment
                  ? Icons.event
                  : (isMedication ? Icons.medication : Icons.note);
              final Color color = isAppointment
                  ? AppTheme.primaryBlue
                  : (isMedication
                        ? AppTheme.primaryGreen
                        : AppTheme.accentCoral);

              final bool isCompact = seriesCount != null && seriesCount > 1;

              // Enhanced subtitle for recurring medications
              final String subtitle =
                  isCompact && seriesEvents != null && seriesEvents.isNotEmpty
                  ? _buildRecurringSubtitle(e, seriesEvents, isToday)
                  : isToday
                  ? DateFormat('h:mm a').format(e.dateTime)
                  : DateFormat('EEE, MMM d • h:mm a').format(e.dateTime);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isCompact
                      ? color.withValues(alpha: 0.05)
                      : (isAppointment || isMedication)
                      ? color.withValues(alpha: 0.03)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompact
                        ? color.withValues(alpha: 0.15)
                        : (isAppointment || isMedication)
                        ? color.withValues(alpha: 0.1)
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black12),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap:
                        isCompact &&
                            seriesEvents != null &&
                            onToggleExpand != null
                        ? () => onToggleExpand(e.seriesId ?? '')
                        : null,
                    onLongPress: isCompact && seriesEvents != null
                        ? () => _showSeriesDeleteDialog(e, seriesEvents)
                        : null,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: isCompact ? 28 : 32,
                                height: isCompact ? 28 : 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: isCompact ? 16 : 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Enhanced subtitle for appointments
                                    if (isAppointment)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          if ((e).vetName != null ||
                                              (e).appointmentType != null) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                if ((e).appointmentType !=
                                                    null) ...[
                                                  Icon(
                                                    _getAppointmentTypeIcon(
                                                      (e).appointmentType!,
                                                    ),
                                                    size: 11,
                                                    color: color,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    (e).appointmentType!,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                                if ((e).location != null &&
                                                    (e).appointmentType != null)
                                                  const Text(
                                                    ' • ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                if ((e).location != null)
                                                  Flexible(
                                                    child: Text(
                                                      (e).location!,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme
                                                            .textTertiary,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      )
                                    else
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isCompact)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.layers,
                                            size: 14,
                                            color: AppTheme.primaryGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$seriesCount',
                                            style: const TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: color,
                                    ),
                                  ],
                                )
                              else if (isMedication && (e).isCompleted)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.primaryGreen,
                                    size: 16,
                                  ),
                                )
                              else if (isAppointment && (e).petId != null)
                                _DashboardPetBadge(petId: (e).petId!),
                            ],
                          ),
                        ),
                        if (isExpanded && seriesEvents != null)
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: [
                                Divider(
                                  color: color.withValues(alpha: 0.2),
                                  height: 1,
                                ),
                                const SizedBox(height: 8),
                                ...(() {
                                  final now = DateTime.now();
                                  // Find the next upcoming medication (give 1 hour buffer for recently passed ones)
                                  final bufferTime = now.subtract(
                                    const Duration(hours: 1),
                                  );
                                  int? nextEventIndex;

                                  for (
                                    int i = 0;
                                    i < seriesEvents.length;
                                    i++
                                  ) {
                                    if (seriesEvents[i].dateTime.isAfter(
                                      bufferTime,
                                    )) {
                                      nextEventIndex = i;
                                      break;
                                    }
                                  }

                                  return seriesEvents.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final event = entry.value;
                                    final isNext = index == nextEventIndex;
                                    final isPast = event.dateTime.isBefore(
                                      bufferTime,
                                    );

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: isNext ? 8 : 6,
                                            height: isNext ? 8 : 6,
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: isNext
                                                    ? 1.0
                                                    : (isPast ? 0.4 : 0.7),
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                if (isNext)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 6,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: color.withValues(
                                                          alpha: 0.15,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Next',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: color,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Text(
                                                    DateFormat(
                                                      isToday
                                                          ? 'h:mm a'
                                                          : 'EEE, MMM d • h:mm a',
                                                    ).format(event.dateTime),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: isPast
                                                              ? AppTheme
                                                                    .textSecondary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    )
                                                              : AppTheme
                                                                    .textSecondary,
                                                          fontSize: 12,
                                                          fontWeight: isNext
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                    .normal,
                                                          decoration: isPast
                                                              ? TextDecoration
                                                                    .lineThrough
                                                              : null,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  });
                                })(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Today's items (merged in todaysEvents above)

            // Find next upcoming event for "Next up" pill
            CalendarEvent? nextEvent;
            final allFutureEvents = [...todaysEvents, ...upcomingEvents]
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            for (final event in allFutureEvents) {
              if (event.dateTime.isAfter(now)) {
                nextEvent = event;
                break;
              }
            }

            return ListView(
              children: [
                // Personalized greeting
                Consumer<UserProvider>(
                  builder: (context, userProvider, _) {
                    final currentUser = userProvider.currentUser;
                    final displayName =
                        currentUser?.displayName ??
                        (currentUser != null
                            ? currentUser.email.split('@').first
                            : null) ??
                        'Pet Owner';
                    final hour = DateTime.now().hour;
                    String greeting;
                    if (hour < 12) {
                      greeting = 'Good Morning';
                    } else if (hour < 18) {
                      greeting = 'Good Afternoon';
                    } else {
                      greeting = 'Good Evening';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $displayName',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMMM d').format(now),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // "Next up" pill
                if (nextEvent != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withValues(alpha: 0.1),
                          AppTheme.primaryGreen.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            nextEvent is AppointmentEvent
                                ? Icons.event
                                : Icons.medication,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next up',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nextEvent.title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            nextEvent.dateTime.day == now.day
                                ? 'h:mm a'
                                : 'MMM d, h:mm a',
                          ).format(nextEvent.dateTime),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),

                // Highlights strip
                Row(
                  children: [
                    Expanded(
                      child: _DashboardHighlight(
                        icon: Icons.event,
                        label: 'This Week',
                        value: upcomingEvents.length.toString(),
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardHighlight(
                        icon: Icons.medication,
                        label: 'Meds Today',
                        value: todaysMeds.length.toString(),
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardHighlight(
                        icon: Icons.chat,
                        label: 'Unread',
                        value: '0',
                        color: AppTheme.accentCoral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Actions Section
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.flash_on,
                            size: 18,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Actions',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final ep = context.read<EventProvider>();
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    useSafeArea: true,
                                    builder: (dialogContext) =>
                                        ChangeNotifierProvider.value(
                                          value: ep,
                                          child: SimpleAppointmentForm(
                                            selectedDate: DateTime.now(),
                                          ),
                                        ),
                                  );
                                },
                                icon: const Icon(Icons.event, size: 18),
                                label: const Text('Add Appointment'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final ep = context.read<EventProvider>();
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    useSafeArea: true,
                                    builder: (dialogContext) =>
                                        ChangeNotifierProvider.value(
                                          value: ep,
                                          child: SimpleMedicationForm(
                                            selectedDate: DateTime.now(),
                                          ),
                                        ),
                                  );
                                },
                                icon: const Icon(Icons.medication, size: 18),
                                label: const Text('Add Medication'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  // Get first pet or let user choose
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) return;
                                  final petsSnap = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('pets')
                                      .limit(1)
                                      .get();
                                  if (petsSnap.docs.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please add a pet first',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  final petId = petsSnap.docs.first.id;
                                  if (context.mounted) {
                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(
                                            context,
                                          ).viewInsets.bottom,
                                        ),
                                        child: AddSymptomSheet(petId: petId),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.monitor_heart, size: 18),
                                label: const Text('Add Symptom'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Today's Events Section
                Row(
                  children: [
                    Icon(Icons.today, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Events",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (todaysEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No events today',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use Quick Actions above to add events',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      // Group medications by seriesId OR medication name for dashboard display
                      final Map<String, List<MedicationEvent>> seriesGroups =
                          {};
                      final List<CalendarEvent> otherEvents = [];

                      for (final e in todaysEvents) {
                        if (e is MedicationEvent) {
                          // Group by seriesId if available, otherwise by medication name
                          final groupKey = (e.seriesId ?? '').isNotEmpty
                              ? e.seriesId!
                              : 'name_${e.medicationName}';
                          seriesGroups.putIfAbsent(groupKey, () => []).add(e);
                        } else {
                          otherEvents.add(e);
                        }
                      }
                      final List<MapEntry<CalendarEvent, int?>> display = [];
                      final Map<String, List<CalendarEvent>> seriesEventsMap =
                          {};

                      for (final entry in seriesGroups.entries) {
                        entry.value.sort(
                          (a, b) => a.dateTime.compareTo(b.dateTime),
                        );
                        display.add(
                          MapEntry(entry.value.first, entry.value.length),
                        );
                        seriesEventsMap[entry.key] = entry.value;
                      }
                      for (final e in otherEvents) {
                        display.add(MapEntry(e, null));
                      }
                      display.sort(
                        (a, b) => a.key.dateTime.compareTo(b.key.dateTime),
                      );
                      return Column(
                        children: display
                            .take(5)
                            .map(
                              (pair) => buildEventItem(
                                pair.key,
                                isToday: true,
                                seriesCount: pair.value,
                                seriesEvents: pair.key.seriesId != null
                                    ? seriesEventsMap[pair.key.seriesId!]
                                    : null,
                                onToggleExpand: _toggleExpand,
                                isExpanded: _expandedSeries.contains(
                                  pair.key.seriesId ?? '',
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Upcoming Events Section
                Row(
                  children: [
                    Icon(Icons.upcoming, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Upcoming (next 7 days)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (upcomingEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nothing scheduled',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plan ahead from the Appointments tab',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      // Group medications by seriesId OR medication name for dashboard display
                      final Map<String, List<MedicationEvent>> seriesGroups =
                          {};
                      final List<CalendarEvent> otherEvents = [];

                      for (final e in upcomingEvents) {
                        if (e is MedicationEvent) {
                          // Group by seriesId if available, otherwise by medication name
                          final groupKey = (e.seriesId ?? '').isNotEmpty
                              ? e.seriesId!
                              : 'name_${e.medicationName}';
                          seriesGroups.putIfAbsent(groupKey, () => []).add(e);
                        } else {
                          otherEvents.add(e);
                        }
                      }
                      final List<MapEntry<CalendarEvent, int?>> display = [];
                      final Map<String, List<CalendarEvent>> seriesEventsMap =
                          {};

                      for (final entry in seriesGroups.entries) {
                        entry.value.sort(
                          (a, b) => a.dateTime.compareTo(b.dateTime),
                        );
                        display.add(
                          MapEntry(entry.value.first, entry.value.length),
                        );
                        seriesEventsMap[entry.key] = entry.value;
                      }
                      for (final e in otherEvents) {
                        display.add(MapEntry(e, null));
                      }
                      display.sort(
                        (a, b) => a.key.dateTime.compareTo(b.key.dateTime),
                      );
                      return Column(
                        children: display
                            .take(5)
                            .map(
                              (pair) => buildEventItem(
                                pair.key,
                                isToday: false,
                                seriesCount: pair.value,
                                seriesEvents: pair.key.seriesId != null
                                    ? seriesEventsMap[pair.key.seriesId!]
                                    : null,
                                onToggleExpand: _toggleExpand,
                                isExpanded: _expandedSeries.contains(
                                  pair.key.seriesId ?? '',
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),

                const SizedBox(height: 16),
                // End content
              ],
            );
          },
        ),
      ),
    );
  }
}

// Pets Page - Now in separate file (pages/pets_page.dart)

// Pet Form Page - Simplified
class PetFormPage extends StatefulWidget {
  const PetFormPage({super.key, this.petRef, this.initialData});
  final DocumentReference<Map<String, dynamic>>? petRef;
  final Map<String, dynamic>? initialData;

  @override
  State<PetFormPage> createState() => _PetFormPageState();
}

class _PetFormPageState extends State<PetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _colorController = TextEditingController();
  final _microchipController = TextEditingController();
  final _veterinarianController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  DateTime? _dateOfBirth;
  String _gender = 'Unknown';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _speciesController.text = widget.initialData!['species'] ?? '';
      _breedController.text = widget.initialData!['breed'] ?? '';
      _weightController.text = widget.initialData!['weight'] ?? '';
      _colorController.text = widget.initialData!['color'] ?? '';
      _microchipController.text = widget.initialData!['microchip'] ?? '';
      _veterinarianController.text = widget.initialData!['veterinarian'] ?? '';
      _medicalNotesController.text = widget.initialData!['medicalNotes'] ?? '';
      _emergencyContactController.text =
          widget.initialData!['emergencyContact'] ?? '';
      _gender = widget.initialData!['gender'] ?? 'Unknown';

      if (widget.initialData!['dateOfBirth'] != null) {
        _dateOfBirth = (widget.initialData!['dateOfBirth'] as Timestamp)
            .toDate();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _colorController.dispose();
    _microchipController.dispose();
    _veterinarianController.dispose();
    _medicalNotesController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final petData = {
        'name': _nameController.text.trim(),
        'species': _speciesController.text.trim(),
        'breed': _breedController.text.trim(),
        'weight': _weightController.text.trim(),
        'color': _colorController.text.trim(),
        'microchip': _microchipController.text.trim(),
        'veterinarian': _veterinarianController.text.trim(),
        'medicalNotes': _medicalNotesController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dateOfBirth != null
            ? Timestamp.fromDate(_dateOfBirth!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.petRef == null) {
        // Creating new pet - get current pet count to assign proper order
        final existingPets = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pets')
            .get();

        petData['createdAt'] = FieldValue.serverTimestamp();
        petData['order'] = existingPets.docs.length; // Assign next order number

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pets')
            .add(petData);
      } else {
        // Updating existing pet
        await widget.petRef!.update(petData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.petRef == null
                  ? 'Pet added successfully!'
                  : 'Pet updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.petRef == null ? 'Add Pet' : 'Edit Pet'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              Text(
                'Basic Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pet Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _speciesController,
                      decoration: const InputDecoration(
                        labelText: 'Species *',
                        hintText: 'Dog, Cat, Bird, etc.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the species';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Breed *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_florist),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the breed';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date of Birth and Gender
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _dateOfBirth ??
                              DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _dateOfBirth = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cake),
                        ),
                        child: Text(
                          _dateOfBirth != null
                              ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                              : 'Select date',
                          style: TextStyle(
                            color: _dateOfBirth != null
                                ? null
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: ['Male', 'Female', 'Unknown'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _gender = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weight and Color
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        hintText: 'e.g., 15 kg, 3.5 lbs',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monitor_weight),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color/Markings',
                        hintText: 'Brown, White spots, etc.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.palette),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Medical Information Section
              Text(
                'Medical Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _microchipController,
                decoration: const InputDecoration(
                  labelText: 'Microchip Number',
                  hintText: 'ID number if microchipped',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.memory),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _veterinarianController,
                decoration: const InputDecoration(
                  labelText: 'Veterinarian',
                  hintText: 'Primary vet name or clinic',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _medicalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Medical Notes',
                  hintText: 'Allergies, conditions, medications',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_information),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Emergency Contact Section
              Text(
                'Emergency Contact',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact',
                  hintText: 'Name and phone number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.emergency),
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.petRef == null ? 'Add Pet' : 'Update Pet',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Pet Details Page - Simplified
class PetDetailsPage extends StatelessWidget {
  const PetDetailsPage({super.key, required this.petRef});
  final DocumentReference<Map<String, dynamic>> petRef;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Details'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              final doc = await petRef.get();
              if (doc.exists && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PetFormPage(petRef: petRef, initialData: doc.data()),
                  ),
                );
              }
            },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: petRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Pet not found'));
          }

          final pet = snapshot.data!.data()!;
          final dateOfBirth = pet['dateOfBirth'] != null
              ? (pet['dateOfBirth'] as Timestamp).toDate()
              : null;

          String getAge() {
            if (dateOfBirth == null) return 'Unknown';
            final now = DateTime.now();
            final years = now.difference(dateOfBirth).inDays ~/ 365;
            final months = (now.difference(dateOfBirth).inDays % 365) ~/ 30;
            if (years > 0) return '$years years, $months months old';
            return '$months months old';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pet Header Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppTheme.primaryBlue,
                              child: Text(
                                (pet['name'] ?? 'P')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['name'] ?? 'Unknown',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${pet['species'] ?? 'Unknown'} • ${pet['breed'] ?? 'Unknown'}',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  if (dateOfBirth != null)
                                    Text(
                                      getAge(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Basic Information Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Basic Information',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Species', pet['species']),
                        _buildInfoRow('Breed', pet['breed']),
                        _buildInfoRow('Gender', pet['gender']),
                        if (dateOfBirth != null)
                          _buildInfoRow(
                            'Date of Birth',
                            '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}',
                          ),
                        _buildInfoRow('Weight', pet['weight']),
                        _buildInfoRow('Color/Markings', pet['color']),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Medical Information Card
                if (pet['microchip']?.isNotEmpty == true ||
                    pet['veterinarian']?.isNotEmpty == true ||
                    pet['medicalNotes']?.isNotEmpty == true)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Information',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (pet['microchip']?.isNotEmpty == true)
                            _buildInfoRow('Microchip', pet['microchip']),
                          if (pet['veterinarian']?.isNotEmpty == true)
                            _buildInfoRow('Veterinarian', pet['veterinarian']),
                          if (pet['medicalNotes']?.isNotEmpty == true)
                            _buildInfoRow(
                              'Medical Notes',
                              pet['medicalNotes'],
                              isMultiline: true,
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Emergency Contact Card
                if (pet['emergencyContact']?.isNotEmpty == true)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Contact',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Contact', pet['emergencyContact']),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Quick Actions Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final eventProvider = context
                                      .read<EventProvider>();
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    useSafeArea: true,
                                    builder: (dialogContext) =>
                                        ChangeNotifierProvider.value(
                                          value: eventProvider,
                                          child: SimpleAppointmentForm(
                                            selectedDate: DateTime.now(),
                                            petId: petRef.id,
                                          ),
                                        ),
                                  );
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: const Text('Add Appointment'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom: MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom,
                                      ),
                                      child: AddSymptomSheet(petId: petRef.id),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.monitor_heart),
                                label: const Text('Add Symptom'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Pet's Events & Symptoms Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activity',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PetSymptomsPage(petId: petRef.id),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.monitor_heart),
                              label: const Text('View Symptoms'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Consumer<EventProvider>(
                          builder: (context, eventProvider, _) {
                            final petEvents =
                                eventProvider.events
                                    .where((event) => event.petId == petRef.id)
                                    .toList()
                                  ..sort(
                                    (a, b) => b.dateTime.compareTo(a.dateTime),
                                  );

                            if (petEvents.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_note,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'No appointments or medications yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: petEvents.take(5).map((event) {
                                final isAppointment = event is AppointmentEvent;
                                final isMedication = event is MedicationEvent;
                                final icon = isAppointment
                                    ? Icons.event
                                    : (isMedication
                                          ? Icons.medication
                                          : Icons.note);
                                final color = isAppointment
                                    ? AppTheme.primaryBlue
                                    : (isMedication
                                          ? AppTheme.primaryGreen
                                          : AppTheme.accentCoral);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat(
                                                'MMM dd, yyyy • h:mm a',
                                              ).format(event.dateTime),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isMedication && (event).isCompleted)
                                        Icon(
                                          Icons.check_circle,
                                          color: AppTheme.primaryGreen,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value, {
    bool isMultiline = false,
  }) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

// Dashboard Highlight component
class _DashboardHighlight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DashboardHighlight({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Pet Badge component for dashboard
class _DashboardPetBadge extends StatelessWidget {
  final String petId;

  const _DashboardPetBadge({required this.petId});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(petId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final petData = snapshot.data!.data()!;
        final petName = petData['name'] as String? ?? 'Pet';
        final species = petData['species'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getPetIcon(species), size: 12, color: AppTheme.primaryBlue),
              const SizedBox(width: 4),
              Text(
                petName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getPetIcon(String species) {
    switch (species.toLowerCase()) {
      case 'dog':
        return Icons.pets;
      case 'cat':
        return Icons.pets;
      case 'bird':
        return Icons.flutter_dash;
      case 'fish':
        return Icons.water;
      case 'rabbit':
        return Icons.cruelty_free;
      default:
        return Icons.pets;
    }
  }
}

// Settings Page - Original functionality restored
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: context.isDarkMode
            ? AppTheme.primaryNavy
            : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Preferences Section
          _buildSectionHeader(context, 'App Preferences'),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.notifications,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Notifications'),
                  subtitle: const Text('Manage push notifications'),
                  trailing: Switch(
                    value: true, // This would be connected to actual settings
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Notifications enabled'
                                : 'Notifications disabled',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Theme Toggle Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'App Theme',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your preferred theme',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const ThemeToggleWidget(
                        showLabel: false,
                        isExpanded: true,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.language, color: AppTheme.primaryBlue),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language selection - Coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pet Care Settings Section
          _buildSectionHeader(context, 'Pet Care Settings'),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.medical_services,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Medicine Reminders'),
                  subtitle: const Text('Get reminded about pet medications'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Medicine reminders enabled'
                                : 'Medicine reminders disabled',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Appointment Reminders'),
                  subtitle: const Text(
                    'Get reminded about upcoming appointments',
                  ),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Appointment reminders enabled'
                                : 'Appointment reminders disabled',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.pets, color: AppTheme.primaryBlue),
                  title: const Text('Pet Profile Sharing'),
                  subtitle: const Text('Allow vets to view pet profiles'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Pet sharing enabled'
                                : 'Pet sharing disabled',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data & Privacy Section
          _buildSectionHeader(context, 'Data & Privacy'),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.backup, color: AppTheme.primaryBlue),
                  title: const Text('Data Backup'),
                  subtitle: const Text('Backup pet data to cloud'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data backup - Coming soon!'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.sync, color: AppTheme.primaryBlue),
                  title: const Text('Auto Sync'),
                  subtitle: const Text(
                    'Automatically sync data across devices',
                  ),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value ? 'Auto sync enabled' : 'Auto sync disabled',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: AppTheme.primaryBlue),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('View privacy policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy policy - Coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader(context, 'Support'),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.help, color: AppTheme.primaryBlue),
                  title: const Text('Help & FAQ'),
                  subtitle: const Text('Get help using the app'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help center - Coming soon!'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.bug_report, color: AppTheme.primaryBlue),
                  title: const Text('Report Bug'),
                  subtitle: const Text('Report issues with the app'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bug reporting - Coming soon!'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.feedback, color: AppTheme.primaryBlue),
                  title: const Text('Send Feedback'),
                  subtitle: const Text('Share your thoughts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feedback form - Coming soon!'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info, color: AppTheme.primaryBlue),
                  title: const Text('About'),
                  subtitle: const Text('App version 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About VetPlus'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VetPlus - Your Pet\'s Health Companion'),
                            SizedBox(height: 12),
                            Text('Version: 1.0.0'),
                            SizedBox(height: 8),
                            Text('Build: 2024.08.29'),
                            SizedBox(height: 12),
                            Text(
                              'Manage your pets\' health, schedule appointments, and stay connected with your veterinary clinic.',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

// Profile Page - Enhanced
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.injectedUserProvider});

  final UserProvider injectedUserProvider;

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryBlue,
      ),
    );
  }

  /// Shows dialog to edit user profile information
  void _showEditProfileDialog(
    BuildContext context,
    User? authUser,
    UserProvider userProvider,
  ) {
    final profile = userProvider.currentUser;

    final nameController = TextEditingController(
      text: profile?.displayName ?? authUser?.displayName ?? '',
    );
    final emailController = TextEditingController(
      text: profile?.email ?? authUser?.email ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                if (authUser != null && emailController.text != authUser.email)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Note: Changing email will require verification',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);

                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null) {
                            // Update display name
                            final newName = nameController.text.trim();
                            if (newName.isNotEmpty) {
                              final profileUpdated = await userProvider
                                  .updateProfile(displayName: newName);

                              if (profileUpdated &&
                                  currentUser.displayName != newName) {
                                await currentUser.updateDisplayName(newName);
                              }
                            }

                            // Update email if changed
                            final newEmail = emailController.text.trim();
                            if (newEmail.isNotEmpty &&
                                currentUser.email != newEmail) {
                              final emailUpdated = await userProvider
                                  .updateProfile(email: newEmail);

                              if (emailUpdated) {
                                await currentUser.verifyBeforeUpdateEmail(
                                  newEmail,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Verification email sent to your new email address',
                                      ),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                }
                              }
                            }

                            await currentUser.reload();

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Profile updated successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error updating profile: ${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows dialog to fix clinic admin linking
  void _showFixClinicAdminDialog(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Clinic Admin Linking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If you signed up with a clinic admin email but got a regular user profile, '
              'enter the email address to fix the linking:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g., thisissarahbuckley@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context);

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Fixing clinic admin linking...'),
                      ],
                    ),
                  ),
                );

                try {
                  final success = await userProvider.fixClinicAdminLinking(
                    email,
                  );

                  // Close loading dialog first
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  // Show feedback with proper context checking
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Successfully linked to clinic! Please logout and login again.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '❌ No clinic admin profile found for this email. Make sure the clinic was created first.',
                          ),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  // Close loading dialog first
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  // Show error feedback
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Fix Linking'),
          ),
        ],
      ),
    );
  }

  /// Shows dialog to change user password
  void _showChangePasswordDialog(BuildContext context, User? user) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showPasswords = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPasswords ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => showPasswords = !showPasswords),
                    ),
                  ),
                  obscureText: !showPasswords,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: !showPasswords,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: !showPasswords,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Password must be at least 6 characters long',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Send password reset email as alternative
                      if (user?.email != null) {
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: user!.email!,
                          );
                          Navigator.pop(context);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent!'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
              child: const Text('Send Reset Email'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);

                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null &&
                              currentUser.email != null) {
                            // Re-authenticate user with current password
                            final credential = EmailAuthProvider.credential(
                              email: currentUser.email!,
                              password: currentPasswordController.text,
                            );

                            await currentUser.reauthenticateWithCredential(
                              credential,
                            );

                            // Update password
                            await currentUser.updatePassword(
                              newPasswordController.text,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password changed successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (context.mounted) {
                            String errorMessage = 'Error changing password';
                            if (e.toString().contains('wrong-password')) {
                              errorMessage = 'Current password is incorrect';
                            } else if (e.toString().contains('weak-password')) {
                              errorMessage = 'New password is too weak';
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = injectedUserProvider;
    final userProfile = userProvider.currentUser;
    final authUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppTheme.primaryBlue,
                      child: Text(
                        (userProfile?.displayName.isNotEmpty == true)
                            ? userProfile!.displayName
                                  .substring(0, 1)
                                  .toUpperCase()
                            : (authUser?.email?.substring(0, 1).toUpperCase() ??
                                  'U'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProfile?.displayName ??
                                authUser?.displayName ??
                                'User',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userProfile?.email ?? authUser?.email ?? '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                authUser?.emailVerified == true
                                    ? Icons.verified
                                    : Icons.warning,
                                color: authUser?.emailVerified == true
                                    ? Colors.green
                                    : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                authUser?.emailVerified == true
                                    ? 'Email verified'
                                    : 'Email not verified',
                                style: TextStyle(
                                  color: authUser?.emailVerified == true
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const SizedBox(height: 24),

            // Account & Security
            _buildSectionHeader(context, 'Account & Security'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.edit, color: AppTheme.primaryBlue),
                    title: const Text('Edit Profile'),
                    subtitle: const Text('Update your personal information'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _showEditProfileDialog(context, authUser, userProvider),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.lock, color: AppTheme.primaryBlue),
                    title: const Text('Change Password'),
                    subtitle: const Text('Update your account password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePasswordDialog(context, authUser),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.build, color: Colors.orange),
                    title: const Text('Fix Clinic Admin'),
                    subtitle: const Text(
                      'Link to clinic if you signed up with admin email',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _showFixClinicAdminDialog(context, userProvider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final shouldSignOut = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                  if (shouldSignOut == true) {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper for AppointmentsPage to ensure proper app bar
class AppointmentsPageWrapper extends StatefulWidget {
  const AppointmentsPageWrapper({super.key});

  @override
  State<AppointmentsPageWrapper> createState() =>
      _AppointmentsPageWrapperState();
}

class _AppointmentsPageWrapperState extends State<AppointmentsPageWrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
          Consumer<UserProvider>(
            builder: (context, userProvider, _) => IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfilePage(injectedUserProvider: userProvider),
                  ),
                );
              },
              icon: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                radius: 16,
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
      body: AppointmentsPage(key: appointmentsPageKey),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          appointmentsPageKey.currentState?.handleFabAction();
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Chat Page with proper profile access
class ChatPageWrapper extends StatelessWidget {
  const ChatPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Since ChatPage already has its own scaffold, we'll use it directly
    // but we need to ensure it has the profile button
    return const ChatPage();
  }
}
