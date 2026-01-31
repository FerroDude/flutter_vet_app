import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

class DisplayNameSetupPage extends StatefulWidget {
  const DisplayNameSetupPage({super.key});

  @override
  State<DisplayNameSetupPage> createState() => _DisplayNameSetupPageState();
}

class _DisplayNameSetupPageState extends State<DisplayNameSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Set Your Display Name',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gap(20.h),
                  // Icon
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 40.sp,
                        color: AppTheme.brandTeal,
                      ),
                    ),
                  ),
                  Gap(24.h),
                  // Title
                  Center(
                    child: Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Gap(8.h),
                  Center(
                    child: Text(
                      'Choose how your name appears to others',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Gap(32.h),
                  // Input label
                  Text(
                    'Display Name',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  // Glassy input field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing3,
                          vertical: AppTheme.spacing3,
                        ),
                        errorStyle: TextStyle(
                          color: AppTheme.error,
                          fontSize: 12.sp,
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Display name is required';
                        if (v.length < 2)
                          return 'Please enter at least 2 characters';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  Gap(24.h),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandTeal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.brandTeal.withValues(
                          alpha: 0.5,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                        ),
                      ),
                      child: _submitting
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final ok = await context.read<UserProvider>().updateProfile(
      displayName: _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } else {
      if (!mounted) return;
      final err =
          context.read<UserProvider>().error ?? 'Error saving display name';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppTheme.error),
      );
    }
  }
}
