const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendLabOrderNotification = functions.firestore
  .document('push_requests/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const topic = data.topic || 'lab_order';
    const title = data.title || 'إشعار';
    const body = data.body || '';

    const message = {
      topic,
      notification: {
        title,
        body,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
      data: {
        createdAt: (Date.now()).toString(),
      },
    };

    try {
      await admin.messaging().send(message);
      console.log('Notification sent to topic', topic);
    } catch (e) {
      console.error('Error sending notification', e);
    }
  });


