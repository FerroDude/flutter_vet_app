import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../models/symptom_models.dart';
import '../../providers/event_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/medication_provider.dart';
import '../../models/medication_model.dart';
import '../../widgets/simple_event_forms.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/medication_widgets.dart';
import '../../services/pet_service.dart';
import 'add_symptom_sheet.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import '../../utils/cleanup_old_medications.dart';

/// Clean, professional calendar page
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => CalendarPageState();
}

// Global key for FAB access
final calendarPageKey = GlobalKey<CalendarPageState>();

class CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );
  final _petService = PetService();

  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  Map<DateTime, List<PetSymptom>> _symptomsByDay = {};
  Map<String, String> _petNamesCache = {};

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
      _loadSymptomsByDay();
      _loadPetNames();
    });
  }

  Future<void> _loadPetNames() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final petsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .get();

    final names = <String, String>{};
    for (final doc in petsSnap.docs) {
      final data = doc.data();
      names[doc.id] = data['name'] as String? ?? 'Unknown';
    }
    if (mounted) {
      setState(() => _petNamesCache = names);
    }
  }

  String _getPetName(String? petId) {
    if (petId == null || petId.isEmpty) return '';
    return _petNamesCache[petId] ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await context.read<EventProvider>().refresh();
    await _loadSymptomsByDay();
  }

  int get currentTabIndex => _tabController.index;

  void switchToAppointmentsTab() {
    if (mounted && _tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  void handleFabAction() {
    switch (_tabController.index) {
      case 0:
        // Calendar tab - show selection dialog
        showAddEventDialog();
        break;
      case 1:
        // Appointments tab - go directly to appointment form
        showAppointmentFormWithPetSelection();
        break;
      case 2:
        // Medications tab - go directly to medication form
        _showMedicationFormWithPetSelection();
        break;
      case 3:
        // Symptoms tab - go directly to symptom form
        _showSymptomSheetWithPetSelection();
        break;
    }
  }

  void showAddEventDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: context.read<EventProvider>(),
        child: SimpleAddEventDialog(
          selectedDate: _selectedDay,
          onShowAppointment: () => showAppointmentFormWithPetSelection(),
          onShowMedication: () => _showMedicationFormWithPetSelection(),
          onShowSymptom: () => _showSymptomSheetWithPetSelection(),
        ),
      ),
    ).then((result) {
      if (result == true) _refreshData();
    });
  }

  void showAppointmentForm() {
    showAppointmentFormWithPetSelection();
  }

  void showMedicationForm() {
    _showMedicationFormWithPetSelection();
  }

  void _onDaySelected(DateTime selectedDay, List<CalendarEvent> events) {
    setState(() => _selectedDay = selectedDay);
  }

  Future<void> _loadSymptomsByDay() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final start = DateTime(_selectedDay.year, _selectedDay.month - 3, 1);
    final end = DateTime(_selectedDay.year, _selectedDay.month + 3, 0);
    final summaries = await _petService.symptomsByDayForUser(
      userId,
      start: start,
      end: end,
    );
    if (mounted) setState(() => _symptomsByDay = summaries);
  }

  void _onFormatChanged(CalendarFormat format) {
    setState(() => _calendarFormat = format);
  }

  Widget _topAction(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 24.sp),
      onPressed: onPressed,
    );
  }

  Widget _buildHeader(BuildContext context, UserProvider userProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top),
        Gap(AppTheme.spacing2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Row(
            children: [
              Text(
                'Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _topAction(Icons.settings_outlined, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsPage(injectedUserProvider: userProvider),
                  ),
                );
              }),
              _topAction(Icons.person_outline, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfilePage(injectedUserProvider: userProvider),
                  ),
                );
              }),
            ],
          ),
        ),
        Gap(AppTheme.spacing1),
        Container(
          margin: EdgeInsets.only(
            left: AppTheme.spacing4,
            right: AppTheme.spacing4,
            bottom: AppTheme.spacing2,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacing2,
            vertical: AppTheme.spacing2,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            boxShadow: AppTheme.cardShadow,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final itemWidth = totalWidth / 4;
              const circleSize = 48.0;
              final icons = [
                Icons.calendar_month,
                Icons.event,
                Icons.medication,
                Icons.healing,
              ];

              return AnimatedBuilder(
                animation: _tabController.animation!,
                builder: (context, child) {
                  final animationValue = _tabController.animation!.value;
                  // Center of selected tab position
                  final indicatorLeft =
                      animationValue * itemWidth + (itemWidth - circleSize) / 2;

                  return SizedBox(
                    height: circleSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Sliding circular indicator
                        Positioned(
                          left: indicatorLeft,
                          top: 0,
                          child: Container(
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Icons row - positioned to match indicator calculation
                        Row(
                          children: List.generate(4, (index) {
                            // Calculate how "selected" this icon is (0.0 to 1.0)
                            final distance = (animationValue - index).abs();
                            final selectionProgress = (1.0 - distance).clamp(
                              0.0,
                              1.0,
                            );

                            return SizedBox(
                              width: itemWidth,
                              height: circleSize,
                              child: GestureDetector(
                                onTap: () => _tabController.animateTo(index),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Icon(
                                    icons[index],
                                    size: 26,
                                    color: Color.lerp(
                                      AppTheme.primary,
                                      Colors.white,
                                      selectionProgress,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildHeader(context, userProvider),
                Expanded(
                  child: Consumer<EventProvider>(
                    builder: (context, eventProvider, child) {
                      if (eventProvider.isLoading &&
                          eventProvider.events.isEmpty) {
                        return _buildLoadingState(context);
                      }

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCalendarView(context, eventProvider),
                          _buildAppointmentsList(context, eventProvider),
                          _buildMedicationsList(context, eventProvider),
                          _buildSymptomsList(context),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: handleFabAction,
            backgroundColor: AppTheme.neutral800,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: AppTheme.spacing4),
          Text(
            'Loading calendar...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(BuildContext context, EventProvider eventProvider) {
    final allEvents = eventProvider.events;
    final eventsByDate = <DateTime, List<CalendarEvent>>{};

    for (final event in allEvents) {
      final date = DateTime(
        event.dateTime.year,
        event.dateTime.month,
        event.dateTime.day,
      );
      eventsByDate.putIfAbsent(date, () => []).add(event);
    }

    // Merge symptom data
    final merged = {...eventsByDate};
    _symptomsByDay.forEach((day, symptoms) {
      if (symptoms.isEmpty) return;
      final existing = merged[day] ??= [];
      final title = _symptomSummaryTitle(symptoms);
      final List<String> uniqueLabels = LinkedHashSet<String>.from(
        symptoms.map((s) => _symptomLabel(s.type)),
      ).toList();
      final description = uniqueLabels.length > 1
          ? 'Logged symptoms: ${uniqueLabels.join(', ')}'
          : '';

      existing.add(
        NoteEvent(
          id: 'symptom_${day.millisecondsSinceEpoch}',
          title: title,
          description: description,
          dateTime: DateTime(day.year, day.month, day.day, 12),
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'currentUser',
          petId: null,
          createdAt: day,
          updatedAt: day,
          tags: uniqueLabels.take(4).toList(),
          reminderDateTime: null,
        ),
      );
    });

    final selectedDate = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedEvents = merged[selectedDate] ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Clean Calendar Widget
          Container(
            margin: EdgeInsets.all(AppTheme.spacing4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius4),
              boxShadow: AppTheme.cardShadow,
            ),
            child: CalendarView(
              events: merged,
              onDaySelected: (selectedDay, events) {
                setState(() => _selectedDay = selectedDay);
                _onDaySelected(selectedDay, events);
                _loadSymptomsByDay();
              },
              selectedDay: _selectedDay,
              calendarFormat: _calendarFormat,
              onFormatChanged: _onFormatChanged,
            ),
          ),

          // Simple Day Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (selectedEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedEvents.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacing3),

          // Events for Selected Day
          if (selectedEvents.isEmpty)
            _buildEmptyDayState(context)
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              child: Column(
                children: [
                  for (int index = 0; index < selectedEvents.length; index++)
                    _buildModernEventCard(
                      context: context,
                      event: selectedEvents[index],
                      delay: index * 50,
                    ),
                ],
              ),
            ),
          
          // Bottom padding
          SizedBox(height: AppTheme.spacing6),
        ],
      ),
    );
  }

  Widget _buildModernEventCard({
    required BuildContext context,
    required CalendarEvent event,
    required int delay,
  }) {
    Color color;
    String? subtitle;
    final petName = _getPetName(event.petId);

    if (event is AppointmentEvent) {
      color = AppTheme.brandBlueLight;
      subtitle = event.location;
    } else if (event is MedicationEvent) {
      color = AppTheme.brandTeal;
      subtitle = event.dosage;
    } else {
      color = Colors.orange;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing2),
      child: Container(
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
      ),
    );
  }

  Widget _buildEmptyDayState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      child: Text(
        'No events this day',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAppointmentsList(
    BuildContext context,
    EventProvider eventProvider,
  ) {
    final appointments =
        eventProvider.events.whereType<AppointmentEvent>().toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (appointments.isEmpty) {
      return _buildSimpleEmptyState(context, 'No appointments');
    }

    // Group by date
    final grouped = <String, List<AppointmentEvent>>{};
    for (final apt in appointments) {
      final key = DateFormat('yyyy-MM-dd').format(apt.dateTime);
      grouped.putIfAbsent(key, () => []).add(apt);
    }

    final dateKeys = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: EdgeInsets.all(AppTheme.spacing4),
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final key = dateKeys[index];
          final group = grouped[key]!;
          final headerDate = DateFormat(
            'EEE, MMM d',
          ).format(group.first.dateTime);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.spacing2,
                  AppTheme.spacing4,
                  AppTheme.spacing2,
                  AppTheme.spacing2,
                ),
                child: Text(
                  headerDate,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              ...group.map((apt) => _buildAppointmentCard(context, apt, index)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    AppointmentEvent appointment,
    int index,
  ) {
    final petName = _getPetName(appointment.petId);
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            onTap: () => _editAppointment(appointment),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing3),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlueLight,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.title,
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
                              DateFormat('h:mm a').format(appointment.dateTime),
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
                            if (appointment.location != null) ...[
                              Gap(AppTheme.spacing2),
                              Icon(
                                Icons.location_on_outlined,
                                size: 12.sp,
                                color: AppTheme.neutral700,
                              ),
                              Gap(AppTheme.spacing1),
                              Expanded(
                                child: Text(
                                  appointment.location!,
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
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationsList(
    BuildContext context,
    EventProvider eventProvider,
  ) {
    return Consumer<MedicationProvider>(
      builder: (context, medicationProvider, _) {
        // Ensure we're subscribed to all pets' medications
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final petId in _petNamesCache.keys) {
            medicationProvider.subscribeToPet(petId);
          }
        });

        // Collect all medications from all subscribed pets
        final allMedications = <Medication>[];
        for (final petId in _petNamesCache.keys) {
          allMedications.addAll(medicationProvider.getMedicationsForPet(petId));
        }

        final activeMeds = allMedications.where((m) => m.isActive).toList();
        final pastMeds = allMedications.where((m) => !m.isActive).toList();

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView(
            padding: EdgeInsets.all(AppTheme.spacing4),
            children: [
              // DEV: Delete all medications button
              _buildDeleteAllMedsButton(context),
              SizedBox(height: AppTheme.spacing4),

              if (allMedications.isEmpty) ...[
                _buildSimpleEmptyState(context, 'No medications'),
              ] else ...[
                // Active medications
                if (activeMeds.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Active Medications', Icons.medication_rounded),
                  ...activeMeds.map((med) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: MedicationCard(
                      medication: med,
                      petName: _getPetName(med.petId),
                      showPetName: true,
                      onMarkDose: () => _markDoseTaken(context, med, medicationProvider),
                    ),
                  )),
                ],

                // Past medications
                if (pastMeds.isNotEmpty) ...[
                  if (activeMeds.isNotEmpty) SizedBox(height: AppTheme.spacing4),
                  _buildSectionHeader(context, 'Past Medications', Icons.history),
                  ...pastMeds.map((med) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: MedicationCard(
                      medication: med,
                      petName: _getPetName(med.petId),
                      showPetName: true,
                    ),
                  )),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _markDoseTaken(
    BuildContext context,
    Medication med,
    MedicationProvider provider,
  ) async {
    try {
      await provider.logDoseTaken(
        med.petId,
        med.id,
        DateTime.now(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dose marked as taken for ${med.name}'),
            backgroundColor: AppTheme.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildDeleteAllMedsButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.developer_mode, color: Colors.red, size: 20.sp),
          SizedBox(width: AppTheme.spacing2),
          Expanded(
            child: Text(
              'Developer Tool',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete All Medications?'),
                  content: const Text(
                    'This will delete ALL medication events (old system) and medications (new system). This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  final results = await MedicationCleanup.cleanupAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Deleted ${results['oldMedicationEvents']} old events, ${results['newMedications']} new meds',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _refreshData();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            child: Text(
              'Delete All Meds (Dev)',
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacing2,
        AppTheme.spacing2,
        AppTheme.spacing2,
        AppTheme.spacing3,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
          SizedBox(width: AppTheme.spacing2),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  void _editAppointment(AppointmentEvent appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider.value(
        value: this.context.read<EventProvider>(),
        child: SimpleAppointmentForm(
          selectedDate: appointment.dateTime,
          existingEvent: appointment,
        ),
      ),
    ).then((result) {
      if (result == true) _refreshData();
    });
  }

  String _symptomSummaryTitle(List<PetSymptom> symptoms) {
    if (symptoms.isEmpty) return 'Symptoms logged';
    final labels = symptoms.map((s) => _symptomLabel(s.type)).toList();
    final uniqueLabels = LinkedHashSet<String>.from(labels).toList();
    if (uniqueLabels.length == 1) {
      final occurrences = labels.length;
      return occurrences > 1
          ? '${uniqueLabels.first} (x$occurrences)'
          : uniqueLabels.first;
    }
    if (uniqueLabels.length == 2) {
      return '${uniqueLabels[0]} & ${uniqueLabels[1]}';
    }
    return '${uniqueLabels[0]}, ${uniqueLabels[1]} + ${uniqueLabels.length - 2} more';
  }

  String _symptomLabel(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
        return 'Vomiting';
      case SymptomType.diarrhea:
        return 'Diarrhea';
      case SymptomType.cough:
        return 'Cough';
      case SymptomType.sneezing:
        return 'Sneezing';
      case SymptomType.choking:
        return 'Choking';
      case SymptomType.seizure:
        return 'Seizure';
      case SymptomType.disorientation:
        return 'Disorientation';
      case SymptomType.circling:
        return 'Circling';
      case SymptomType.restlessness:
        return 'Restlessness';
      case SymptomType.limping:
        return 'Limping';
      case SymptomType.jointDiscomfort:
        return 'Joint discomfort';
      case SymptomType.itching:
        return 'Itching';
      case SymptomType.ocularDischarge:
        return 'Ocular discharge';
      case SymptomType.vaginalDischarge:
        return 'Vaginal discharge';
      case SymptomType.estrus:
        return 'Estrus';
      case SymptomType.other:
        return 'Other symptom';
    }
  }

  // Pet Selection Methods

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _showPetSelectionDialog() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in first'),
          backgroundColor: AppTheme.error,
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
          backgroundColor: AppTheme.warning,
        ),
      );
      return null;
    }

    // Show pet selection dialog
    return await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacing5),
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a Pet',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              Gap(AppTheme.spacing5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(petsSnapshot.docs.length, (index) {
                      final pet = petsSnapshot.docs[index];
                      final petData = pet.data();
                      final petName = petData['name'] as String? ?? 'Unknown';
                      final species =
                          petData['species'] as String? ?? 'Unknown';

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < petsSnapshot.docs.length - 1
                              ? AppTheme.spacing3
                              : 0,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(dialogContext, pet),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius3,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing4,
                                vertical: AppTheme.spacing3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius3,
                                ),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getSpeciesIcon(species),
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  Gap(AppTheme.spacing3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          petName,
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        Text(
                                          species,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: AppTheme.neutral700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Gap(AppTheme.spacing4),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSpeciesIcon(String species) {
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

  void showAppointmentFormWithPetSelection() async {
    // Capture the provider before async operation
    final eventProvider = context.read<EventProvider>();
    final selectedPet = await _showPetSelectionDialog();
    if (selectedPet != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: eventProvider,
          child: SimpleAppointmentForm(
            selectedDate: _selectedDay,
            petId: selectedPet.id,
          ),
        ),
      ).then((result) {
        if (result == true && mounted) _refreshData();
      });
    }
  }

  void _showMedicationFormWithPetSelection() async {
    final medicationProvider = context.read<MedicationProvider>();
    final selectedPet = await _showPetSelectionDialog();
    if (selectedPet != null && mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: medicationProvider,
          child: MedicationFormDialog(
            petId: selectedPet.id,
          ),
        ),
      ).then((result) {
        if (result == true && mounted) _refreshData();
      });
    }
  }

  void _showSymptomSheetWithPetSelection() async {
    final selectedPet = await _showPetSelectionDialog();
    if (selectedPet != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddSymptomSheet(petId: selectedPet.id),
      ).then((result) {
        if (result == true) _refreshData();
      });
    }
  }

  Widget _buildSymptomsList(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return _buildEmptyState(
        context: context,
        icon: Icons.healing,
        title: 'Not signed in',
        message: 'Please sign in to view symptoms',
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .get(),
      builder: (context, petsSnapshot) {
        if (petsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!petsSnapshot.hasData || petsSnapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            context: context,
            icon: Icons.pets,
            title: 'No pets',
            message: 'Add a pet to track symptoms',
          );
        }

        // Build a map of petId -> petName
        final petNames = <String, String>{};
        for (final doc in petsSnapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          petNames[doc.id] = data['name'] as String? ?? 'Unknown';
        }

        // Fetch all symptoms from all pets
        return FutureBuilder<List<_SymptomWithPet>>(
          future: _fetchAllSymptoms(userId, petsSnapshot.data!.docs, petNames),
          builder: (context, symptomsSnapshot) {
            if (symptomsSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final allSymptoms = symptomsSnapshot.data ?? [];
            if (allSymptoms.isEmpty) {
              return _buildSimpleEmptyState(context, 'No symptoms');
            }

            // Group by date
            final grouped = <String, List<_SymptomWithPet>>{};
            for (final symptom in allSymptoms) {
              final key = DateFormat('yyyy-MM-dd').format(symptom.timestamp);
              grouped.putIfAbsent(key, () => []).add(symptom);
            }

            final dateKeys = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return RefreshIndicator(
              onRefresh: () async {
                await _loadSymptomsByDay();
                setState(() {});
              },
              child: ListView.builder(
                padding: EdgeInsets.all(AppTheme.spacing4),
                itemCount: dateKeys.length,
                itemBuilder: (context, index) {
                  final key = dateKeys[index];
                  final group = grouped[key]!;
                  final headerDate = DateFormat(
                    'EEE, MMM d',
                  ).format(group.first.timestamp);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppTheme.spacing2,
                          AppTheme.spacing4,
                          AppTheme.spacing2,
                          AppTheme.spacing2,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            SizedBox(width: AppTheme.spacing2),
                            Text(
                              headerDate,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            Spacer(),
                            Text(
                              '${group.length} ${group.length == 1 ? 'symptom' : 'symptoms'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...group.map(
                        (symptom) => _buildSymptomCard(
                          context,
                          symptom.type,
                          symptom.timestamp,
                          symptom.note,
                          symptom.petName,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_SymptomWithPet>> _fetchAllSymptoms(
    String userId,
    List<QueryDocumentSnapshot> petDocs,
    Map<String, String> petNames,
  ) async {
    final allSymptoms = <_SymptomWithPet>[];

    for (final petDoc in petDocs) {
      final symptomsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(petDoc.id)
          .collection('symptoms')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      for (final doc in symptomsSnap.docs) {
        final data = doc.data();
        final type = SymptomType.values.firstWhere(
          (t) => t.toString().split('.').last == data['type'],
          orElse: () => SymptomType.other,
        );
        final timestamp =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final note = data['note'] as String?;

        allSymptoms.add(
          _SymptomWithPet(
            type: type,
            timestamp: timestamp,
            note: note,
            petId: petDoc.id,
            petName: petNames[petDoc.id] ?? 'Unknown',
          ),
        );
      }
    }

    // Sort by timestamp descending
    allSymptoms.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allSymptoms;
  }

  Widget _buildSymptomCard(
    BuildContext context,
    SymptomType type,
    DateTime timestamp,
    String? note,
    String petName,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing2),
      child: Container(
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
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _symptomLabel(type),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
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
                          DateFormat('h:mm a').format(timestamp),
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
                        if (note != null && note.isNotEmpty) ...[
                          Gap(AppTheme.spacing2),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppTheme.neutral700,
                                fontStyle: FontStyle.italic,
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
      ),
    );
  }
}

// Helper class to store symptom with pet info
class _SymptomWithPet {
  final SymptomType type;
  final DateTime timestamp;
  final String? note;
  final String petId;
  final String petName;

  _SymptomWithPet({
    required this.type,
    required this.timestamp,
    this.note,
    required this.petId,
    required this.petName,
  });
}

// Extension methods are already defined in app_theme.dart
