/* Cloud Functions to clean up clinic invites when a real vet membership is created */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

try {
  admin.initializeApp();
} catch (_) {}

const db = admin.firestore();

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
        { merge: true }
      );
    } catch (_) {}
    try {
      await inviteRef.delete();
    } catch (_) {}

    return null;
  });
