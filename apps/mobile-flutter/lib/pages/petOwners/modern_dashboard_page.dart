import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../add_symptom_sheet.dart';
import '../../widgets/simple_event_forms.dart';
import '../../widgets/modern_modals.dart';
import '../../shared/widgets/gradient_background.dart';
import '../../main.dart' show ProfilePage, SettingsPage;

/// Modern, clean dashboard inspired by the final design
class ModernDashboardPage extends StatefulWidget {
  const ModernDashboardPage({super.key});

  @override
  State<ModernDashboardPage> createState() => _ModernDashboardPageState();
}

class _ModernDashboardPageState extends State<ModernDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) setState(() {});
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Header
                SliverToBoxAdapter(child: _buildHeader(context)),

                // Quick Add Section
                SliverToBoxAdapter(child: _buildQuickAdd(context)),

                // Today's Events
                SliverToBoxAdapter(child: _buildTodaySection(context)),

                // Upcoming Events
                SliverToBoxAdapter(child: _buildUpcomingSection(context)),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final firstName =
        userProvider.currentUser?.displayName.split(' ').first ?? 'there';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile icon
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfilePage(injectedUserProvider: userProvider),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF1F2937),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting text (no emoji)
          Expanded(
            child: Text(
              'Hey $firstName',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Settings icon
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF1F2937),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdd(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Add',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF432818), // Dark brown
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.event_outlined,
                  label: 'Appointment',
                  color: const Color(0xFF309CB0), // Teal
                  onTap: () => _showPetSelectionDialog(
                    context,
                    (petId) => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SimpleAppointmentForm(
                        selectedDate: DateTime.now(),
                        petId: petId,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.medication_outlined,
                  label: 'Medication',
                  color: const Color(0xFF57B4A4), // Medium teal
                  onTap: () => _showPetSelectionDialog(
                    context,
                    (petId) => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SimpleMedicationForm(
                        selectedDate: DateTime.now(),
                        petId: petId,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.favorite_outline,
                  label: 'Health Log',
                  color: const Color(0xFF85E7A9), // Light green
                  onTap: () => _showPetSelectionDialog(
                    context,
                    (petId) => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddSymptomSheet(petId: petId),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final events = eventProvider.events;
    final todayEvents = events.where((event) {
      return event.dateTime.isAfter(todayStart) &&
          event.dateTime.isBefore(todayEnd);
    }).toList();

    todayEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (todayEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...todayEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EventCard(event: event),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final now = DateTime.now();
    final todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final events = eventProvider.events;
    final upcomingEvents = events.where((event) {
      return event.dateTime.isAfter(todayEnd);
    }).toList();

    upcomingEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final limitedEvents = upcomingEvents.take(5).toList();

    if (limitedEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...limitedEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpcomingEventCard(event: event),
            ),
          ),
        ],
      ),
    );
  }

  void _showPetSelectionDialog(
    BuildContext parentContext,
    Function(String petId) onPetSelected,
  ) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ModernBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernModalHeader(
              title: 'Select Pet',
              icon: Icons.pets,
              iconColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('pets')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  );
                }

                final pets = snapshot.data!.docs;

                if (pets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No pets found. Add a pet first.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return Column(
                  children: pets.map((doc) {
                    final pet = doc.data();
                    return ModernSelectionCard(
                      title: pet['name'] ?? 'Unknown',
                      subtitle: pet['breed'] ?? pet['species'] ?? '',
                      icon: Icons.pets,
                      onTap: () {
                        final petId = doc.id;
                        Navigator.pop(modalContext);
                        // Use Future.delayed to ensure the modal is closed first
                        Future.delayed(const Duration(milliseconds: 300), () {
                          onPetSelected(petId);
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: color.withOpacity(0.2),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF432818), // Dark brown
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    Color eventColor;

    if (event is AppointmentEvent) {
      eventColor = const Color(0xFFBB9457); // Warm gold
    } else if (event is MedicationEvent) {
      eventColor = const Color(0xFF99582A); // Medium brown
    } else {
      eventColor = const Color(0xFF6F1D1B); // Deep red
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Prominent colored left border
          Container(
            width: 6,
            height: 80,
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF432818), // Dark brown
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF99582A), // Medium brown
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(event.dateTime),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF99582A), // Medium brown
                        ),
                      ),
                      if (event is AppointmentEvent &&
                          (event as AppointmentEvent).location != null) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF99582A), // Medium brown
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (event as AppointmentEvent).location!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF99582A), // Medium brown
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: eventColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: eventColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  final CalendarEvent event;

  const _UpcomingEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final Color eventColor;

    if (event is AppointmentEvent) {
      eventColor = const Color(0xFF5B8DEF);
    } else if (event is MedicationEvent) {
      eventColor = const Color(0xFF10B981);
    } else {
      eventColor = const Color(0xFFEF4444);
    }

    final dayOfWeek = DateFormat('EEEE').format(event.dateTime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                dayOfWeek.substring(0, 3),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd').format(event.dateTime),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                DateFormat('MMM').format(event.dateTime),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (event is AppointmentEvent &&
                    (event as AppointmentEvent).location != null)
                  Text(
                    (event as AppointmentEvent).location!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (event is MedicationEvent)
                  Text(
                    (event as MedicationEvent).dosage,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(event.dateTime),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: eventColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

extension ThemeExtensions on BuildContext {
  Color get surfacePrimary {
    return Theme.of(this).brightness == Brightness.dark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
  }
}
