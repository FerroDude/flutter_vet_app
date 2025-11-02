import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import 'package:intl/intl.dart';
import '../../models/symptom_models.dart';
import '../../services/pet_service.dart';
import '../../theme/app_theme.dart';

class PetSymptomsPage extends StatefulWidget {
  const PetSymptomsPage({super.key, required this.petId});
  final String petId;

  @override
  State<PetSymptomsPage> createState() => _PetSymptomsPageState();
}

class _PetSymptomsPageState extends State<PetSymptomsPage> {
  final _petService = PetService();
  SymptomType? _filterType;
  DateTime? _start;
  DateTime? _end;

  @override
  Widget build(BuildContext context) {
    final ownerId = FirebaseAuth.instance.currentUser?.uid;
    if (ownerId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Not authenticated',
            style: TextStyle(fontSize: 14.sp, color: context.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        title: const Text('Symptoms'),
        actions: [
          GFIconButton(
            icon: Icon(Icons.filter_alt, color: context.textPrimary),
            type: GFButtonType.transparent,
            onPressed: _pickFilters,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _petService.symptomsStream(
          ownerId,
          widget.petId,
          type: _filterType,
          start: _start,
          end: _end,
          limit: 200,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: GFLoader(type: GFLoaderType.circle));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(fontSize: 14.sp, color: Colors.red),
              ),
            );
          }
          final items = snapshot.data ?? const <PetSymptom>[];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 64.sp,
                    color: context.textSecondary,
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'No symptoms recorded',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(AppTheme.spacing4),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final symptom = items[index];
              return Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                child: GFCard(
                  elevation: 0,
                  color: context.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                    side: BorderSide(color: context.border),
                  ),
                  content: GFListTile(
                    avatar: GFAvatar(
                      backgroundColor: _getSymptomColor(
                        symptom.type,
                      ).withValues(alpha: 0.1),
                      child: Icon(
                        _getSymptomIcon(symptom.type),
                        color: _getSymptomColor(symptom.type),
                        size: 20.sp,
                      ),
                    ),
                    title: Text(
                      _labelFor(symptom.type),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    subTitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Gap(AppTheme.spacing1),
                        Text(
                          DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(symptom.timestamp),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: context.textSecondary,
                          ),
                        ),
                        if (symptom.note?.isNotEmpty == true) ...[
                          Gap(AppTheme.spacing1),
                          Text(
                            symptom.note!,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickFilters() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius4),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.all(AppTheme.spacing4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Symptoms',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  Gap(AppTheme.spacing4),
                  Text(
                    'Type',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  Wrap(
                    spacing: AppTheme.spacing2,
                    children: [
                      GFButton(
                        onPressed: () =>
                            setModalState(() => _filterType = null),
                        text: 'All',
                        color: _filterType == null
                            ? AppTheme.primary
                            : Colors.grey,
                        size: GFSize.SMALL,
                      ),
                      ...SymptomType.values.map((type) {
                        return GFButton(
                          onPressed: () =>
                              setModalState(() => _filterType = type),
                          text: _labelFor(type),
                          color: _filterType == type
                              ? AppTheme.primary
                              : Colors.grey,
                          size: GFSize.SMALL,
                        );
                      }),
                    ],
                  ),
                  Gap(AppTheme.spacing4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterType = null;
                            _start = null;
                            _end = null;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                      Gap(AppTheme.spacing2),
                      GFButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                        text: 'Apply',
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
        return 'Joint Discomfort';
      case SymptomType.itching:
        return 'Itching';
      case SymptomType.ocularDischarge:
        return 'Ocular Discharge';
      case SymptomType.vaginalDischarge:
        return 'Vaginal Discharge';
      case SymptomType.estrus:
        return 'Estrus';
      case SymptomType.other:
        return 'Other';
    }
  }

  IconData _getSymptomIcon(SymptomType t) {
    switch (t) {
      case SymptomType.vomiting:
        return Icons.sick;
      case SymptomType.diarrhea:
        return Icons.report_problem;
      case SymptomType.cough:
        return Icons.air;
      case SymptomType.sneezing:
        return Icons.masks;
      case SymptomType.choking:
        return Icons.warning;
      case SymptomType.seizure:
        return Icons.emergency;
      case SymptomType.disorientation:
        return Icons.psychology;
      case SymptomType.circling:
        return Icons.rotate_right;
      case SymptomType.restlessness:
        return Icons.run_circle;
      case SymptomType.limping:
        return Icons.accessible;
      case SymptomType.jointDiscomfort:
        return Icons.healing;
      case SymptomType.itching:
        return Icons.pets;
      case SymptomType.ocularDischarge:
        return Icons.visibility;
      case SymptomType.vaginalDischarge:
        return Icons.female;
      case SymptomType.estrus:
        return Icons.favorite;
      case SymptomType.other:
        return Icons.monitor_heart;
    }
  }

  Color _getSymptomColor(SymptomType t) {
    switch (t) {
      case SymptomType.vomiting:
      case SymptomType.diarrhea:
        return Colors.red;
      case SymptomType.choking:
      case SymptomType.seizure:
        return Colors.red.shade700;
      case SymptomType.cough:
      case SymptomType.sneezing:
        return Colors.blue;
      case SymptomType.disorientation:
      case SymptomType.circling:
      case SymptomType.restlessness:
        return Colors.orange;
      case SymptomType.limping:
      case SymptomType.jointDiscomfort:
        return Colors.purple;
      case SymptomType.itching:
      case SymptomType.ocularDischarge:
        return Colors.pink;
      case SymptomType.vaginalDischarge:
      case SymptomType.estrus:
        return Colors.teal;
      case SymptomType.other:
        return Colors.grey;
    }
  }
}
