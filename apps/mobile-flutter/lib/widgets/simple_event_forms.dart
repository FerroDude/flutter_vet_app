import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

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
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add New Event',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppTheme.spacing6),
            GFButton(
              onPressed: () => _showAppointmentForm(context),
              text: 'Appointment',
              icon: Icon(Icons.event, color: Colors.white),
              color: AppTheme.neutral800,
              fullWidthButton: true,
              size: GFSize.LARGE,
            ),
            Gap(AppTheme.spacing3),
            GFButton(
              onPressed: () => _showMedicationForm(context),
              text: 'Medication',
              icon: Icon(Icons.medication, color: Colors.white),
              color: AppTheme.neutral600,
              fullWidthButton: true,
              size: GFSize.LARGE,
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    final userProvider = context.read<UserProvider>();
    final clinicName = userProvider.connectedClinic?.name;
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleAppointmentForm(
          selectedDate: selectedDate,
          petId: petId,
          clinicName: clinicName,
        ),
      ),
    );
  }

  void _showMedicationForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleMedicationForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }
}

class SimpleAppointmentForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final AppointmentEvent? existingEvent;
  final String? clinicName;

  const SimpleAppointmentForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
    this.clinicName,
  });

  @override
  State<SimpleAppointmentForm> createState() => _SimpleAppointmentFormState();
}

