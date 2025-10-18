import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/symptom_models.dart';
import '../services/pet_service.dart';
import '../theme/app_theme.dart';

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
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptoms'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _pickFilters,
            tooltip: 'Filters',
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const <PetSymptom>[];
          if (items.isEmpty) {
            return const Center(child: Text('No symptoms recorded'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: Text(_labelFor(s.type)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('yyyy-MM-dd HH:mm').format(s.timestamp)),
                      if (s.note?.isNotEmpty == true) Text(s.note!),
                    ],
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
      isScrollControlled: true,
      builder: (context) {
        SymptomType? localType = _filterType;
        DateTime? localStart = _start;
        DateTime? localEnd = _end;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SymptomType?>(
                  value: localType,
                  decoration: const InputDecoration(
                    labelText: 'Symptom',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<SymptomType?>(
                      value: null,
                      child: Text('Any'),
                    ),
                    ...SymptomType.values.map(
                      (t) => DropdownMenuItem<SymptomType?>(
                        value: t,
                        child: Text(_labelFor(t)),
                      ),
                    ),
                  ],
                  onChanged: (v) => localType = v,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate:
                                localStart ??
                                DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) localStart = d;
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            localStart == null
                                ? 'Any'
                                : DateFormat('yyyy-MM-dd').format(localStart),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: localEnd ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) localEnd = d;
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            localEnd == null
                                ? 'Any'
                                : DateFormat('yyyy-MM-dd').format(localEnd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterType = localType;
                        _start = localStart;
                        _end = localEnd;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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
      return 'Ocular discharge';
    case SymptomType.vaginalDischarge:
      return 'Vaginal discharge';
    case SymptomType.estrus:
      return 'Estrus';
    case SymptomType.other:
      return 'Other';
  }
}
