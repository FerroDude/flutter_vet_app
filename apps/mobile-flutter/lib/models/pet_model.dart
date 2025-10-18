import 'package:cloud_firestore/cloud_firestore.dart';

class Pet {
  final String id;
  final String ownerId;
  final String name;
  final String? species;
  final String? breed;
  final String? sex;
  final DateTime? birthDate;
  final double? weightKg;
  final String? microchip;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    this.species,
    this.breed,
    this.sex,
    this.birthDate,
    this.weightKg,
    this.microchip,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json, String id, String ownerId) {
    return Pet(
      id: id,
      ownerId: ownerId,
      name: json['name'] ?? '',
      species: json['species'],
      breed: json['breed'],
      sex: json['sex'],
      birthDate: _parseDateTimeNullable(json['birthDate']),
      weightKg: json['weightKg'] != null
          ? (json['weightKg'] is num
                ? (json['weightKg'] as num).toDouble()
                : double.tryParse(json['weightKg'].toString()))
          : null,
      microchip: json['microchip'],
      photoUrl: json['photoUrl'],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'species': species,
      'breed': breed,
      'sex': sex,
      'birthDate': birthDate?.millisecondsSinceEpoch,
      'weightKg': weightKg,
      'microchip': microchip,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Pet copyWith({
    String? name,
    String? species,
    String? breed,
    String? sex,
    DateTime? birthDate,
    double? weightKg,
    String? microchip,
    String? photoUrl,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      weightKg: weightKg ?? this.weightKg,
      microchip: microchip ?? this.microchip,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    }
    throw ArgumentError('Invalid datetime value: $value');
  }

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    return _parseDateTime(value);
  }
}
