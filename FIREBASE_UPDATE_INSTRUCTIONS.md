# تعليمات تحديث Firebase Cloud Functions

## المشكلة
Firebase CLI لا يعمل بشكل صحيح على هذا النظام. تحتاج لتحديث Cloud Functions يدوياً.

## الحل
1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروع `hospitalapp-681f1`
3. اذهب إلى **Functions** من القائمة الجانبية
4. ابحث عن function باسم `sendLabOrderNotification`
5. انقر على **Edit** أو **Source**
6. استبدل الكود بالكود التالي:

```javascript
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
        topic: topic,
        labId: labId,
        labName: labName,
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
```

7. انقر على **Deploy** لحفظ التغييرات

## ما تم إصلاحه
- ✅ إضافة الصوت `lab_notification` للإشعارات
- ✅ إضافة `labId` و `labName` في البيانات المرسلة
- ✅ إضافة التنقل عند الضغط على الإشعارات
- ✅ إضافة رسائل تصحيح في الكونسول

## اختبار الإشعارات
بعد التحديث، جرب:
1. إشعار `new_patient` → يجب أن يفتح `PatientsScreen` (شاشة المرضى في الكنترول)
2. إشعار `lab_order` → يجب أن يفتح `PatientsScreen` (شاشة المرضى في الكنترول)
3. إشعار `lab_order_received` → يجب أن يفتح `LabResultsPatientsScreen` (شاشة مرضى المعمل)
4. إشعار `new_lab` → يجب أن يفتح `LabToLab` (شاشة المعامل)

راقب الكونسول لرسائل التصحيح التي تبدأ بـ 🔔
