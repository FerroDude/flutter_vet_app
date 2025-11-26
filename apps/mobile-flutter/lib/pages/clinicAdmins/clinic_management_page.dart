import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

class ClinicManagementPage extends StatefulWidget {
  final bool isCreating;

  const ClinicManagementPage({super.key, this.isCreating = false});

  @override
  State<ClinicManagementPage> createState() => _ClinicManagementPageState();
}

class _ClinicManagementPageState extends State<ClinicManagementPage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;

  // Business hours
  final Map<String, TimeOfDay?> _openingHours = {
    'monday': const TimeOfDay(hour: 9, minute: 0),
    'tuesday': const TimeOfDay(hour: 9, minute: 0),
    'wednesday': const TimeOfDay(hour: 9, minute: 0),
    'thursday': const TimeOfDay(hour: 9, minute: 0),
    'friday': const TimeOfDay(hour: 9, minute: 0),
    'saturday': const TimeOfDay(hour: 9, minute: 0),
    'sunday': null,
  };

  final Map<String, TimeOfDay?> _closingHours = {
    'monday': const TimeOfDay(hour: 17, minute: 0),
    'tuesday': const TimeOfDay(hour: 17, minute: 0),
    'wednesday': const TimeOfDay(hour: 17, minute: 0),
    'thursday': const TimeOfDay(hour: 17, minute: 0),
    'friday': const TimeOfDay(hour: 17, minute: 0),
    'saturday': const TimeOfDay(hour: 12, minute: 0),
    'sunday': null,
  };

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isCreating;

    if (!widget.isCreating) {
      _loadClinicData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadClinicData() {
    final userProvider = context.read<UserProvider>();
    final clinic = userProvider.connectedClinic;

    if (clinic != null) {
      _nameController.text = clinic.name;
      _addressController.text = clinic.address;
      _phoneController.text = clinic.phone;
      _emailController.text = clinic.email;
      _websiteController.text = clinic.website ?? '';
      _descriptionController.text = clinic.description ?? '';

      // Load business hours if available
      if (clinic.businessHours != null) {
        _loadBusinessHours(clinic.businessHours!);
      }
    }
  }

  void _loadBusinessHours(Map<String, dynamic> businessHours) {
    for (final day in _openingHours.keys) {
      final dayData = businessHours[day] as Map<String, dynamic>?;
      if (dayData != null) {
        final openTime = dayData['open'] as String?;
        final closeTime = dayData['close'] as String?;

        if (openTime != null) {
          _openingHours[day] = _parseTimeString(openTime);
        }
        if (closeTime != null) {
          _closingHours[day] = _parseTimeString(closeTime);
        }
      }
    }
  }

  TimeOfDay? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(
                  widget.isCreating ? 'Create Clinic' : 'Clinic Settings',
                ),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                actions: [
                  if (!widget.isCreating && !_isEditing)
                    IconButton(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit),
                    )
                  else if (_isEditing) ...[
                    TextButton(
                      onPressed: () {
                        if (widget.isCreating) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _isEditing = false);
                          _loadClinicData();
                        }
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _saveClinic,
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
              body: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Basic Information Card
                            _buildBasicInfoCard(),

                            const SizedBox(height: 16),

                            // Contact Information Card
                            _buildContactInfoCard(),

                            const SizedBox(height: 16),

                            // Business Hours Card
                            _buildBusinessHoursCard(),

                            const SizedBox(height: 16),

                            // Additional Information Card
                            _buildAdditionalInfoCard(),

                            if (widget.isCreating) ...[
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _saveClinic,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppTheme.primary,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primary,
                                          ),
                                        )
                                      : const Text(
                                          'Create Clinic',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBasicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            style: TextStyle(color: AppTheme.primary),
            decoration: InputDecoration(
              labelText: 'Clinic Name *',
              hintText: 'Enter clinic name',
              prefixIcon: Icon(Icons.local_hospital, color: AppTheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Clinic name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            enabled: _isEditing,
            maxLines: 2,
            style: TextStyle(color: AppTheme.primary),
            decoration: InputDecoration(
              labelText: 'Address *',
              hintText: 'Enter clinic address',
              prefixIcon: Icon(Icons.location_on, color: AppTheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: AppTheme.primary),
            decoration: InputDecoration(
              labelText: 'Phone Number *',
              hintText: 'Enter phone number',
              prefixIcon: Icon(Icons.phone, color: AppTheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            enabled: _isEditing,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppTheme.primary),
            decoration: InputDecoration(
              labelText: 'Email Address *',
              hintText: 'Enter email address',
              prefixIcon: Icon(Icons.email, color: AppTheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email address is required';
              }
              if (!value.contains('@')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _websiteController,
            enabled: _isEditing,
            keyboardType: TextInputType.url,
            style: TextStyle(color: AppTheme.primary),
            decoration: InputDecoration(
              labelText: 'Website',
              hintText: 'Enter website URL (optional)',
              prefixIcon: Icon(Icons.web, color: AppTheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Hours',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          ..._openingHours.keys.map((day) => _buildDayHours(day)),
        ],
      ),
    );
  }

  Widget _buildDayHours(String day) {
    final isOpen = _openingHours[day] != null && _closingHours[day] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              _capitalizeDayName(day),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ),

          const SizedBox(width: 16),

          if (_isEditing)
            Switch(
              value: isOpen,
              activeColor: AppTheme.primary,
              onChanged: (value) {
                setState(() {
                  if (value) {
                    _openingHours[day] = const TimeOfDay(hour: 9, minute: 0);
                    _closingHours[day] = const TimeOfDay(hour: 17, minute: 0);
                  } else {
                    _openingHours[day] = null;
                    _closingHours[day] = null;
                  }
                });
              },
            )
          else
            const SizedBox(width: 48),

          const SizedBox(width: 16),

          if (isOpen) ...[
            Expanded(
              child: InkWell(
                onTap: _isEditing ? () => _selectTime(day, true) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.neutral300),
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                  child: Text(
                    _openingHours[day]!.format(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),
            Text('to', style: TextStyle(color: AppTheme.neutral600)),
            const SizedBox(width: 8),

            Expanded(
              child: InkWell(
                onTap: _isEditing ? () => _selectTime(day, false) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.neutral300),
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                  child: Text(
                    _closingHours[day]!.format(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Text(
                'Closed',
                style: TextStyle(
                  color: AppTheme.neutral500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            enabled: _isEditing,
            maxLines: 4,
            style: TextStyle(color: AppTheme.primary),
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Enter clinic description (optional)',
              prefixIcon: Icon(Icons.description, color: AppTheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeDayName(String day) {
    return day[0].toUpperCase() + day.substring(1);
  }

  Future<void> _selectTime(String day, bool isOpening) async {
    final initialTime = isOpening ? _openingHours[day] : _closingHours[day];

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingHours[day] = picked;
        } else {
          _closingHours[day] = picked;
        }
      });
    }
  }

  Map<String, dynamic> _buildBusinessHoursMap() {
    final businessHours = <String, dynamic>{};

    for (final day in _openingHours.keys) {
      final openTime = _openingHours[day];
      final closeTime = _closingHours[day];

      if (openTime != null && closeTime != null) {
        businessHours[day] = {
          'open':
              '${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}',
          'close':
              '${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}',
        };
      }
    }

    return businessHours;
  }

  Future<void> _saveClinic() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();

      if (widget.isCreating) {
        // Create new clinic
        final clinicId = await userProvider.createClinic(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          website: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          businessHours: _buildBusinessHoursMap(),
        );

        if (clinicId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clinic created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        //Implement clinic update
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clinic updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save clinic: $e'),
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
