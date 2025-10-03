import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';

class AddEventDialog extends StatelessWidget {
  final DateTime selectedDate;
  final String? petId;

  const AddEventDialog({super.key, required this.selectedDate, this.petId});

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
              label: 'Note/Reminder',
              color: AppTheme.accentCoral,
              onTap: () => _showNoteForm(context),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentForm(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) =>
          AppointmentForm(selectedDate: selectedDate, petId: petId),
    );
  }

  void _showMedicationForm(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) =>
          MedicationForm(selectedDate: selectedDate, petId: petId),
    );
  }

  void _showNoteForm(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => NoteForm(selectedDate: selectedDate, petId: petId),
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
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }
}

class AppointmentForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final AppointmentEvent? existingEvent;

  const AppointmentForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vetNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _appointmentTypeController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  bool _isConfirmed = false;
  bool _isLoading = false;

  final List<String> _appointmentTypes = [
    'Check-up',
    'Vaccination',
    'Surgery',
    'Dental',
    'Grooming',
    'Emergency',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _vetNameController.text = event.vetName ?? '';
      _locationController.text = event.location ?? '';
      _contactInfoController.text = event.contactInfo ?? '';
      _appointmentTypeController.text = event.appointmentType ?? '';
      _selectedDateTime = event.dateTime;
      _isConfirmed = event.isConfirmed;
    } else {
      _selectedDateTime = widget.selectedDate;
      _appointmentTypeController.text = _appointmentTypes[0];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _vetNameController.dispose();
    _locationController.dispose();
    _contactInfoController.dispose();
    _appointmentTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existingEvent == null
                      ? 'New Appointment'
                      : 'Edit Appointment',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: 'e.g., Annual Check-up',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Additional details...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DateTimePicker(
                          selectedDateTime: _selectedDateTime,
                          onDateTimeChanged: (dateTime) {
                            setState(() => _selectedDateTime = dateTime);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _vetNameController,
                          decoration: const InputDecoration(
                            labelText: 'Vet Name',
                            hintText: 'Dr. Smith',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            hintText: 'Vet Clinic Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value:
                              _appointmentTypes.contains(
                                _appointmentTypeController.text,
                              )
                              ? _appointmentTypeController.text
                              : _appointmentTypes[0],
                          decoration: const InputDecoration(
                            labelText: 'Appointment Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _appointmentTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            _appointmentTypeController.text = value ?? '';
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactInfoController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Info',
                            hintText: 'Phone number or email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Confirmed'),
                          value: _isConfirmed,
                          onChanged: (value) =>
                              setState(() => _isConfirmed = value),
                          tileColor: _isConfirmed
                              ? AppTheme.primaryGreen.withOpacity(0.1)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveAppointment,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();
      print('DEBUG: Saving appointment...');
      print('DEBUG: Current user ID: ${eventProvider.currentUserId}');

      final appointment = AppointmentEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dateTime: _selectedDateTime,
        petId: widget.petId,
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        vetName: _vetNameController.text.trim().isEmpty
            ? null
            : _vetNameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        appointmentType: _appointmentTypeController.text.trim().isEmpty
            ? null
            : _appointmentTypeController.text.trim(),
        isConfirmed: _isConfirmed,
        contactInfo: _contactInfoController.text.trim().isEmpty
            ? null
            : _contactInfoController.text.trim(),
      );

      print('DEBUG: Created appointment object: ${appointment.toJson()}');

      if (widget.existingEvent == null) {
        print('DEBUG: Creating new event...');
        final result = await eventProvider.createEvent(appointment);
        print('DEBUG: Create result: $result');
      } else {
        print('DEBUG: Updating existing event...');
        await eventProvider.updateEvent(appointment.id, appointment);
      }

      if (mounted) {
        print('DEBUG: Event saved successfully, closing dialog');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('DEBUG: Error saving appointment: $e');
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

class MedicationForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final MedicationEvent? existingEvent;

  const MedicationForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<MedicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _medicationNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String _frequency = 'once';
  bool _isRecurring = false;
  int _recurrenceInterval = 1;
  bool _requiresNotification = true;
  bool _isLoading = false;

  final List<String> _frequencies = [
    'once',
    'daily',
    'weekly',
    'monthly',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _medicationNameController.text = event.medicationName;
      _dosageController.text = event.dosage;
      _instructionsController.text = event.instructions ?? '';
      _selectedDateTime = event.dateTime;
      _frequency = event.frequency;
      _isRecurring = event.isRecurring;
      _recurrenceInterval = event.recurrenceInterval ?? 1;
      _requiresNotification = event.requiresNotification;
    } else {
      _selectedDateTime = widget.selectedDate;
    }
  }

  @override
  void dispose() {
    _medicationNameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existingEvent == null
                      ? 'New Medication'
                      : 'Edit Medication',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _medicationNameController,
                          decoration: const InputDecoration(
                            labelText: 'Medication Name *',
                            hintText: 'e.g., Heartworm Prevention',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Medication name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dosageController,
                          decoration: const InputDecoration(
                            labelText: 'Dosage *',
                            hintText: 'e.g., 1 tablet, 5mg',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Dosage is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _DateTimePicker(
                          selectedDateTime: _selectedDateTime,
                          onDateTimeChanged: (dateTime) {
                            setState(() => _selectedDateTime = dateTime);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(),
                          ),
                          items: _frequencies.map((freq) {
                            return DropdownMenuItem(
                              value: freq,
                              child: Text(freq.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _frequency = value ?? 'once';
                              _isRecurring = _frequency != 'once';
                            });
                          },
                        ),
                        if (_frequency != 'once') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _recurrenceInterval.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Repeat every',
                              hintText: '1',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _recurrenceInterval = int.tryParse(value) ?? 1;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _instructionsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Instructions',
                            hintText: 'e.g., Take with food, give at bedtime',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Enable notifications'),
                          value: _requiresNotification,
                          onChanged: (value) =>
                              setState(() => _requiresNotification = value),
                          tileColor: _requiresNotification
                              ? AppTheme.primaryGreen.withOpacity(0.1)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveMedication,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();

      final medication = MedicationEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: 'Medication: ${_medicationNameController.text.trim()}',
        description: _instructionsController.text.trim(),
        dateTime: _selectedDateTime,
        petId: widget.petId,
        userId: eventProvider.currentUserId ?? '',
        isRecurring: _isRecurring,
        recurrencePattern: _frequency,
        recurrenceInterval: _recurrenceInterval,
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        medicationName: _medicationNameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: _frequency,
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        requiresNotification: _requiresNotification,
      );

      if (widget.existingEvent == null) {
        await eventProvider.createEvent(medication);
      } else {
        await eventProvider.updateEvent(medication.id, medication);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
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
}

class NoteForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final NoteEvent? existingEvent;

  const NoteForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  int _priority = 3;
  bool _isLoading = false;
  final List<String> _categories = [
    'General',
    'Health',
    'Behavior',
    'Training',
    'Grooming',
    'Diet',
    'Exercise',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _categoryController.text = event.category ?? '';
      _selectedDateTime = event.dateTime;
      _priority = event.priority;
    } else {
      _selectedDateTime = widget.selectedDate;
      _categoryController.text = _categories[0];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existingEvent == null ? 'New Note' : 'Edit Note',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: 'e.g., Grooming appointment',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Additional details...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DateTimePicker(
                          selectedDateTime: _selectedDateTime,
                          onDateTimeChanged: (dateTime) {
                            setState(() => _selectedDateTime = dateTime);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _categories.contains(_categoryController.text)
                              ? _categoryController.text
                              : _categories[0],
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            _categoryController.text = value ?? '';
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Priority:'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              onPressed: () =>
                                  setState(() => _priority = index + 1),
                              icon: Icon(
                                index < _priority
                                    ? Icons.star
                                    : Icons.star_border,
                                color: index < _priority
                                    ? AppTheme.primaryGreen
                                    : AppTheme.textSecondary,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveNote,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();

      final note = NoteEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dateTime: _selectedDateTime,
        petId: widget.petId,
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        priority: _priority,
      );

      if (widget.existingEvent == null) {
        await eventProvider.createEvent(note);
      } else {
        await eventProvider.updateEvent(note.id, note);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
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

class _DateTimePicker extends StatelessWidget {
  final DateTime selectedDateTime;
  final Function(DateTime) onDateTimeChanged;

  const _DateTimePicker({
    required this.selectedDateTime,
    required this.onDateTimeChanged,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      );

      if (time != null) {
        onDateTimeChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pickDateTime(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date & Time *',
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('MMM dd, yyyy hh:mm a').format(selectedDateTime)),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }
}
