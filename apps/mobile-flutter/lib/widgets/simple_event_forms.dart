import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';
import 'modern_modals.dart';

class SimpleAddEventDialog extends StatelessWidget {
  final DateTime selectedDate;
  final String? petId;

  const SimpleAddEventDialog({
    super.key,
    required this.selectedDate,
    this.petId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add New Event',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _EventTypeButton(
              icon: Icons.event,
              label: 'Appointment',
              color: AppTheme.primaryBlue,
              onTap: () => _showAppointmentForm(context),
            ),
            const SizedBox(height: 12),
            _EventTypeButton(
              icon: Icons.medication,
              label: 'Medication',
              color: AppTheme.primaryGreen,
              onTap: () => _showMedicationForm(context),
            ),
            const SizedBox(height: 12),
            _EventTypeButton(
              icon: Icons.note,
              label: 'Quick Note',
              color: AppTheme.accentCoral,
              onTap: () => _showNoteForm(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleAppointmentForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }

  void _showMedicationForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleMedicationForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }

  void _showNoteForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleNoteForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }
}

class _EventTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EventTypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class SimpleAppointmentForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final AppointmentEvent? existingEvent;

  const SimpleAppointmentForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<SimpleAppointmentForm> createState() => _SimpleAppointmentFormState();
}

class _SimpleAppointmentFormState extends State<SimpleAppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _vetNameController;
  late final TextEditingController _locationController;
  late DateTime _selectedDateTime;
  String? _selectedPetId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingEvent?.title ?? '',
    );
    _vetNameController = TextEditingController(
      text: widget.existingEvent?.vetName ?? '',
    );
    _locationController = TextEditingController(
      text: widget.existingEvent?.location ?? '',
    );
    _selectedDateTime = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vetNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernBottomSheet(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModernModalHeader(
              title: widget.existingEvent == null
                  ? 'Add Appointment'
                  : 'Edit Appointment',
              icon: Icons.event_outlined,
              iconColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 24),
            ModernModalTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Vet visit, grooming, checkup',
              icon: Icons.calendar_today,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter appointment title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              controller: _vetNameController,
              label: 'Vet Name (Optional)',
              hint: 'Dr. Smith',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              controller: _locationController,
              label: 'Location (Optional)',
              hint: 'Pet Clinic',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              readOnly: true,
              label: 'Date & Time',
              hint: DateFormat(
                'MMM dd, yyyy • h:mm a',
              ).format(_selectedDateTime),
              icon: Icons.event_outlined,
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 24),
            ModernModalButton(
              text: widget.existingEvent == null
                  ? 'Add Appointment'
                  : 'Update Appointment',
              isLoading: _isLoading,
              onPressed: _saveAppointment,
              color: const Color(0xFF3B82F6),
              icon: widget.existingEvent == null ? Icons.add : Icons.check,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();

      final appointment = AppointmentEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: _titleController.text.trim(),
        description: '',
        dateTime: _selectedDateTime,
        petId: _selectedPetId,
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        vetName: _vetNameController.text.trim().isEmpty
            ? null
            : _vetNameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        appointmentType: null,
        isConfirmed: widget.existingEvent?.isConfirmed ?? false,
        contactInfo: null,
      );

      if (widget.existingEvent == null) {
        await eventProvider.createEvent(appointment);
      } else {
        await eventProvider.updateEvent(appointment.id, appointment);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving appointment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class SimpleMedicationForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final MedicationEvent? existingEvent;

  const SimpleMedicationForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<SimpleMedicationForm> createState() => _SimpleMedicationFormState();
}

