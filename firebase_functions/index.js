/**
 * Firebase Cloud Functions - جيبلي ديلفري
 * ترسل إشعارات FCM تلقائياً لجميع الأطراف عند تغيير حالة الطلب
 *
 * كيفية الرفع:
 * 1. npm install -g firebase-tools
 * 2. firebase login
 * 3. firebase init functions (اختر مشروعك)
 * 4. انسخ هذا الكود إلى functions/index.js
 * 5. firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

async function getTokenForDevice(deviceUid) {
  if (!deviceUid) return null;
  try {
    const doc = await db.collection('fcm_tokens').doc(deviceUid).get();
    if (doc.exists) return doc.data().token || null;
  } catch (e) { console.error('Error fetching token:', e); }
  return null;
}

async function sendPush(token, title, body, data = {}) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'jeebli_orders_channel', priority: 'max' } },
      data: { route: 'orders', ...data },
    });
    console.log('✅ Push sent:', title);
  } catch (e) { console.error('Push error:', e); }
}

async function saveNotif(deviceUid, message, isWarning = false) {
  if (!deviceUid) return;
  await db.collection('notification_history').doc(deviceUid).collection('items').add({
    message, isWarning, isOwnerNotification: false, isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ── طلب جديد ─ يُشعر صاحب المطعم ──────────────────────────────────
exports.onNewOrder = functions.firestore.document('orders/{orderId}').onCreate(async (snap, ctx) => {
  const order = snap.data();
  const restDoc = await db.collection('restaurants').doc(order.restaurantId || '').get();
  if (!restDoc.exists) return;
  const ownerUid = restDoc.data().ownerDeviceUid || '';
  const token = await getTokenForDevice(ownerUid);
  const title = '🔔 طلب جديد وارد!';
  const body = ${order.customerName || 'زبون'} |  د.ع | ;
  await sendPush(token, title, body, { orderId: ctx.params.orderId });
  await saveNotif(ownerUid, title + ' ' + body);
});

// ── تغيير حالة الطلب ─ يُشعر الزبون ────────────────────────────────
exports.onOrderStatusChange = functions.firestore.document('orders/{orderId}').onUpdate(async (change) => {
  const before = change.before.data();
  const after = change.after.data();
  if (before.status === after.status) return;
  const custUid = after.deviceUid || '';
  const token = await getTokenForDevice(custUid);
  let title = '', body = '';
  switch (after.status) {
    case 'preparing': title = '👨‍🍳 المطعم قبل طلبك!'; body = 'وجبتك قيد التحضير الآن!'; break;
    case 'onTheWay':  title = '🛵 طلبك في الطريق!'; body = ${after.driverName || 'المندوب'} في الطريق إليك.; break;
    case 'delivered': title = '✅ تم التوصيل!'; body = 'ألف عافية وبالصحة والعافية ❤️'; break;
    case 'rejected':  title = '❌ تم رفض طلبك'; body = 'يمكنك تجربة مطعم آخر.'; break;
    default: return;
  }
  await sendPush(token, title, body);
  await saveNotif(custUid, title + ' ' + body, after.status === 'rejected');
});
