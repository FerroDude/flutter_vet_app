import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:developer' as developer;
import 'dart:async';
import '../models/clinic_models.dart';
import '../firebase_options.dart';
import '../services/clinic_service.dart';

class UserProvider extends ChangeNotifier {
  final ClinicService _clinicService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ClinicMember>>? _membersSub;
  bool _isDisposed = false;

  UserProfile? _currentUser;
  Clinic? _connectedClinic;
  List<ClinicMember> _clinicMembers = [];
  bool _isLoading = false;
  String? _error;

  UserProvider(this._clinicService) {
    _init();
  }

  /// Record a vet invitation by email for the connected clinic
  Future<bool> inviteVetByEmail(String email) async {
    if (!canManageVets || _connectedClinic == null) return false;

    try {
      _setLoading(true);

      final normalizedEmail = email.trim().toLowerCase();
      await _clinicService.createVetInvite(
        _connectedClinic!.id,
        normalizedEmail,
      );

      // Provision an auth account (idempotent) and send a password reset email
      try {
        await provisionAuthAccountAndSendReset(normalizedEmail);
      } catch (e) {
        // Don't fail the invite if email sending fails; surface a soft error
        developer.log(
          'Failed to send reset for vet invite: $e',
          name: 'UserProvider',
        );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to invite vet: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Revoke a pending vet invite for the connected clinic
  Future<bool> revokeVetInvite(String email) async {
    if (!canManageVets || _connectedClinic == null) return false;
    try {
      final normalizedEmail = email.trim().toLowerCase();
      await _clinicService.revokeVetInvite(
        _connectedClinic!.id,
        normalizedEmail,
      );
      return true;
    } catch (e) {
      _setError('Failed to revoke invite: $e');
      return false;
    }
  }

  // Getters
  UserProfile? get currentUser => _currentUser;
  Clinic? get connectedClinic => _connectedClinic;
  List<ClinicMember> get clinicMembers => _clinicMembers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // User type helpers
  bool get isPetOwner => _currentUser?.isPetOwner ?? false;
  bool get isVet => _currentUser?.isVet ?? false;
  bool get isClinicAdmin => _currentUser?.isClinicAdmin ?? false;
  bool get isAppOwner => _currentUser?.isAppOwner ?? false;
  bool get hasClinicConnection => _currentUser?.hasClinicConnection ?? false;

  // Permission helpers
  bool get canManageVets => isClinicAdmin || isAppOwner;
  bool get canViewClinicData => isVet || isClinicAdmin || isAppOwner;
  bool get canCreateClinicAdmins => isAppOwner;

  void _init() {
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _authSub?.cancel();
    } catch (_) {}
    _authSub = null;
    try {
      _membersSub?.cancel();
    } catch (_) {}
    _membersSub = null;
    super.dispose();
  }

  Future<FirebaseApp> _getOrInitSecondaryApp() async {
    try {
      return Firebase.app('secondary');
    } catch (_) {
      return Firebase.initializeApp(
        name: 'secondary',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (_isDisposed) return;
    if (firebaseUser == null) {
      _clearUserData();
      return;
    }

    if (!firebaseUser.emailVerified) {
      _clearUserData();
      return;
    }

    await _loadUserProfile(firebaseUser.uid);

    // Note: Vet invite handling is done via temp profiles during _loadUserProfile
    // and _createInitialUserProfile, so no additional invite checking needed here.
  }

  /// Attempt to apply a pending vet invite for the currently signed-in
  /// Firebase user based on their email. Returns true if applied.
  Future<bool> applyPendingInviteForCurrentEmail() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return false;
      final email = (firebaseUser.email ?? '').trim().toLowerCase();
      if (email.isEmpty) return false;

      _setLoading(true);
      final invite = await _clinicService.findPendingVetInviteByEmail(email);
      if (invite == null) {
        _setLoading(false);
        return false;
      }

      await _clinicService.applyVetInvite(
        clinicId: invite['clinicId'] as String,
        userId: firebaseUser.uid,
        inviteRef: invite['inviteRef'] as dynamic,
        normalizedEmailForCleanup: email,
      );

      await _loadUserProfile(firebaseUser.uid);
      _setLoading(false);
      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  void _clearUserData() {
    if (_isDisposed) return;
    _currentUser = null;
    _connectedClinic = null;
    _clinicMembers = [];
    _error = null;
    try {
      _membersSub?.cancel();
    } catch (_) {}
    _membersSub = null;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      _setLoading(true);

      // Load user profile
      final userProfile = await _clinicService.getUserProfile(userId);

      if (userProfile != null) {
        _currentUser = userProfile;

        // Check if existing user should be upgraded to app owner
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null &&
            _isAppOwnerEmail(firebaseUser.email) &&
            userProfile.globalType != 'appOwner') {
          // Update existing user to app owner
          final updatedProfile = userProfile.copyWith(
            globalType: 'appOwner',
            updatedAt: DateTime.now(),
          );

          await _clinicService.updateUserProfile(updatedProfile);
          _currentUser = updatedProfile;
        }

        // If user is not yet a clinic admin or vet, check for temp profiles by email (case-insensitive)
        final signedInEmail = (_auth.currentUser?.email ?? '').trim();
        if (signedInEmail.isNotEmpty &&
            _currentUser!.userType != UserType.clinicAdmin &&
            _currentUser!.userType != UserType.vet) {
          final emailLower = signedInEmail.toLowerCase();
          final emailToken = emailLower
              .replaceAll('@', '_')
              .replaceAll('.', '_')
              .replaceAll('+', '_');
          final tempAdminId = 'temp_admin_$emailToken';
          final tempVetId = 'temp_vet_$emailToken';

          developer.log(
            'Link-check: looking for temp admin profile $tempAdminId',
            name: 'UserProvider',
          );

          UserProfile? tempProfile = await _clinicService.getUserProfile(
            tempAdminId,
          );
          if (tempProfile != null &&
              tempProfile.userType == UserType.clinicAdmin &&
              tempProfile.connectedClinicId != null) {
            final linkedClinicId = tempProfile.connectedClinicId!;

            // Ensure membership and transfer ownership
            await _clinicService.ensureAdminMembershipFor(
              linkedClinicId,
              _currentUser!.id,
              tempAdminId: tempAdminId,
            );
            await _updateClinicAdminId(
              linkedClinicId,
              tempAdminId,
              _currentUser!.id,
            );

            // Upgrade profile to clinic admin and connect clinic, keep adminName
            final upgraded = _currentUser!.copyWith(
              userType: UserType.clinicAdmin,
              clinicRole: ClinicRole.admin,
              connectedClinicId: linkedClinicId,
              displayName: tempProfile.displayName,
              updatedAt: DateTime.now(),
            );
            await _clinicService.updateUserProfile(upgraded);
            _currentUser = upgraded;
            await _loadConnectedClinic(linkedClinicId);
            if (!_isDisposed) notifyListeners();

            // Best-effort delete temp user doc
            try {
              await _clinicService.deleteUserDocOnly(tempAdminId);
            } catch (_) {}
          } else {
            // Check for vet invite
            developer.log(
              'Link-check: looking for temp vet profile $tempVetId',
              name: 'UserProvider',
            );

            tempProfile = await _clinicService.getUserProfile(tempVetId);
            if (tempProfile != null &&
                tempProfile.userType == UserType.vet &&
                tempProfile.connectedClinicId != null) {
              final linkedClinicId = tempProfile.connectedClinicId!;

              // Ensure membership - vets always have full access
              await _clinicService.ensureVetMembershipFor(
                linkedClinicId,
                _currentUser!.id,
                tempVetId: tempVetId,
              );

              // Upgrade profile to vet and connect clinic
              // Keep displayName empty so vet can set it on first login
              final upgraded = _currentUser!.copyWith(
                userType: UserType.vet,
                clinicRole: ClinicRole.vet,
                connectedClinicId: linkedClinicId,
                displayName: '', // Empty - vet will set their own
                updatedAt: DateTime.now(),
              );
              await _clinicService.updateUserProfile(upgraded);
              _currentUser = upgraded;
              await _loadConnectedClinic(linkedClinicId);
              if (!_isDisposed) notifyListeners();

              // Delete the invite document now that user has logged in
              try {
                await _clinicService.deleteVetInvite(
                  linkedClinicId,
                  signedInEmail,
                );
                developer.log(
                  'Deleted vet invite for: $signedInEmail',
                  name: 'UserProvider',
                );
              } catch (e) {
                developer.log(
                  'Failed to delete vet invite (will ignore): $e',
                  name: 'UserProvider',
                );
              }

              // Best-effort delete temp user doc
              try {
                await _clinicService.deleteUserDocOnly(tempVetId);
                developer.log(
                  'Deleted temporary vet user doc: $tempVetId',
                  name: 'UserProvider',
                );
              } catch (e) {
                developer.log(
                  'Failed to delete temp vet user doc (will ignore): $e',
                  name: 'UserProvider',
                );
              }
            }
          }
        }

        // Load connected clinic if user has one
        if (_currentUser!.connectedClinicId != null) {
          await _loadConnectedClinic(_currentUser!.connectedClinicId!);
        }
      } else {
        // Create initial user profile for new users
        await _createInitialUserProfile(userId);
      }

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load user profile: $e');
      _setLoading(false);
    }
  }

  Future<void> _createInitialUserProfile(String userId) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return;

      final now = DateTime.now();
      final email = (firebaseUser.email ?? '').trim();
      final emailLower = email.toLowerCase();

      // Check if this is the app owner
      UserType userType =
          UserType.petOwner; // legacy compat; use globalType + clinicRole
      String? globalType = _isAppOwnerEmail(email) ? 'appOwner' : null;

      String? connectedClinicId;
      ClinicRole? clinicRole;

      // Check if there's a placeholder admin profile for this email (case-insensitive)
      final emailToken = emailLower
          .replaceAll('@', '_')
          .replaceAll('.', '_')
          .replaceAll('+', '_');
      final tempAdminId = 'temp_admin_$emailToken';
      final tempVetId = 'temp_vet_$emailToken';

      developer.log(
        'Checking for temp admin profile with ID: $tempAdminId',
        name: 'UserProvider',
      );

      UserProfile? existingProfile = await _clinicService.getUserProfile(
        tempAdminId,
      );

      if (existingProfile != null &&
          existingProfile.userType == UserType.clinicAdmin) {
        developer.log(
          'Found existing clinic admin profile for email: $email',
          name: 'UserProvider',
        );

        // This user is a clinic admin that was created by an app owner
        userType = UserType.clinicAdmin;
        connectedClinicId = existingProfile.connectedClinicId;
        clinicRole = ClinicRole.admin;

        // Establish membership and ownership before any reads
        if (connectedClinicId != null) {
          developer.log(
            'Ensuring real admin membership and updating clinic admin ID',
            name: 'UserProvider',
          );
          await _clinicService.ensureAdminMembershipFor(
            connectedClinicId,
            userId,
            tempAdminId: tempAdminId,
          );
          await _updateClinicAdminId(connectedClinicId, tempAdminId, userId);
        }

        // Delete the temporary profile doc only (safer under rules)
        try {
          await _clinicService.deleteUserDocOnly(tempAdminId);
          developer.log(
            'Deleted temporary admin user doc: $tempAdminId',
            name: 'UserProvider',
          );
        } catch (e) {
          developer.log(
            'Failed to delete temp admin user doc (will ignore): $e',
            name: 'UserProvider',
          );
        }
      } else {
        // Check for vet invite
        developer.log(
          'No temp admin found, checking for temp vet profile with ID: $tempVetId',
          name: 'UserProvider',
        );

        existingProfile = await _clinicService.getUserProfile(tempVetId);

        if (existingProfile != null &&
            existingProfile.userType == UserType.vet) {
          developer.log(
            'Found existing vet profile for email: $email',
            name: 'UserProvider',
          );

          // This user is a vet that was invited by a clinic admin
          userType = UserType.vet;
          connectedClinicId = existingProfile.connectedClinicId;
          clinicRole = ClinicRole.vet;

          // Establish membership and link to clinic
          if (connectedClinicId != null) {
            developer.log('Ensuring real vet membership', name: 'UserProvider');

            // Ensure membership - vets always have full access
            await _clinicService.ensureVetMembershipFor(
              connectedClinicId,
              userId,
              tempVetId: tempVetId,
            );

            // Delete the invite document now that user has logged in for the first time
            try {
              await _clinicService.deleteVetInvite(connectedClinicId, email);
              developer.log(
                'Deleted vet invite for: $email',
                name: 'UserProvider',
              );
            } catch (e) {
              developer.log(
                'Failed to delete vet invite (will ignore): $e',
                name: 'UserProvider',
              );
            }
          }
        } else {
          developer.log(
            'No existing admin or vet profile found for email: $email',
            name: 'UserProvider',
          );
        }
      }

      // Determine display name based on user type
      String displayName;
      if (userType == UserType.clinicAdmin && existingProfile != null) {
        // Clinic admins get their name from temp profile
        displayName = existingProfile.displayName;
      } else if (userType == UserType.vet && existingProfile != null) {
        // Vets should set their own name - use empty string
        displayName = '';
      } else {
        // Pet owners and others use Firebase display name or 'User'
        displayName = firebaseUser.displayName ?? 'User';
      }

      final profile = UserProfile(
        id: userId,
        email: email,
        displayName: displayName,
        userType: userType,
        connectedClinicId: connectedClinicId,
        clinicRole: clinicRole,
        createdAt: now,
        updatedAt: now,
        globalType: globalType,
      );

      await _clinicService.createUserProfile(profile);
      _currentUser = profile;

      // Delete temp user profile AFTER creating the real one
      if (userType == UserType.vet && existingProfile != null) {
        final tempVetId = 'temp_vet_$emailToken';
        try {
          await _clinicService.deleteUserDocOnly(tempVetId);
          developer.log(
            'Deleted temporary vet user doc: $tempVetId',
            name: 'UserProvider',
          );
        } catch (e) {
          developer.log(
            'Failed to delete temp vet user doc (will ignore): $e',
            name: 'UserProvider',
          );
        }
      }

      // Immediately load connected clinic on first-time admin creation
      if (connectedClinicId != null) {
        try {
          await _loadConnectedClinic(connectedClinicId);
        } catch (_) {}
      }

      if (!_isDisposed) notifyListeners();
    } catch (e) {
      _setError('Failed to create user profile: $e');
    }
  }

