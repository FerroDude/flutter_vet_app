import 'package:cloud_firestore/cloud_firestore.dart';

enum SymptomType {
  vomiting,
  diarrhea,
  cough,
  sneezing,
  choking,
  seizure,
  disorientation,
  circling,
  restlessness,
  limping,
  jointDiscomfort,
  itching,
  ocularDischarge,
  vaginalDischarge,
  estrus,
  other,
}

String symptomTypeToKey(SymptomType type) {
  switch (type) {
    case SymptomType.vomiting:
      return 'vomiting';
    case SymptomType.diarrhea:
      return 'diarrhea';
    case SymptomType.cough:
      return 'cough';
    case SymptomType.sneezing:
      return 'sneezing';
    case SymptomType.choking:
      return 'choking';
    case SymptomType.seizure:
      return 'seizure';
    case SymptomType.disorientation:
      return 'disorientation';
    case SymptomType.circling:
      return 'circling';
    case SymptomType.restlessness:
      return 'restlessness';
    case SymptomType.limping:
      return 'limping';
    case SymptomType.jointDiscomfort:
      return 'jointDiscomfort';
    case SymptomType.itching:
      return 'itching';
    case SymptomType.ocularDischarge:
      return 'ocularDischarge';
    case SymptomType.vaginalDischarge:
      return 'vaginalDischarge';
    case SymptomType.estrus:
      return 'estrus';
    case SymptomType.other:
      return 'other';
  }
}

SymptomType symptomTypeFromKey(String key) {
  switch (key) {
    case 'vomiting':
      return SymptomType.vomiting;
    case 'diarrhea':
      return SymptomType.diarrhea;
    case 'cough':
      return SymptomType.cough;
    case 'sneezing':
      return SymptomType.sneezing;
    case 'choking':
      return SymptomType.choking;
    case 'seizure':
      return SymptomType.seizure;
    case 'disorientation':
      return SymptomType.disorientation;
    case 'circling':
      return SymptomType.circling;
    case 'restlessness':
      return SymptomType.restlessness;
    case 'limping':
      return SymptomType.limping;
    case 'jointDiscomfort':
      return SymptomType.jointDiscomfort;
    case 'itching':
      return SymptomType.itching;
    case 'ocularDischarge':
      return SymptomType.ocularDischarge;
    case 'vaginalDischarge':
      return SymptomType.vaginalDischarge;
    case 'estrus':
      return SymptomType.estrus;
    default:
      return SymptomType.other;
  }
}

class PetSymptom {
  final String id;
  final String ownerId;
  final String petId;
  final SymptomType type;
  final DateTime timestamp;
  final String? note;
  final DateTime createdAt;

  const PetSymptom({
    required this.id,
    required this.ownerId,
    required this.petId,
    required this.type,
    required this.timestamp,
    this.note,
    required this.createdAt,
  });

  factory PetSymptom.fromJson(
    Map<String, dynamic> json,
    String id,
    String ownerId,
    String petId,
  ) {
    return PetSymptom(
      id: id,
      ownerId: ownerId,
      petId: petId,
      type: symptomTypeFromKey(json['type'] as String? ?? 'other'),
      timestamp: _parseDateTime(json['timestamp']),
      note: json['note'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerId': ownerId,
      'petId': petId,
      'type': symptomTypeToKey(type),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.parse(value);
    throw ArgumentError('Invalid datetime value: $value');
  }
}
