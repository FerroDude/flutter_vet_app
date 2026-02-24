import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/appointment_request_model.dart';
import '../services/appointment_request_service.dart';

/// Provider for managing appointment requests state.
class AppointmentRequestProvider extends ChangeNotifier {
  final AppointmentRequestService _service = AppointmentRequestService();

  List<AppointmentRequest> _pendingRequests = [];
  List<AppointmentRequest> _allRequests = [];
  List<AppointmentRequest> _myRequests = [];

  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<AppointmentRequest>>? _pendingRequestsSub;
  StreamSubscription<List<AppointmentRequest>>? _allRequestsSub;
  StreamSubscription<List<AppointmentRequest>>? _myRequestsSub;

  bool _isDisposed = false;

  // Getters
  List<AppointmentRequest> get pendingRequests => _pendingRequests;
  List<AppointmentRequest> get allRequests => _allRequests;
  List<AppointmentRequest> get myRequests => _myRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Count of pending requests (for badges)
  int get pendingCount => _pendingRequests.length;

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    if (_isDisposed) return;
    _error = error;
    notifyListeners();
  }

  /// Initialize for receptionist - load clinic requests
  void initializeForReceptionist(String clinicId) {
    _cancelSubscriptions();
    _setError(null);
    _setLoading(true);

    // Subscribe to pending requests
    _pendingRequestsSub = _service
        .clinicPendingRequestsStream(clinicId)
        .listen(
          (requests) {
            if (_isDisposed) return;
            _pendingRequests = requests;
            _setLoading(false);
            notifyListeners();
          },
          onError: (e) {
            _setError('Failed to load pending requests: $e');
            _setLoading(false);
          },
        );

    // Subscribe to all requests (for history view)
    _allRequestsSub = _service
        .clinicAllRequestsStream(clinicId)
        .listen(
          (requests) {
            if (_isDisposed) return;
            _allRequests = requests;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Failed to load all requests: $e');
          },
        );
  }

  /// Initialize for pet owner - load their requests
  void initializeForPetOwner(String petOwnerId) {
    _cancelSubscriptions();
    _setError(null);
    _setLoading(true);

    _myRequestsSub = _service
        .petOwnerRequestsStream(petOwnerId)
        .listen(
          (requests) {
            if (_isDisposed) return;
            _myRequests = requests;
            _setLoading(false);
            notifyListeners();
          },
          onError: (e) {
            _setError('Failed to load appointment requests: $e');
            _setLoading(false);
          },
        );
  }

  /// Create a new appointment request
  Future<String?> createRequest({
    required String clinicId,
    required String petOwnerId,
    required String petOwnerName,
    required String petId,
    required String petName,
    String? petSpecies,
    required DateTime preferredDateStart,
    required DateTime preferredDateEnd,
    required TimePreference timePreference,
    required String reason,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final requestId = await _service.createRequest(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        petId: petId,
        petName: petName,
        petSpecies: petSpecies,
        preferredDateStart: preferredDateStart,
        preferredDateEnd: preferredDateEnd,
        timePreference: timePreference,
        reason: reason,
        notes: notes,
      );

      _setLoading(false);
      return requestId;
    } catch (e) {
      _setError('Failed to create request: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Confirm an appointment request (receptionist)
  Future<bool> confirmRequest({
    required String requestId,
    required String handledBy,
    required String handledByName,
    String? message,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _service.confirmRequest(
        requestId: requestId,
        handledBy: handledBy,
        handledByName: handledByName,
        message: message,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to confirm request: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Deny an appointment request (receptionist)
  Future<bool> denyRequest({
    required String requestId,
    required String handledBy,
    required String handledByName,
    required String message,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _service.denyRequest(
        requestId: requestId,
        handledBy: handledBy,
        handledByName: handledByName,
        message: message,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to deny request: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Cancel an appointment request (pet owner)
  Future<bool> cancelRequest(String requestId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _service.cancelRequest(requestId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to cancel request: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Link a chat room to an appointment request
  Future<bool> linkChatRoom({
    required String requestId,
    required String chatRoomId,
  }) async {
    try {
      await _service.linkChatRoom(requestId: requestId, chatRoomId: chatRoomId);
      return true;
    } catch (e) {
      _setError('Failed to link chat room: $e');
      return false;
    }
  }

  /// Check if pet owner has pending request for clinic
  Future<bool> hasPendingRequest({
    required String clinicId,
    required String petOwnerId,
  }) async {
    try {
      return await _service.hasPendingRequest(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
      );
    } catch (e) {
      debugPrint('Failed to check pending request: $e');
      return false;
    }
  }

  void _cancelSubscriptions() {
    _pendingRequestsSub?.cancel();
    _pendingRequestsSub = null;
    _allRequestsSub?.cancel();
    _allRequestsSub = null;
    _myRequestsSub?.cancel();
    _myRequestsSub = null;
  }

  void clearData() {
    _cancelSubscriptions();
    _pendingRequests = [];
    _allRequests = [];
    _myRequests = [];
    _error = null;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelSubscriptions();
    super.dispose();
  }
}
