import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../models/clinic_models.dart';
import '../services/clinic_service.dart';

class UserProvider extends ChangeNotifier {
  final ClinicService _clinicService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _currentUser;
  Clinic? _connectedClinic;
  List<ClinicMember> _clinicMembers = [];
  bool _isLoading = false;
  String? _error;

  UserProvider(this._clinicService) {
    _init();
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
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _clearUserData();
      return;
    }

    if (!firebaseUser.emailVerified) {
      _clearUserData();
      return;
    }

    await _loadUserProfile(firebaseUser.uid);
  }

  void _clearUserData() {
    _currentUser = null;
    _connectedClinic = null;
    _clinicMembers = [];
    _error = null;
    notifyListeners();
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
            userProfile.userType != UserType.appOwner) {
          // Update existing user to app owner
          final updatedProfile = userProfile.copyWith(
            userType: UserType.appOwner,
            updatedAt: DateTime.now(),
          );

          await _clinicService.updateUserProfile(updatedProfile);
          _currentUser = updatedProfile;
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
      final email = firebaseUser.email ?? '';

      // Check if this is the app owner
      UserType userType = _isAppOwnerEmail(email)
          ? UserType.appOwner
          : UserType.petOwner;

      String? connectedClinicId;
      ClinicRole? clinicRole;

      // Check if there's a placeholder admin profile for this email
      final tempAdminId =
          'temp_admin_${email.replaceAll('@', '_').replaceAll('.', '_')}';

      developer.log(
        'Checking for temp admin profile with ID: $tempAdminId',
        name: 'UserProvider',
      );

      final existingProfile = await _clinicService.getUserProfile(tempAdminId);

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

        // Update the clinic to use the real user ID instead of temp ID
        if (connectedClinicId != null) {
          developer.log(
            'Updating clinic admin ID from $tempAdminId to $userId',
            name: 'UserProvider',
          );
          await _updateClinicAdminId(connectedClinicId, tempAdminId, userId);
        }

        // Delete the temporary profile
        await _clinicService.deleteUserProfile(tempAdminId);
        developer.log(
          'Deleted temporary admin profile: $tempAdminId',
          name: 'UserProvider',
        );
      } else {
        developer.log(
          'No existing clinic admin profile found for email: $email',
          name: 'UserProvider',
        );
      }

      final profile = UserProfile(
        id: userId,
        email: email,
        displayName: firebaseUser.displayName ?? 'User',
        userType: userType,
        connectedClinicId: connectedClinicId,
        clinicRole: clinicRole,
        createdAt: now,
        updatedAt: now,
      );

      await _clinicService.createUserProfile(profile);
      _currentUser = profile;
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
        final members = await _clinicService.getClinicMembers(clinicId);
        _clinicMembers = members;
      }
    } catch (e) {
      developer.log(
        'Failed to load connected clinic: $e',
        name: 'UserProvider',
      );
      // Don't set error for this - user profile is still valid
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// PUBLIC METHODS ///

  // Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? phone,
    String? address,
    bool? hasSkippedClinicSelection,
  }) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);

      final updatedProfile = _currentUser!.copyWith(
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

      // Generate a temporary admin ID using the email
      final tempAdminId =
          'temp_admin_${adminEmail.replaceAll('@', '_').replaceAll('.', '_')}';

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
        email: adminEmail,
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

      // Also create a Firebase Auth account for the admin
      try {
        developer.log(
          'Creating Firebase Auth account for admin...',
          name: 'UserProvider',
        );
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: 'TempPassword123!', // Temporary password
        );

        // Create the real admin profile with the Firebase UID
        final realAdminProfile = UserProfile(
          id: userCredential.user!.uid,
          email: adminEmail,
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
        await _clinicService.deleteUserProfile(tempAdminId);

        // Update clinic to use real admin ID
        await _updateClinicAdminId(
          clinicId,
          tempAdminId,
          userCredential.user!.uid,
        );

        developer.log(
          'Firebase Auth account created successfully',
          name: 'UserProvider',
        );
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
  Future<bool> addVetToClinic(
    String vetUserId,
    List<String> permissions,
  ) async {
    if (!canManageVets || _connectedClinic == null) return false;

    try {
      _setLoading(true);

      await _clinicService.addVetToClinic(
        _connectedClinic!.id,
        vetUserId,
        permissions,
      );

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

        // Update the clinic to use the real user ID
        if (existingProfile.connectedClinicId != null) {
          await _updateClinicAdminId(
            existingProfile.connectedClinicId!,
            tempAdminId,
            userId,
          );
        }

        // Delete the temporary profile
        await _clinicService.deleteUserProfile(tempAdminId);

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

  @override
  void dispose() {
    super.dispose();
  }
}
