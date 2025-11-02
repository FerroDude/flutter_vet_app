import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';

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
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEvent?.title ?? '');
    _descriptionController = TextEditingController(text: widget.existingEvent?.description ?? '');
    _selectedDate = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing6),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existingEvent == null ? 'Add Note' : 'Edit Note',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                Gap(AppTheme.spacing4),
                
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter note title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                  ),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Title required' : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                Gap(AppTheme.spacing3),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter note description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                Gap(AppTheme.spacing3),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, color: AppTheme.neutral600, size: 20.sp),
                  title: Text('Date', style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary)),
                  subtitle: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.access_time, color: AppTheme.neutral600, size: 20.sp),
                  title: Text('Time', style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary)),
                  subtitle: Text(
                    _selectedTime.format(context),
                    style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary),
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
                
                Gap(AppTheme.spacing4),
                
                Row(
                  children: [
                    Expanded(
                      child: GFButton(
                        onPressed: () => Navigator.pop(context),
                        text: 'Cancel',
                        type: GFButtonType.outline2x,
                        color: AppTheme.neutral500,
                        size: GFSize.LARGE,
                      ),
                    ),
                    Gap(AppTheme.spacing3),
                    Expanded(
                      child: GFButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        text: widget.existingEvent == null ? 'Add' : 'Update',
                        color: AppTheme.neutral800,
                        size: GFSize.LARGE,
                      ),
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final now = DateTime.now();
      
      final event = NoteEvent(
        id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? 'Note' : _descriptionController.text.trim(),
        dateTime: dateTime,
        petId: widget.petId ?? widget.existingEvent?.petId,
        userId: userId,
        priority: 3,
        isCompleted: widget.existingEvent?.isCompleted ?? false,
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
          SnackBar(content: Text('Note ${widget.existingEvent == null ? 'added' : 'updated'}')),
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

