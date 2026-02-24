/* Cloud Functions for Peton app */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

try {
  admin.initializeApp();
} catch (_) {}

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================
// PUSH NOTIFICATION HELPERS
// ============================================================

/**
 * Structured log helper for easier filtering in Cloud Logging.
 * @param {'INFO'|'WARNING'|'ERROR'} severity
 * @param {string} event
 * @param {Object} data
 */
function logStructured(severity, event, data = {}) {
  const payload = {
    severity,
    event,
    timestamp: new Date().toISOString(),
    ...data,
  };
  console.log(JSON.stringify(payload));
}

/**
 * Extract a consistent error code string from Firebase Admin errors.
 * @param {any} error
 * @returns {string}
 */
function getErrorCode(error) {
  return (
    error?.errorInfo?.code || error?.code || error?.details?.code || 'unknown'
  );
}

/**
 * Returns true if the provided error code indicates a bad token that should
 * be removed from the user profile.
 * @param {string} code
 * @returns {boolean}
 */
function shouldDeleteToken(code) {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token'
  );
}

/**
 * Send a push notification to a specific user by their userId.
 * Retrieves the FCM token from the user's profile.
 *
 * @param {string} userId - The user's document ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Additional data payload for navigation
 * @returns {Promise<boolean>} - Whether notification was sent successfully
 */
async function sendPushToUser(userId, title, body, data = {}) {
  try {
    logStructured('INFO', 'push_send_attempt', { userId, title });

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      logStructured('WARNING', 'push_skipped_user_not_found', { userId });
      return false;
    }

    const fcmToken = userDoc.get('fcmToken');
    if (!fcmToken) {
      logStructured('WARNING', 'push_skipped_missing_token', { userId });
      return false;
    }

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        ...data,
        // Ensure all values are strings
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'peton_notifications',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    await messaging.send(message);
    logStructured('INFO', 'push_send_success', { userId, title });
    return true;
  } catch (error) {
    const code = getErrorCode(error);
    logStructured('ERROR', 'push_send_failed', {
      userId,
      title,
      code,
      message: error?.message || String(error),
    });

    // Remove invalid or unregistered tokens to reduce repeated failures.
    if (shouldDeleteToken(code)) {
      try {
        await db.collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        logStructured('INFO', 'push_token_deleted', { userId, code });
      } catch (cleanupError) {
        logStructured('ERROR', 'push_token_delete_failed', {
          userId,
          code: getErrorCode(cleanupError),
          message: cleanupError?.message || String(cleanupError),
        });
      }
    }

    return false;
  }
}

/**
 * Send push notifications to all receptionists in a clinic.
 * ClinicRole enum: admin=0, vet=1, receptionist=2
 *
 * @param {string} clinicId - The clinic's document ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Additional data payload
 */
async function sendPushToClinicReceptionists(clinicId, title, body, data = {}) {
  try {
    logStructured('INFO', 'clinic_receptionist_push_fanout_attempt', {
      clinicId,
      title,
    });

    // Get all active receptionists in the clinic
    const membersSnap = await db
      .collection('clinics')
      .doc(clinicId)
      .collection('members')
      .where('role', '==', 2) // receptionist
      .where('isActive', '==', true)
      .get();

    if (membersSnap.empty) {
      logStructured('INFO', 'clinic_receptionist_push_skipped_no_members', {
        clinicId,
      });
      return;
    }

    const sendPromises = membersSnap.docs.map((memberDoc) =>
      sendPushToUser(memberDoc.id, title, body, data),
    );

    const results = await Promise.all(sendPromises);
    const sentCount = results.filter(Boolean).length;

    logStructured('INFO', 'clinic_receptionist_push_fanout_complete', {
      clinicId,
      targetCount: membersSnap.size,
      sentCount,
      failedCount: membersSnap.size - sentCount,
    });
  } catch (error) {
    logStructured('ERROR', 'clinic_receptionist_push_fanout_failed', {
      clinicId,
      code: getErrorCode(error),
      message: error?.message || String(error),
    });
  }
}

/**
 * Send push notifications to all staff (admins + receptionists) in a clinic.
 *
 * @param {string} clinicId - The clinic's document ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Additional data payload
 */
async function sendPushToClinicStaff(clinicId, title, body, data = {}) {
  try {
    logStructured('INFO', 'clinic_staff_push_fanout_attempt', {
      clinicId,
      title,
    });

    // Get all active staff (admins and receptionists) in the clinic
    const membersSnap = await db
      .collection('clinics')
      .doc(clinicId)
      .collection('members')
      .where('isActive', '==', true)
      .get();

    if (membersSnap.empty) {
      logStructured('INFO', 'clinic_staff_push_skipped_no_members', {
        clinicId,
      });
      return;
    }

    // Filter to admins (role=0) and receptionists (role=2)
    const staffMembers = membersSnap.docs.filter((doc) => {
      const role = doc.get('role');
      return role === 0 || role === 2;
    });

    if (staffMembers.length === 0) {
      logStructured('INFO', 'clinic_staff_push_skipped_no_staff_roles', {
        clinicId,
      });
      return;
    }

    const sendPromises = staffMembers.map((memberDoc) =>
      sendPushToUser(memberDoc.id, title, body, data),
    );

    const results = await Promise.all(sendPromises);
    const sentCount = results.filter(Boolean).length;

    logStructured('INFO', 'clinic_staff_push_fanout_complete', {
      clinicId,
      targetCount: staffMembers.length,
      sentCount,
      failedCount: staffMembers.length - sentCount,
    });
  } catch (error) {
    logStructured('ERROR', 'clinic_staff_push_fanout_failed', {
      clinicId,
      code: getErrorCode(error),
      message: error?.message || String(error),
    });
  }
}

