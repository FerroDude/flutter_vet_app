import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_request_model.dart';

/// Service for managing appointment requests between pet owners and clinics.
class AppointmentRequestService {
  final FirebaseFirestore _firestore;

  AppointmentRequestService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requestsCollection =>
      _firestore.collection('appointmentRequests');

  /// Create a new appointment request
  Future<String> createRequest({
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
      final now = DateTime.now();
      final data = {
        'clinicId': clinicId,
        'petOwnerId': petOwnerId,
        'petOwnerName': petOwnerName,
        'petId': petId,
        'petName': petName,
        'petSpecies': petSpecies,
        'preferredDateStart': preferredDateStart.millisecondsSinceEpoch,
        'preferredDateEnd': preferredDateEnd.millisecondsSinceEpoch,
        'timePreference': timePreference.index,
        'reason': reason,
        'notes': notes,
        'status': AppointmentRequestStatus.pending.index,
        'handledBy': null,
        'handledByName': null,
        'handledAt': null,
        'responseMessage': null,
        'linkedChatRoomId': null,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      };

      final docRef = await _requestsCollection.add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create appointment request: $e');
    }
  }

  /// Get a single appointment request by ID
  Future<AppointmentRequest?> getRequest(String requestId) async {
    try {
      final doc = await _requestsCollection.doc(requestId).get();
      if (!doc.exists) return null;
      return AppointmentRequest.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get appointment request: $e');
    }
  }

  /// Stream of pending appointment requests for a clinic (for receptionists)
  Stream<List<AppointmentRequest>> clinicPendingRequestsStream(
    String clinicId,
  ) {
    return _requestsCollection
        .where('clinicId', isEqualTo: clinicId)
        .where('status', isEqualTo: AppointmentRequestStatus.pending.index)
        .orderBy('createdAt', descending: false) // oldest first
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentRequest.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Stream of all appointment requests for a clinic (pending + handled, excludes cancelled)
  Stream<List<AppointmentRequest>> clinicAllRequestsStream(String clinicId) {
    return _requestsCollection
        .where('clinicId', isEqualTo: clinicId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentRequest.fromJson(doc.data(), doc.id))
              // Filter out cancelled requests (for backwards compatibility with old data)
              .where((r) => r.status != AppointmentRequestStatus.cancelled)
              .toList(),
        );
  }

  /// Stream of appointment requests for a pet owner (excludes cancelled)
  Stream<List<AppointmentRequest>> petOwnerRequestsStream(String petOwnerId) {
    return _requestsCollection
        .where('petOwnerId', isEqualTo: petOwnerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppointmentRequest.fromJson(doc.data(), doc.id))
              // Filter out cancelled requests (for backwards compatibility with old data)
              .where((r) => r.status != AppointmentRequestStatus.cancelled)
              .toList(),
        );
  }

  /// Get pending requests count for a clinic
  Future<int> getPendingRequestsCount(String clinicId) async {
    try {
      final snapshot = await _requestsCollection
          .where('clinicId', isEqualTo: clinicId)
          .where('status', isEqualTo: AppointmentRequestStatus.pending.index)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get pending requests count: $e');
    }
  }

  /// Confirm an appointment request (receptionist action)
  Future<void> confirmRequest({
    required String requestId,
    required String handledBy,
    required String handledByName,
    String? message,
  }) async {
    try {
      await _requestsCollection.doc(requestId).update({
        'status': AppointmentRequestStatus.confirmed.index,
        'handledBy': handledBy,
        'handledByName': handledByName,
        'handledAt': DateTime.now().millisecondsSinceEpoch,
        'responseMessage': message,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to confirm appointment request: $e');
    }
  }

  /// Deny an appointment request (receptionist action)
  Future<void> denyRequest({
    required String requestId,
    required String handledBy,
    required String handledByName,
    required String message,
  }) async {
    try {
      await _requestsCollection.doc(requestId).update({
        'status': AppointmentRequestStatus.denied.index,
        'handledBy': handledBy,
        'handledByName': handledByName,
        'handledAt': DateTime.now().millisecondsSinceEpoch,
        'responseMessage': message,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to deny appointment request: $e');
    }
  }

  /// Cancel an appointment request (pet owner action)
  /// Deletes the request document entirely instead of keeping it with cancelled status
  Future<void> cancelRequest(String requestId) async {
    try {
      // Use transaction to ensure we only cancel pending requests
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(_requestsCollection.doc(requestId));
        if (!doc.exists) {
          throw Exception('Request not found');
        }

        final status = doc.data()?['status'] ?? 0;
        if (status != AppointmentRequestStatus.pending.index) {
          throw Exception('Only pending requests can be cancelled');
        }

        // Delete the document instead of updating status
        transaction.delete(_requestsCollection.doc(requestId));
      });
    } catch (e) {
      throw Exception('Failed to cancel appointment request: $e');
    }
  }

  /// Link a chat room to an appointment request
  Future<void> linkChatRoom({
    required String requestId,
    required String chatRoomId,
  }) async {
    try {
      await _requestsCollection.doc(requestId).update({
        'linkedChatRoomId': chatRoomId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to link chat room to appointment request: $e');
    }
  }

  /// Check if a pet owner has any pending requests for a clinic
  Future<bool> hasPendingRequest({
    required String clinicId,
    required String petOwnerId,
  }) async {
    try {
      final snapshot = await _requestsCollection
          .where('clinicId', isEqualTo: clinicId)
          .where('petOwnerId', isEqualTo: petOwnerId)
          .where('status', isEqualTo: AppointmentRequestStatus.pending.index)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check pending requests: $e');
    }
  }
}
