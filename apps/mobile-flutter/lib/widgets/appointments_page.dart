import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../models/symptom_models.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';
import 'simple_event_forms.dart';
import 'simple_note_form.dart';
import 'calendar_view.dart';
import '../services/pet_service.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => AppointmentsPageState();
}

// Global key to access the appointments page state
final appointmentsPageKey = GlobalKey<AppointmentsPageState>();

class AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 3, vsync: this);
  final Set<String> _expandedSeries = {};
  final _petService = PetService();

  // Calendar state
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<PetSymptom>> _symptomsByDay = {};

  @override
  void initState() {
    super.initState();
    // Add listener to update FAB when tab changes
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
      _loadSymptomsByDay();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await context.read<EventProvider>().refresh();
    await _loadSymptomsByDay();
  }

  // Getter to access current tab index
  int get currentTabIndex => _controller.index;

  // Method to handle smart FAB action based on current tab
  void handleFabAction() {
    switch (_controller.index) {
      case 0: // Calendar tab - show event type selection
        showAddEventDialog();
        break;
      case 1: // Calendar: Appointments tab - directly create appointment
        showAppointmentForm();
        break;
      case 2: // Medications tab - directly create medication
        showMedicationForm();
        break;
    }
  }

  void showAppointmentForm() {
    // Ensure we have a valid selected date, fallback to today
    final dateToUse = _selectedDay;

    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: context.read<EventProvider>(),
        child: SimpleAppointmentForm(selectedDate: dateToUse),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void showMedicationForm() {
    // Ensure we have a valid selected date, fallback to today
    final dateToUse = _selectedDay;

    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: context.read<EventProvider>(),
        child: SimpleMedicationForm(selectedDate: dateToUse),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void _onDaySelected(DateTime selectedDay, List<CalendarEvent> events) {
    setState(() {
      _selectedDay = selectedDay;
    });
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
    if (mounted) {
      setState(() => _symptomsByDay = summaries);
    }
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

  void _onFormatChanged(CalendarFormat format) {
    setState(() {
      _calendarFormat = format;
    });
  }

  void showAddEventDialog() {
    // Ensure we have a valid selected date, fallback to today
    final dateToUse = _selectedDay;

    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: context.read<EventProvider>(),
        child: SimpleAddEventDialog(selectedDate: dateToUse),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void _showEventDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme
                    .neutral500, // Unified navy color for all event types
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                event is AppointmentEvent
                    ? Icons.event
                    : (event is MedicationEvent
                          ? Icons.medication
                          : Icons.note),
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and time
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'EEEE, MMM dd, yyyy • h:mm a',
                      ).format(event.dateTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Pet information
              if (event.petId != null) ...[
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('pets')
                      .doc(event.petId!)
                      .snapshots(),
                  builder: (context, petSnapshot) {
                    if (petSnapshot.hasData && petSnapshot.data!.exists) {
                      final pet = petSnapshot.data!.data()!;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.neutral700.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.neutral700.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.neutral700,
                              child: Text(
                                (pet['name'] ?? 'P')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['name'] ?? 'Unknown',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${pet['species'] ?? 'Unknown'} • ${pet['breed'] ?? 'Unknown'}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],

              // Event-specific details
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(event.description),
                    ],
                  ),
                ),
              ],

              if (event is AppointmentEvent) ...[
                if (event.vetName != null || event.location != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral700.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.vetName != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: AppTheme.neutral700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text('Location: ${event.vetName}'),
                            ],
                          ),
                        ],
                        if (event.location != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.notes,
                                color: AppTheme.neutral700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Notes: ${event.location}')),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],

              if (event is MedicationEvent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral600.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.medical_services,
                            color: AppTheme.neutral600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Medication Details',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Medication: ${event.medicationName}'),
                      const SizedBox(height: 4),
                      Text('Dosage: ${event.dosage}'),
                      const SizedBox(height: 4),
                      Text('Frequency: ${event.frequency}'),
                      if (event.isRecurring && event.endDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Course: daily until '
                          '${DateFormat('MMM dd, yyyy').format(event.endDate!)}',
                        ),
                      ],
                      if (event.instructions != null) ...[
                        const SizedBox(height: 4),
                        Text('Instructions: ${event.instructions}'),
                      ],
                      if (event.isCompleted) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.neutral600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Completed',
                              style: TextStyle(
                                color: AppTheme.neutral600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _deleteEvent(dialogContext, event),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          ElevatedButton(
            onPressed: () => _editEvent(dialogContext, event),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neutral700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _editEvent(BuildContext dialogContext, CalendarEvent event) {
    Navigator.of(dialogContext).pop();

    showDialog(
      context: context,
      builder: (editContext) {
        if (event is AppointmentEvent) {
          return ChangeNotifierProvider.value(
            value: context.read<EventProvider>(),
            child: SimpleAppointmentForm(
              selectedDate: event.dateTime,
              existingEvent: event,
            ),
          );
        } else if (event is MedicationEvent) {
          return ChangeNotifierProvider.value(
            value: context.read<EventProvider>(),
            child: SimpleMedicationForm(
              selectedDate: event.dateTime,
              existingEvent: event,
            ),
          );
        } else if (event is NoteEvent) {
          return ChangeNotifierProvider.value(
            value: context.read<EventProvider>(),
            child: SimpleNoteForm(
              selectedDate: event.dateTime,
              existingEvent: event,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  /// Direct edit for appointments - bypasses detail dialog
  void _editAppointmentDirectly(AppointmentEvent appointment) {
    showDialog(
      context: context,
      builder: (editContext) {
        return ChangeNotifierProvider.value(
          value: context.read<EventProvider>(),
          child: SimpleAppointmentForm(
            selectedDate: appointment.dateTime,
            existingEvent: appointment,
          ),
        );
      },
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void _deleteEvent(BuildContext dialogContext, CalendarEvent event) {
    Navigator.of(dialogContext).pop();

    showDialog(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(confirmContext).pop();

              final eventProvider = context.read<EventProvider>();
              final success = await eventProvider.deleteEvent(event.id);

              if (!mounted) return;

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event deleted successfully')),
                );
                _refreshData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete event'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        // Get fresh data from the provider
        final allEvents = eventProvider.events;
        final appointments = allEvents.whereType<AppointmentEvent>().toList();
        final medications = allEvents.whereType<MedicationEvent>().toList();

        // Update calendar events
        final eventsByDate = <DateTime, List<CalendarEvent>>{};
        for (final event in allEvents) {
          final date = DateTime(
            event.dateTime.year,
            event.dateTime.month,
            event.dateTime.day,
          );
          if (eventsByDate[date] == null) {
            eventsByDate[date] = [];
          }
          eventsByDate[date]!.add(event);
        }

        // Update selected events for current day
        final selectedEvents =
            eventsByDate[DateTime(
              _selectedDay.year,
              _selectedDay.month,
              _selectedDay.day,
            )] ??
            [];

        if (eventProvider.isLoading &&
            appointments.isEmpty &&
            medications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            const SizedBox(height: 8),
            TabBar(
              controller: _controller,
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month), text: 'Calendar'),
                Tab(icon: Icon(Icons.event), text: 'Appointments'),
                Tab(icon: Icon(Icons.medication), text: 'Medications'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: [
                  // Calendar Tab
                  _buildCalendarView(eventsByDate, selectedEvents),
                  // Appointments Tab
                  _buildAppointmentsList(appointments),
                  // Medications Tab
                  _buildMedicationsList(medications),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarView(
    Map<DateTime, List<CalendarEvent>> eventsByDate,
    List<CalendarEvent> selectedEvents,
  ) {
    // Merge symptom markers as note-like events for the day list
    final Map<DateTime, List<CalendarEvent>> merged = {...eventsByDate};
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
      // Add a lightweight NoteEvent placeholder so the day list shows it
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

    final selectedWithSymptoms =
        merged[DateTime(
          _selectedDay.year,
          _selectedDay.month,
          _selectedDay.day,
        )] ??
        selectedEvents;

    return Column(
      children: [
        // Calendar widget
        CalendarView(
          events: merged,
          onDaySelected: (selectedDay, events) {
            setState(() {
              _selectedDay = selectedDay;
            });
            _onDaySelected(selectedDay, events);
            _loadSymptomsByDay();
          },
          selectedDay: _selectedDay,
          calendarFormat: _calendarFormat,
          onFormatChanged: _onFormatChanged,
        ),

        const Divider(height: 1),
        // Events for selected day
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: selectedWithSymptoms.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 64,
                          color: AppTheme.neutral500,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No events for this day',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button to add an event',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : DayEventsView(
                    events: selectedWithSymptoms,
                    onEventTap: (event) {
                      if (event is AppointmentEvent) {
                        _editAppointmentDirectly(event);
                      } else {
                        _showEventDialog(event);
                      }
                    },
                    onEventLongPress: _showEventDialog,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList(List<CalendarEvent> appointments) {
    if (appointments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No appointments yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add your first appointment',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group by date (YYYY-MM-DD)
    final Map<String, List<AppointmentEvent>> byDate = {};
    final appts = appointments.whereType<AppointmentEvent>().toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    for (final a in appts) {
      final key = DateFormat('yyyy-MM-dd').format(a.dateTime);
      byDate.putIfAbsent(key, () => []);
      byDate[key]!.add(a);
    }

    final dateKeys = byDate.keys.toList()..sort((a, b) => a.compareTo(b));

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: dateKeys.length,
        itemBuilder: (context, i) {
          final key = dateKeys[i];
          final group = byDate[key]!;
          final headerDate = DateFormat(
            'EEE, MMM d',
          ).format(group.first.dateTime);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  headerDate,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral700,
                  ),
                ),
              ),
              ...group.map(
                (appointment) => Container(
                  margin: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral700.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.neutral700.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _editAppointmentDirectly(appointment),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.neutral700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getAppointmentTypeIcon(
                                  appointment.appointmentType ?? 'checkup',
                                ),
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
                                    appointment.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  // Enhanced subtitle for appointments (same as dashboard)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat(
                                          'h:mm a',
                                        ).format(appointment.dateTime),
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
                                      if (appointment.appointmentType != null ||
                                          appointment.location != null) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (appointment.appointmentType !=
                                                null) ...[
                                              Icon(
                                                _getAppointmentTypeIcon(
                                                  appointment.appointmentType!,
                                                ),
                                                size: 11,
                                                color: AppTheme.neutral700,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                appointment.appointmentType!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.neutral700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                            if (appointment.location != null &&
                                                appointment.appointmentType !=
                                                    null)
                                              const Text(
                                                ' • ',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            if (appointment.location != null)
                                              Flexible(
                                                child: Text(
                                                  appointment.location!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (appointment.petId != null)
                              _AppointmentsPetBadge(petId: appointment.petId!),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedicationsList(List<CalendarEvent> medications) {
    if (medications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No medications yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add your first medication',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final meds = medications.whereType<MedicationEvent>().toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // First, group medications globally by seriesId/name
    final Map<String, List<MedicationEvent>> globalGroups = {};
    for (final m in meds) {
      final seriesKey = (m.seriesId ?? '').trim();
      final groupKey = seriesKey.isNotEmpty
          ? seriesKey
          : 'name_${m.medicationName}';
      (globalGroups[groupKey] ??= []).add(m);
    }

    // Separate grouped vs single medications
    final Map<String, List<MedicationEvent>> seriesGroups = {};
    final List<MedicationEvent> singles = [];
    for (final entry in globalGroups.entries) {
      if (entry.value.length > 1) {
        seriesGroups[entry.key] = entry.value;
      } else {
        singles.addAll(entry.value);
      }
    }

    // Now group by date for display
    final Map<String, List<MedicationEvent>> byDate = {};
    for (final m in singles) {
      final key = DateFormat('yyyy-MM-dd').format(m.dateTime);
      byDate.putIfAbsent(key, () => []);
      byDate[key]!.add(m);
    }

    final List<Widget> allItems = [];

    // Header for grouped medications if any exist
    if (seriesGroups.isNotEmpty) {
      allItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.repeat, size: 18, color: AppTheme.neutral600),
              const SizedBox(width: 8),
              Text(
                'Recurring Medications',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add grouped series first (they show up at top, compact style)
    for (final entry in seriesGroups.entries) {
      final items = entry.value
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final first = items.first;
      final isExpanded = _expandedSeries.contains(entry.key);

      allItems.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.neutral600.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.neutral600.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSeries.remove(entry.key);
                      } else {
                        _expandedSeries.add(entry.key);
                      }
                    });
                  },
                  onLongPress: () => _showSeriesDeleteDialog(first, items),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.neutral600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.medication,
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
                                first.medicationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${first.dosage} • ${first.frequency}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.neutral600.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.layers,
                                size: 14,
                                color: AppTheme.neutral600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${items.length}',
                                style: const TextStyle(
                                  color: AppTheme.neutral600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: AppTheme.neutral600,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isExpanded)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      Divider(
                        color: AppTheme.neutral600.withValues(alpha: 0.2),
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

                        for (int i = 0; i < items.length; i++) {
                          if (items[i].dateTime.isAfter(bufferTime)) {
                            nextEventIndex = i;
                            break;
                          }
                        }

                        return items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final med = entry.value;
                          final isNext = index == nextEventIndex;
                          final isPast = med.dateTime.isBefore(bufferTime);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: isNext ? 8 : 6,
                                  height: isNext ? 8 : 6,
                                  decoration: BoxDecoration(
                                    color: AppTheme.neutral600.withValues(
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
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.neutral600
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Next',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.neutral600,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          DateFormat(
                                            'EEE, MMM d • h:mm a',
                                          ).format(med.dateTime),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isPast
                                                    ? AppTheme.textSecondary
                                                          .withValues(
                                                            alpha: 0.6,
                                                          )
                                                    : AppTheme.textSecondary,
                                                fontSize: 12,
                                                fontWeight: isNext
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                decoration: isPast
                                                    ? TextDecoration.lineThrough
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
      );
    }

    // Add a separator if we have both groups and singles
    if (seriesGroups.isNotEmpty && singles.isNotEmpty) {
      allItems.add(const SizedBox(height: 16));
    }

    // Header for individual medications if any exist
    if (singles.isNotEmpty) {
      allItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 18, color: AppTheme.neutral700),
              const SizedBox(width: 8),
              Text(
                'Individual Medications',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add singles grouped by date with enhanced styling
    final dateKeys = byDate.keys.toList()..sort((a, b) => a.compareTo(b));
    for (final key in dateKeys) {
      final group = byDate[key]!;
      final headerDate = DateFormat('EEE, MMM d').format(group.first.dateTime);

      allItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            headerDate,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );

      for (final m in group) {
        allItems.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showEventDialog(m),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.neutral600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.medication,
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
                              m.medicationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${m.dosage} • ${m.frequency}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.neutral700.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: AppTheme.neutral700,
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
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(children: allItems),
    );
  }

  void _showSeriesDeleteDialog(
    MedicationEvent first,
    List<MedicationEvent> seriesItems,
  ) {
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
              'Are you sure you want to delete all ${seriesItems.length} occurrences of "${first.medicationName}"?',
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
              await _deleteSeriesEvents(seriesItems);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete All (${seriesItems.length})'),
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
        _refreshData();
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

  /// Gets appropriate icon for appointment type
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

  // _getAppointmentTypeColor removed (unused)
}

// Pet Badge component for appointments page
class _AppointmentsPetBadge extends StatelessWidget {
  final String petId;

  const _AppointmentsPetBadge({required this.petId});

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
            color: AppTheme.neutral700.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.neutral700.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getPetIcon(species), size: 12, color: AppTheme.neutral700),
              const SizedBox(width: 4),
              Text(
                petName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral700,
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
