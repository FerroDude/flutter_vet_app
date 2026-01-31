import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_request_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../theme/app_theme.dart';
import 'appointment_request_form.dart';

class MyAppointmentRequestsPage extends StatefulWidget {
  const MyAppointmentRequestsPage({super.key});

  @override
  State<MyAppointmentRequestsPage> createState() =>
      _MyAppointmentRequestsPageState();
}

class _MyAppointmentRequestsPageState extends State<MyAppointmentRequestsPage> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final userProvider = context.read<UserProvider>();
      final petOwnerId = userProvider.currentUser?.id;
      if (petOwnerId != null) {
        context.read<AppointmentRequestProvider>().initializeForPetOwner(
          petOwnerId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'My Appointment Requests',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _openRequestForm,
            ),
          ],
        ),
        body: Consumer<AppointmentRequestProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.myRequests.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (provider.error != null && provider.myRequests.isEmpty) {
              return _buildErrorState(provider.error!);
            }

            if (provider.myRequests.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: () async {
                final petOwnerId = context.read<UserProvider>().currentUser?.id;
                if (petOwnerId != null) {
                  provider.initializeForPetOwner(petOwnerId);
                }
              },
              child: ListView.builder(
                padding: EdgeInsets.all(AppTheme.spacing4),
                itemCount: provider.myRequests.length,
                itemBuilder: (context, index) {
                  final request = provider.myRequests[index];
                  return _buildRequestCard(request, provider);
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openRequestForm,
          backgroundColor: AppTheme.brandTeal,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'New Request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _openRequestForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AppointmentRequestForm()),
    );

    if (result == true && mounted) {
      // Request was created, the stream will update automatically
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Gap(AppTheme.spacing4),
            Text(
              'No Appointment Requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(AppTheme.spacing2),
            Text(
              'Request an appointment with your clinic and track its status here.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppTheme.spacing6),
            ElevatedButton.icon(
              onPressed: _openRequestForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandTeal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing5,
                  vertical: AppTheme.spacing3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Request Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60.sp,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            Gap(AppTheme.spacing4),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(AppTheme.spacing2),
            Text(
              error,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    AppointmentRequest request,
    AppointmentRequestProvider provider,
  ) {
    final dateFormat = DateFormat('MMM d');
    final dateRangeText =
        '${dateFormat.format(request.preferredDateStart)} - ${dateFormat.format(request.preferredDateEnd)}';

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: EdgeInsets.all(AppTheme.spacing3),
            decoration: BoxDecoration(
              color: _getStatusColor(request.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radius4),
                topRight: Radius.circular(AppTheme.radius4),
              ),
            ),
            child: Row(children: [_buildStatusBadge(request.status)]),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pet name and dates
                Row(
                  children: [
                    Icon(Icons.pets, color: AppTheme.brandTeal, size: 20.sp),
                    Gap(AppTheme.spacing2),
                    Text(
                      request.petName,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Gap(AppTheme.spacing2),

                // Date range
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppTheme.neutral700,
                      size: 16.sp,
                    ),
                    Gap(AppTheme.spacing2),
                    Text(
                      dateRangeText,
                      style: TextStyle(
                        color: AppTheme.neutral700,
                        fontSize: 14.sp,
                      ),
                    ),
                    Gap(AppTheme.spacing3),
                    Icon(
                      Icons.access_time,
                      color: AppTheme.neutral700,
                      size: 16.sp,
                    ),
                    Gap(AppTheme.spacing1),
                    Text(
                      request.timePreference.shortText,
                      style: TextStyle(
                        color: AppTheme.neutral700,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                Gap(AppTheme.spacing2),

                // Reason
                Text(
                  request.reason,
                  style: TextStyle(color: AppTheme.primary, fontSize: 14.sp),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Response message if any
                if (request.responseMessage != null &&
                    request.responseMessage!.isNotEmpty) ...[
                  Gap(AppTheme.spacing3),
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing2),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.message,
                          color: AppTheme.neutral700,
                          size: 16.sp,
                        ),
                        Gap(AppTheme.spacing2),
                        Expanded(
                          child: Text(
                            request.responseMessage!,
                            style: TextStyle(
                              color: AppTheme.neutral700,
                              fontSize: 13.sp,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Cancel button for pending requests
                if (request.isPending) ...[
                  Gap(AppTheme.spacing3),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _confirmCancel(request, provider),
                      child: Text(
                        'Cancel Request',
                        style: TextStyle(color: Colors.red, fontSize: 14.sp),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppointmentRequestStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing1,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(AppTheme.radius2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: Colors.white, size: 14.sp),
          Gap(4.w),
          Text(
            status.displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AppointmentRequestStatus status) {
    switch (status) {
      case AppointmentRequestStatus.pending:
        return Colors.orange;
      case AppointmentRequestStatus.confirmed:
        return AppTheme.brandTeal;
      case AppointmentRequestStatus.denied:
        return Colors.red;
      case AppointmentRequestStatus.cancelled:
        return AppTheme.neutral500;
    }
  }

  IconData _getStatusIcon(AppointmentRequestStatus status) {
    switch (status) {
      case AppointmentRequestStatus.pending:
        return Icons.schedule;
      case AppointmentRequestStatus.confirmed:
        return Icons.check_circle;
      case AppointmentRequestStatus.denied:
        return Icons.cancel;
      case AppointmentRequestStatus.cancelled:
        return Icons.block;
    }
  }

  Future<void> _confirmCancel(
    AppointmentRequest request,
    AppointmentRequestProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: Text(
          'Are you sure you want to cancel your appointment request for ${request.petName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await provider.cancelRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Request cancelled'
                  : provider.error ?? 'Failed to cancel request',
            ),
            backgroundColor: success ? AppTheme.brandTeal : Colors.red,
          ),
        );
      }
    }
  }
}
