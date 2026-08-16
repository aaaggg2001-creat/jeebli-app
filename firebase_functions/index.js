/**
 * Firebase Cloud Functions - جيبلي ديلفري
 */

const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

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
    const strData = {};
    for (const [k, v] of Object.entries(data)) strData[k] = String(v);
    await messaging.send({
      token,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: { sound: 'jeebli_notification', channelId: 'jeebli_orders_v2', priority: 'max', defaultVibrateTimings: true },
      },
      data: strData,
    });
    console.log('Push sent:', title);
  } catch (e) { console.error('Push error:', e.message); }
}

async function saveNotif(deviceUid, title, message, isWarning = false, isOwner = false, orderId = '') {
  if (!deviceUid) return;
  try {
    await db.collection('notification_history').doc(deviceUid).collection('items').add({
      title, message, isWarning, isOwnerNotification: isOwner, isRead: false, orderId,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) { console.error('saveNotif error:', e); }
}

exports.onNewOrder = functions.firestore.document('orders/{orderId}').onCreate(async (snap, ctx) => {
  const order = snap.data();
  const restDoc = await db.collection('restaurants').doc(order.restaurantId || '').get();
  if (!restDoc.exists) return;
  const ownerUid = restDoc.data().ownerDeviceUid || '';
  const token = await getTokenForDevice(ownerUid);
  const title = 'طلب جديد وارد!';
  const body = (order.customerName || 'زبون') + ' | ' + (order.totalPrice || '') + ' د.ع';
  await sendPush(token, title, body, { orderId: ctx.params.orderId, route: 'owner_dashboard' });
  await saveNotif(ownerUid, title, body, false, true, ctx.params.orderId);
});

exports.onOrderStatusChange = functions.firestore.document('orders/{orderId}').onUpdate(async (change, ctx) => {
  const before = change.before.data();
  const after = change.after.data();
  if (before.status === after.status) return;
  const custUid = after.deviceUid || '';
  const token = await getTokenForDevice(custUid);
  let title = '', body = '';
  switch (after.status) {
    case 'preparing': title = 'المطعم قبل طلبك!'; body = 'وجبتك قيد التحضير الآن!'; break;
    case 'accepted':  title = 'تم قبول طلبك!'; body = 'سيبدأ المطعم بتحضير طلبك قريباً.'; break;
    case 'onTheWay':  title = 'طلبك في الطريق!'; body = (after.driverName || 'المندوب') + ' في الطريق إليك.'; break;
    case 'delivered': title = 'تم التوصيل!'; body = 'ألف عافية وبالصحة والعافية'; break;
    case 'rejected':  title = 'تم رفض طلبك'; body = 'يمكنك تجربة مطعم آخر.'; break;
    default: return;
  }
  await sendPush(token, title, body, { orderId: ctx.params.orderId, route: 'customer_dashboard' });
  await saveNotif(custUid, title, body, after.status === 'rejected', false, ctx.params.orderId);

  if (after.status === 'accepted' && before.status !== 'accepted') {
    const driversSnap = await db.collection('fcm_tokens').where('role', '==', 'driver').get();
    const dTitle = 'طلب جديد متاح للتوصيل!';
    const dBody = 'مطعم ' + (after.restaurantName || '') + ' يبحث عن مندوب.';
    const tokens = [];
    const uids = [];
    driversSnap.forEach(doc => { if (doc.data().token) { tokens.push(doc.data().token); uids.push(doc.id); } });
    if (tokens.length > 0) {
      try {
        await messaging.sendEachForMulticast({
          tokens, notification: { title: dTitle, body: dBody },
          android: { priority: 'high', notification: { sound: 'jeebli_notification', channelId: 'jeebli_orders_v2', priority: 'max' } },
          data: { orderId: ctx.params.orderId, route: 'driver_dashboard' },
        });
      } catch (e) { console.error('Driver multicast error:', e); }
      for (const uid of uids) await saveNotif(uid, dTitle, dBody, false, false, ctx.params.orderId);
    }
  }
});
