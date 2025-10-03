import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { petOwner, vet, clinicAdmin, appOwner }

enum ClinicRole { admin, vet }

class Clinic {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String adminId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? website;
  final String? description;
  final Map<String, dynamic>? businessHours;

  const Clinic({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.adminId,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.website,
    this.description,
    this.businessHours,
  });

  factory Clinic.fromJson(Map<String, dynamic> json, String id) {
    return Clinic(
      id: id,
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      adminId: json['adminId'],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      website: json['website'],
      description: json['description'],
      businessHours: json['businessHours'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'adminId': adminId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isActive': isActive,
      'website': website,
      'description': description,
      'businessHours': businessHours,
    };
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

  Clinic copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? adminId,
    DateTime? updatedAt,
    bool? isActive,
    String? website,
    String? description,
    Map<String, dynamic>? businessHours,
  }) {
    return Clinic(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      adminId: adminId ?? this.adminId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      website: website ?? this.website,
      description: description ?? this.description,
      businessHours: businessHours ?? this.businessHours,
    );
  }
}

class ClinicMember {
  final String userId;
  final String clinicId;
  final ClinicRole role;
  final List<String> permissions;
  final DateTime addedAt;
  final String addedBy;
  final bool isActive;
  final DateTime? lastActive;

  const ClinicMember({
    required this.userId,
    required this.clinicId,
    required this.role,
    required this.permissions,
    required this.addedAt,
    required this.addedBy,
    this.isActive = true,
    this.lastActive,
  });

  factory ClinicMember.fromJson(Map<String, dynamic> json) {
    return ClinicMember(
      userId: json['userId'],
      clinicId: json['clinicId'],
      role: ClinicRole.values[json['role']],
      permissions: List<String>.from(json['permissions'] ?? []),
      addedAt: Clinic._parseDateTime(json['addedAt']),
      addedBy: json['addedBy'],
      isActive: json['isActive'] ?? true,
      lastActive: json['lastActive'] != null
          ? Clinic._parseDateTime(json['lastActive'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'clinicId': clinicId,
      'role': role.index,
      'permissions': permissions,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'addedBy': addedBy,
      'isActive': isActive,
      'lastActive': lastActive?.millisecondsSinceEpoch,
    };
  }

  ClinicMember copyWith({
    ClinicRole? role,
    List<String>? permissions,
    bool? isActive,
    DateTime? lastActive,
  }) {
    return ClinicMember(
      userId: userId,
      clinicId: clinicId,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      addedAt: addedAt,
      addedBy: addedBy,
      isActive: isActive ?? this.isActive,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}

class UserClinicHistory {
  final String id;
  final String userId;
  final String clinicId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? reason;

  const UserClinicHistory({
    required this.id,
    required this.userId,
    required this.clinicId,
    required this.joinedAt,
    this.leftAt,
    this.reason,
  });

  factory UserClinicHistory.fromJson(Map<String, dynamic> json, String id) {
    return UserClinicHistory(
      id: id,
      userId: json['userId'],
      clinicId: json['clinicId'],
      joinedAt: Clinic._parseDateTime(json['joinedAt']),
      leftAt: json['leftAt'] != null
          ? Clinic._parseDateTime(json['leftAt'])
          : null,
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'clinicId': clinicId,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'leftAt': leftAt?.millisecondsSinceEpoch,
      'reason': reason,
    };
  }
}

// Extension to add clinic-related fields to existing user model
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final UserType userType;
  final String? connectedClinicId;
  final ClinicRole? clinicRole;
  final String? phone;
  final String? address;
  final bool hasSkippedClinicSelection;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.userType,
    this.connectedClinicId,
    this.clinicRole,
    this.phone,
    this.address,
    this.hasSkippedClinicSelection = false,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, String id) {
    return UserProfile(
      id: id,
      email: json['email'],
      displayName: json['displayName'],
      userType: UserType.values[json['userType'] ?? 0],
      connectedClinicId: json['connectedClinicId'],
      clinicRole: json['clinicRole'] != null
          ? ClinicRole.values[json['clinicRole']]
          : null,
      phone: json['phone'],
      address: json['address'],
      hasSkippedClinicSelection: json['hasSkippedClinicSelection'] ?? false,
      createdAt: Clinic._parseDateTime(json['createdAt']),
      updatedAt: Clinic._parseDateTime(json['updatedAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'userType': userType.index,
      'connectedClinicId': connectedClinicId,
      'clinicRole': clinicRole?.index,
      'phone': phone,
      'address': address,
      'hasSkippedClinicSelection': hasSkippedClinicSelection,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    UserType? userType,
    String? connectedClinicId,
    ClinicRole? clinicRole,
    String? phone,
    String? address,
    bool? hasSkippedClinicSelection,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      userType: userType ?? this.userType,
      connectedClinicId: connectedClinicId ?? this.connectedClinicId,
      clinicRole: clinicRole ?? this.clinicRole,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      hasSkippedClinicSelection:
          hasSkippedClinicSelection ?? this.hasSkippedClinicSelection,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper methods
  bool get isPetOwner => userType == UserType.petOwner;
  bool get isVet => userType == UserType.vet;
  bool get isClinicAdmin => userType == UserType.clinicAdmin;
  bool get isAppOwner => userType == UserType.appOwner;
  bool get hasClinicConnection => connectedClinicId != null;
}
