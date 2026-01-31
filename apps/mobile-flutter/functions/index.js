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
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return false;
    }

    const fcmToken = userDoc.get('fcmToken');
    if (!fcmToken) {
      console.log(`No FCM token for user ${userId}`);
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
    console.log(`Notification sent to user ${userId}`);
    return true;
  } catch (error) {
    console.error(`Failed to send notification to user ${userId}:`, error);
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
    // Get all active receptionists in the clinic
    const membersSnap = await db
      .collection('clinics')
      .doc(clinicId)
      .collection('members')
      .where('role', '==', 2) // receptionist
      .where('isActive', '==', true)
      .get();

    if (membersSnap.empty) {
      console.log(`No active receptionists found for clinic ${clinicId}`);
      return;
    }

    const sendPromises = membersSnap.docs.map((memberDoc) =>
      sendPushToUser(memberDoc.id, title, body, data),
    );

    await Promise.all(sendPromises);
    console.log(`Notifications sent to ${membersSnap.size} receptionists`);
  } catch (error) {
    console.error('Failed to send notifications to receptionists:', error);
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
    // Get all active staff (admins and receptionists) in the clinic
    const membersSnap = await db
      .collection('clinics')
      .doc(clinicId)
      .collection('members')
      .where('isActive', '==', true)
      .get();

    if (membersSnap.empty) {
      console.log(`No active staff found for clinic ${clinicId}`);
      return;
    }

    // Filter to admins (role=0) and receptionists (role=2)
    const staffMembers = membersSnap.docs.filter((doc) => {
      const role = doc.get('role');
      return role === 0 || role === 2;
    });

    const sendPromises = staffMembers.map((memberDoc) =>
      sendPushToUser(memberDoc.id, title, body, data),
    );

    await Promise.all(sendPromises);
    console.log(`Notifications sent to ${staffMembers.length} staff members`);
  } catch (error) {
    console.error('Failed to send notifications to staff:', error);
  }
}

// Trigger when a clinic member is created
exports.onClinicMemberCreate = functions.firestore
  .document('clinics/{clinicId}/members/{memberId}')
  .onCreate(async (snap, context) => {
    const { clinicId, memberId } = context.params;
    const data = snap.data() || {};

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

    const { clinicId, petOwnerName, petName, isUrgent } = data;

    if (!clinicId) {
      console.log('No clinicId in appointment request');
      return null;
    }

    const title = isUrgent
      ? '🚨 Urgent Appointment Request'
      : 'New Appointment Request';
    const body = `${petOwnerName} requested an appointment for ${petName}`;

    await sendPushToClinicStaff(clinicId, title, body, {
      type: 'new_appointment_request',
      requestId: requestId,
      clinicId: clinicId,
    });

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
      return null;
    }

    const { petOwnerId, petName } = after;
    const newStatus = after.status;

    if (!petOwnerId) {
      console.log('No petOwnerId in appointment request');
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
        return null;
    }

    await sendPushToUser(petOwnerId, title, body, {
      type: notificationType,
      requestId: requestId,
      status: String(newStatus),
    });

    return null;
  });
