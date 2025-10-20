import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../add_symptom_sheet.dart';
import '../../widgets/simple_event_forms.dart';

/// Modern, redesigned dashboard with clean UI and smooth animations
class ModernDashboardPage extends StatefulWidget {
  const ModernDashboardPage({super.key});

  @override
  State<ModernDashboardPage> createState() => _ModernDashboardPageState();
}

class _ModernDashboardPageState extends State<ModernDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.surfacePrimary,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Modern App Bar
            SliverToBoxAdapter(child: _buildModernHeader(context, isDark)),

            // Quick Actions Section
            SliverToBoxAdapter(
              child: _buildQuickActions(context)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
            ),

            // Stats Cards
            SliverToBoxAdapter(
              child: _buildStatsCards(context)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
            ),

            // Today's Events Section
            SliverToBoxAdapter(
              child: _buildTodaysEvents(context)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
            ),

            // Upcoming Events Section
            SliverToBoxAdapter(
              child: _buildUpcomingEvents(context)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
            ),

            // Bottom Padding
            SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, bool isDark) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.currentUser == null) {
          return SizedBox.shrink();
        }

        final displayName = userProvider.currentUser?.displayName ?? 'User';
        final firstName = displayName.split(' ').first;

        // Determine greeting based on time of day
        final hour = DateTime.now().hour;
        String greeting;
        IconData greetingIcon;

        if (hour < 12) {
          greeting = 'Good morning';
          greetingIcon = Icons.wb_sunny;
        } else if (hour < 17) {
          greeting = 'Good afternoon';
          greetingIcon = Icons.wb_sunny_outlined;
        } else {
          greeting = 'Good evening';
          greetingIcon = Icons.nightlight_outlined;
        }

        return Container(
          padding: EdgeInsets.all(AppTheme.spacing6),
          margin: EdgeInsets.all(AppTheme.spacing4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.primaryColor.withOpacity(0.05),
                context.primaryColor.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: context.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(greetingIcon, color: context.primaryColor, size: 28)
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 2000.ms, delay: 1000.ms),
                  SizedBox(width: AppTheme.spacing3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        Text(
                          firstName,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.textColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Profile Avatar
                  Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.primaryColor,
                              context.primaryColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            firstName[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .scale(duration: 300.ms, delay: 100.ms)
                      .fadeIn(duration: 300.ms),
                ],
              ),
              SizedBox(height: AppTheme.spacing2),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing3),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context: context,
                  title: 'Add Appointment',
                  icon: Icons.event,
                  color: context.primaryColor,
                  onTap: () => _showAppointmentForm(context),
                ),
              ),
              SizedBox(width: AppTheme.spacing3),
              Expanded(
                child: _buildActionCard(
                  context: context,
                  title: 'Add Medication',
                  icon: Icons.medication,
                  color: AppTheme.primaryGreen,
                  onTap: () => _showMedicationForm(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing3),
          _buildActionCard(
            context: context,
            title: 'Add Symptom',
            icon: Icons.healing,
            color: AppTheme.accentCoral,
            onTap: () => _showSymptomSheet(context),
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Row(
              mainAxisAlignment: isFullWidth
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacing2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                if (isFullWidth) ...[
                  SizedBox(width: AppTheme.spacing3),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(width: AppTheme.spacing2),
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 300.ms).fadeIn(duration: 300.ms);
  }

  Widget _buildStatsCards(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final endToday = start.add(Duration(days: 1));
        final next7Days = start.add(Duration(days: 7));

        final todayCount =
            eventProvider.appointments
                .where(
                  (e) =>
                      !e.dateTime.isBefore(start) &&
                      e.dateTime.isBefore(endToday),
                )
                .length +
            eventProvider.medications
                .where(
                  (e) =>
                      !e.dateTime.isBefore(start) &&
                      e.dateTime.isBefore(endToday),
                )
                .length;

        final upcomingCount = eventProvider.appointments
            .where(
              (e) =>
                  !e.dateTime.isBefore(endToday) &&
                  e.dateTime.isBefore(next7Days),
            )
            .length;

        final medCount = eventProvider.medications
            .where(
              (e) =>
                  !e.dateTime.isBefore(start) && e.dateTime.isBefore(next7Days),
            )
            .length;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: AppTheme.spacing4,
            vertical: AppTheme.spacing2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              SizedBox(height: AppTheme.spacing3),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      title: 'Today',
                      count: todayCount,
                      icon: Icons.today,
                      color: context.primaryColor,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing3),
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      title: 'Next 7 Days',
                      count: upcomingCount,
                      icon: Icons.calendar_month,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing3),
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      title: 'Medications',
                      count: medCount,
                      icon: Icons.medication,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
          padding: EdgeInsets.all(AppTheme.spacing4),
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: context.borderLight, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: AppTheme.spacing2),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        )
        .animate()
        .scale(duration: 300.ms, begin: Offset(0.9, 0.9), end: Offset(1, 1))
        .fadeIn(duration: 300.ms);
  }

  Widget _buildTodaysEvents(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final endToday = start.add(Duration(days: 1));

        final todaysEvents = <CalendarEvent>[
          ...eventProvider.appointments.where(
            (e) => !e.dateTime.isBefore(start) && e.dateTime.isBefore(endToday),
          ),
          ...eventProvider.medications.where(
            (e) => !e.dateTime.isBefore(start) && e.dateTime.isBefore(endToday),
          ),
        ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        return Container(
          margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Schedule',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.textColor,
                    ),
                  ),
                  if (todaysEvents.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Text(
                        '${todaysEvents.length}',
                        style: TextStyle(
                          color: context.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppTheme.spacing3),
              if (todaysEvents.isEmpty)
                _buildEmptyState(
                  context: context,
                  icon: Icons.event_available,
                  message: 'No events scheduled for today',
                )
              else
                ...todaysEvents.toList().asMap().entries.map((entry) {
                  return _buildEventCard(
                    context: context,
                    event: entry.value,
                    delay: entry.key * 50,
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingEvents(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final endToday = start.add(Duration(days: 1));
        final next7Days = start.add(Duration(days: 7));

        final upcomingEvents = <CalendarEvent>[
          ...eventProvider.appointments.where(
            (e) =>
                !e.dateTime.isBefore(endToday) &&
                e.dateTime.isBefore(next7Days),
          ),
          ...eventProvider.medications.where(
            (e) =>
                !e.dateTime.isBefore(endToday) &&
                e.dateTime.isBefore(next7Days),
          ),
        ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        if (upcomingEvents.isEmpty) return SizedBox.shrink();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming This Week',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              SizedBox(height: AppTheme.spacing3),
              ...upcomingEvents.take(5).toList().asMap().entries.map((entry) {
                return _buildEventCard(
                  context: context,
                  event: entry.value,
                  delay: entry.key * 50,
                  showDate: true,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard({
    required BuildContext context,
    required CalendarEvent event,
    required int delay,
    bool showDate = false,
  }) {
    final isAppointment = event is AppointmentEvent;
    final isMedication = event is MedicationEvent;

    Color color;
    IconData icon;

    if (isAppointment) {
      color = context.primaryColor;
      icon = Icons.event;
    } else if (isMedication) {
      color = AppTheme.primaryGreen;
      icon = Icons.medication;
    } else {
      color = AppTheme.accentCoral;
      icon = Icons.note;
    }

    return Container(
          margin: EdgeInsets.only(bottom: AppTheme.spacing3),
          padding: EdgeInsets.all(AppTheme.spacing4),
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: AppTheme.spacing4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppTheme.spacing1),
                    Text(
                      showDate
                          ? DateFormat(
                              'EEE, MMM d • h:mm a',
                            ).format(event.dateTime)
                          : DateFormat('h:mm a').format(event.dateTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.secondaryTextColor,
                size: 20,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: delay.ms)
        .slideX(begin: 0.2, end: 0, duration: 300.ms, delay: delay.ms);
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing6),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.borderLight, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: context.secondaryTextColor.withOpacity(0.5),
          ),
          SizedBox(height: AppTheme.spacing2),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _showAppointmentForm(BuildContext context) async {
    final selectedPet = await _showPetSelectionDialog(context);
    if (selectedPet != null && mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: context.read<EventProvider>(),
          child: SimpleAppointmentForm(
            selectedDate: DateTime.now(),
            petId: selectedPet.id,
          ),
        ),
      );
    }
  }

  void _showMedicationForm(BuildContext context) async {
    final selectedPet = await _showPetSelectionDialog(context);
    if (selectedPet != null && mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: context.read<EventProvider>(),
          child: SimpleMedicationForm(
            selectedDate: DateTime.now(),
            petId: selectedPet.id,
          ),
        ),
      );
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _showPetSelectionDialog(
    BuildContext context,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in first'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return null;
    }

    // Get user's pets
    final petsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .get();

    if (!mounted) return null;

    if (petsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add a pet first'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return null;
    }

    // Show pet selection dialog
    return await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Select a Pet'),
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
                  backgroundColor: context.primaryColor,
                  child: Text(
                    petName[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
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
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSymptomSheet(BuildContext context) async {
    final selectedPet = await _showPetSelectionDialog(context);
    if (selectedPet != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddSymptomSheet(petId: selectedPet.id),
      );
    }
  }
}