  Future<void> _loadConnectedClinic(String clinicId) async {
    try {
      final clinic = await _clinicService.getClinic(clinicId);
      _connectedClinic = clinic;

      // Load clinic members if user is vet or admin
      if (canViewClinicData) {
        try {
          _membersSub?.cancel();
        } catch (_) {}
        _membersSub = _clinicService.clinicMembersStream(clinicId).listen((
          members,
        ) {
          _clinicMembers = members;
          if (!_isDisposed) notifyListeners();
        });
      }
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      developer.log(
        'Failed to load connected clinic: $e',
        name: 'UserProvider',
      );
      // Don't set error for this - user profile is still valid
    }
  }

  /// If the current user is a clinic admin but has no connectedClinicId, attempt to
  /// discover and connect them to their clinic by admin ownership.
  Future<void> ensureAdminConnectedToClinic() async {
    if (_currentUser == null) return;
    if (!isClinicAdmin) return;
    if (_currentUser!.connectedClinicId != null) return;

    try {
      final ownedClinic = await _clinicService.findClinicByAdmin(
        _currentUser!.id,
      );
      if (ownedClinic != null) {
        final updatedProfile = _currentUser!.copyWith(
          connectedClinicId: ownedClinic.id,
          clinicRole: ClinicRole.admin,
          updatedAt: DateTime.now(),
        );
        await _clinicService.updateUserProfile(updatedProfile);
        _currentUser = updatedProfile;
        await _loadConnectedClinic(ownedClinic.id);
        if (!_isDisposed) notifyListeners();
        if (!_isDisposed) notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    if (_isLoading != loading) {
      _isLoading = loading;
      if (!_isDisposed) notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_isDisposed) return;
    if (_error != error) {
      _error = error;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// PUBLIC METHODS ///

  // Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? email,
    String? phone,
    String? address,
    bool? hasSkippedClinicSelection,
  }) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);

      final updatedProfile = _currentUser!.copyWith(
        email: email,
        displayName: displayName,
        phone: phone,
        address: address,
        hasSkippedClinicSelection: hasSkippedClinicSelection,
        updatedAt: DateTime.now(),
      );

      await _clinicService.updateUserProfile(updatedProfile);
      _currentUser = updatedProfile;

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      _setLoading(false);
      return false;
    }
  }

  // Connect to clinic
  Future<bool> connectToClinic(String clinicId) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);

      await _clinicService.connectUserToClinic(_currentUser!.id, clinicId);

      // Reload user profile to get updated clinic connection
      await _loadUserProfile(_currentUser!.id);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to connect to clinic: $e');
      _setLoading(false);
      return false;
    }
  }

  // Disconnect from clinic
  Future<bool> disconnectFromClinic({String? reason}) async {
    if (_currentUser == null || !hasClinicConnection) return false;

    try {
      _setLoading(true);

      await _clinicService.disconnectUserFromClinic(
        _currentUser!.id,
        reason: reason,
      );

      // Clear clinic data
      _connectedClinic = null;
      _clinicMembers = [];

      // Reload user profile
      await _loadUserProfile(_currentUser!.id);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to disconnect from clinic: $e');
      _setLoading(false);
      return false;
    }
  }

  // Search clinics
  Future<List<Clinic>> searchClinics({String? query}) async {
    try {
      return await _clinicService.searchClinics(nameQuery: query);
    } catch (e) {
      _setError('Failed to search clinics: $e');
      return [];
    }
  }

  // Create clinic (for clinic admins)
  Future<String?> createClinic({
    required String name,
    required String address,
    required String phone,
    required String email,
    String? website,
    String? description,
    Map<String, dynamic>? businessHours,
  }) async {
    if (_currentUser == null) return null;

    try {
      _setLoading(true);

      final now = DateTime.now();
      final clinic = Clinic(
        id: '', // Will be set by Firestore
        name: name,
        address: address,
        phone: phone,
        email: email,
        adminId: _currentUser!.id,
        createdAt: now,
        updatedAt: now,
        website: website,
        description: description,
        businessHours: businessHours,
      );

      final clinicId = await _clinicService.createClinic(clinic);

      // Update user to clinic admin
      final updatedProfile = _currentUser!.copyWith(
        userType: UserType.clinicAdmin,
        connectedClinicId: clinicId,
        clinicRole: ClinicRole.admin,
        updatedAt: DateTime.now(),
      );

      await _clinicService.updateUserProfile(updatedProfile);
      _currentUser = updatedProfile;

      // Load the created clinic
      await _loadConnectedClinic(clinicId);

      _setLoading(false);
      return clinicId;
    } catch (e) {
      _setError('Failed to create clinic: $e');
      _setLoading(false);
      return null;
    }
  }

  // Create clinic and admin profile (for app owners)
  Future<String?> createClinicForAdmin({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String adminEmail,
    required String adminName,
    String? website,
    String? description,
    Map<String, dynamic>? businessHours,
  }) async {
    developer.log(
      'UserProvider.createClinicForAdmin called',
      name: 'UserProvider',
    );
    developer.log(
      'Current user: ${_currentUser?.email}, isAppOwner: $isAppOwner',
      name: 'UserProvider',
    );

    if (_currentUser == null) {
      developer.log('No current user found', name: 'UserProvider');
      return null;
    }

    if (!isAppOwner) {
      developer.log(
        'User is not app owner: ${_currentUser?.userType}',
        name: 'UserProvider',
      );
      return null;
    }

    try {
      developer.log(
        'Starting clinic creation process...',
        name: 'UserProvider',
      );
      _setLoading(true);

      final now = DateTime.now();

      // Normalize email
      final normalizedAdminEmail = adminEmail.trim().toLowerCase();

      // Generate a temporary admin ID using the email
      final tempAdminId =
          'temp_admin_${normalizedAdminEmail.replaceAll('@', '_').replaceAll('.', '_')}';

      developer.log(
        'Generated temp admin ID: $tempAdminId',
        name: 'UserProvider',
      );

      // Create the clinic with temporary admin ID
      final clinic = Clinic(
        id: '', // Will be set by Firestore
        name: name,
        address: address,
        phone: phone,
        email: email,
        adminId: tempAdminId, // Will be updated when admin signs up
        createdAt: now,
        updatedAt: now,
        website: website,
        description: description,
        businessHours: businessHours,
      );

      developer.log('Creating clinic in Firestore...', name: 'UserProvider');
      final clinicId = await _clinicService.createClinic(clinic);
      developer.log('Clinic created with ID: $clinicId', name: 'UserProvider');

      // Create a placeholder admin user profile
      final adminProfile = UserProfile(
        id: tempAdminId,
        email: normalizedAdminEmail,
        displayName: adminName,
        userType: UserType.clinicAdmin,
        connectedClinicId: clinicId,
        clinicRole: ClinicRole.admin,
        createdAt: now,
        updatedAt: now,
        isActive: false, // Will be activated when they sign up
      );

      developer.log('Creating admin profile...', name: 'UserProvider');
      await _clinicService.createUserProfile(adminProfile);
      developer.log('Admin profile created successfully', name: 'UserProvider');

      // Also create a Firebase Auth account for the admin using a secondary app
      try {
        developer.log(
          'Creating Firebase Auth account for admin (secondary app)...',
          name: 'UserProvider',
        );
        final secondaryApp = await _getOrInitSecondaryApp();

        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        UserCredential? userCredential;
        bool emailAlreadyExists = false;
        try {
          userCredential = await secondaryAuth.createUserWithEmailAndPassword(
            email: normalizedAdminEmail,
            password: 'TempPassword123!', // Temporary password
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            emailAlreadyExists = true;
          } else {
            // Still attempt to send reset email below; rethrowing not needed
            developer.log('Auth create error: ${e.code}', name: 'UserProvider');
          }
        }

        // Send password reset email to force setting a new password (always try)
        try {
          await secondaryAuth.sendPasswordResetEmail(
            email: normalizedAdminEmail,
          );
        } catch (e) {
          // Fallback via default auth
          try {
            await _auth.sendPasswordResetEmail(email: normalizedAdminEmail);
          } catch (_) {}
        }

        // Create the real admin profile with the Firebase UID
        if (userCredential == null && !emailAlreadyExists) {
          // Could not create or obtain UID; skip profile creation but clinic exists with temp admin
          await secondaryApp.delete();
          _setLoading(false);
          return clinicId;
        }

        // If account existed, we don't have a UID; cannot create a real profile here
        if (userCredential != null) {
          // Update auth display name for the admin user
          try {
            await userCredential.user!.updateDisplayName(adminName);
          } catch (_) {}

          final realAdminProfile = UserProfile(
            id: userCredential.user!.uid,
            email: normalizedAdminEmail,
            displayName: adminName,
            userType: UserType.clinicAdmin,
            connectedClinicId: clinicId,
            clinicRole: ClinicRole.admin,
            createdAt: now,
            updatedAt: DateTime.now(),
            isActive: true,
          );

          // Create the real profile and delete the temp one
          await _clinicService.createUserProfile(realAdminProfile);
          await _clinicService.ensureAdminMembershipFor(
            clinicId,
            userCredential.user!.uid,
            tempAdminId: tempAdminId,
          );
          await _updateClinicAdminId(
            clinicId,
            tempAdminId,
            userCredential.user!.uid,
          );
          // Delete only the temp user doc (rules-friendly)
          await _clinicService.deleteUserDocOnly(tempAdminId);
        }

        developer.log('Admin auth handling complete', name: 'UserProvider');
        try {
          await secondaryApp.delete();
        } catch (_) {}
      } catch (e) {
        developer.log(
          'Could not create Firebase Auth account: $e',
          name: 'UserProvider',
        );
        // Continue with temp profile approach
      }

      _setLoading(false);
      developer.log(
        'Complete! Returning clinic ID: $clinicId',
        name: 'UserProvider',
      );
      return clinicId;
    } catch (e) {
      developer.log('Error in createClinicForAdmin: $e', name: 'UserProvider');
      _setError('Failed to create clinic and admin: $e');
      _setLoading(false);
      return null;
    }
  }

  // Add vet to clinic (admin only)
  Future<bool> addVetToClinic(String vetUserId) async {
    if (!canManageVets || _connectedClinic == null) return false;

    try {
      _setLoading(true);

      // Vets always have full access - no permissions tracking
      await _clinicService.addVetToClinic(_connectedClinic!.id, vetUserId);

      // Reload clinic members
      await _loadConnectedClinic(_connectedClinic!.id);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to add vet to clinic: $e');
      _setLoading(false);
      return false;
    }
  }

  // Remove member from clinic (admin only)
  Future<bool> removeMemberFromClinic(String userId) async {
    if (!canManageVets || _connectedClinic == null) return false;

    try {
      _setLoading(true);

      await _clinicService.removeMemberFromClinic(_connectedClinic!.id, userId);

      // Reload clinic members
      await _loadConnectedClinic(_connectedClinic!.id);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to remove member from clinic: $e');
      _setLoading(false);
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Skip clinic selection for pet owners
  Future<bool> skipClinicSelection() async {
    try {
      _setLoading(true);

      if (_currentUser == null || !_currentUser!.isPetOwner) {
        _setError('Only pet owners can skip clinic selection');
        return false;
      }

      // Update user profile to indicate they've skipped clinic selection
      final success = await updateProfile(hasSkippedClinicSelection: true);

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Failed to skip clinic selection: $e');
      _setLoading(false);
      return false;
    }
  }

  // Force refresh user data
  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _loadUserProfile(user.uid);
    }
  }

  /// If the user has a connected clinic ID but `_connectedClinic` is null,
  /// load it and notify listeners.
  Future<void> loadClinicIfMissing() async {
    final clinicId = _currentUser?.connectedClinicId;
    if (clinicId != null && _connectedClinic == null) {
      await _loadConnectedClinic(clinicId);
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Ensure a Firebase Auth account exists for the given email and send a
  /// password reset email. Uses a secondary app instance to avoid affecting
  /// the current user's session.
  Future<bool> provisionAuthAccountAndSendReset(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final secondaryApp = await _getOrInitSecondaryApp();
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      bool emailAlreadyExists = false; // used to avoid treating as failure
      try {
        await secondaryAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: 'TempPassword123!',
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          emailAlreadyExists = true;
        } else {
          // Non-existence/other errors may still allow sending reset
        }
      }

      // Attempt to send reset email regardless
      try {
        await secondaryAuth.sendPasswordResetEmail(email: normalizedEmail);
      } catch (_) {
        try {
          await _auth.sendPasswordResetEmail(email: normalizedEmail);
        } catch (_) {}
      }

      try {
        await secondaryApp.delete();
      } catch (_) {}

      return emailAlreadyExists || true;
    } catch (e) {
      _setError('Failed to send reset: $e');
      return false;
    }
  }

  /// Delete the current user's account and all associated data
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _setError(null);

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _setError('No user signed in');
        return false;
      }

      final userId = firebaseUser.uid;

      // 1. Delete user profile from Firestore
      await _clinicService.deleteUserProfile(userId);

      // 2. Delete the Firebase Auth account
      await firebaseUser.delete();

      // 3. Clear local data
      _clearUserData();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete account: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update clinic admin ID when a clinic admin signs up
  Future<void> _updateClinicAdminId(
    String clinicId,
    String oldAdminId,
    String newAdminId,
  ) async {
    try {
      final clinic = await _clinicService.getClinic(clinicId);
      if (clinic != null && clinic.adminId == oldAdminId) {
        final updatedClinic = clinic.copyWith(
          adminId: newAdminId,
          updatedAt: DateTime.now(),
        );
        await _clinicService.updateClinic(clinicId, updatedClinic);
      }
    } catch (e) {
      developer.log(
        'Failed to update clinic admin ID: $e',
        name: 'UserProvider',
      );
      // Don't throw - this shouldn't prevent user creation
    }
  }

  /// Check if an email belongs to the app owner
  bool _isAppOwnerEmail(String? email) {
    if (email == null) return false;

    // Add your app owner email here
    const appOwnerEmails = [
      'pedroferrodude@hotmail.com',
      'ines.breia@gmail.com',
      // Add more app owner emails as needed
    ];

    return appOwnerEmails.contains(email.toLowerCase());
  }

  /// Manual method to fix clinic admin linking for existing users
  Future<bool> fixClinicAdminLinking(String email) async {
    try {
      developer.log(
        'Attempting to fix clinic admin linking for: $email',
        name: 'UserProvider',
      );

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        developer.log('No current user found', name: 'UserProvider');
        return false;
      }

      final userId = firebaseUser.uid;
      final tempAdminId =
          'temp_admin_${email.replaceAll('@', '_').replaceAll('.', '_')}';

      developer.log(
        'Looking for temp admin profile: $tempAdminId',
        name: 'UserProvider',
      );

      // Check if there's a temporary admin profile
      final existingProfile = await _clinicService.getUserProfile(tempAdminId);

      developer.log(
        'Existing profile found: ${existingProfile != null}',
        name: 'UserProvider',
      );

      if (existingProfile != null) {
        developer.log(
          'Profile user type: ${existingProfile.userType}',
          name: 'UserProvider',
        );
      }

      if (existingProfile != null &&
          existingProfile.userType == UserType.clinicAdmin) {
        developer.log(
          'Found temp admin profile, updating user to clinic admin',
          name: 'UserProvider',
        );

        // Update current user to be clinic admin
        final updatedProfile = _currentUser!.copyWith(
          userType: UserType.clinicAdmin,
          connectedClinicId: existingProfile.connectedClinicId,
          clinicRole: ClinicRole.admin,
          updatedAt: DateTime.now(),
        );

        await _clinicService.updateUserProfile(updatedProfile);
        _currentUser = updatedProfile;

        // Ensure admin membership first, then update clinic admin ID
        if (existingProfile.connectedClinicId != null) {
          await _clinicService.ensureAdminMembershipFor(
            existingProfile.connectedClinicId!,
            userId,
            tempAdminId: tempAdminId,
          );
          await _updateClinicAdminId(
            existingProfile.connectedClinicId!,
            tempAdminId,
            userId,
          );
        }

        // Delete only the temporary profile doc
        try {
          await _clinicService.deleteUserDocOnly(tempAdminId);
        } catch (_) {
          // ignore
        }

        developer.log(
          'Successfully updated user to clinic admin',
          name: 'UserProvider',
        );
        return true;
      } else {
        developer.log(
          'No temp admin profile found for: $email',
          name: 'UserProvider',
        );
        return false;
      }
    } catch (e) {
      developer.log(
        'Error fixing clinic admin linking: $e',
        name: 'UserProvider',
      );
      return false;
    }
  }
}
