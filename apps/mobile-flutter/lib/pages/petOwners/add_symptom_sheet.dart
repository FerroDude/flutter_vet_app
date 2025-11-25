import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../models/symptom_models.dart';
import '../../services/pet_service.dart';
import '../../theme/app_theme.dart';

class AddSymptomSheet extends StatefulWidget {
  const AddSymptomSheet({super.key, required this.petId});
  final String petId;

  @override
  State<AddSymptomSheet> createState() => _AddSymptomSheetState();
}

class _AddSymptomSheetState extends State<AddSymptomSheet> {
  final _petService = PetService();
  SymptomType _type = SymptomType.vomiting;
  DateTime _timestamp = DateTime.now();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius4)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spacing4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              Text(
                'Add Symptom',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              Gap(AppTheme.spacing5),

              // Symptom Type
              _buildSymptomTypeSelector(),
              Gap(AppTheme.spacing3),

              // Date & Time
              _buildDateTimePicker(),
              Gap(AppTheme.spacing3),

              // Notes
              _buildTextField(
                controller: _noteController,
                label: 'Notes',
                hint: 'Describe what happened (optional)',
                icon: Icons.notes,
                maxLines: 3,
              ),
              Gap(AppTheme.spacing5),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      isOutlined: true,
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: _buildButton(
                      text: 'Add',
                      onPressed: _saving ? null : _save,
                      isLoading: _saving,
                    ),
                  ),
                ],
              ),
              Gap(AppTheme.spacing2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomTypeSelector() {
    // Group symptoms by category for better UX
    final commonSymptoms = [
      SymptomType.vomiting,
      SymptomType.diarrhea,
      SymptomType.cough,
      SymptomType.sneezing,
      SymptomType.itching,
      SymptomType.limping,
    ];
    
    final otherSymptoms = SymptomType.values
        .where((t) => !commonSymptoms.contains(t))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Symptom Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(AppTheme.spacing2),
        
        // Common symptoms grid
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              // Common symptoms as chips
              Padding(
                padding: EdgeInsets.all(AppTheme.spacing3),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: commonSymptoms.map((type) {
                    final isSelected = _type == type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = type),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _labelFor(type),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.primary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              // Divider
              Divider(height: 1, color: AppTheme.neutral700.withValues(alpha: 0.1)),
              
              // Other symptoms dropdown
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing3, vertical: AppTheme.spacing2),
                child: Row(
                  children: [
                    Icon(Icons.more_horiz, color: AppTheme.neutral700, size: 20),
                    Gap(AppTheme.spacing2),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<SymptomType>(
                          value: otherSymptoms.contains(_type) ? _type : null,
                          hint: Text(
                            'Other symptoms...',
                            style: TextStyle(
                              color: AppTheme.neutral700,
                              fontSize: 14.sp,
                            ),
                          ),
                          isExpanded: true,
                          icon: Icon(Icons.expand_more, color: AppTheme.neutral700),
                          items: otherSymptoms.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                _labelFor(type),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 14.sp,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _type = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When did this happen?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(AppTheme.spacing2),
        InkWell(
          onTap: _pickDateTime,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius2),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: AppTheme.primary, size: 20),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(_timestamp),
                    style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
                  ),
                ),
                Icon(Icons.edit, color: AppTheme.neutral700, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(AppTheme.spacing2),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.neutral700.withValues(alpha: 0.5)),
              prefixIcon: icon != null ? Icon(icon, color: AppTheme.primary, size: 20) : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    VoidCallback? onPressed,
    bool isOutlined = false,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          foregroundColor: isOutlined ? Colors.white : AppTheme.primary,
          elevation: isOutlined ? 0 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            side: isOutlined
                ? BorderSide(color: Colors.white.withValues(alpha: 0.3))
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  String _labelFor(SymptomType t) {
    switch (t) {
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
        return 'Eye discharge';
      case SymptomType.vaginalDischarge:
        return 'Vaginal discharge';
      case SymptomType.estrus:
        return 'Estrus';
      case SymptomType.other:
        return 'Other';
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted || !context.mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (time == null || !mounted || !context.mounted) return;
    
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    try {
      setState(() => _saving = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      
      await _petService.addSymptom(
        ownerId: user.uid,
        petId: widget.petId,
        type: _type,
        at: _timestamp,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      
      if (!mounted || !context.mounted) return;
      Navigator.pop(context, true);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Symptom added'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
