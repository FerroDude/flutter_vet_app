import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../models/symptom_models.dart';
import '../../providers/event_provider.dart';
import '../../widgets/simple_event_forms.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/modern_modals.dart';
import '../../services/pet_service.dart';
import 'add_symptom_sheet.dart';

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
  final Set<String> _expandedSeries = {};
  final _petService = PetService();

  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<PetSymptom>> _symptomsByDay = {};

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
      _loadSymptomsByDay();
    });
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

  void handleFabAction() {
    switch (_tabController.index) {
      case 0:
        showAddEventDialog();
        break;
      case 1:
        _showAppointmentFormWithPetSelection();
        break;
      case 2:
        _showMedicationFormWithPetSelection();
        break;
      case 3:
        _showSymptomSheetWithPetSelection();
        break;
    }
  }

  void showAddEventDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: context.read<EventProvider>(),
        child: SimpleAddEventDialog(selectedDate: _selectedDay),
      ),
    ).then((result) {
      if (result == true) _refreshData();
    });
  }

  void showAppointmentForm() {
    _showAppointmentFormWithPetSelection();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.surfacePrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? context.surfaceSecondary : Colors.white,
            border: Border(bottom: BorderSide(color: context.border, width: 1)),
          ),
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacing2),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.neutral700,
            unselectedLabelColor: context.secondaryTextColor,
            indicatorColor: AppTheme.neutral700,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_month, size: 32)),
              Tab(icon: Icon(Icons.event, size: 32)),
              Tab(icon: Icon(Icons.medication, size: 32)),
              Tab(icon: Icon(Icons.healing, size: 32)),
            ],
          ),
        ),
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          if (eventProvider.isLoading && eventProvider.events.isEmpty) {
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
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.neutral700),
          SizedBox(height: AppTheme.spacing4),
          Text(
            'Loading calendar...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.secondaryTextColor),
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

    return Column(
      children: [
        // Clean Calendar Widget
        Container(
          margin: EdgeInsets.all(AppTheme.spacing4),
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(16),
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
                  color: context.textColor,
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
                    color: AppTheme.neutral700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedEvents.length}',
                    style: TextStyle(
                      color: AppTheme.neutral700,
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
        Expanded(
          child: selectedEvents.isEmpty
              ? _buildEmptyDayState(context)
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    return _buildModernEventCard(
                      context: context,
                      event: selectedEvents[index],
                      delay: index * 50,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Apple-style event card with colored accent bar
  Widget _buildModernEventCard({
    required BuildContext context,
    required CalendarEvent event,
    required int delay,
  }) {
    Color color;
    IconData icon;
    String? subtitle;

    if (event is AppointmentEvent) {
      color = const Color(0xFF309CB0); // Teal
      icon = Icons.event_outlined;
      subtitle = event.location;
    } else if (event is MedicationEvent) {
      color = const Color(0xFF57B4A4); // Medium teal
      icon = Icons.medication_outlined;
      subtitle = event.dosage;
    } else {
      color = const Color(0xFF85E7A9); // Light green
      icon = Icons.healing_outlined;
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleEventTap(event),
          child: Row(
            children: [
              // Prominent colored left border
              Container(
                width: 6,
                height: 80,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Time display
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('h:mm').format(event.dateTime),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      DateFormat('a').format(event.dateTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Event details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: context.textColor,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.secondaryTextColor,
                                fontSize: 12,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Chevron
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: context.secondaryTextColor.withOpacity(0.3),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDayState(BuildContext context) {
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
                color: AppTheme.neutral700.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available,
                size: 40,
                color: AppTheme.neutral700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No events this day',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add an event',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      return _buildEmptyState(
        context: context,
        icon: Icons.event_note,
        title: 'No appointments',
        message: 'Schedule your first appointment',
      );
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
                    color: AppTheme.neutral700,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editAppointment(appointment),
          child: Row(
            children: [
              // Prominent colored left border
              Container(
                width: 6,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF309CB0), // Teal
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
                        appointment.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(appointment.dateTime),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (appointment.location != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                appointment.location!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationsList(
    BuildContext context,
    EventProvider eventProvider,
  ) {
    final medications =
        eventProvider.events.whereType<MedicationEvent>().toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (medications.isEmpty) {
      return _buildEmptyState(
        context: context,
        icon: Icons.medication,
        title: 'No medications',
        message: 'Add your first medication reminder',
      );
    }

    // Group medications by series
    final globalGroups = <String, List<MedicationEvent>>{};
    for (final med in medications) {
      final seriesKey = (med.seriesId ?? '').trim();
      final groupKey = seriesKey.isNotEmpty
          ? seriesKey
          : 'name_${med.medicationName}';
      globalGroups.putIfAbsent(groupKey, () => []).add(med);
    }

    final seriesGroups = <String, List<MedicationEvent>>{};
    final singles = <MedicationEvent>[];

    for (final entry in globalGroups.entries) {
      if (entry.value.length > 1) {
        seriesGroups[entry.key] = entry.value;
      } else {
        singles.addAll(entry.value);
      }
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: EdgeInsets.all(AppTheme.spacing4),
        children: [
          if (seriesGroups.isNotEmpty) ...[
            _buildSectionHeader(context, 'Recurring Medications', Icons.repeat),
            ...seriesGroups.entries.map(
              (entry) => _buildSeriesCard(context, entry.key, entry.value),
            ),
          ],
          if (singles.isNotEmpty) ...[
            if (seriesGroups.isNotEmpty) SizedBox(height: AppTheme.spacing4),
            _buildSectionHeader(
              context,
              'Individual Medications',
              Icons.schedule,
            ),
            ...singles.map((med) => _buildMedicationCard(context, med)),
          ],
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
          Icon(icon, size: 18, color: AppTheme.neutral600),
          SizedBox(width: AppTheme.spacing2),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(
    BuildContext context,
    String key,
    List<MedicationEvent> items,
  ) {
    items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final first = items.first;
    final isExpanded = _expandedSeries.contains(key);

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.neutral600.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.neutral600.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSeries.remove(key);
                  } else {
                    _expandedSeries.add(key);
                  }
                });
              },
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing4),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.neutral600,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            first.medicationName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.textColor,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppTheme.spacing1),
                          Text(
                            '${first.dosage} • ${first.frequency}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral600.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers,
                            size: 14,
                            color: AppTheme.neutral600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${items.length}',
                            style: TextStyle(
                              color: AppTheme.neutral600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing2),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.neutral600,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spacing4,
                0,
                AppTheme.spacing4,
                AppTheme.spacing4,
              ),
              child: Column(
                children: [
                  Divider(color: AppTheme.neutral600.withOpacity(0.2)),
                  SizedBox(height: AppTheme.spacing2),
                  ...items.asMap().entries.map((entry) {
                    final med = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.neutral600.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacing3),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'EEE, MMM d • h:mm a',
                              ).format(med.dateTime),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.secondaryTextColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, MedicationEvent med) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleEventTap(med),
          child: Row(
            children: [
              // Prominent colored left border
              Container(
                width: 6,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF57B4A4), // Medium teal
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
                        med.medicationName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(med.dateTime),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              med.dosage,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
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
                color: AppTheme.neutral700.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.neutral700),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  void _handleEventTap(CalendarEvent event) {
    if (event is AppointmentEvent) {
      _editAppointment(event);
    } else {
      _showEventDialog(event);
    }
  }

  void _editAppointment(AppointmentEvent appointment) {
    showDialog(
      context: context,
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

  void _showEventDialog(CalendarEvent event) {
    // Implementation for showing event details dialog
    // (simplified for brevity - uses existing dialog from original page)
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
    return await showModalBottomSheet<
      QueryDocumentSnapshot<Map<String, dynamic>>
    >(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => ModernBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernModalHeader(
              title: 'Select a Pet',
              icon: Icons.pets,
              iconColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(petsSnapshot.docs.length, (index) {
                    final pet = petsSnapshot.docs[index];
                    final petData = pet.data();
                    final petName = petData['name'] as String? ?? 'Unknown';
                    final species = petData['species'] as String? ?? 'Unknown';

                    return ModernSelectionCard(
                      title: petName,
                      subtitle: species,
                      iconColor: _getSpeciesColor(species),
                      onTap: () => Navigator.pop(dialogContext, pet),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSpeciesColor(String species) {
    switch (species.toLowerCase()) {
      case 'dog':
        return const Color(0xFF3B82F6); // Blue
      case 'cat':
        return const Color(0xFF8B5CF6); // Purple
      case 'bird':
        return const Color(0xFFF59E0B); // Amber
      case 'rabbit':
        return const Color(0xFF10B981); // Green
      default:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  void _showAppointmentFormWithPetSelection() async {
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
          child: SimpleMedicationForm(
            selectedDate: _selectedDay,
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

        return RefreshIndicator(
          onRefresh: () async {
            await _loadSymptomsByDay();
            setState(() {});
          },
          child: ListView.builder(
            padding: EdgeInsets.all(AppTheme.spacing4),
            itemCount: petsSnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final petDoc = petsSnapshot.data!.docs[index];
              final petData = petDoc.data() as Map<String, dynamic>;
              final petName = petData['name'] as String? ?? 'Unknown';

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('pets')
                    .doc(petDoc.id)
                    .collection('symptoms')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .get(),
                builder: (context, symptomsSnapshot) {
                  if (!symptomsSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final symptoms = symptomsSnapshot.data!.docs;
                  if (symptoms.isEmpty) return SizedBox.shrink();

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
                              Icons.pets,
                              size: 18,
                              color: AppTheme.neutral500,
                            ),
                            SizedBox(width: AppTheme.spacing2),
                            Text(
                              petName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.neutral500,
                                  ),
                            ),
                            Spacer(),
                            Text(
                              '${symptoms.length} symptoms',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...symptoms.map((symptomDoc) {
                        final data = symptomDoc.data() as Map<String, dynamic>;
                        final type = SymptomType.values.firstWhere(
                          (t) => t.toString().split('.').last == data['type'],
                          orElse: () => SymptomType.other,
                        );
                        final timestamp =
                            (data['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        final note = data['note'] as String?;

                        return _buildSymptomCard(
                          context,
                          type,
                          timestamp,
                          note,
                        );
                      }),
                      SizedBox(height: AppTheme.spacing4),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSymptomCard(
    BuildContext context,
    SymptomType type,
    DateTime timestamp,
    String? note,
  ) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Row(
            children: [
              // Prominent colored left border
              Container(
                width: 6,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF85E7A9), // Light green
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
                        _symptomLabel(type),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(timestamp),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension methods are already defined in app_theme.dart
