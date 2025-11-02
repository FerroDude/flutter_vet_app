import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import '../../providers/user_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import 'add_symptom_sheet.dart';
import '../../widgets/simple_event_forms.dart';
import '../../theme/app_theme.dart';
import 'profile_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      body: SafeArea(
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
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildQuickAdd(context)),
              SliverToBoxAdapter(child: _buildTodaySection(context)),
              SliverToBoxAdapter(child: _buildUpcomingSection(context)),
              SliverToBoxAdapter(child: Gap(AppTheme.spacing8)),
            ],
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
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hey $firstName',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          GFIconButton(
            icon: Icon(Icons.person_outline, size: 20.sp),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfilePage(injectedUserProvider: userProvider),
                ),
              );
            },
            type: GFButtonType.outline2x,
            shape: GFIconButtonShape.standard,
            color: AppTheme.neutral300,
          ),
          Gap(AppTheme.spacing2),
          GFIconButton(
            icon: Icon(Icons.settings_outlined, size: 20.sp),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsPage(injectedUserProvider: userProvider),
                ),
              );
            },
            type: GFButtonType.outline2x,
            shape: GFIconButtonShape.standard,
            color: AppTheme.neutral300,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdd(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Add',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          Gap(AppTheme.spacing3),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.event_outlined,
                  label: 'Appointment',
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
              Gap(AppTheme.spacing2),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.medication_outlined,
                  label: 'Medication',
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
              Gap(AppTheme.spacing2),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.favorite_outline,
                  label: 'Health Log',
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
          Gap(AppTheme.spacing6),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          Gap(AppTheme.spacing3),
          if (todayEvents.isEmpty)
            Container(
              padding: EdgeInsets.all(AppTheme.spacing4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius3),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 20.sp,
                    color: context.textSecondary,
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'No events today',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...todayEvents.map(
              (event) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                child: _EventCard(event: event),
              ),
            ),
          Gap(AppTheme.spacing4),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          Gap(AppTheme.spacing3),
          if (limitedEvents.isEmpty)
            Container(
              padding: EdgeInsets.all(AppTheme.spacing4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius3),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 20.sp,
                    color: context.textSecondary,
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'No upcoming events',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...limitedEvents.map(
              (event) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacing2),
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
      backgroundColor: parentContext.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius4),
        ),
      ),
      builder: (modalContext) => Container(
        padding: EdgeInsets.all(AppTheme.spacing4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Pet',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: modalContext.textPrimary,
              ),
            ),
            Gap(AppTheme.spacing4),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('pets')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: GFLoader(type: GFLoaderType.circle));
                }

                final pets = snapshot.data!.docs;

                if (pets.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: Text(
                      'No pets found. Add a pet first.',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  );
                }

                return Column(
                  children: pets.map((doc) {
                    final pet = doc.data();
                    return GFListTile(
                      avatar: GFAvatar(
                        backgroundColor: context.isDark
                            ? Color(0xFF2F2F2F)
                            : AppTheme.neutral100,
                        child: Icon(
                          Icons.pets,
                          size: 20.sp,
                          color: context.textPrimary,
                        ),
                      ),
                      title: Text(
                        pet['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      subTitle: Text(
                        pet['breed'] ?? pet['species'] ?? '',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: context.textSecondary,
                        ),
                      ),
                      onTap: () {
                        final petId = doc.id;
                        Navigator.pop(modalContext);
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
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius3),
      child: Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          border: Border.all(color: context.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28.sp, color: AppTheme.neutral700),
            Gap(AppTheme.spacing2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
    return GFCard(
      elevation: 0,
      color: context.surface,
      borderOnForeground: true,
      boxFit: BoxFit.cover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      content: Row(
        children: [
          Container(
            width: 4.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: AppTheme.neutral800,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap(AppTheme.spacing1),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12.sp,
                      color: context.textSecondary,
                    ),
                    Gap(AppTheme.spacing1),
                    Text(
                      DateFormat('h:mm a').format(event.dateTime),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: context.textSecondary,
                      ),
                    ),
                    if (event is AppointmentEvent &&
                        (event as AppointmentEvent).location != null) ...[
                      Gap(AppTheme.spacing2),
                      Icon(
                        Icons.location_on_outlined,
                        size: 12.sp,
                        color: context.textSecondary,
                      ),
                      Gap(AppTheme.spacing1),
                      Expanded(
                        child: Text(
                          (event as AppointmentEvent).location!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: context.textSecondary,
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
          GFBadge(
            text: 'Today',
            color: AppTheme.neutral800,
            size: GFSize.SMALL,
            textStyle: TextStyle(fontSize: 10.sp),
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
    return GFCard(
      elevation: 0,
      color: context.surface,
      borderOnForeground: true,
      boxFit: BoxFit.cover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      content: Row(
        children: [
          Column(
            children: [
              Text(
                DateFormat('EEE').format(event.dateTime).toUpperCase(),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateFormat('dd').format(event.dateTime),
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap(AppTheme.spacing1),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12.sp,
                      color: context.textSecondary,
                    ),
                    Gap(AppTheme.spacing1),
                    Text(
                      DateFormat('h:mm a').format(event.dateTime),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
