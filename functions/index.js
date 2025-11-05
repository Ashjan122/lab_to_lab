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

// Send FCM on new chat message to specific control user
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

    // Fetch control user's FCM token
    let fcmToken = '';
    try {
      if (receiverId) {
        const controlUserDoc = await admin.firestore().collection('controlUsers').doc(receiverId).get();
        if (controlUserDoc.exists) {
          fcmToken = controlUserDoc.data().fcmToken || '';
        }
      }
    } catch (e) {
      console.error('Error fetching control user FCM token:', e);
    }

    // If no FCM token found, skip sending notification
    if (!fcmToken) {
      console.log('No FCM token found for control user:', receiverId);
      return;
    }

    const title = `رسالة جديدة من ${labName}`;
    const body = message;

    console.log('Sending chat notification:', {
      title,
      body,
      senderId,
      receiverId,
      labName,
      fcmToken: fcmToken.substring(0, 20) + '...'
    });

    const fcm = {
      token: fcmToken, // Send to specific user's device
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
        action: 'open_chat_screen',
        senderId: String(senderId),
        receiverId: String(receiverId),
        labName: String(labName),
        message: String(message),
        createdAt: String(Date.now()),
      },
    };

    try {
      await admin.messaging().send(fcm);
      console.log('Chat notification sent to specific control user');
    } catch (e) {
      console.error('Error sending chat notification', e);
    }
  });