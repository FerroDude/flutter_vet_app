import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
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
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleAppointmentForm(selectedDate: selectedDate, petId: petId),
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
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.fromDateTime(widget.selectedDate);
    if (widget.existingEvent != null) {
      _titleController.text = widget.existingEvent!.title;
      _locationController.text = widget.existingEvent!.location ?? '';
      _notesController.text = widget.existingEvent!.description;
      _selectedTime = TimeOfDay.fromDateTime(widget.existingEvent!.dateTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius4)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existingEvent == null ? 'New Appointment' : 'Edit Appointment',
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
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Vet Clinic Name',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            Gap(AppTheme.spacing3),
            GFListTile(
              avatar: Icon(Icons.access_time, color: context.textPrimary),
              title: Text('Time', style: TextStyle(color: context.textSecondary, fontSize: 12.sp)),
              subTitle: Text(
                _selectedTime.format(context),
                style: TextStyle(color: context.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      
      final event = AppointmentEvent(
        id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _notesController.text.trim().isEmpty ? 'Appointment' : _notesController.text.trim(),
        dateTime: dateTime,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        petId: widget.petId ?? widget.existingEvent?.petId,
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment ${widget.existingEvent == null ? 'added' : 'updated'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius4)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existingEvent == null ? 'New Medication' : 'Edit Medication',
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
            GFListTile(
              avatar: Icon(Icons.access_time, color: context.textPrimary),
              title: Text('Time', style: TextStyle(color: context.textSecondary, fontSize: 12.sp)),
              subTitle: Text(
                _selectedTime.format(context),
                style: TextStyle(color: context.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      
      final event = MedicationEvent(
        id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _nameController.text.trim(),
        description: _notesController.text.trim().isEmpty ? 'Medication reminder' : _notesController.text.trim(),
        dateTime: dateTime,
        medicationName: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: 'once',
        petId: widget.petId ?? widget.existingEvent?.petId,
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Medication ${widget.existingEvent == null ? 'added' : 'updated'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
