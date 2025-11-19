import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/clinic_models.dart';
import '../models/pet_model.dart';

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

  // Get clinic invites subcollection
  CollectionReference _getClinicInvitesCollection(String clinicId) {
    return _clinicsCollection.doc(clinicId).collection('invites');
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

  // Find clinic by admin user ID
  Future<Clinic?> findClinicByAdmin(String adminUserId) async {
    try {
      final query = await _clinicsCollection
          .where('adminId', isEqualTo: adminUserId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Clinic.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find clinic by admin: $e');
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
      // 1. Fetch active clinics (up to limit)
      // Note: For true scalable 'contains' search, we'd need a 3rd party service (Algolia/Elastic).
      // For now, we fetch a batch of active clinics and filter client-side or relying on exact prefix if we used Firestore queries.
      // But the user wants substring match ("test" in "My Test Clinic"). Firestore only does prefix.
      // So we'll fetch active clinics and filter client-side.
      
      Query query = _clinicsCollection
          .where('isActive', isEqualTo: true)
          .limit(50); // increased limit for client-side filtering chance

      final snapshot = await query.get();
      var clinics = snapshot.docs
          .map(
            (doc) =>
                Clinic.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // 2. Filter client-side for "contains" (case-insensitive)
      if (nameQuery != null && nameQuery.isNotEmpty) {
        final lowerQuery = nameQuery.toLowerCase();
        clinics = clinics.where((clinic) {
          final nameMatches = clinic.name.toLowerCase().contains(lowerQuery);
          // Optional: also search address?
          // final addressMatches = clinic.address.toLowerCase().contains(lowerQuery);
          return nameMatches; 
        }).toList();
      }
      
      // If we filtered down to 0, maybe we should have fetched more, but this is a simple implementation.
      // Return up to requested limit
      if (clinics.length > limit) {
        clinics = clinics.sublist(0, limit);
      }

      return clinics;
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
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify current user is admin of this clinic
      final isAdmin = await _isClinicAdmin(currentUser.uid, clinicId);
      if (!isAdmin) throw Exception('Insufficient permissions');

      // Vets always have full access - no permissions tracking
      final member = ClinicMember(
        userId: vetUserId,
        clinicId: clinicId,
        role: ClinicRole.vet,
        permissions: const [], // No permissions tracking - vets have full access
        addedAt: DateTime.now(),
        addedBy: currentUser.uid,
      );

      await _addClinicMember(clinicId, member);

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

  // Internal method to add clinic member
  Future<void> _addClinicMember(String clinicId, ClinicMember member) async {
    await _getClinicMembersCollection(
      clinicId,
    ).doc(member.userId).set(member.toJson());
  }

  /// Ensure there is an admin membership entry for the given user in the clinic,
  /// and optionally remove a temporary placeholder admin membership document.
  Future<void> ensureAdminMembershipFor(
    String clinicId,
    String userId, {
    String? tempAdminId,
  }) async {
    // Create or overwrite the real admin membership for this user
    final adminMember = ClinicMember(
      userId: userId,
      clinicId: clinicId,
      role: ClinicRole.admin,
      permissions: const ['*'],
      addedAt: DateTime.now(),
      addedBy: userId,
    );

    await _addClinicMember(clinicId, adminMember);

    // If there is a temporary admin membership, delete it
    if (tempAdminId != null && tempAdminId.isNotEmpty) {
      try {
        await _getClinicMembersCollection(clinicId).doc(tempAdminId).delete();
      } catch (_) {
        // Ignore if it does not exist or permission denies; rules may allow only
        // clinic admins to delete placeholders. Since we just created the real
        // admin membership, subsequent operations should succeed regardless.
      }
    }
  }

  /// Delete only the user profile document at `users/{userId}`.
  /// This avoids broader cascading deletions that may be blocked by rules.
  Future<void> deleteUserDocOnly(String userId) async {
    try {
      await _usersCollection.doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user doc: $e');
    }
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

  // Get clinic members including inactive (for admin management views)
  Future<List<ClinicMember>> getClinicMembersIncludeInactive(
    String clinicId,
  ) async {
    try {
      final snapshot = await _getClinicMembersCollection(clinicId).get();
      return snapshot.docs
          .map(
            (doc) => ClinicMember.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get all clinic members: $e');
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
  // Vets always have full access - no permissions tracking
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
        // Vets always have full access - just check if they're active
        return member.isActive;
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
    return _getClinicMembersCollection(clinicId).snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => ClinicMember.fromJson(doc.data() as Map<String, dynamic>),
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

  /// Create a vet invite and a temporary vet placeholder user profile
  /// under the clinic's invites subcollection and `users/` respectively.
  Future<void> createVetInvite(
    String clinicId,
    String email,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final normalizedEmail = email.trim().toLowerCase();
      final inviteId = normalizedEmail
          .replaceAll('@', '_')
          .replaceAll('.', '_')
          .replaceAll('+', '_');

      // Create both invite and placeholder user profile in a batch
      final batch = _firestore.batch();

      // 1) Create/merge invite (no permissions - vets always have full access)
      final inviteDocRef = _getClinicInvitesCollection(clinicId).doc(inviteId);
      batch.set(inviteDocRef, {
        'email': normalizedEmail,
        'role': 'vet',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'invitedBy': currentUser.uid,
      }, SetOptions(merge: true));
      // Make sure status reflects pending even if existed
      batch.update(inviteDocRef, {'status': 'pending'});

      // 2) Create placeholder user profile: users/temp_vet_{email_token}
      final tempVetId = 'temp_vet_$inviteId';
      batch.set(_usersCollection.doc(tempVetId), {
        'email': normalizedEmail,
        'displayName': normalizedEmail,
        'userType': UserType.vet.index,
        'connectedClinicId': clinicId,
        'clinicRole': ClinicRole.vet.index,
        'hasSkippedClinicSelection': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': false, // activated when the real account links
      });

      // 3) Create an inactive clinic member entry for visibility in management
      // Vets always have full access - use empty permissions list
      final placeholderMember = ClinicMember(
        userId: tempVetId,
        clinicId: clinicId,
        role: ClinicRole.vet,
        permissions: const [], // No permissions tracking - vets have full access
        addedAt: DateTime.now(),
        addedBy: currentUser.uid,
        isActive: false,
      );
      batch.set(
        _getClinicMembersCollection(clinicId).doc(tempVetId),
        placeholderMember.toJson(),
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create vet invite: $e');
    }
  }

  /// Revoke a vet invite by email (normalized to inviteId)
  Future<void> revokeVetInvite(String clinicId, String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final inviteId = normalizedEmail
          .replaceAll('@', '_')
          .replaceAll('.', '_')
          .replaceAll('+', '_');

      await _getClinicInvitesCollection(clinicId).doc(inviteId).delete();
    } catch (e) {
      throw Exception('Failed to revoke vet invite: $e');
    }
  }

  /// Find a pending vet invite by email across all clinics
  Future<Map<String, dynamic>?> findPendingVetInviteByEmail(
    String email,
  ) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      // Query only by email to avoid composite index requirements; filter in code
      final snap = await _firestore
          .collectionGroup('invites')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      if (snap.docs.isEmpty) return null;
      // Prefer first with status 'pending'
      final doc = snap.docs.firstWhere(
        (d) => (d.data()['status'] ?? 'pending') == 'pending',
        orElse: () => snap.docs.first,
      );
      final data = doc.data();
      final clinicId = doc.reference.parent.parent!.id;
      final permissions = List<String>.from(data['permissions'] ?? []);
      return {
        'clinicId': clinicId,
        'inviteRef': doc.reference,
        'permissions': permissions,
      };
    } catch (e) {
      throw Exception('Failed to find pending invite: $e');
    }
  }

  /// Apply a vet invite for the signed-in vet user
  Future<void> applyVetInvite({
    required String clinicId,
    required String userId,
    required DocumentReference inviteRef,
    String? normalizedEmailForCleanup,
  }) async {
    try {
      // First, atomically create membership and update user profile
      final membershipAndUserBatch = _firestore.batch();

      // Create membership as vet - vets always have full access
      final member = ClinicMember(
        userId: userId,
        clinicId: clinicId,
        role: ClinicRole.vet,
        permissions: const [], // No permissions tracking - vets have full access
        addedAt: DateTime.now(),
        addedBy: userId,
      );
      membershipAndUserBatch.set(
        _getClinicMembersCollection(clinicId).doc(userId),
        member.toJson(),
      );

      // Update user profile to link clinic and mark as vet
      membershipAndUserBatch.update(_usersCollection.doc(userId), {
        'connectedClinicId': clinicId,
        'clinicRole': ClinicRole.vet.index,
        'userType': UserType.vet.index,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await membershipAndUserBatch.commit();

      // Then, best-effort mark the invite as accepted (may be blocked by rules due to email casing)
      try {
        await inviteRef.update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore invite update failures; membership and user profile are already updated
      }

      // Best-effort cleanup of temporary placeholder user profile created at invite time
      try {
        final emailToken = (normalizedEmailForCleanup ?? '')
            .trim()
            .toLowerCase()
            .replaceAll('@', '_')
            .replaceAll('.', '_')
            .replaceAll('+', '_');
        if (emailToken.isNotEmpty) {
          final tempVetId = 'temp_vet_$emailToken';
          await deleteUserDocOnly(tempVetId);
        }
      } catch (_) {
        // Ignore cleanup failures
      }
    } catch (e) {
      throw Exception('Failed to apply vet invite: $e');
    }
  }

  /// App owner-only: delete a clinic and clean up membership and invites
  Future<void> deleteClinicAsOwner(String clinicId) async {
    try {
      // Load members and invites
      final membersSnap = await _getClinicMembersCollection(clinicId).get();
      final invitesSnap = await _getClinicInvitesCollection(clinicId).get();

      final batch = _firestore.batch();

      // Clean up members and unlink users
      for (final doc in membersSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final memberUserId = data['userId'] as String? ?? doc.id;

        // Delete member doc
        batch.delete(doc.reference);

        // Unlink user from clinic
        batch.update(_usersCollection.doc(memberUserId), {
          'connectedClinicId': FieldValue.delete(),
          'clinicRole': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Delete invites
      for (final doc in invitesSnap.docs) {
        batch.delete(doc.reference);
      }

      // Delete clinic doc last
      batch.delete(_clinicsCollection.doc(clinicId));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete clinic: $e');
    }
  }

  /// Get a single clinic member
  Future<ClinicMember?> getClinicMember(String clinicId, String userId) async {
    try {
      final doc = await _getClinicMembersCollection(clinicId).doc(userId).get();
      if (doc.exists) {
        return ClinicMember.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get clinic member: $e');
    }
  }

  /// Ensure there is a vet membership entry for the given user in the clinic,
  /// and optionally remove a temporary placeholder vet membership document.
  Future<void> ensureVetMembershipFor(
    String clinicId,
    String userId, {
    String? tempVetId,
  }) async {
    // Create or overwrite the real vet membership for this user
    // Vets always have full access - no permissions tracking
    final vetMember = ClinicMember(
      userId: userId,
      clinicId: clinicId,
      role: ClinicRole.vet,
      permissions: const [], // No permissions tracking - vets have full access
      addedAt: DateTime.now(),
      addedBy: userId,
    );

    await _addClinicMember(clinicId, vetMember);

    // If there is a temporary vet membership, delete it
    if (tempVetId != null && tempVetId.isNotEmpty) {
      try {
        await _getClinicMembersCollection(clinicId).doc(tempVetId).delete();
      } catch (_) {
        // Ignore if it does not exist or permission denies
      }
    }
  }

  /// Delete a vet invite by email (alias for revokeVetInvite)
  Future<void> deleteVetInvite(String clinicId, String email) async {
    return revokeVetInvite(clinicId, email);
  }

  /// Stream of pet owner users connected to a clinic
  /// Optionally filtered by display name prefix and limited
  Stream<List<UserProfile>> clinicPatientsStream(
    String clinicId, {
    String? namePrefix,
    int limit = 25,
  }) {
    Query query = _usersCollection
        .where('connectedClinicId', isEqualTo: clinicId)
        .where('userType', isEqualTo: UserType.petOwner.index);

    // Add name prefix filter if provided
    if (namePrefix != null && namePrefix.trim().isNotEmpty) {
      final prefix = namePrefix.trim();
      query = query
          .where('displayName', isGreaterThanOrEqualTo: prefix)
          .where('displayName', isLessThan: '$prefix\uf8ff');
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => UserProfile.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    });
  }

  /// Stream of pets for a given owner
  Stream<List<Pet>> ownerPetsStream(String ownerId) {
    return _usersCollection.doc(ownerId).collection('pets').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return Pet.fromJson(doc.data(), doc.id, ownerId);
      }).toList();
    });
  }
}
