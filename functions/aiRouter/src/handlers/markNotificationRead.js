// Marks a notification as read. Notifications are created server-side by many handlers
// (offer accepted, verification decisions, SOS, fraud, charge approvals, ...) without owner
// permissions set, so marking one read needs to go through here rather than a direct client
// update — gated on the caller actually being the notification's recipient (via their real
// x-appwrite-user-id), not anything the client claims.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

module.exports = async function markNotificationRead(body, { req }) {
  const callerAuthId = req.headers?.['x-appwrite-user-id'];
  if (!callerAuthId) return { status: 401, body: { error: 'no authenticated caller' } };

  const { notificationId } = body;
  if (!notificationId) return { status: 400, body: { error: 'notificationId is required' } };

  const databases = getDatabases();
  const callerRes = await databases.listDocuments(DB_ID, 'users', [
    Query.equal('authId', callerAuthId),
    Query.limit(1),
  ]);
  const caller = callerRes.documents[0];
  if (!caller) return { status: 403, body: { error: 'caller has no users document' } };

  const notification = await databases.getDocument(DB_ID, 'notifications', notificationId).catch(() => null);
  if (!notification) return { status: 404, body: { error: 'notification not found' } };
  if (notification.userId !== caller.$id && notification.userId !== 'admin') {
    return { status: 403, body: { error: 'not the recipient of this notification' } };
  }
  // The 'admin' sentinel userId (used by SOS/fraud/chat-flag notifications) requires the
  // caller to actually be an admin, since it's not tied to one specific user document.
  if (notification.userId === 'admin' && caller.role !== 'admin') {
    return { status: 403, body: { error: 'not the recipient of this notification' } };
  }

  await databases.updateDocument(DB_ID, 'notifications', notificationId, { read: true });
  return { status: 200, body: { ok: true } };
};