// Trigger when a clinic member is created
exports.onClinicMemberCreate = functions.firestore
  .document('clinics/{clinicId}/members/{memberId}')
  .onCreate(async (snap, context) => {
    const { clinicId, memberId } = context.params;
    const data = snap.data() || {};

    logStructured('INFO', 'clinic_member_create_triggered', {
      clinicId,
      memberId,
      role: data.role,
    });

    // Ignore temp members and non-vet roles (ClinicRole: admin=0, vet=1)
    if (!memberId || memberId.startsWith('temp_')) return null;
    if (data.role !== 1) return null;

    // Fetch user profile for email
    const userDoc = await db.collection('users').doc(memberId).get();
    if (!userDoc.exists) return null;
    const email = (userDoc.get('email') || '').trim().toLowerCase();
    if (!email) return null;

    // Build inviteId same way as client
    const inviteId = email
      .replace(/@/g, '_')
      .replace(/\./g, '_')
      .replace(/\+/g, '_');
    const inviteRef = db
      .collection('clinics')
      .doc(clinicId)
      .collection('invites')
      .doc(inviteId);

    // Best-effort mark accepted then delete
    try {
      await inviteRef.set(
        {
          status: 'accepted',
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (_) {}
    try {
      await inviteRef.delete();
    } catch (_) {}

    logStructured('INFO', 'clinic_member_invite_cleanup_complete', {
      clinicId,
      memberId,
      inviteId,
    });

    return null;
  });

// ============================================================
// APPOINTMENT REQUEST NOTIFICATIONS
// ============================================================

// AppointmentRequestStatus enum indices:
// pending=0, confirmed=1, denied=2, cancelled=3

/**
 * Trigger when a new appointment request is created.
 * Notifies receptionists (and admins) at the clinic.
 */
exports.onAppointmentRequestCreated = functions.firestore
  .document('appointmentRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const { requestId } = context.params;
    const data = snap.data() || {};

    const { clinicId, petOwnerName, petName } = data;
    logStructured('INFO', 'appointment_request_created_triggered', {
      requestId,
      clinicId,
      petOwnerName,
      petName,
    });

    if (!clinicId) {
      logStructured('WARNING', 'appointment_request_created_missing_clinic', {
        requestId,
      });
      return null;
    }

    const title = 'New Appointment Request';
    const body = `${petOwnerName} requested an appointment for ${petName}`;

    await sendPushToClinicStaff(clinicId, title, body, {
      type: 'new_appointment_request',
      requestId: requestId,
      clinicId: clinicId,
    });

    logStructured(
      'INFO',
      'appointment_request_created_notification_dispatched',
      {
        requestId,
        clinicId,
      },
    );

    return null;
  });

/**
 * Trigger when an appointment request is updated.
 * Notifies the pet owner when status changes (confirmed/denied).
 */
exports.onAppointmentRequestUpdated = functions.firestore
  .document('appointmentRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const { requestId } = context.params;
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    // Only notify on status change
    if (before.status === after.status) {
      logStructured('INFO', 'appointment_request_updated_no_status_change', {
        requestId,
        status: after.status,
      });
      return null;
    }

    const { petOwnerId, petName } = after;
    const newStatus = after.status;

    if (!petOwnerId) {
      logStructured(
        'WARNING',
        'appointment_request_updated_missing_pet_owner',
        {
          requestId,
        },
      );
      return null;
    }

    let title;
    let body;
    let notificationType;

    switch (newStatus) {
      case 1: // confirmed
        title = 'Appointment Confirmed! ✓';
        body = `Your appointment request for ${petName} has been confirmed.`;
        notificationType = 'appointment_confirmed';
        break;
      case 2: // denied
        title = 'Appointment Request Update';
        body = `Your appointment request for ${petName} needs attention.`;
        notificationType = 'appointment_denied';
        break;
      default:
        // Don't notify for cancelled (status=3) or other changes
        logStructured('INFO', 'appointment_request_updated_status_no_notify', {
          requestId,
          status: newStatus,
        });
        return null;
    }

    await sendPushToUser(petOwnerId, title, body, {
      type: notificationType,
      requestId: requestId,
      status: String(newStatus),
    });

    logStructured(
      'INFO',
      'appointment_request_updated_notification_dispatched',
      {
        requestId,
        petOwnerId,
        status: newStatus,
        notificationType,
      },
    );

    return null;
  });
