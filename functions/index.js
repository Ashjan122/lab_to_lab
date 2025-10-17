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
    const labId = data.labId || '';
    const labName = data.labName || '';
  const action = data.action || '';
  const patientDocId = data.patientDocId || '';

    const message = {
      topic,
      notification: {
        title,
        body,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel_v2',
          sound: 'lab_notification',
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
        topic: String(topic),
        labId: String(labId),
        labName: String(labName),
        action: String(action),
        patientDocId: String(patientDocId),
        createdAt: String(Date.now()),
      },
    };

    try {
      await admin.messaging().send(message);
      console.log('Notification sent to topic', topic);
    } catch (e) {
      console.error('Error sending notification', e);
    }
  });

// Send FCM on new chat message to control users
exports.sendChatNotification = functions.firestore
  .document('messages/{msgId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const senderId = data.senderId || '';
    const receiverId = data.receiverId || '';
    const message = (data.message || '').toString();

    // Fetch lab name of sender if available
    let labName = 'معمل';
    try {
      if (senderId) {
        const labDoc = await admin.firestore().collection('labToLap').doc(senderId).get();
        if (labDoc.exists) {
          labName = (labDoc.data().name || 'معمل').toString();
        }
      }
    } catch (e) {}

    const title = `رسالة جديدة من ${labName}`;
    const body = message;

    const fcm = {
      topic: 'control_chat', // all control devices listen to this
      notification: { title, body },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel_v2',
          sound: 'lab_notification',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', contentAvailable: true } },
      },
      data: {
        topic: 'control_chat',
        action: 'open_control_panel',
        senderId: String(senderId),
        receiverId: String(receiverId),
        labName: String(labName),
        message: String(message),
        createdAt: String(Date.now()),
      },
    };

    try {
      await admin.messaging().send(fcm);
      console.log('Chat notification sent');
    } catch (e) {
      console.error('Error sending chat notification', e);
    }
  });