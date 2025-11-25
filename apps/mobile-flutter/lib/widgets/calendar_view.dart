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
    this.calendarFormat = CalendarFormat.twoWeeks,
    required this.onFormatChanged,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Custom format selector above calendar
        _buildFormatSelector(),
        TableCalendar<CalendarEvent>(
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
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            defaultTextStyle: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
            weekendTextStyle: TextStyle(
              color: AppTheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            todayTextStyle: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false, // Using custom selector instead
            titleCentered: true,
            formatButtonShowsNext: false,
            titleTextStyle: const TextStyle(
              color: AppTheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            leftChevronIcon: const Icon(
              Icons.chevron_left,
              color: AppTheme.primary,
            ),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: AppTheme.primary,
            ),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: AppTheme.neutral700,
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: TextStyle(
              color: AppTheme.neutral700,
              fontWeight: FontWeight.w600,
            ),
          ),
          calendarBuilders: CalendarBuilders<CalendarEvent>(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;

              final displayEvents = events.take(3).toList();
              return Container(
                margin: const EdgeInsets.only(top: 28),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  alignment: WrapAlignment.center,
                  children: displayEvents.map((event) {
                    Color dotColor;
                    if (event is AppointmentEvent) {
                      dotColor = AppTheme.primary;
                    } else if (event is MedicationEvent) {
                      dotColor = AppTheme.brandTeal;
                    } else if (event is NoteEvent) {
                      dotColor = Colors.orange;
                    } else {
                      dotColor = AppTheme.neutral600;
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
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    final formats = [
      (CalendarFormat.month, 'Month', Icons.calendar_view_month),
      (CalendarFormat.twoWeeks, '2 Weeks', Icons.calendar_view_week),
      (CalendarFormat.week, 'Week', Icons.view_week),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: formats.map((item) {
          final (format, label, icon) = item;
          final isSelected = widget.calendarFormat == format;

          return Expanded(
            child: GestureDetector(
              onTap: () => widget.onFormatChanged(format),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppTheme.neutral700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
    final bool isNote = event is NoteEvent;

    final AppointmentEvent? appointment = isAppointment
        ? event as AppointmentEvent
        : null;
    final MedicationEvent? medication = isMedication
        ? event as MedicationEvent
        : null;
    final NoteEvent? note = isNote ? event as NoteEvent : null;

    final IconData icon = isAppointment
        ? Icons.event
        : (isMedication ? Icons.medication : Icons.note);
    final Color baseColor = isAppointment
        ? AppTheme.neutral700
        : (isMedication ? AppTheme.neutral600 : AppTheme.neutral500);

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color subtleTextColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    final List<Widget> infoChips = [];
    final List<Widget> detailLines = [];

    final String description = event.description.trim();
    final String descriptionLower = description.toLowerCase();
    if (description.isNotEmpty) {
      detailLines.add(_DetailLine(text: description, color: subtleTextColor));
    }

    void addChip(IconData chipIcon, String? rawLabel, {Color? color}) {
      if (rawLabel == null) return;
      final label = rawLabel.trim();
      if (label.isEmpty) return;
      infoChips.add(
        _InfoChip(
          icon: chipIcon,
          label: label,
          color: color ?? subtleTextColor,
        ),
      );
    }

    void addDetail(String? rawText, {IconData? icon, Color? color}) {
      if (rawText == null) return;
      final text = rawText.trim();
      if (text.isEmpty) return;
      detailLines.add(
        _DetailLine(icon: icon, text: text, color: color ?? subtleTextColor),
      );
    }

    if (appointment != null) {
      if ((appointment.appointmentType ?? '').trim().isNotEmpty) {
        addChip(
          _getAppointmentTypeIcon(appointment.appointmentType),
          appointment.appointmentType,
          color: AppTheme.neutral700,
        );
      }
      if ((appointment.location ?? '').trim().isNotEmpty) {
        addChip(
          Icons.place_outlined,
          appointment.location,
          color: AppTheme.neutral700,
        );
      }
      if ((appointment.vetName ?? '').trim().isNotEmpty) {
        addChip(
          Icons.person_outline,
          appointment.vetName,
          color: AppTheme.neutral700,
        );
      }
      addDetail(
        appointment.contactInfo,
        icon: Icons.call,
        color: AppTheme.neutral700,
      );
    }

    if (medication != null) {
      addChip(
        Icons.vaccines_outlined,
        medication.dosage,
        color: AppTheme.neutral600,
      );
      addChip(
        Icons.calendar_today_outlined,
        _formatMedicationFrequency(medication),
        color: AppTheme.neutral600,
      );
      if (medication.nextDose != null) {
        addChip(
          Icons.arrow_forward,
          'Next: ${DateFormat('MMM d, h:mm a').format(medication.nextDose!)}',
          color: AppTheme.neutral600,
        );
      }
      if (medication.remainingDoses != null) {
        addChip(
          Icons.inventory_2_outlined,
          '${medication.remainingDoses} left',
          color: AppTheme.neutral600,
        );
      }
      if (medication.lastTaken != null) {
        addChip(
          Icons.check_circle_outline,
          'Last: ${DateFormat('MMM d, h:mm a').format(medication.lastTaken!)}',
          color: AppTheme.neutral600,
        );
      }
      if (medication.requiresNotification) {
        addChip(
          Icons.notifications_active,
          'Reminders on',
          color: AppTheme.neutral600,
        );
      }
      final instructions = medication.instructions?.trim();
      if (instructions != null &&
          instructions.isNotEmpty &&
          instructions.toLowerCase() != descriptionLower) {
        addDetail(
          instructions,
          icon: Icons.info_outline,
          color: AppTheme.neutral600,
        );
      }
    }

    if (note != null) {
      if ((note.category ?? '').trim().isNotEmpty) {
        addChip(
          Icons.folder_outlined,
          note.category,
          color: AppTheme.neutral500,
        );
      }
      if (note.reminderDateTime != null) {
        addChip(
          Icons.alarm,
          'Reminder: ${DateFormat('MMM d, h:mm a').format(note.reminderDateTime!)}',
          color: AppTheme.neutral500,
        );
      }
      if (note.isCompleted) {
        addChip(Icons.check_circle, 'Completed', color: AppTheme.neutral600);
      }
      if (note.tags != null && note.tags!.isNotEmpty) {
        final tags = note.tags!;
        final int limit = tags.length > 3 ? 3 : tags.length;
        for (final tag in tags.take(limit)) {
          addChip(Icons.sell_outlined, tag, color: AppTheme.neutral500);
        }
        final int extraCount = tags.length - limit;
        if (extraCount > 0) {
          addChip(
            Icons.sell_outlined,
            '+$extraCount more',
            color: AppTheme.neutral500,
          );
        }
      }
    }

    Widget? trailing;
    if (medication?.isCompleted ?? false) {
      trailing = Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.neutral600.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.check_circle,
          color: AppTheme.neutral600,
          size: 16,
        ),
      );
    } else if (event.petId != null) {
      trailing = _PetBadge(petId: event.petId!, badgeColor: baseColor);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: (isAppointment || isMedication)
            ? baseColor.withValues(alpha: 0.03)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isAppointment || isMedication)
              ? baseColor.withValues(alpha: 0.1)
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: baseColor,
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
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: subtleTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(event.dateTime),
                            style: textTheme.bodySmall?.copyWith(
                              color: subtleTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (infoChips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 6, children: infoChips),
                      ],
                      if (detailLines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < detailLines.length; i++) ...[
                              if (i > 0) const SizedBox(height: 6),
                              detailLines[i],
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMedicationFrequency(MedicationEvent medication) {
    final String freq = medication.frequency.toLowerCase();
    switch (freq) {
      case 'once':
        return 'Single dose';
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        final interval = medication.customIntervalMinutes;
        if (interval != null && interval > 0) {
          final duration = Duration(minutes: interval);
          if (duration.inDays >= 1) {
            if (duration.inDays == 1) return 'Every day';
            return 'Every ${duration.inDays} days';
          } else if (duration.inHours >= 1) {
            return 'Every ${duration.inHours} hours';
          } else {
            return 'Every ${duration.inMinutes} minutes';
          }
        }
        return medication.frequency;
    }
  }

  IconData _getAppointmentTypeIcon(String? type) {
    final value = type?.toLowerCase().trim() ?? '';
    switch (value) {
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
      case 'surgery':
        return Icons.health_and_safety;
      default:
        return Icons.event;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.labelSmall ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;

  const _DetailLine({this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.bodySmall ??
        TextStyle(color: color, fontSize: 13, height: 1.3);
    final textStyle = baseStyle.copyWith(color: color, height: 1.3);

    if (icon == null) {
      return Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
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
      shadowColor: AppTheme.neutral700.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: isDark
              ? AppTheme.neutral500.withValues(alpha: 0.3)
              : context.borderLight,
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
                          color: AppTheme.neutral600.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neutral600.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.layers,
                              size: 14,
                              color: AppTheme.neutral600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.count}',
                              style: const TextStyle(
                                color: AppTheme.neutral600,
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
                          color: AppTheme.neutral600,
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
                    color: AppTheme.neutral600.withValues(alpha: 0.2),
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
                                color: AppTheme.neutral600.withValues(
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
                                          color: AppTheme.neutral600.withValues(
                                            alpha: 0.15,
                                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    IconData icon;
    Color color;

    switch (eventType) {
      case EventType.appointment:
        icon = Icons.event;
        color = isDark ? AppTheme.brandBlueLight : AppTheme.neutral700;
        break;
      case EventType.medication:
        icon = Icons.medication;
        color = isDark ? AppTheme.brandTeal : AppTheme.neutral600;
        break;
      case EventType.note:
        icon = Icons.note;
        color = isDark ? AppTheme.neutral300 : AppTheme.neutral500;
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

        final color = badgeColor ?? AppTheme.neutral600;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
          Icon(Icons.event_note_outlined, size: 64, color: AppTheme.neutral500),
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
