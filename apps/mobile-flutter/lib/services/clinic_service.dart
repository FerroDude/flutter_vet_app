import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/clinic_models.dart';

class ClinicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _clinicsCollection =>
      _firestore.collection('clinics');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get clinic members subcollection
  CollectionReference _getClinicMembersCollection(String clinicId) {
    return _clinicsCollection.doc(clinicId).collection('members');
  }

  // Get user clinic history subcollection
  CollectionReference _getUserClinicHistoryCollection(String userId) {
    return _usersCollection.doc(userId).collection('clinicHistory');
  }

  /// CLINIC MANAGEMENT ///

  // Create a new clinic (admin only)
  Future<String> createClinic(Clinic clinic) async {
    try {
      final docRef = await _clinicsCollection.add(clinic.toJson());

      // Add the admin as the first member
      await _addClinicMember(
        docRef.id,
        ClinicMember(
          userId: clinic.adminId,
          clinicId: docRef.id,
          role: ClinicRole.admin,
          permissions: ['*'], // All permissions
          addedAt: DateTime.now(),
          addedBy: clinic.adminId, // Self-added
        ),
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create clinic: $e');
    }
  }

  // Get clinic by ID
  Future<Clinic?> getClinic(String clinicId) async {
    try {
      final doc = await _clinicsCollection.doc(clinicId).get();
      if (doc.exists) {
        return Clinic.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get clinic: $e');
    }
  }

  // Update clinic
  Future<void> updateClinic(String clinicId, Clinic clinic) async {
    try {
      await _clinicsCollection.doc(clinicId).update(clinic.toJson());
    } catch (e) {
      throw Exception('Failed to update clinic: $e');
    }
  }

  // Search clinics (for users to find and connect)
  Future<List<Clinic>> searchClinics({
    String? nameQuery,
    String? locationQuery,
    int limit = 20,
  }) async {
    try {
      Query query = _clinicsCollection
          .where('isActive', isEqualTo: true)
          .limit(limit);

      // Add name filter if provided
      if (nameQuery != null && nameQuery.isNotEmpty) {
        query = query
            .where('name', isGreaterThanOrEqualTo: nameQuery)
            .where('name', isLessThan: nameQuery + '\uf8ff');
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) =>
                Clinic.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search clinics: $e');
    }
  }

  /// USER-CLINIC CONNECTION ///

  // Connect user to clinic
  Future<void> connectUserToClinic(String userId, String clinicId) async {
    try {
      final batch = _firestore.batch();

      // Update user's connected clinic
      batch.update(_usersCollection.doc(userId), {
        'connectedClinicId': clinicId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to clinic history
      final historyRef = _getUserClinicHistoryCollection(userId).doc();
      batch.set(historyRef, {
        'userId': userId,
        'clinicId': clinicId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to connect user to clinic: $e');
    }
  }

  // Disconnect user from clinic
  Future<void> disconnectUserFromClinic(String userId, {String? reason}) async {
    try {
      final user = await getUserProfile(userId);
      if (user?.connectedClinicId == null) return;

      final batch = _firestore.batch();

      // Remove user's connected clinic
      batch.update(_usersCollection.doc(userId), {
        'connectedClinicId': FieldValue.delete(),
        'clinicRole': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update clinic history
      final historyQuery = await _getUserClinicHistoryCollection(userId)
          .where('clinicId', isEqualTo: user!.connectedClinicId)
          .where('leftAt', isNull: true)
          .limit(1)
          .get();

      if (historyQuery.docs.isNotEmpty) {
        batch.update(historyQuery.docs.first.reference, {
          'leftAt': FieldValue.serverTimestamp(),
          'reason': reason,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to disconnect user from clinic: $e');
    }
  }

  /// CLINIC MEMBER MANAGEMENT ///

  // Add member to clinic (admin only)
  Future<void> addVetToClinic(
    String clinicId,
    String vetUserId,
    List<String> permissions,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify current user is admin of this clinic
      final isAdmin = await _isClinicAdmin(currentUser.uid, clinicId);
      if (!isAdmin) throw Exception('Insufficient permissions');

      final membersCollection = _getClinicMembersCollection(clinicId);
      final memberDoc = await membersCollection.doc(vetUserId).get();

      if (memberDoc.exists) {
        final existingMember = ClinicMember.fromJson(
          memberDoc.data() as Map<String, dynamic>,
        );

        if (existingMember.isActive) {
          throw Exception('This vet is already a member of your clinic.');
        }

        await membersCollection.doc(vetUserId).update({
          'isActive': true,
          'permissions': permissions,
          'role': ClinicRole.vet.index,
          'lastActive': FieldValue.serverTimestamp(),
        });
      } else {
        final member = ClinicMember(
          userId: vetUserId,
          clinicId: clinicId,
          role: ClinicRole.vet,
          permissions: permissions,
          addedAt: DateTime.now(),
          addedBy: currentUser.uid,
        );

        await _addClinicMember(clinicId, member);
      }

      // Update user's clinic connection and role
      await _usersCollection.doc(vetUserId).update({
        'connectedClinicId': clinicId,
        'clinicRole': ClinicRole.vet.index,
        'userType': UserType.vet.index,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add vet to clinic: $e');
    }
  }

  Future<String> ensureVetProfileForEmail(String clinicId, String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    final existing = await _usersCollection
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final existingClinicId = data['connectedClinicId'] as String?;

      if (existingClinicId != null && existingClinicId != clinicId) {
        throw Exception(
          'This email is already linked to another clinic. Ask the vet to disconnect before inviting again.',
        );
      }

      await _usersCollection.doc(doc.id).set({
        'email': normalizedEmail,
        'userType': UserType.vet.index,
        'clinicRole': ClinicRole.vet.index,
        'connectedClinicId': clinicId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return doc.id;
    }

    final sanitizedId =
        'temp_vet_${normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final now = DateTime.now();

    final profile = UserProfile(
      id: sanitizedId,
      email: normalizedEmail,
      displayName: '',
      userType: UserType.vet,
      connectedClinicId: clinicId,
      clinicRole: ClinicRole.vet,
      phone: null,
      address: null,
      hasSkippedClinicSelection: false,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );

    await createUserProfile(profile);

    return sanitizedId;
  }

  // Lookup a user by email in Firestore `users` collection
  Future<String?> findUserIdByEmail(String email) async {
    try {
      final normalized = email.trim().toLowerCase();
      final snapshot = await _usersCollection
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      print('findUserIdByEmail failed: ' + e.toString());
      return null;
    }
  }

  // Create a vet invite under the clinic; Cloud Function should send the email
  Future<void> createVetInvite({
    required String clinicId,
    required String email,
    required List<String> permissions,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final invites = _clinicsCollection.doc(clinicId).collection('invites');
    await invites.add({
      'email': email.trim().toLowerCase(),
      'role': 'vet',
      'permissions': permissions,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUser.uid,
      'lastSentAt': FieldValue.serverTimestamp(),
    });
  }

  // Internal method to add clinic member
  Future<void> _addClinicMember(String clinicId, ClinicMember member) async {
    await _getClinicMembersCollection(
      clinicId,
    ).doc(member.userId).set(member.toJson());
  }

  Future<void> ensureMemberRecord({
    required String clinicId,
    required String userId,
    required ClinicRole role,
    List<String>? permissions,
  }) async {
    final members = _getClinicMembersCollection(clinicId);
    final memberDoc = await members.doc(userId).get();

    if (memberDoc.exists) {
      final data = memberDoc.data() as Map<String, dynamic>;
      final updates = <String, dynamic>{};

      if ((data['role'] as int?) != role.index) {
        updates['role'] = role.index;
      }
      if (data['isActive'] == false) {
        updates['isActive'] = true;
        updates['lastActive'] = FieldValue.serverTimestamp();
      }
      if (permissions != null && permissions.isNotEmpty) {
        updates['permissions'] = permissions;
      }

      if (updates.isNotEmpty) {
        await members.doc(userId).update(updates);
      }
      return;
    }

    final member = ClinicMember(
      userId: userId,
      clinicId: clinicId,
      role: role,
      permissions: permissions ?? (role == ClinicRole.admin ? ['*'] : []),
      addedAt: DateTime.now(),
      addedBy: _auth.currentUser?.uid ?? userId,
    );

    await _addClinicMember(clinicId, member);
  }

  Future<void> transferClinicMember(
    String clinicId,
    String oldMemberId,
    String newMemberId,
  ) async {
    final members = _getClinicMembersCollection(clinicId);
    final oldRef = members.doc(oldMemberId);
    final newRef = members.doc(newMemberId);

    await _firestore.runTransaction((transaction) async {
      final oldSnapshot = await transaction.get(oldRef);
      if (!oldSnapshot.exists) return;

      final data = oldSnapshot.data() as Map<String, dynamic>;
      data['userId'] = newMemberId;

      transaction.set(newRef, data);
      transaction.delete(oldRef);
    });
  }

  // Get clinic members
  Future<List<ClinicMember>> getClinicMembers(String clinicId) async {
    try {
      final snapshot = await _getClinicMembersCollection(
        clinicId,
      ).where('isActive', isEqualTo: true).get();

      return snapshot.docs
          .map(
            (doc) => ClinicMember.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get clinic members: $e');
    }
  }

  // Remove member from clinic
  Future<void> removeMemberFromClinic(String clinicId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify current user is admin of this clinic
      final isAdmin = await _isClinicAdmin(currentUser.uid, clinicId);
      if (!isAdmin) throw Exception('Insufficient permissions');

      final batch = _firestore.batch();

      // Deactivate clinic member
      batch.update(_getClinicMembersCollection(clinicId).doc(userId), {
        'isActive': false,
        'lastActive': FieldValue.serverTimestamp(),
      });

      // Disconnect user from clinic
      batch.update(_usersCollection.doc(userId), {
        'connectedClinicId': FieldValue.delete(),
        'clinicRole': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove member from clinic: $e');
    }
  }

  /// USER PROFILE MANAGEMENT ///

  // Create user profile
  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _usersCollection.doc(profile.id).set(profile.toJson());
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      await _usersCollection.doc(profile.id).update(profile.toJson());
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// PERMISSION HELPERS ///

  // Check if user is admin of clinic
  Future<bool> _isClinicAdmin(String userId, String clinicId) async {
    try {
      final memberDoc = await _getClinicMembersCollection(
        clinicId,
      ).doc(userId).get();

      if (memberDoc.exists) {
        final member = ClinicMember.fromJson(
          memberDoc.data() as Map<String, dynamic>,
        );
        return member.role == ClinicRole.admin && member.isActive;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if user has permission for clinic
  Future<bool> hasClinicPermission(
    String userId,
    String clinicId,
    String permission,
  ) async {
    try {
      final memberDoc = await _getClinicMembersCollection(
        clinicId,
      ).doc(userId).get();

      if (memberDoc.exists) {
        final member = ClinicMember.fromJson(
          memberDoc.data() as Map<String, dynamic>,
        );
        return member.isActive &&
            (member.permissions.contains('*') ||
                member.permissions.contains(permission));
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// STREAMS FOR REAL-TIME UPDATES ///

  // Stream clinic data
  Stream<Clinic?> clinicStream(String clinicId) {
    return _clinicsCollection.doc(clinicId).snapshots().map((doc) {
      if (doc.exists) {
        return Clinic.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // Stream user profile
  Stream<UserProfile?> userProfileStream(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // Stream clinic members
  Stream<List<ClinicMember>> clinicMembersStream(String clinicId) {
    return _getClinicMembersCollection(clinicId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    ClinicMember.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  /// Delete user profile and all associated data
  Future<void> deleteUserProfile(String userId) async {
    final batch = _firestore.batch();

    try {
      // 1. Delete user profile document
      batch.delete(_usersCollection.doc(userId));

      // 2. Delete user's clinic history
      final historyQuery = await _getUserClinicHistoryCollection(userId).get();
      for (final doc in historyQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. Remove user from any clinic memberships
      final clinicsQuery = await _clinicsCollection.get();
      for (final clinicDoc in clinicsQuery.docs) {
        final memberQuery = await _getClinicMembersCollection(
          clinicDoc.id,
        ).where('userId', isEqualTo: userId).get();

        for (final memberDoc in memberQuery.docs) {
          batch.delete(memberDoc.reference);
        }
      }

      // 4. Delete user's events/appointments (if they exist)
      try {
        final eventsQuery = await _firestore
            .collection('events')
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in eventsQuery.docs) {
          batch.delete(doc.reference);
        }
      } catch (e) {
        // Events collection might not exist, continue
      }

      // 5. Delete user's pets (if they exist)
      try {
        final petsQuery = await _firestore
            .collection('pets')
            .where('ownerId', isEqualTo: userId)
            .get();

        for (final doc in petsQuery.docs) {
          batch.delete(doc.reference);
        }
      } catch (e) {
        // Pets collection might not exist, continue
      }

      // 6. Delete user's chat messages and rooms (one-on-one chats)
      try {
        // Get chat rooms where user is pet owner
        final petOwnerRoomsQuery = await _firestore
            .collection('chatRooms')
            .where('petOwnerId', isEqualTo: userId)
            .get();

        // Get chat rooms where user is vet
        final vetRoomsQuery = await _firestore
            .collection('chatRooms')
            .where('vetId', isEqualTo: userId)
            .get();

        final allRooms = [...petOwnerRoomsQuery.docs, ...vetRoomsQuery.docs];

        for (final roomDoc in allRooms) {
          // Delete all messages in this room
          final messagesQuery = await roomDoc.reference
              .collection('messages')
              .get();

          for (final msgDoc in messagesQuery.docs) {
            batch.delete(msgDoc.reference);
          }

          // Delete the entire room (since it's one-on-one, no other participants)
          batch.delete(roomDoc.reference);
        }
      } catch (e) {
        // Chat collections might not exist, continue
      }

      // Execute all deletions in a batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }
}