class _SimpleMedicationFormState extends State<SimpleMedicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  String? _selectedPetId;
  String _recurrencePattern = 'daily';
  int _recurrenceInterval = 1;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingEvent?.medicationName ?? '',
    );
    _dosageController = TextEditingController(
      text: widget.existingEvent?.dosage ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.existingEvent?.instructions ?? '',
    );
    _startDate = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _startTime = TimeOfDay.fromDateTime(_startDate);
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
    _recurrencePattern = widget.existingEvent?.recurrencePattern ?? 'daily';
    _recurrenceInterval = widget.existingEvent?.recurrenceInterval ?? 1;
    _endDate =
        widget.existingEvent?.endDate ??
        _startDate.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernBottomSheet(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModernModalHeader(
              title: widget.existingEvent == null
                  ? 'Add Medication'
                  : 'Edit Medication',
              icon: Icons.medication,
              iconColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 24),
            ModernModalTextField(
              controller: _nameController,
              label: 'Medication Name',
              hint: 'Heartworm pill, Flea drops',
              icon: Icons.medical_services,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter medication name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              controller: _dosageController,
              label: 'Dosage',
              hint: '1 tablet, 5mg, 2ml',
              icon: Icons.local_pharmacy,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter dosage';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              controller: _instructionsController,
              label: 'Instructions (Optional)',
              hint: 'With food, morning only, etc.',
              icon: Icons.info_outline,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              readOnly: true,
              label: 'Start Date & Time',
              hint:
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} • ${_startTime.format(context)}',
              icon: Icons.calendar_today,
              onTap: _selectStartDateTime,
            ),
            const SizedBox(height: 16),
            ModernModalDropdown<String>(
              label: 'Frequency',
              value: _recurrencePattern,
              icon: Icons.repeat,
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _recurrencePattern = value);
                }
              },
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              readOnly: true,
              label: 'End Date',
              hint: _endDate != null
                  ? DateFormat('MMM dd, yyyy').format(_endDate!)
                  : 'Select end date',
              icon: Icons.event,
              onTap: _selectEndDate,
            ),
            const SizedBox(height: 24),
            ModernModalButton(
              text: widget.existingEvent == null
                  ? 'Create Schedule'
                  : 'Update Schedule',
              isLoading: _isLoading,
              onPressed: _saveMedication,
              color: const Color(0xFF10B981),
              icon: widget.existingEvent == null ? Icons.add : Icons.check,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );

      if (time != null && mounted) {
        setState(() {
          _startDate = date;
          _startTime = time;
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (date != null && mounted) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();

      String frequencyString = 'Every ';
      frequencyString +=
          '$_recurrenceInterval ${_recurrencePattern == 'daily'
              ? (_recurrenceInterval == 1 ? 'day' : 'days')
              : _recurrencePattern == 'weekly'
              ? (_recurrenceInterval == 1 ? 'week' : 'weeks')
              : (_recurrenceInterval == 1 ? 'month' : 'months')}';

      final DateTime effectiveEnd = _endDate ?? _startDate;
      final DateTime startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final occurrences = _generateOccurrences(
        startDateTime,
        effectiveEnd,
        _recurrencePattern,
        _recurrenceInterval,
      );

      final String seriesId = CalendarEvent.generateId();
      for (final dt in occurrences) {
        final medication = MedicationEvent(
          id: CalendarEvent.generateId(),
          title: _nameController.text.trim(),
          description: '${_dosageController.text.trim()} - $frequencyString',
          dateTime: dt,
          petId: _selectedPetId,
          userId: eventProvider.currentUserId ?? '',
          seriesId: seriesId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          medicationName: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          frequency: frequencyString,
          endDate: effectiveEnd,
          isRecurring: true,
          recurrencePattern: _recurrencePattern,
          recurrenceInterval: _recurrenceInterval,
          customIntervalMinutes: null,
          remainingDoses: null,
          requiresNotification: true,
          lastTaken: null,
          nextDose: dt,
          instructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
        );
        await eventProvider.createEvent(medication);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving medication: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<DateTime> _generateOccurrences(
    DateTime start,
    DateTime end,
    String pattern,
    int interval,
  ) {
    final List<DateTime> result = [];
    DateTime current = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    final DateTime endDay = DateTime(
      end.year,
      end.month,
      end.day,
      end.hour,
      end.minute,
    );

    while (!current.isAfter(endDay)) {
      result.add(current);
      if (pattern == 'daily') {
        current = current.add(Duration(days: interval));
      } else if (pattern == 'weekly') {
        current = current.add(Duration(days: 7 * interval));
      } else {
        int y = current.year;
        int m = current.month + interval;
        while (m > 12) {
          y += 1;
          m -= 12;
        }
        final int day = current.day;
        final int lastDayOfTarget = DateTime(y, m + 1, 0).day;
        final int d = day > lastDayOfTarget ? lastDayOfTarget : day;
        current = DateTime(y, m, d, current.hour, current.minute);
      }
    }

    return result;
  }
}

class SimpleNoteForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final NoteEvent? existingEvent;

  const SimpleNoteForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<SimpleNoteForm> createState() => _SimpleNoteFormState();
}

class _SimpleNoteFormState extends State<SimpleNoteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _selectedDateTime;
  String? _selectedPetId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingEvent?.title ?? '',
    );
    _noteController = TextEditingController(
      text: widget.existingEvent?.description ?? '',
    );
    _selectedDateTime = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernBottomSheet(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernModalHeader(
              title: widget.existingEvent == null ? 'Add Note' : 'Edit Note',
              icon: Icons.note_outlined,
              iconColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 24),
            ModernModalTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Reminder, observation, etc.',
              icon: Icons.title,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              controller: _noteController,
              label: 'Note',
              hint: 'Add details...',
              icon: Icons.note_outlined,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a note';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ModernModalTextField(
              readOnly: true,
              label: 'Date & Time',
              hint: DateFormat(
                'MMM dd, yyyy • h:mm a',
              ).format(_selectedDateTime),
              icon: Icons.calendar_today,
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 24),
            ModernModalButton(
              text: widget.existingEvent == null ? 'Add Note' : 'Update Note',
              isLoading: _isLoading,
              onPressed: _saveNote,
              color: const Color(0xFFF59E0B),
              icon: widget.existingEvent == null ? Icons.add : Icons.check,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();

      final note = NoteEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: _titleController.text.trim(),
        description: _noteController.text.trim(),
        dateTime: _selectedDateTime,
        petId: _selectedPetId,
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        tags: widget.existingEvent?.tags ?? [],
      );

      if (widget.existingEvent == null) {
        await eventProvider.createEvent(note);
      } else {
        await eventProvider.updateEvent(note.id, note);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
