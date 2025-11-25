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
import '../../theme/app_theme.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'pet_details_page.dart';
import 'pet_form_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
              SliverToBoxAdapter(child: _buildMyPetsSection(context)),
              SliverToBoxAdapter(child: _buildTodaySection(context)),
              SliverToBoxAdapter(child: Gap(AppTheme.spacing8)),
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
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hey $firstName',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_outline, size: 24.sp, color: Colors.white),
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
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 24.sp, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsPage(injectedUserProvider: userProvider),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyPetsSection(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Pets',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PetFormPage(),
                    ),
                  );
                },
                child: Text(
                  'Add Pet',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
        Gap(AppTheme.spacing3),
        SizedBox(
          height: 220.h,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('pets')
                .orderBy('order')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: GFLoader(type: GFLoaderType.circle));
              }

              final pets = snapshot.data?.docs ?? [];

              if (pets.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
                  child: Center(
                    child: Text(
                      'No pets yet',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: AppTheme.spacing4),
                itemCount: pets.length,
                itemBuilder: (context, index) {
                  final petDoc = pets[index];
                  final isLast = index == pets.length - 1;
                  return _PetCard(
                    petId: petDoc.id,
                    petData: petDoc.data(),
                    isLast: isLast,
                  );
                },
              );
            },
          ),
        ),
        Gap(AppTheme.spacing6),
      ],
    );
  }

  Widget _buildTodaySection(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final events = eventProvider.events;
    final todayEvents = events.where((event) {
      final isToday =
          event.dateTime.isAfter(todayStart) &&
          event.dateTime.isBefore(todayEnd);
      final isRelevantType =
          event is AppointmentEvent || event is MedicationEvent;
      return isToday && isRelevantType;
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
              color: Colors.white,
            ),
          ),
          Gap(AppTheme.spacing3),
          if (todayEvents.isEmpty)
            Container(
              padding: EdgeInsets.all(AppTheme.spacing4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius4),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 20.sp,
                    color: AppTheme.neutral700,
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'No appointments or medications today',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.neutral700,
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
}

class _PetCard extends StatelessWidget {
  final String petId;
  final Map<String, dynamic> petData;
  final bool isLast;

  const _PetCard({
    required this.petId,
    required this.petData,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = petData['name'] ?? 'Unknown';
    final dateOfBirth = petData['dateOfBirth'] != null
        ? (petData['dateOfBirth'] as Timestamp).toDate()
        : null;

    String getAge() {
      if (dateOfBirth == null) return 'Age unknown';
      final now = DateTime.now();
      final difference = now.difference(dateOfBirth);
      final years = difference.inDays ~/ 365;
      final months = (difference.inDays % 365) ~/ 30;

      if (years > 0) {
        return '$years ${years == 1 ? 'year' : 'years'}';
      } else if (months > 0) {
        return '$months ${months == 1 ? 'month' : 'months'}';
      } else {
        return 'Less than a month';
      }
    }

    return Container(
      width: 160.w,
      height: 220.h,
      margin: EdgeInsets.only(
        right: isLast ? AppTheme.spacing4 : AppTheme.spacing3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radius3),
                topRight: Radius.circular(AppTheme.radius3),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                ),
                child: Center(
                  child: Icon(
                    Icons.pets,
                    size: 32.sp,
                    color: AppTheme.neutral700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacing2,
                right: AppTheme.spacing2,
                top: AppTheme.spacing1,
                bottom: 2.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    getAge(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.neutral700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    width: double.infinity,
                    height: 36.h,
                    child: ElevatedButton(
                      onPressed: () {
                        final userId = FirebaseAuth.instance.currentUser?.uid;
                        if (userId != null) {
                          final petRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('pets')
                              .doc(petId);

                        // Pass providers to the new route
                        final eventProvider = context.read<EventProvider>();
                        final userProvider = context.read<UserProvider>();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MultiProvider(
                              providers: [
                                ChangeNotifierProvider.value(value: eventProvider),
                                ChangeNotifierProvider.value(value: userProvider),
                              ],
                              child: PetDetailsPage(petRef: petRef),
                            ),
                          ),
                        );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                        ),
                      ),
                      child: Text(
                        'See More',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadPetDocument() async {
    final petId = event.petId;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (petId == null || userId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(petId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing3),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    color: AppTheme.primary,
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
                      color: AppTheme.neutral700,
                    ),
                    Gap(AppTheme.spacing1),
                    Text(
                      DateFormat('h:mm a').format(event.dateTime),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                    if (event is AppointmentEvent &&
                        (event as AppointmentEvent).location != null) ...[
                      Gap(AppTheme.spacing2),
                      Icon(
                        Icons.location_on_outlined,
                        size: 12.sp,
                        color: AppTheme.neutral700,
                      ),
                      Gap(AppTheme.spacing1),
                      Expanded(
                        child: Text(
                          (event as AppointmentEvent).location!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.neutral700,
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
          SizedBox(width: AppTheme.spacing2),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: _loadPetDocument(),
            builder: (context, snapshot) {
              String label = 'Unknown pet';
              if (snapshot.connectionState == ConnectionState.waiting) {
                label = 'Loading...';
              } else if (snapshot.hasData && snapshot.data != null) {
                final data = snapshot.data!.data();
                if (data != null && data['name'] is String) {
                  label = data['name'] as String;
                }
              }

              return SizedBox(
                height: 48.h,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 120.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing2,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral800,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }
}
