import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';

class CalendarView extends StatefulWidget {
  final Map<DateTime, List<CalendarEvent>> events;
  final Function(DateTime, List<CalendarEvent>) onDaySelected;
  final DateTime? selectedDay;
  final CalendarFormat calendarFormat;
  final Function(CalendarFormat) onFormatChanged;

  const CalendarView({
    super.key,
    required this.events,
    required this.onDaySelected,
    this.selectedDay,
    this.calendarFormat = CalendarFormat.month,
    required this.onFormatChanged,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  @override
  Widget build(BuildContext context) {
    return TableCalendar<CalendarEvent>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: widget.selectedDay ?? DateTime.now(),
      calendarFormat: widget.calendarFormat,
      eventLoader: (day) {
        final dayKey = DateTime(day.year, day.month, day.day);
        return widget.events[dayKey] ?? [];
      },
      selectedDayPredicate: (day) {
        return isSameDay(widget.selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        final events =
            widget.events[DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day,
            )] ??
            [];
        widget.onDaySelected(selectedDay, events);
      },
      onFormatChanged: widget.onFormatChanged,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        selectedDecoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        defaultTextStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkTextPrimary
              : AppTheme.textPrimary,
        ),
        weekendTextStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkTextSecondary
              : AppTheme.textSecondary,
        ),
        holidayTextStyle: TextStyle(color: AppTheme.primaryBlue),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(12.0),
        ),
        formatButtonTextStyle: const TextStyle(color: Colors.white),
      ),
      calendarBuilders: CalendarBuilders<CalendarEvent>(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;

          final displayEvents = events.take(3).toList();
          return Positioned(
            bottom: 1,
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              children: displayEvents.map((event) {
                Color dotColor;
                if (event is AppointmentEvent) {
                  dotColor = AppTheme.primaryBlue;
                } else if (event is MedicationEvent) {
                  dotColor = AppTheme.primaryGreen;
                } else if (event is NoteEvent) {
                  dotColor = Colors.orange;
                } else {
                  dotColor = Colors.grey;
                }

                return Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class DayEventsView extends StatelessWidget {
  final List<CalendarEvent> events;
  final Function(CalendarEvent)? onEventTap;
  final Function(CalendarEvent)? onEventLongPress;

  const DayEventsView({
    super.key,
    required this.events,
    this.onEventTap,
    this.onEventLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyEventsView();
    }

    // Group medications by seriesId to avoid bloat
    final List<Widget> children = [];
    final eventsBySeries = <String, List<CalendarEvent>>{};
    final standaloneEvents = <CalendarEvent>[];

    for (final e in events) {
      if (e is MedicationEvent) {
        final seriesKey = (e.seriesId ?? '').trim();
        final groupKey = seriesKey.isNotEmpty
            ? seriesKey
            : 'name_${e.medicationName}';

        // Check if there are multiple medications with this key
        final allMedsWithSameName = events.where((event) {
          if (event is MedicationEvent) {
            final eventSeriesKey = (event.seriesId ?? '').trim();
            final eventGroupKey = eventSeriesKey.isNotEmpty
                ? eventSeriesKey
                : 'name_${event.medicationName}';
            return eventGroupKey == groupKey;
          }
          return false;
        }).toList();

        if (allMedsWithSameName.length > 1) {
          (eventsBySeries[groupKey] ??= []).add(e);
        } else {
          standaloneEvents.add(e);
        }
      } else {
        standaloneEvents.add(e);
      }
    }

    // Build cards for grouped series (collapsed to one entry with count)
    for (final entry in eventsBySeries.entries) {
      final seriesEvents = entry.value
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final CalendarEvent first = seriesEvents.first;
      children.add(
        _SeriesEventCard(
          baseEvent: first,
          seriesEvents: seriesEvents,
          count: seriesEvents.length,
          onTap: () => onEventTap?.call(first),
          onLongPress: () => onEventLongPress?.call(first),
        ),
      );
    }

    // Add standalone events using dashboard style
    standaloneEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    for (final event in standaloneEvents) {
      children.add(
        _DashboardStyleEventCard(
          event: event,
          onTap: () => onEventTap?.call(event),
          onLongPress: () => onEventLongPress?.call(event),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

// Dashboard-style event card for consistent appearance
class _DashboardStyleEventCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _DashboardStyleEventCard({
    required this.event,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAppointment = event is AppointmentEvent;
    final bool isMedication = event is MedicationEvent;
    final IconData icon = isAppointment
        ? Icons.event
        : (isMedication ? Icons.medication : Icons.note);
    final Color color = isAppointment
        ? AppTheme.primaryBlue
        : (isMedication ? AppTheme.primaryGreen : AppTheme.accentCoral);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: (isAppointment || isMedication)
            ? color.withValues(alpha: 0.03)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isAppointment || isMedication)
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
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Enhanced subtitle for appointments (same as dashboard)
                      if (isAppointment && event is AppointmentEvent)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('h:mm a').format(event.dateTime),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            if ((event as AppointmentEvent).appointmentType !=
                                    null ||
                                (event as AppointmentEvent).location !=
                                    null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if ((event as AppointmentEvent)
                                          .appointmentType !=
                                      null) ...[
                                    Icon(
                                      _getAppointmentTypeIcon(
                                        (event as AppointmentEvent)
                                            .appointmentType!,
                                      ),
                                      size: 11,
                                      color: color,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      (event as AppointmentEvent)
                                          .appointmentType!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  if ((event as AppointmentEvent).location !=
                                          null &&
                                      (event as AppointmentEvent)
                                              .appointmentType !=
                                          null)
                                    const Text(
                                      ' • ',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  if ((event as AppointmentEvent).location !=
                                      null)
                                    Flexible(
                                      child: Text(
                                        (event as AppointmentEvent).location!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textTertiary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        )
                      else
                        Text(
                          DateFormat('h:mm a').format(event.dateTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (isMedication && (event as MedicationEvent).isCompleted)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 16,
                    ),
                  )
                else if (isAppointment &&
                    (event as AppointmentEvent).petId != null)
                  _PetBadge(
                    petId: (event as AppointmentEvent).petId!,
                    badgeColor: AppTheme.primaryBlue,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
}

class _SeriesEventCard extends StatefulWidget {
  final CalendarEvent baseEvent;
  final List<CalendarEvent> seriesEvents;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SeriesEventCard({
    required this.baseEvent,
    required this.seriesEvents,
    required this.count,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_SeriesEventCard> createState() => _SeriesEventCardState();
}

class _SeriesEventCardState extends State<_SeriesEventCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMedicationSeries = widget.baseEvent is MedicationEvent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: isDark
              ? AppTheme.accentCoral.withValues(alpha: 0.3)
              : AppTheme.borderLight,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            onTap: isMedicationSeries
                ? () => setState(() => isExpanded = !isExpanded)
                : widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _EventIcon(eventType: widget.baseEvent.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.baseEvent.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isExpanded && isMedicationSeries
                              ? _buildFrequencyText()
                              : DateFormat(
                                  'h:mm a',
                                ).format(widget.baseEvent.dateTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                          ),
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
                              '${widget.count}',
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isMedicationSeries) ...[
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: AppTheme.primaryGreen,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && isMedicationSeries)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  ...(() {
                    final now = DateTime.now();
                    final bufferTime = now.subtract(const Duration(hours: 1));
                    int? nextEventIndex;

                    for (int i = 0; i < widget.seriesEvents.length; i++) {
                      if (widget.seriesEvents[i].dateTime.isAfter(bufferTime)) {
                        nextEventIndex = i;
                        break;
                      }
                    }

                    return widget.seriesEvents.asMap().entries.map((entry) {
                      final index = entry.key;
                      final event = entry.value;
                      final isNext = index == nextEventIndex;
                      final isPast = event.dateTime.isBefore(bufferTime);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: isNext ? 8 : 6,
                              height: isNext ? 8 : 6,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: isNext ? 1.0 : (isPast ? 0.4 : 0.7),
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
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Next',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.primaryGreen,
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
                                      ).format(event.dateTime),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isPast
                                                ? AppTheme.textSecondary
                                                      .withValues(alpha: 0.6)
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
    );
  }

  String _buildFrequencyText() {
    if (widget.seriesEvents.length < 2) return 'Series';

    final timeBetween = widget.seriesEvents[1].dateTime.difference(
      widget.seriesEvents[0].dateTime,
    );
    if (timeBetween.inDays >= 1) {
      if (timeBetween.inDays == 1) {
        return 'Daily • ${widget.count} doses';
      } else if (timeBetween.inDays == 7) {
        return 'Weekly • ${widget.count} doses';
      } else {
        return 'Every ${timeBetween.inDays} days • ${widget.count} doses';
      }
    } else if (timeBetween.inHours >= 1) {
      return 'Every ${timeBetween.inHours}h • ${widget.count} doses';
    }
    return '${widget.count} doses';
  }
}

class _EventIcon extends StatelessWidget {
  final EventType eventType;

  const _EventIcon({required this.eventType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (eventType) {
      case EventType.appointment:
        icon = Icons.event;
        color = AppTheme.primaryBlue;
        break;
      case EventType.medication:
        icon = Icons.medication;
        color = AppTheme.primaryGreen;
        break;
      case EventType.note:
        icon = Icons.note;
        color = AppTheme.accentCoral;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _PetBadge extends StatelessWidget {
  final String petId;
  final Color? badgeColor;

  const _PetBadge({required this.petId, this.badgeColor});

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

        final color = badgeColor ?? AppTheme.primaryGreen;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getPetIcon(species), size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                petName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
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

class _EmptyEventsView extends StatelessWidget {
  const _EmptyEventsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: AppTheme.accentCoral,
          ),
          SizedBox(height: 16),
          Text(
            'No events for this day',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to add an event',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