class _SimpleAppointmentFormState extends State<SimpleAppointmentForm> {
  // Use a static counter to ensure unique keys across multiple instances if any
  static int _formKeyCounter = 0;
  final _formKey = GlobalKey<FormState>(
    debugLabel: 'SimpleAppointmentForm_${_formKeyCounter++}',
  );
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _selectedPetId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.selectedDate);
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
    if (widget.existingEvent != null) {
      _titleController.text = widget.existingEvent!.title;
      _locationController.text = widget.existingEvent!.location ?? '';
      _notesController.text = widget.existingEvent!.description;
      _selectedDate = widget.existingEvent!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.existingEvent!.dateTime);
    } else {
      // Pre-fill clinic name if provided
      if (widget.clinicName != null && widget.clinicName!.isNotEmpty) {
        _locationController.text = widget.clinicName!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text(
          'Are you sure you want to delete this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteEvent();
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.existingEvent == null) return;

    setState(() => _isSubmitting = true);
    try {
      final eventProvider = context.read<EventProvider>();
      await eventProvider.deleteEvent(widget.existingEvent!.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius4),
        ),
      ),
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
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            Gap(AppTheme.spacing4),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Annual Checkup',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            Gap(AppTheme.spacing3),
            _buildPetSelector(),
            Gap(AppTheme.spacing3),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Clinic',
                hintText: 'Clinic name',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),
            Gap(AppTheme.spacing3),
            Row(
              children: [
                Expanded(
                  child: GFListTile(
                    avatar: Icon(
                      Icons.calendar_today,
                      color: context.textPrimary,
                    ),
                    title: Text(
                      'Date',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    subTitle: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(Duration(days: 365)),
                        lastDate: DateTime.now().add(Duration(days: 365 * 2)),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                  ),
                ),
                Gap(AppTheme.spacing2),
                Expanded(
                  child: GFListTile(
                    avatar: Icon(Icons.access_time, color: context.textPrimary),
                    title: Text(
                      'Time',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    subTitle: Text(
                      _selectedTime.format(context),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) {
                        setState(() => _selectedTime = time);
                      }
                    },
                  ),
                ),
              ],
            ),
            Gap(AppTheme.spacing3),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional information',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
            ),
            Gap(AppTheme.spacing4),
            Row(
              children: [
                Expanded(
                  child: GFButton(
                    onPressed: () => Navigator.pop(context),
                    text: 'Cancel',
                    type: GFButtonType.outline2x,
                    size: GFSize.LARGE,
                  ),
                ),
                Gap(AppTheme.spacing2),
                Expanded(
                  child: GFButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    text: widget.existingEvent == null ? 'Add' : 'Update',
                    color: AppTheme.neutral800,
                    size: GFSize.LARGE,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 16.w,
                            height: 16.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
            if (widget.existingEvent != null) ...[
              Gap(AppTheme.spacing3),
              GFButton(
                onPressed: _confirmDelete,
                text: 'Delete Appointment',
                type: GFButtonType.outline2x,
                color: GFColors.DANGER,
                size: GFSize.LARGE,
                fullWidthButton: true,
              ),
            ],
            Gap(AppTheme.spacing2),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();

      final event = AppointmentEvent(
        id:
            widget.existingEvent?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _notesController.text.trim().isEmpty
            ? 'Appointment'
            : _notesController.text.trim(),
        dateTime: dateTime,
        location: _locationController.text.trim().isEmpty
            ? 'Clinic'
            : _locationController.text.trim(),
        petId: _selectedPetId ?? widget.petId ?? widget.existingEvent?.petId,
        userId: userId,
        createdAt: widget.existingEvent?.createdAt ?? now,
        updatedAt: now,
      );

      final eventProvider = context.read<EventProvider>();
      if (widget.existingEvent == null) {
        await eventProvider.createEvent(event);
      } else {
        await eventProvider.updateEvent(event.id, event);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment ${widget.existingEvent == null ? 'added' : 'updated'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPetSelector() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Pet',
              hintText: 'Loading pets...',
              prefixIcon: Icon(Icons.pets),
            ),
            items: [],
            onChanged: null,
          );
        }

        final pets = snapshot.data!.docs;
        if (pets.isEmpty) {
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Pet',
              hintText: 'No pets found',
              prefixIcon: Icon(Icons.pets),
            ),
            items: [],
            onChanged: null,
          );
        }

        // Ensure the selected pet ID is valid, fallback to first pet if needed
        String? selectedValue = _selectedPetId;
        if (selectedValue == null ||
            !pets.any((doc) => doc.id == selectedValue)) {
          if (pets.isNotEmpty) {
            selectedValue = pets.first.id;
            // Update state if needed
            if (_selectedPetId != selectedValue) {
              Future.microtask(() {
                if (mounted) {
                  setState(() => _selectedPetId = selectedValue);
                }
              });
            }
          }
        }

        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Pet',
            prefixIcon: Icon(Icons.pets),
          ),
          initialValue: selectedValue,
          items: pets.map((doc) {
            final pet = doc.data();
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(pet['name'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedPetId = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a pet';
            }
            return null;
          },
        );
      },
    );
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
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;
  String _frequency = 'once'; // once or daily
  final TextEditingController _durationController = TextEditingController(
    text: '7',
  ); // default 7 days

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.fromDateTime(widget.selectedDate);
    if (widget.existingEvent != null) {
      _nameController.text = widget.existingEvent!.medicationName;
      _dosageController.text = widget.existingEvent!.dosage;
      _notesController.text = widget.existingEvent!.description;
      _selectedTime = TimeOfDay.fromDateTime(widget.existingEvent!.dateTime);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius4),
        ),
      ),
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
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            Gap(AppTheme.spacing4),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Medication Name',
                hintText: 'e.g., Antibiotics',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter medication name';
                }
                return null;
              },
            ),
            Gap(AppTheme.spacing3),
            TextFormField(
              controller: _dosageController,
              decoration: InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g., 1 tablet',
                prefixIcon: Icon(Icons.local_pharmacy_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter dosage';
                }
                return null;
              },
            ),
            Gap(AppTheme.spacing3),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: const [
                DropdownMenuItem(value: 'once', child: Text('One time')),
                DropdownMenuItem(value: 'daily', child: Text('Every day')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _frequency = value);
              },
            ),
            if (_frequency == 'daily') ...[
              Gap(AppTheme.spacing3),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (days)',
                  hintText: 'e.g., 7',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_frequency != 'daily') return null;
                  if (value == null || value.isEmpty) {
                    return 'Please enter duration in days';
                  }
                  final days = int.tryParse(value);
                  if (days == null || days <= 0) {
                    return 'Enter a valid number of days';
                  }
                  return null;
                },
              ),
            ],
            Gap(AppTheme.spacing3),
            GFListTile(
              avatar: Icon(Icons.access_time, color: context.textPrimary),
              title: Text(
                'Time',
                style: TextStyle(color: context.textSecondary, fontSize: 12.sp),
              ),
              subTitle: Text(
                _selectedTime.format(context),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
            ),
            Gap(AppTheme.spacing3),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional information',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
            ),
            Gap(AppTheme.spacing4),
            Row(
              children: [
                Expanded(
                  child: GFButton(
                    onPressed: () => Navigator.pop(context),
                    text: 'Cancel',
                    type: GFButtonType.outline2x,
                    size: GFSize.LARGE,
                  ),
                ),
                Gap(AppTheme.spacing2),
                Expanded(
                  child: GFButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    text: widget.existingEvent == null ? 'Add' : 'Update',
                    color: AppTheme.neutral800,
                    size: GFSize.LARGE,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 16.w,
                            height: 16.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
            Gap(AppTheme.spacing2),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final eventProvider = context.read<EventProvider>();

      // Editing existing medication - keep single event behavior
      if (widget.existingEvent != null) {
        final existing = widget.existingEvent!;
        final updatedEvent = existing.copyWith(
          title: _nameController.text.trim(),
          description: _notesController.text.trim().isEmpty
              ? 'Medication reminder'
              : _notesController.text.trim(),
          dateTime: dateTime,
          medicationName: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          updatedAt: now,
        );

        await eventProvider.updateEvent(updatedEvent.id, updatedEvent);
      } else {
        // New medication - support one-time or daily course over multiple days
        final isDailyCourse = _frequency == 'daily';
        int totalDays = 1;
        if (isDailyCourse) {
          totalDays = int.tryParse(_durationController.text) ?? 1;
          if (totalDays <= 0) totalDays = 1;
        }

        final title = _nameController.text.trim();
        final description = _notesController.text.trim().isEmpty
            ? 'Medication reminder'
            : _notesController.text.trim();
        final dosage = _dosageController.text.trim();
        final petId = widget.petId ?? widget.existingEvent?.petId;

        final seriesId = isDailyCourse ? CalendarEvent.generateId() : null;
        final firstDateTime = dateTime;
        final endDate = isDailyCourse
            ? firstDateTime.add(Duration(days: totalDays - 1))
            : null;

        for (int i = 0; i < totalDays; i++) {
          final occurrenceDate = firstDateTime.add(Duration(days: i));

          final event = MedicationEvent(
            id: CalendarEvent.generateId(),
            title: title,
            description: description,
            dateTime: occurrenceDate,
            medicationName: title,
            dosage: dosage,
            frequency: isDailyCourse ? 'daily' : 'once',
            petId: petId,
            userId: userId,
            seriesId: seriesId,
            isRecurring: isDailyCourse,
            recurrencePattern: isDailyCourse ? 'daily' : null,
            recurrenceInterval: isDailyCourse ? 1 : null,
            endDate: endDate,
            remainingDoses: isDailyCourse ? totalDays : null,
            createdAt: firstDateTime,
            updatedAt: now,
          );

          await eventProvider.createEvent(event);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingEvent == null
                  ? (_frequency == 'daily'
                        ? 'Medication course added'
                        : 'Medication added')
                  : 'Medication updated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
