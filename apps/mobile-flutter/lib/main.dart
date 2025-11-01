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
import 'widgets/simple_event_forms.dart';
import 'providers/event_provider.dart';
import 'providers/user_provider.dart';
import 'services/cache_service.dart';
import 'services/chat_service.dart';

import 'shared/widgets/list_placeholder.dart';
import 'core/auth/auth_wrapper.dart';
import 'pages/add_symptom_sheet.dart';
import 'pages/petOwners/modern_dashboard_page.dart';
import 'pages/petOwners/modern_pets_page.dart';
import 'pages/petOwners/modern_calendar_page.dart';
import 'pages/petOwners/modern_chat_page.dart';
import 'pages/petOwners/modern_settings_page.dart';
import 'pages/petOwners/modern_profile_page.dart';

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
            title: 'Peton',
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
    const ModernDashboardPage(),
    const ModernPetsPage(),
    const ModernCalendarPageWrapper(),
    const ModernChatPageWrapper(),
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
            icon: Icon(Icons.calendar_month),
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

  /// Show dialog to select a pet and then add symptom
  Future<void> _showAddSymptomDialog(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Fetch user's pets
    final petsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .orderBy('order')
        .get();

    if (!mounted) return;

    if (petsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a pet first before tracking symptoms'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show pet selection dialog
    final selectedPetDoc =
        await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Select a Pet'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: petsSnapshot.docs.length,
                itemBuilder: (context, index) {
                  final pet = petsSnapshot.docs[index];
                  final petData = pet.data();
                  final petName = petData['name'] as String? ?? 'Unknown';
                  final species = petData['species'] as String? ?? 'Unknown';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue,
                      child: Text(
                        petName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(petName),
                    subtitle: Text(species),
                    onTap: () => Navigator.pop(dialogContext, pet),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

    if (selectedPetDoc != null && mounted) {
      // Show the add symptom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: AddSymptomSheet(petId: selectedPetDoc.id),
        ),
      );
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

            return ListView(
              children: [
                // Welcome section with personalized greeting
                Consumer<UserProvider>(
                  builder: (context, userProvider, _) {
                    final displayName =
                        userProvider.currentUser?.displayName ?? 'User';
                    final firstName = displayName.split(' ').first;

                    // Determine greeting based on time of day
                    final hour = DateTime.now().hour;
                    String greeting;
                    if (hour < 12) {
                      greeting = 'Good morning';
                    } else if (hour < 17) {
                      greeting = 'Good afternoon';
                    } else {
                      greeting = 'Good evening';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $firstName',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your pet care overview',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    );
                  },
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
                      // Add Symptom Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentCoral.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddSymptomDialog(context),
                          icon: const Icon(Icons.medical_information, size: 18),
                          label: const Text('Add Symptom'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentCoral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
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

// Pets Page - Simplified
class PetsPage extends StatelessWidget {
  const PetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
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
      body: const PetsPageContent(),
    );
  }
}

class PetsPageContent extends StatelessWidget {
  const PetsPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view your pets'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const ListPlaceholder(
            icon: Icons.pets_outlined,
            text: 'No pets yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final pet = docs[index].data();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(
                    (pet['name'] as String? ?? 'P')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(pet['name'] as String? ?? 'Unknown'),
                subtitle: Text(
                  '${pet['species'] as String? ?? 'Unknown'} • ${pet['breed'] as String? ?? 'Unknown'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PetDetailsPage(petRef: docs[index].reference),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

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
                                onPressed: () {
                                  final eventProvider = context
                                      .read<EventProvider>();
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) =>
                                        ChangeNotifierProvider.value(
                                          value: eventProvider,
                                          child: SimpleMedicationForm(
                                            selectedDate: DateTime.now(),
                                            petId: petRef.id,
                                          ),
                                        ),
                                  );
                                },
                                icon: const Icon(Icons.medication),
                                label: const Text('Add Medication'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
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

                // Pet's Events Section
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

// Settings Page - Wrapper for modern implementation
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModernSettingsPage();
  }
}

// Profile Page - Wrapper for modern implementation
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.injectedUserProvider});

  final UserProvider injectedUserProvider;

  @override
  Widget build(BuildContext context) {
    return ModernProfilePage(injectedUserProvider: injectedUserProvider);
  }
}

// Wrapper for AppointmentsPage to ensure proper app bar
class ModernCalendarPageWrapper extends StatefulWidget {
  const ModernCalendarPageWrapper({super.key});

  @override
  State<ModernCalendarPageWrapper> createState() =>
      _ModernCalendarPageWrapperState();
}

class _ModernCalendarPageWrapperState extends State<ModernCalendarPageWrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ModernCalendarPage(key: modernCalendarPageKey),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          modernCalendarPageKey.currentState?.handleFabAction();
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Chat Page with proper profile access
class ModernChatPageWrapper extends StatelessWidget {
  const ModernChatPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Modern chat page already has its own scaffold
    return const ModernChatPage();
  }
}
