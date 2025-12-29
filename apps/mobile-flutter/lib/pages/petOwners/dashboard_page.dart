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
import '../../providers/chat_provider.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'pet_details_page.dart';
import 'pet_form_page.dart';
import 'home_page.dart';

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
              SliverToBoxAdapter(child: _buildUnreadMessagesCard(context)),
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

  /// Builds a notification card when there are unread messages
  Widget _buildUnreadMessagesCard(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final unreadCount = chatProvider.totalUnreadCount;
        
        // Don't show if no unread messages
        if (unreadCount <= 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacing4,
            vertical: AppTheme.spacing2,
          ),
          child: InkWell(
            onTap: () {
              // Navigate to chat tab
              final homeState = context.findAncestorStateOfType<MyHomePageState>();
              homeState?.switchToChat();
            },
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radius3),
                    ),
                    child: Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unreadCount == 1
                              ? 'You have a new message'
                              : 'You have $unreadCount new messages',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Gap(2.h),
                        Text(
                          'Tap to view your conversations',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius3),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  Future<String> _loadPetName() async {
    final petId = event.petId;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (petId == null || userId == null) return '';
    
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(petId)
        .get();
    
    if (doc.exists && doc.data() != null) {
      return doc.data()!['name'] as String? ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Determine color based on event type
    Color color;
    String? subtitle;

    if (event is AppointmentEvent) {
      color = AppTheme.brandBlueLight;
      subtitle = (event as AppointmentEvent).location;
    } else if (event is MedicationEvent) {
      color = AppTheme.brandTeal;
      subtitle = (event as MedicationEvent).dosage;
    } else {
      color = Colors.orange;
    }

    return FutureBuilder<String>(
      future: _loadPetName(),
      builder: (context, snapshot) {
        final petName = snapshot.data ?? '';
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Row(
              children: [
                Container(
                  width: 4.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: color,
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
                          if (petName.isNotEmpty) ...[
                            Gap(AppTheme.spacing2),
                            Icon(
                              Icons.pets,
                              size: 12.sp,
                              color: AppTheme.neutral700,
                            ),
                            Gap(AppTheme.spacing1),
                            Text(
                              petName,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppTheme.neutral700,
                              ),
                            ),
                          ],
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            Gap(AppTheme.spacing2),
                            Icon(
                              event is AppointmentEvent
                                  ? Icons.location_on_outlined
                                  : Icons.info_outline,
                              size: 12.sp,
                              color: AppTheme.neutral700,
                            ),
                            Gap(AppTheme.spacing1),
                            Expanded(
                              child: Text(
                                subtitle,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
