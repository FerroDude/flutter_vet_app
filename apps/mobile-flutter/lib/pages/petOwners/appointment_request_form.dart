import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_request_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../theme/app_theme.dart';

class AppointmentRequestForm extends StatefulWidget {
  const AppointmentRequestForm({super.key});

  @override
  State<AppointmentRequestForm> createState() => _AppointmentRequestFormState();
}

class _AppointmentRequestFormState extends State<AppointmentRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPetId;
  String? _selectedPetName;
  String? _selectedPetSpecies;
  DateTime _preferredDateStart = DateTime.now().add(const Duration(days: 1));
  DateTime _preferredDateEnd = DateTime.now().add(const Duration(days: 7));
  TimePreference _timePreference = TimePreference.anyTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Request Appointment',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacing4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet Selection
                  _buildSectionTitle('Select Pet'),
                  Gap(AppTheme.spacing2),
                  _buildPetSelector(),
                  Gap(AppTheme.spacing4),

                  // Date Range
                  _buildSectionTitle('Preferred Dates'),
                  Gap(AppTheme.spacing2),
                  _buildDateRangePicker(),
                  Gap(AppTheme.spacing4),

                  // Time Preference
                  _buildSectionTitle('Preferred Time'),
                  Gap(AppTheme.spacing2),
                  _buildTimePreferenceSelector(),
                  Gap(AppTheme.spacing4),

                  // Reason
                  _buildSectionTitle('Reason for Visit *'),
                  Gap(AppTheme.spacing2),
                  _buildTextField(
                    controller: _reasonController,
                    hint: 'e.g., Annual checkup, vaccination, skin issue...',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a reason for the appointment';
                      }
                      return null;
                    },
                    maxLines: 2,
                  ),
                  Gap(AppTheme.spacing4),

                  // Additional Notes
                  _buildSectionTitle('Additional Notes (Optional)'),
                  Gap(AppTheme.spacing2),
                  _buildTextField(
                    controller: _notesController,
                    hint: 'Any additional information for the clinic...',
                    maxLines: 3,
                  ),
                  Gap(AppTheme.spacing6),

                  // Submit Button
                  _buildSubmitButton(userProvider),
                  Gap(AppTheme.spacing4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPetSelector() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Text(
        'Please sign in',
        style: TextStyle(color: Colors.white),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: EdgeInsets.all(AppTheme.spacing4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius3),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(AppTheme.spacing4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.pets, color: Colors.white.withValues(alpha: 0.6)),
                Gap(AppTheme.spacing3),
                Text(
                  'No pets found. Add a pet first.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          );
        }

        final pets = snapshot.data!.docs;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            boxShadow: AppTheme.cardShadow,
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedPetId,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.pets, color: AppTheme.primary),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing3,
                vertical: AppTheme.spacing3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius3),
                borderSide: BorderSide.none,
              ),
            ),
            hint: Text(
              'Select a pet',
              style: TextStyle(
                color: AppTheme.neutral700.withValues(alpha: 0.6),
              ),
            ),
            items: pets.map((doc) {
              final data = doc.data();
              final name = data['name'] ?? 'Unknown';
              final species = data['species'] ?? '';
              return DropdownMenuItem(
                value: doc.id,
                child: Text(
                  species.isNotEmpty ? '$name ($species)' : name,
                  style: TextStyle(color: AppTheme.primary),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                final selectedDoc = pets.firstWhere((doc) => doc.id == value);
                setState(() {
                  _selectedPetId = value;
                  _selectedPetName = selectedDoc.data()['name'] ?? 'Unknown';
                  _selectedPetSpecies = selectedDoc.data()['species'];
                });
              }
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a pet';
              }
              return null;
            },
          ),
        );
      },
    );
  }

  Widget _buildDateRangePicker() {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // From Date
          InkWell(
            onTap: () => _pickDate(isStart: true),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.primary,
                  size: 20.sp,
                ),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: TextStyle(
                          color: AppTheme.neutral700,
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        dateFormat.format(_preferredDateStart),
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.neutral700),
              ],
            ),
          ),
          Divider(height: AppTheme.spacing4),
          // To Date
          InkWell(
            onTap: () => _pickDate(isStart: false),
            child: Row(
              children: [
                Icon(Icons.event, color: AppTheme.primary, size: 20.sp),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: TextStyle(
                          color: AppTheme.neutral700,
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        dateFormat.format(_preferredDateEnd),
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.neutral700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _preferredDateStart : _preferredDateEnd;
    final firstDate = isStart ? DateTime.now() : _preferredDateStart;
    final lastDate = DateTime.now().add(const Duration(days: 90));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.brandTeal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _preferredDateStart = picked;
          // Ensure end date is not before start date
          if (_preferredDateEnd.isBefore(picked)) {
            _preferredDateEnd = picked;
          }
        } else {
          _preferredDateEnd = picked;
        }
      });
    }
  }

  Widget _buildTimePreferenceSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: TimePreference.values.map((pref) {
          final isSelected = _timePreference == pref;
          return InkWell(
            onTap: () => setState(() => _timePreference = pref),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing3,
                vertical: AppTheme.spacing3,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.brandTeal.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border(
                  bottom: pref != TimePreference.evening
                      ? BorderSide(color: AppTheme.neutral200)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTimeIcon(pref),
                    color: isSelected
                        ? AppTheme.brandTeal
                        : AppTheme.neutral700,
                    size: 20.sp,
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: Text(
                      pref.displayText,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.brandTeal
                            : AppTheme.primary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.brandTeal,
                      size: 20.sp,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getTimeIcon(TimePreference pref) {
    switch (pref) {
      case TimePreference.anyTime:
        return Icons.schedule;
      case TimePreference.morning:
        return Icons.wb_sunny_outlined;
      case TimePreference.afternoon:
        return Icons.wb_sunny;
      case TimePreference.evening:
        return Icons.nights_stay_outlined;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppTheme.neutral700.withValues(alpha: 0.5),
            fontSize: 14.sp,
          ),
          contentPadding: EdgeInsets.all(AppTheme.spacing3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            borderSide: BorderSide(color: AppTheme.brandTeal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(UserProvider userProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _submitRequest(userProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brandTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.brandTeal.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacing4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius3),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Submit Request',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _submitRequest(UserProvider userProvider) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final clinicId = userProvider.connectedClinic?.id;
    final petOwnerId = userProvider.currentUser?.id;
    final petOwnerName = userProvider.currentUser?.displayName ?? '';

    if (clinicId == null || petOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to a clinic first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<AppointmentRequestProvider>();
      final requestId = await provider.createRequest(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        petId: _selectedPetId!,
        petName: _selectedPetName ?? 'Unknown',
        petSpecies: _selectedPetSpecies,
        preferredDateStart: _preferredDateStart,
        preferredDateEnd: _preferredDateEnd,
        timePreference: _timePreference,
        reason: _reasonController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (requestId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment request submitted successfully!'),
            backgroundColor: AppTheme.brandTeal,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to submit request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
