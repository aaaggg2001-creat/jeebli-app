import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
content = re.sub(r"import 'package:onesignal_flutter/onesignal_flutter\.dart';", "import 'package:firebase_messaging/firebase_messaging.dart';", content)

# 2. Top-level Config & Methods (Replace OneSignal variables and methods with FCM background handler)
fcm_handler = '''@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  // await Firebase.initializeApp(); // Assuming initialized by platform
  print("Handling a background message: \");
}'''
content = re.sub(r"// ─── OneSignal Config ──.*?Future<bool> sendOneSignalBroadcast\(\{(.*?)\}\n", fcm_handler + "\n\n", content, flags=re.DOTALL)

# 3. main() setup
content = re.sub(r"// ── تهيئة OneSignal للإشعارات حتى والتطبيق مغلق ──────────────.*?OneSignal\.Notifications\.requestPermission\(true\);", "FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);\n    await _localNotif.initialize();", content, flags=re.DOTALL)

# 4. FCM Token save
fcm_token_code = '''
  /// حفظ FCM Token في Firestore
  Future<void> _saveFCMToken(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await db.collection('fcm_tokens').doc(uid).set({
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('FCM Token error: ');
    }
  }
'''
content = re.sub(r"// ── حفظ FCM Token \+ OneSignal Player ID في Firestore ────────────────.*?_saveOneSignalPlayerIdDirect\(deviceUid, currentId\);\n\s*\}\);\n\s*\}", "// ── حفظ FCM Token ────────────────\n        _saveFCMToken(deviceUid);\n      }", content, flags=re.DOTALL)
content = re.sub(r"/// حفظ OneSignal Player ID في Firestore مع retry تلقائي.*?/// حفظ OneSignal Player ID المباشر بدون محاولات تكرار.*?debugPrint\('Direct OneSignal Player ID save error: \'\);\n\s*\}\n\s*\}", fcm_token_code, content, flags=re.DOTALL)

# 5. Remove _notifyOwnerNewOrder completely because Cloud Function handles it.
content = re.sub(r"/// ─── إرسال إشعار OneSignal لصاحب المطعم عند طلب جديد ───.*?\n  \}", "", content, flags=re.DOTALL)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
