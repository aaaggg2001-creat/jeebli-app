// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'super_admin_screen.dart';

// ─── OneSignal Config ──────────────────────────────────────────────────────
const String _kOneSignalAppId = '43a24efe-0d39-453f-8b14-1c3a6282c230';
const String _kOneSignalRestKey =
    'os_v2_app_iore57qnhfct7cyudq5gfawcgat657gcghhuizm565y42brttgdfspecp5gpnbgykubv6gabyz63svr6nqkvd4gk64yj4nvws5gtxba';

/// إرسال Push Notification عبر OneSignal REST API
/// يعمل حتى والتطبيق مغلق تماماً
Future<void> sendOneSignalPush({
  required String playerId,
  required String title,
  required String body,
  Map<String, String> data = const {},
}) async {
  await sendOneSignalPushWithResponse(
      playerId: playerId, title: title, body: body, data: data);
}

/// إرسال Push Notification مع إرجاع نص الاستجابة للتشخيص
Future<String> sendOneSignalPushWithResponse({
  required String playerId,
  required String title,
  required String body,
  Map<String, String> data = const {},
}) async {
  if (playerId.isEmpty) return 'empty_player_id';
  try {
    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic $_kOneSignalRestKey',
      },
      body: jsonEncode({
        'app_id': _kOneSignalAppId,
        // ✅ الطريقة الحديثة: include_subscription_ids بدلاً من include_player_ids المهمل
        'include_subscription_ids': [playerId],
        'headings': {'en': title, 'ar': title},
        'contents': {'en': body, 'ar': body},
        'priority': 10,
        'android_accent_color': 'FFFF8F00',
        'android_visibility': 1,
        'existing_android_channel_id': 'jeebli_orders_channel',
        'android_channel_id': 'jeebli_orders_channel',
        'content_available': true,
        'data': data,
      }),
    );
    debugPrint(
        'OneSignal [${response.statusCode}]: ${response.body}');
    return response.body;
  } catch (e) {
    debugPrint('OneSignal error: $e');
    return 'error: $e';
  }
}


/// ─── إرسال إشعار ترويجي لجميع مستخدمي التطبيق ────────────────────────────
Future<bool> sendOneSignalBroadcast({
  required String title,
  required String body,
}) async {
  try {
    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic $_kOneSignalRestKey',
      },
      body: jsonEncode({
        'app_id': _kOneSignalAppId,
        'included_segments': ['Subscribed Users'],
        'headings': {'en': title, 'ar': title},
        'contents': {'en': body, 'ar': body},
        'priority': 10,
        'android_accent_color': 'FFFF8F00',
        'android_visibility': 1,
        'existing_android_channel_id': 'jeebli_orders_channel',
        'android_channel_id': 'jeebli_orders_channel',
        'content_available': true,
        'data': {'screen': 'promo'},
      }),
    );
    debugPrint('📢 OneSignal Broadcast sent! Status: ${response.statusCode}');
    return response.statusCode == 200;
  } catch (e) {
    debugPrint('❌ OneSignal Broadcast error: $e');
    return false;
  }
}

/// ─── فتح تطبيق الخرائط المباشر (Belli / Uber / Google Maps) ───────────────
Future<void> openNativeMap({
  double? destLat,
  double? destLng,
  double? originLat,
  double? originLng,
}) async {
  if (destLat == null || destLng == null) return;
  final String googleMapsUrl = originLat != null && originLng != null
      ? 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving'
      : 'https://www.google.com/maps/search/?api=1&query=$destLat,$destLng';

  final Uri uri = Uri.parse(googleMapsUrl);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  } catch (_) {}

  final Uri geoUri = Uri.parse('geo:$destLat,$destLng?q=$destLat,$destLng');
  try {
    await launchUrl(geoUri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}



/// ─── خدمة الإشعارات المحلية والسحابية ──────────────────────────────────────
class JeebliNotificationService {
  static final JeebliNotificationService _instance =
      JeebliNotificationService._internal();
  factory JeebliNotificationService() => _instance;
  JeebliNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// قناة الإشعارات لأندرويد - أعلى أولوية مع صوت ووميض
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'jeebli_orders_channel',
    'إشعارات الطلبات',
    description: 'إشعارات حالة الطلبات والعروض من جيبلي',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
    enableLights: true,
    ledColor: Color(0xFFFF8F00),
  );

  Future<void> initialize() async {


    // ── تهيئة الإشعارات المحلية ───────────────────────────────────
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse res) {
        debugPrint('تم النقر على الإشعار: ${res.payload}');
      },
    );

    // إنشاء قناة الأندرويد
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);


  }

  /// حفظ FCM Token في Firestore لإرسال الإشعارات عند إغلاق التطبيق

  /// إرسال إشعار محلي يظهر فوراً مع صوت ووميض وبقاء في البردة
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
    int id = 0,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'jeebli_orders_channel',
      'إشعارات الطلبات',
      channelDescription: 'إشعارات حالة الطلبات والعروض من جيبلي',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      autoCancel: false, // يبقى في البردة حتى يمسحه المستخدم يدوياً ✅
      ongoing: false,
      color: const Color(0xFFFF8F00),
      ledColor: const Color(0xFFFF8F00),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      fullScreenIntent: true, // يوقظ الشاشة إن كانت مغلقة ✅
      ticker: title,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
      ),
    );
    final details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// إشعار محلي مباشر (للاستخدام من داخل التطبيق)
  Future<void> showOrderNotification({
    required String title,
    required String body,
    int id = 1,
  }) async {
    await _showLocalNotification(title: title, body: body, id: id);
  }
}

/// ─── Instance عالمي للخدمة ──────────────────────────────────────────────────
final jeebliNotifications = JeebliNotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── تسجيل Background handler قبل أي شيء ──────────────────────


  try {
    // الاعتماد بالكامل على google-services.json بعد تفعيل البلوجن
    await Firebase.initializeApp();

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // ── تهيئة نظام الإشعارات ──────────────────────────────────────
    await jeebliNotifications.initialize();

    // ── تهيئة OneSignal للإشعارات حتى والتطبيق مغلق ──────────────
    OneSignal.initialize(_kOneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }
  runApp(const MyApp());
}

/// زر رجوع أنيق ومميز وسهل اللمس والتفاعل
class JeebliBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;

  const JeebliBackButton({
    super.key,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        color: backgroundColor ?? context.dynamicWhite.withOpacity(0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            SystemSound.play(SystemSoundType.click);
            if (onPressed != null) {
              onPressed!();
            } else {
              Navigator.maybePop(context);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.dynamicWhite.withOpacity(0.2),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: iconColor ?? Colors.amber,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 1. النماذج (Models)
/// ============================================================================

class Restaurant {
  final String id;
  final String name;
  final String location;
  final String cuisine;
  final double rating;
  final String deliveryTime;
  final String imageUrl;
  final String description;
  final String whatsappNumber;
  bool isActive;
  bool isClosedManually;
  String serviceArea;
  double deliveryFee;
  String? ownerPhone;
  final int openHour; // 0-23
  final int closeHour; // 0-23
  double? restaurantLat; // موقع المطعم
  double? restaurantLng;
  List<String> customCategories;

  DateTime? joinedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.location,
    required this.cuisine,
    required this.rating,
    required this.deliveryTime,
    required this.imageUrl,
    required this.description,
    required this.whatsappNumber,
    this.isActive = true,
    this.isClosedManually = false,
    this.serviceArea = 'الهاشمية',
    this.deliveryFee = 1500,
    this.ownerPhone,
    this.openHour = 0,
    this.closeHour = 24,
    this.restaurantLat,
    this.restaurantLng,
    this.customCategories = const [],
  });

  bool get isOpenNow {
    if (isClosedManually) return false;
    if (openHour == closeHour || (openHour == 0 && closeHour == 24)) {
      return true; // يعمل 24 ساعة ليل ونهار
    }
    final now = DateTime.now();
    final hour = now.hour;
    if (openHour < closeHour) {
      return hour >= openHour && hour < closeHour;
    } else {
      // يعمل بعد منتصف الليل
      return hour >= openHour || hour < closeHour;
    }
  }

  String get workingHoursLabel {
    if (openHour == closeHour || (openHour == 0 && closeHour == 24)) {
      return '24 ساعة (على مدار اليوم 🌙☀️)';
    }
    String fmt(int h) {
      final period = h >= 12 ? 'م' : 'ص';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:00 $period';
    }

    return '${fmt(openHour)} - ${fmt(closeHour)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'joinedAt': joinedAt != null
          ? joinedAt!.toIso8601String()
          : FieldValue.serverTimestamp(),
      'id': id,
      'name': name,
      'location': location,
      'cuisine': cuisine,
      'rating': rating,
      'deliveryTime': deliveryTime,
      'imageUrl': imageUrl,
      'description': description,
      'whatsappNumber': whatsappNumber,
      'isActive': isActive,
      'isClosedManually': isClosedManually,
      'serviceArea': serviceArea,
      'deliveryFee': deliveryFee,
      'ownerPhone': ownerPhone,
      'openHour': openHour,
      'closeHour': closeHour,
      'restaurantLat': restaurantLat,
      'restaurantLng': restaurantLng,
      'customCategories': customCategories,
    };
  }

  factory Restaurant.fromMap(Map<String, dynamic> map, String docId) {
    return Restaurant(
        id: map['id'] ?? docId,
        name: map['name'] ?? '',
        location: map['location'] ?? '',
        cuisine: map['cuisine'] ?? '',
        rating: (map['rating'] ?? 4.5).toDouble(),
        deliveryTime: map['deliveryTime'] ?? '20-30 دقيقة',
        imageUrl: map['imageUrl'] ?? '',
        description: map['description'] ?? '',
        whatsappNumber: map['whatsappNumber'] ?? '',
        isActive: map['isActive'] ?? true,
        isClosedManually: map['isClosedManually'] ?? false,
        serviceArea: map['serviceArea'] ?? 'الهاشمية',
        deliveryFee: (map['deliveryFee'] ?? 1500).toDouble(),
        ownerPhone: map['ownerPhone'],
        openHour: map['openHour'] ?? 0,
        closeHour: map['closeHour'] ?? 24,
        restaurantLat: map['restaurantLat'] != null
            ? (map['restaurantLat'] as num).toDouble()
            : null,
        restaurantLng: map['restaurantLng'] != null
            ? (map['restaurantLng'] as num).toDouble()
            : null,
        customCategories: (map['customCategories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      )
      ..joinedAt = map['joinedAt'] != null
          ? (map['joinedAt'] is Timestamp
                ? (map['joinedAt'] as Timestamp).toDate()
                : DateTime.tryParse(map['joinedAt'].toString()))
          : null;
  }

  /// حساب المسافة بالكيلومتر بين المطعم والزبون
  double? distanceTo(double? lat, double? lng) {
    if (restaurantLat == null ||
        restaurantLng == null ||
        lat == null ||
        lng == null)
      return null;
    const R = 6371.0;
    final dLat = _toRad(lat - restaurantLat!);
    final dLng = _toRad(lng - restaurantLng!);
    final a =
        _sin2(dLat / 2) +
        cos(_toRad(restaurantLat!)) * cos(_toRad(lat)) * _sin2(dLng / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
  static double _sin2(double x) => sin(x) * sin(x);
}

class Product {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String imageUrl;
  final String categoryId;
  bool isAvailable;

  Product({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.imageUrl,
    required this.categoryId,
    this.isAvailable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'isAvailable': isAvailable,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String docId) {
    return Product(
      id: map['id'] ?? docId,
      restaurantId: map['restaurantId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      discountPrice: map['discountPrice'] != null
          ? (map['discountPrice'] as num).toDouble()
          : null,
      imageUrl: map['imageUrl'] ?? '',
      categoryId: map['categoryId'] ?? 'all',
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Product copyWith({
    String? name,
    String? description,
    double? price,
    double? discountPrice,
    String? imageUrl,
    String? categoryId,
    bool? isAvailable,
    bool clearDiscount = false,
  }) {
    return Product(
      id: id,
      restaurantId: restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountPrice: clearDiscount
          ? null
          : (discountPrice ?? this.discountPrice),
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
  double get totalPrice => (product.discountPrice ?? product.price) * quantity;

  Map<String, dynamic> toMap() {
    return {'product': product.toMap(), 'quantity': quantity};
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product.fromMap(
        map['product'] as Map<String, dynamic>,
        map['product']['id'] ?? '',
      ),
      quantity: map['quantity'] ?? 1,
    );
  }
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  Category({required this.id, required this.name, required this.icon});
}

class PastOrder {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final List<CartItem> items;
  final double totalAmount;
  final DateTime date;

  PastOrder({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.totalAmount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
    };
  }

  factory PastOrder.fromMap(Map<String, dynamic> map) {
    return PastOrder(
      id: map['id'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((i) => CartItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LoyaltyEntry {
  final int points;
  final String reason;
  final DateTime date;
  LoyaltyEntry({
    required this.points,
    required this.reason,
    required this.date,
  });
}

/// تنسيق رقم الهاتف ليناسب الواتساب بشكل دقيق وبدون خطأ (07/964/+964)
String formatWhatsAppNumber(String rawPhone) {
  var cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.startsWith('+')) {
    cleaned = cleaned.substring(1);
  }
  if (cleaned.startsWith('07')) {
    cleaned = '964${cleaned.substring(1)}';
  } else if (cleaned.startsWith('7') && cleaned.length == 10) {
    cleaned = '964$cleaned';
  } else if (!cleaned.startsWith('964') && cleaned.length == 10) {
    cleaned = '964$cleaned';
  }
  return cleaned;
}

class Offer {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String title;
  final String description;
  final String discountTag; // مثال: "خصم 25%" / "عرض عائلي" / "توصيل مجاني"
  final String imageUrl;
  final String? promoCode;
  bool isActive;

  Offer({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.title,
    required this.description,
    required this.discountTag,
    required this.imageUrl,
    this.promoCode,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'title': title,
      'description': description,
      'discountTag': discountTag,
      'imageUrl': imageUrl,
      'promoCode': promoCode,
      'isActive': isActive,
    };
  }

  factory Offer.fromMap(Map<String, dynamic> map, String docId) {
    return Offer(
      id: map['id'] ?? docId,
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      discountTag: map['discountTag'] ?? 'عرض خاص',
      imageUrl: map['imageUrl'] ?? '',
      promoCode: map['promoCode'],
      isActive: map['isActive'] ?? true,
    );
  }
}

/// ============================================================================
/// 2. نظام حماية الطلبات (Security & Anti-Hacking Simulator)
/// ============================================================================

class SecurityEngine {
  static final Map<String, List<DateTime>> _requestLog = {};
  static const int _maxRequests = 5;
  static const Duration _window = Duration(minutes: 1);

  static bool checkRateLimit(String userId) {
    final now = DateTime.now();
    final logs = _requestLog[userId] ?? [];
    logs.removeWhere((t) => now.difference(t) > _window);
    if (logs.length >= _maxRequests) return false;
    logs.add(now);
    _requestLog[userId] = logs;
    return true;
  }

  static String encryptOrderData(Map<String, dynamic> orderData) {
    final jsonStr = jsonEncode(orderData);
    int hash = 0;
    for (var rune in jsonStr.runes) {
      hash = ((hash << 5) - hash) + rune;
      hash &= hash;
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'JEEBLI-SEC-${timestamp.toRadixString(16).toUpperCase()}-${hash.abs().toRadixString(16).toUpperCase()}';
  }

  static bool verifyOrderIntegrity(List<CartItem> items, double claimedTotal) {
    double calculated = items.fold(0, (s, i) => s + i.totalPrice);
    return (claimedTotal - calculated).abs() < 0.01;
  }
}

/// ============================================================================
/// 3. إدارة الحالة (State Management)
/// ============================================================================

enum OrderStatus { idle, confirmed, preparing, onWay, arrived, rated }

/// حالات الطلب في Firestore (تُخزَّن كـ string)
/// pending → accepted/preparing → onTheWay → delivered → rejected
enum PaymentMethod { cod, mastercard }

extension ColorExtension on BuildContext {
  Color get dynamicWhite => Theme.of(this).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
  Color get dynamicWhite70 => Theme.of(this).brightness == Brightness.dark
      ? Colors.white70
      : Colors.black87;
}

class JeebliController extends ChangeNotifier {
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// ═══ مؤشر تحميل الجلسة — يمنع عرض الشاشات قبل قراءة SharedPreferences ═══
  bool _isSessionLoading = true;
  bool get isSessionLoading => _isSessionLoading;

  StreamSubscription? _connectivitySubscription;

  JeebliController() {
    _initConnectivity();
    _loadLocalData().then((_) {
      _initFirebaseSync();
      _loadSavedSession(); // ستضع _isSessionLoading = false عند الانتهاء
    });
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      bool isConnected = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (_isOffline == isConnected) {
        _isOffline = !isConnected;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _deliveryTimer?.cancel();
    super.dispose();
  }

  void _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── تحميل/إنشاء معرّف الجهاز الفريد ─────────────────────────
      String? savedUid = prefs.getString('device_uid');
      if (savedUid == null || savedUid.isEmpty) {
        savedUid = const Uuid().v4();
        await prefs.setString('device_uid', savedUid);
      }
      deviceUid = savedUid;

      // ── تحميل بيانات الجلسة والملف الشخصي دائماً وبدون شروط ───────
      customerName = prefs.getString('customer_name') ?? '';
      customerPhone = prefs.getString('customer_phone') ?? '';
      customerAvatarUrl = prefs.getString('customer_avatar_url') ?? '';
      selectedNeighborhood = prefs.getString('selected_neighborhood') ?? '';
      streetDetails = prefs.getString('street_details') ?? '';
      _userEmailOrPhone = prefs.getString('user_email_or_phone');
      _userRestaurantId = prefs.getString('user_restaurant_id');
      _userRole = prefs.getString('user_role');

      final loggedIn = prefs.getBool('is_logged_in') ?? false;

      // إذا كان مسجلاً دخول مسبقاً أو لديه اسم ورقم هاتف محفوظان → اعتبره زبوناً مسجلاً تلقائياً
      if (loggedIn || customerName.isNotEmpty || customerPhone.isNotEmpty) {
        _isLoggedIn = true;
        _userRole ??= 'customer';
      }

      // ── استعادة معرّف الطلب النشط ──────────────────────────────
      final savedOrderId = prefs.getString('active_order_id');
      if (savedOrderId != null && savedOrderId.isNotEmpty) {
        activeOrderId = savedOrderId;
      }
      unreadNotifications = prefs.getInt('unread_notifications') ?? 0;

      // بمجرد تحميل المعرف، نجلب الطلبات النشطة للاستماع لها فوراً
      _recoverActiveOrders();

      // ── حفظ FCM Token + OneSignal Player ID في Firestore ────────────────
      if (deviceUid.isNotEmpty) {
//         jeebliNotifications.saveFcmTokenToFirestore(deviceUid);
        // حفظ OneSignal Player ID لإرسال الإشعارات حتى والتطبيق مغلق
        _saveOneSignalPlayerId(deviceUid);
      }
    } catch (e) {
      debugPrint('Session load note: $e');
    } finally {
      // ✅ انتهى التحميل — أعلم الـ UI ليعرض الشاشة الصحيحة
      _isSessionLoading = false;
      notifyListeners();
    }
  }

  /// حفظ OneSignal Player ID في Firestore مع retry تلقائي
  Future<void> _saveOneSignalPlayerId(String uid) async {
    if (uid.isEmpty) return;
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        // انتظر قليلاً لكي يكتمل تهيئة OneSignal SDK
        await Future.delayed(Duration(seconds: attempt == 0 ? 3 : 5));
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId == null || playerId.isEmpty) {
          debugPrint('OneSignal not ready (attempt ${attempt + 1}/6)');
          continue;
        }
        final db = FirebaseFirestore.instance;
        // حفظ تحت معرّف الجهاز (لجميع الأدوار)
        await db.collection('onesignal_players').doc(uid).set({
          'playerId': playerId,
          'role': _userRole ?? 'customer',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // إذا كان مالك مطعم: احفظ أيضاً في وثيقة المطعم مباشرةً
        if (_userRole == 'owner' &&
            _userRestaurantId != null &&
            _userRestaurantId!.isNotEmpty) {
          await db.collection('restaurants').doc(_userRestaurantId!).set({
            'ownerDeviceUid': uid,
            'ownerPlayerId': playerId,
          }, SetOptions(merge: true));
          debugPrint('Owner PlayerId saved in restaurant doc: $playerId');
        }
        debugPrint('OneSignal Player ID saved OK: $playerId');
        return; // نجح
      } catch (e) {
        debugPrint('OneSignal save attempt ${attempt + 1} error: $e');
      }
    }
  }


  void saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_uid', deviceUid);
      await prefs.setBool('is_logged_in', _isLoggedIn);
      if (_userRole != null) await prefs.setString('user_role', _userRole!);
      await prefs.setString('customer_name', customerName);
      await prefs.setString('customer_phone', customerPhone);
      await prefs.setString('customer_avatar_url', customerAvatarUrl);
      // بيانات التوصيل
      await prefs.setString('selected_neighborhood', selectedNeighborhood);
      await prefs.setString('street_details', streetDetails);
      if (_userRestaurantId != null)
        await prefs.setString('user_restaurant_id', _userRestaurantId!);
      if (_userEmailOrPhone != null)
        await prefs.setString('user_email_or_phone', _userEmailOrPhone!);
      // ── حفظ معرّف الطلب النشط ────────────────────────────────────
      if (activeOrderId != null && activeOrderId!.isNotEmpty) {
        await prefs.setString('active_order_id', activeOrderId!);
      } else {
        await prefs.remove('active_order_id');
      }
      await prefs.setInt('unread_notifications', unreadNotifications);
    } catch (e) {
      debugPrint('Session save note: $e');
    }
  }

  void logout() async {
    _deliveryTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all
      // Reset all state variables
      customerName = '';
      customerPhone = '';
      customerAvatarUrl = '';
      selectedNeighborhood = '';
      streetDetails = '';
      _cartItems.clear();
      pastOrders.clear();
      notifications.clear();
      unreadNotifications = 0;
      activeOrderId = null;
      deviceUid = ''; // It will be recreated on next load
      _isLoggedIn = false;
      _userRole = null;
      _userEmailOrPhone = null;
      _userRestaurantId = null;
      _activeRestaurant = null;
      _currentTab = 0;
      _playClickFeedback();
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  // ─── حفظ وتحميل البيانات محلياً ───────────────────────────────────────
  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restsJson = _restaurants.map((r) => jsonEncode(r.toMap())).toList();
      await prefs.setStringList('local_restaurants', restsJson);
      final prodsJson = _products.map((p) => jsonEncode(p.toMap())).toList();
      await prefs.setStringList('local_products', prodsJson);
      final offersJson = _offers.map((o) => jsonEncode(o.toMap())).toList();
      await prefs.setStringList('local_offers', offersJson);
      final pastOrdersJson = pastOrders
          .map((o) => jsonEncode(o.toMap()))
          .toList();
      await prefs.setStringList('local_past_orders', pastOrdersJson);
      final notificationsJson = notifications
          .map((n) => jsonEncode(n.toMap()))
          .toList();
      await prefs.setStringList('local_notifications', notificationsJson);
    } catch (e) {
      debugPrint('Local save note: $e');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restsJson = prefs.getStringList('local_restaurants') ?? [];
      if (restsJson.isNotEmpty) {
        _restaurants.clear();
        for (var j in restsJson) {
          final map = jsonDecode(j) as Map<String, dynamic>;
          _restaurants.add(Restaurant.fromMap(map, map['id'] ?? ''));
        }
      } else {
        _saveLocalData();
      }
      final prodsJson = prefs.getStringList('local_products') ?? [];
      if (prodsJson.isNotEmpty) {
        _products.clear();
        for (var j in prodsJson) {
          final map = jsonDecode(j) as Map<String, dynamic>;
          _products.add(Product.fromMap(map, map['id'] ?? ''));
        }
      } else {
        _saveLocalData();
      }
      final offersJson = prefs.getStringList('local_offers') ?? [];
      if (offersJson.isNotEmpty) {
        _offers.clear();
        for (var j in offersJson) {
          final map = jsonDecode(j) as Map<String, dynamic>;
          _offers.add(Offer.fromMap(map, map['id'] ?? ''));
        }
      } else {
        _saveLocalData();
      }
      final pastOrdersJson = prefs.getStringList('local_past_orders') ?? [];
      if (pastOrdersJson.isNotEmpty) {
        pastOrders.clear();
        for (var j in pastOrdersJson) {
          final map = jsonDecode(j) as Map<String, dynamic>;
          pastOrders.add(PastOrder.fromMap(map));
        }
      }
      final notificationsJson =
          prefs.getStringList('local_notifications') ?? [];
      if (notificationsJson.isNotEmpty) {
        notifications.clear();
        for (var j in notificationsJson) {
          final map = jsonDecode(j) as Map<String, dynamic>;
          notifications.add(AppNotification.fromMap(map));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Local load note: $e');
    }
  }

  void _initFirebaseSync() {
    try {
      final firestore = FirebaseFirestore.instance;

      // ═══ مزامنة المطاعم - استبدال كامل للبيانات من Firestore ═══
      firestore.collection('restaurants').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // استبدال البيانات من Firestore (الحقيقة المركزية)
          // نحتفظ فقط بالمطاعم الافتراضية المضمّنة إذا لم تكن في Firestore
          final firestoreIds = snapshot.docs.map((d) => d.id).toSet();
          // احذف المطاعم المحذوفة من Firestore
          _restaurants.removeWhere(
            (r) =>
                firestoreIds.contains(r.id) == false &&
                snapshot.docs.isNotEmpty,
          );
          // أضف أو حدّث من Firestore
          for (var doc in snapshot.docs) {
            final r = Restaurant.fromMap(doc.data(), doc.id);
            final idx = _restaurants.indexWhere((item) => item.id == r.id);
            if (idx >= 0) {
              _restaurants[idx] = r;
            } else {
              _restaurants.add(r);
            }
          }
          _saveLocalData();
          notifyListeners();
        } else {
          // Firestore فارغة: ارفع المطاعم الافتراضية إلى Firestore لتصبح متاحة لجميع الأجهزة
          for (final rest in _restaurants) {
            firestore.collection('restaurants').doc(rest.id).set(rest.toMap());
          }
          // أيضاً ارفع المنتجات الافتراضية
          for (final prod in _products) {
            firestore.collection('products').doc(prod.id).set(prod.toMap());
          }
          // ارفع العروض الافتراضية
          for (final offer in _offers) {
            firestore.collection('offers').doc(offer.id).set(offer.toMap());
          }
        }
      }, onError: (e) => debugPrint('Firestore restaurants sync note: $e'));

      // ═══ مزامنة المنتجات ═══
      firestore.collection('products').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final firestoreIds = snapshot.docs.map((d) => d.id).toSet();
          _products.removeWhere((p) => !firestoreIds.contains(p.id));
          for (var doc in snapshot.docs) {
            final p = Product.fromMap(doc.data(), doc.id);
            final idx = _products.indexWhere((item) => item.id == p.id);
            if (idx >= 0) {
              _products[idx] = p;
            } else {
              _products.add(p);
            }
          }
          _saveLocalData();
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Firestore products sync note: $e'));

      bool isFirstOffersLoad = true;
      // ═══ مزامنة العروض ═══
      firestore.collection('offers').snapshots().listen((snapshot) {
        final firestoreIds = snapshot.docs.map((d) => d.id).toSet();
        _offers.removeWhere((o) => !firestoreIds.contains(o.id));

        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added && !isFirstOffersLoad) {
            final o = Offer.fromMap(
              change.doc.data() as Map<String, dynamic>,
              change.doc.id,
            );
            if (o.isActive) {
              _addNotification(
                '🎉 عرض جديد من ${o.restaurantName}: ${o.title} - ${o.discountTag}',
              );
              jeebliNotifications.showOrderNotification(
                id: o.id.hashCode,
                title: 'عرض جديد من ${o.restaurantName}!',
                body: '${o.title} - ${o.discountTag}',
              );
            }
          }
        }

        for (var doc in snapshot.docs) {
          final o = Offer.fromMap(doc.data(), doc.id);
          final idx = _offers.indexWhere((item) => item.id == o.id);
          if (idx >= 0) {
            _offers[idx] = o;
          } else {
            _offers.add(o);
          }
        }

        isFirstOffersLoad = false;
        _saveLocalData();
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore offers sync note: $e'));

      // ═══ مزامنة إعدادات التطبيق (نظام النقاط) ═══
      firestore.collection('app_settings').doc('loyalty').snapshots().listen((
        doc,
      ) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _loyaltySystemEnabled = data['enabled'] as bool? ?? false;
          _adminPointsPerOrder = (data['pointsPerOrder'] as int?) ?? 10;
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Firestore app_settings sync note: $e'));
    } catch (e) {
      debugPrint('Firestore sync init note: $e');
    }
  }

  // --- قوائم البيانات ---
  final List<Restaurant> _restaurants = [
    Restaurant(
      id: 'akkala',
      name: 'مطعم أكّالة للوجبات السريعة',
      location: 'قضاء الهاشمية، بابل',
      cuisine: 'برجر • زنجر • بيتزا • شاورما',
      rating: 4.8,
      deliveryTime: '20-30 دقيقة',
      description: 'أقوى مطعم برجر في الهاشمية، نكهة لا تقاوم وتوصيل فوري!',
      whatsappNumber: '07802019730',
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
      ownerPhone: '07802019730',
      deliveryFee: 1500,
      openHour: 0,
      closeHour: 24,
    ),
    Restaurant(
      id: 'abualabd',
      name: 'مطعم أبو العبد الشهير',
      location: 'مدينة الحمزة الغربي، بابل',
      cuisine: 'شاورما • زنجر • بيتزا عائلية • فنجر',
      rating: 4.9,
      deliveryTime: '25-35 دقيقة',
      description:
          'معلم الوجبات السريعة في الحمزة، خلطات سرية مميزة وشاورما الفحم.',
      whatsappNumber: '07800108275',
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80',
      ownerPhone: '07800108275',
      deliveryFee: 1500,
      openHour: 0,
      closeHour: 24,
    ),
  ];

  final List<Product> _products = [
    Product(
      id: 'ak1',
      restaurantId: 'akkala',
      name: 'برجر لحم دبل جبن كلاسيك',
      description: 'شريحتين لحم مشوي مع الجبن السائل والصلصة السرية',
      price: 6000,
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
      categoryId: 'burger',
    ),
    Product(
      id: 'ak2',
      restaurantId: 'akkala',
      name: 'وجبة زنجر سبايسي عملاق',
      description: 'صدر دجاج مقرمش حار مع الجبنة والبطاطس',
      price: 5500,
      imageUrl:
          'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=400&q=80',
      categoryId: 'zinger',
    ),
    Product(
      id: 'ak3',
      restaurantId: 'akkala',
      name: 'بيتزا إيطالية وسط',
      description: 'عجينة رقيقة بصلصة الطماطم وجبن الموزاريلا',
      price: 8000,
      imageUrl:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
      categoryId: 'pizza',
      isAvailable: false,
    ),
    Product(
      id: 'ak4',
      restaurantId: 'akkala',
      name: 'شاورما لحم عراقية بالصاج',
      description: 'قص لحم متبل ملفوف بخبز الصاج مع ثومية ومخلل',
      price: 4500,
      imageUrl:
          'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=400&q=80',
      categoryId: 'shawarma',
    ),
    Product(
      id: 'ak5',
      restaurantId: 'akkala',
      name: 'فنجر بطاطس عائلي بالبهارات',
      description: 'بطاطس ذهبية مع بهارات البابريكا والكاتشب',
      price: 2500,
      imageUrl:
          'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&q=80',
      categoryId: 'fries',
    ),
    Product(
      id: 'aa1',
      restaurantId: 'abualabd',
      name: 'برجر دجاج كريسبي بالجبن',
      description: 'صدر دجاج مقرمش ذهبي مع الجبنة والمايونيز المدخن',
      price: 5000,
      imageUrl:
          'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=400&q=80',
      categoryId: 'burger',
    ),
    Product(
      id: 'aa2',
      restaurantId: 'abualabd',
      name: 'صاج زنجر ملكي أبو العبد',
      description: 'قطع زنجر حارة بخبز الصاج العراقي مع الجبن السائل',
      price: 6000,
      imageUrl:
          'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=400&q=80',
      categoryId: 'zinger',
    ),
    Product(
      id: 'aa3',
      restaurantId: 'abualabd',
      name: 'شاورما دجاج بالفرن',
      description: 'قص دجاج مشوي متبل لبناني مع صوص الثوم',
      price: 4000,
      imageUrl:
          'https://images.unsplash.com/photo-1561651823-34fed0225408?w=400&q=80',
      categoryId: 'shawarma',
      isAvailable: false,
    ),
    Product(
      id: 'aa4',
      restaurantId: 'abualabd',
      name: 'بيتزا لحم بابلية كبير',
      description: 'عجينة هشة بقطع اللحم المفروم وموزاريلا كثيفة',
      price: 10000,
      imageUrl:
          'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=400&q=80',
      categoryId: 'pizza',
    ),
    Product(
      id: 'aa5',
      restaurantId: 'abualabd',
      name: 'فنجر غرقان بالجبن الساخن',
      description: 'أصابع بطاطس مقرمشة بجبنة شيدر ذائبة وهالبينو',
      price: 3500,
      imageUrl:
          'https://images.unsplash.com/photo-1585109649139-366815a0d713?w=400&q=80',
      categoryId: 'fries',
    ),
  ];

  // --- Theme State ---
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  Color get bgColor =>
      _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get cardColor => _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get subtextColor =>
      _isDarkMode ? Colors.white70 : const Color(0xFF475569);
  Color get borderColor => _isDarkMode
      ? Colors.white.withOpacity(0.05)
      : Colors.black.withOpacity(0.08);

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    playFeedbackSound();
    notifyListeners();
  }

  // --- State fields ---
  int _currentTab = 0;
  String _selectedCategoryId = 'all';
  Restaurant? _activeRestaurant;

  bool _isLoggedIn = false;
  String? _userRole;
  String? _userEmailOrPhone;
  String? _userRestaurantId;

  String deviceUid = '';
  String customerName = '';
  String customerPhone = '';
  String selectedNeighborhood = '';
  String customerAvatarUrl = '';
  String streetDetails = '';
  String orderNotes = '';
  String? activeOrderId; // معرّف الطلب النشط للزبون لمتابعته حياً
  StreamSubscription<DocumentSnapshot>?
  _activeOrderSubscription; // مستمع الطلب النشط
  String? _lastKnownOrderStatus; // لمنع تكرار الإشعارات عند فتح التطبيق
  bool isLocating = false;
  double? customerLat;
  double? customerLng;

  /// ═══ إرسال إشعار OneSignal لصاحب المطعم عند طلب جديد ═══
  Future<void> _notifyOwnerNewOrder({
    required String restaurantId,
    required String customerName,
    required double totalAmount,
    required String orderId,
  }) async {
    try {
      if (restaurantId.isEmpty) return;
      final restDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      if (!restDoc.exists) return;

      // المسار الأول: ownerPlayerId محفوظ مباشرة في وثيقة المطعم
      String playerId = restDoc.data()?['ownerPlayerId'] as String? ?? '';
      String ownerDeviceUid = restDoc.data()?['ownerDeviceUid'] as String? ?? '';

      // المسار الثاني: البحث عبر ownerDeviceUid → onesignal_players
      if (playerId.isEmpty && ownerDeviceUid.isNotEmpty) {
        final playerDoc = await FirebaseFirestore.instance
            .collection('onesignal_players')
            .doc(ownerDeviceUid)
            .get();
        playerId = playerDoc.data()?['playerId'] as String? ?? '';
      }

      final title = '🔔 طلب جديد!';
      final body = '$customerName طلب بمبلغ ${totalAmount.toStringAsFixed(0)} IQD';

      if (playerId.isNotEmpty) {
        final result = await sendOneSignalPushWithResponse(
          playerId: playerId,
          title: title,
          body: body,
          data: {'orderId': orderId, 'screen': 'orders'},
        );
        debugPrint('Notify owner result: $result');
      } else {
        debugPrint('Owner playerId not found for: $restaurantId');
      }

      // ✅ حفظ الإشعار في سجل الإشعارات الدائم لصاحب المطعم حتى يراه عند فتح التطبيق
      if (ownerDeviceUid.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('notification_history')
            .doc(ownerDeviceUid)
            .collection('items')
            .add({
              'message': '🛒 $body',
              'isWarning': false,
              'isOwnerNotification': true,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'orderId': orderId,
            })
            .catchError((e) {
              debugPrint('Owner notif save error: $e');
              throw e;
            });
      }
    } catch (e) {
      debugPrint('Notify owner error: $e');
    }
  }


  /// ═══ إرسال إشعار OneSignal للزبون عند تغيير حالة طلبه ═══
  Future<void> _notifyCustomer({
    required String custDeviceUid,
    required String title,
    required String body,
    required String orderId,
  }) async {
    try {
      if (custDeviceUid.isEmpty) return;

      // إرسال إشعار Push عبر OneSignal (يصل حتى عند إغلاق التطبيق)
      final playerDoc = await FirebaseFirestore.instance
          .collection('onesignal_players')
          .doc(custDeviceUid)
          .get();
      final playerId = playerDoc.data()?['playerId'] ?? '';
      if (playerId.isNotEmpty) {
        await sendOneSignalPush(
          playerId: playerId,
          title: title,
          body: body,
          data: {'orderId': orderId, 'screen': 'track'},
        );
      }

      // ✅ حفظ الإشعار في سجل الإشعارات الدائم للزبون (يظهر في نافذة الإشعارات)
      FirebaseFirestore.instance
          .collection('notification_history')
          .doc(custDeviceUid)
          .collection('items')
          .add({
            'message': '$title\n$body',
            'isWarning': false,
            'isOwnerNotification': false,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'orderId': orderId,
          })
          .catchError((e) {
            debugPrint('Customer notif save error: $e');
            throw e;
          });
    } catch (e) {
      debugPrint('Notify customer error: $e');
    }
  }

  /// ═══ إرسال إشعار لجميع المندوبين المسجلين في مطعم معين ═══
  Future<void> _notifyAllDrivers({
    required String restaurantId,
    required String title,
    required String body,
    required String orderId,
  }) async {
    try {
      // جلب جميع المندوبين الخاصين بهذا المطعم
      final driversSnap = await FirebaseFirestore.instance
          .collection('admin_credentials')
          .where('role', isEqualTo: 'driver')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      for (final driverDoc in driversSnap.docs) {
        final driverDeviceUid =
            driverDoc.data()['deviceUid']?.toString() ?? '';
        if (driverDeviceUid.isEmpty) continue;

        final playerDoc = await FirebaseFirestore.instance
            .collection('onesignal_players')
            .doc(driverDeviceUid)
            .get();
        final playerId = playerDoc.data()?['playerId'] ?? '';

        // إرسال Push إذا كان لديه playerId
        if (playerId.isNotEmpty) {
          await sendOneSignalPush(
            playerId: playerId,
            title: title,
            body: body,
            data: {'orderId': orderId, 'screen': 'driver_dashboard'},
          );
        }

        // ✅ دائماً احفظ الإشعار في سجل المندوب الدائم
        FirebaseFirestore.instance
            .collection('notification_history')
            .doc(driverDeviceUid)
            .collection('items')
            .add({
              'message': '$title\n$body',
              'isWarning': false,
              'isOwnerNotification': false,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'orderId': orderId,
            })
            .catchError((e) {
              debugPrint('Driver notif save error: $e');
              throw e;
            });
      }
      debugPrint('✅ Notified all drivers for restaurant: $restaurantId');
    } catch (e) {
      debugPrint('Notify all drivers error: $e');
    }
  }

  /// ═══ المستمع الذكي للزبون - يرصد تغيرات حالة طلبه فوراً ويرسل إشعاراً خاصاً به ═══
  void startCustomerOrderListener(String orderId) {
    _activeOrderSubscription?.cancel();
    _lastKnownOrderStatus = null;
    activeOrderId = orderId;
    _activeOrderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) return;
          final data = doc.data() as Map<String, dynamic>;
          final newStatus = data['status'] as String? ?? 'pending';
          if (newStatus == _lastKnownOrderStatus) return; // لا تحديث
          final prevStatus = _lastKnownOrderStatus;
          _lastKnownOrderStatus = newStatus;
          if (prevStatus == null)
            return; // تجاهل أول قراءة عند الفتح لمنع الإشعار المكرر
          // ═══ إرسال الإشعار للزبون حسب الحالة الجديدة ═══
          String title = '';
          String body = '';
          switch (newStatus) {
            case 'preparing':
              title = '👨‍🍳 قبل المطعم طلبك!';
              body = 'مطعمك بدأ بتحضير وجبتك الآن. استعد!';
              break;
            case 'onTheWay':
              final driverName = data['driverName'] ?? '';
              title = '🛵 طلبك قادم إليك!';
              body = driverName.isNotEmpty
                  ? 'المندوب $driverName استلم وجبتك وهو في الطريق إليك!'
                  : 'المندوب استلم وجبتك وهو في الطريق إليك!';
              break;
            case 'delivered':
              title = '✅ تم استلام طلبك!';
              body = 'تم توصيل وجبتك بنجاح. ألف صحة وعافية ❤️';
              _stopCustomerOrderListener();
              // لا نزيل activeOrderId فوراً ليراه الزبون في شريط الحالة حتى يغلقه بنفسه
              break;
            case 'rejected':
              title = '❌ تم رفض طلبك';
              body = 'نأسف، قام المطعم برفض طلبك. يمكنك تجربة مطعم آخر.';
              _stopCustomerOrderListener();
              // لا نزيل activeOrderId فوراً ليراه الزبون
              break;
            default:
              return;
          }
          _addNotification('$title $body');
          jeebliNotifications.showOrderNotification(
            id: orderId.hashCode,
            title: title,
            body: body,
          );
          notifyListeners();
        }, onError: (e) => debugPrint('Order listener error: $e'));
  }

  void _stopCustomerOrderListener() {
    _activeOrderSubscription?.cancel();
    _activeOrderSubscription = null;
  }

  void clearActiveOrder() {
    activeOrderId = null;
    saveSession();
    notifyListeners();
  }

  void _recoverActiveOrders() async {
    if (deviceUid.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('deviceUid', isEqualTo: deviceUid)
          .get();
      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (status == 'pending' ||
            status == 'preparing' ||
            status == 'onTheWay') {
          startCustomerOrderListener(doc.id);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error recovering active order: $e');
    }
  }

  Future<bool> detectLocation() async {
    isLocating = true;
    notifyListeners();
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        isLocating = false;
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          isLocating = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        isLocating = false;
        notifyListeners();
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      customerLat = position.latitude;
      customerLng = position.longitude;
      isLocating = false;
      playFeedbackSound();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Location detection note: $e');
      isLocating = false;
      notifyListeners();
      return false;
    }
  }

  PaymentMethod paymentMethod = PaymentMethod.cod;
  String cardNumber = '';
  String cardExpiry = '';
  String cardCvv = '';

  double get deliveryFee => _activeRestaurant?.deliveryFee ?? 1500.0;

  OrderStatus _orderStatus = OrderStatus.idle;
  List<AppNotification> notifications = [];
  int unreadNotifications = 0;

  void clearNotifications() {
    notifications.clear();
    unreadNotifications = 0;
    notifyListeners();
  }

  double restaurantRating = 0;
  double driverRating = 0;
  String feedbackText = '';
  String _lastOrderToken = '';

  Timer? _deliveryTimer;
  int _deliveryCountdown = 0;

  final String driverName = 'أحمد المحمداوي';
  final String driverPhone = '07801234567';

  // --- Favorites State ---
  final Set<String> _favoriteProductIds = {};
  final Set<String> _favoriteRestaurantIds = {};

  Set<String> get favoriteProductIds => _favoriteProductIds;
  Set<String> get favoriteRestaurantIds => _favoriteRestaurantIds;

  bool isProductFavorite(String id) => _favoriteProductIds.contains(id);
  bool isRestaurantFavorite(String id) => _favoriteRestaurantIds.contains(id);

  void toggleFavoriteProduct(String id) {
    if (_favoriteProductIds.contains(id)) {
      _favoriteProductIds.remove(id);
    } else {
      _favoriteProductIds.add(id);
    }
    playFeedbackSound();
    notifyListeners();
  }

  void toggleFavoriteRestaurant(String id) {
    if (_favoriteRestaurantIds.contains(id)) {
      _favoriteRestaurantIds.remove(id);
    } else {
      _favoriteRestaurantIds.add(id);
    }
    playFeedbackSound();
    notifyListeners();
  }

  // --- Loyalty Points State ---
  int _loyaltyPoints = 150; // نقاط ترحيبية
  bool _redeemingPoints = false;
  final List<LoyaltyEntry> _loyaltyHistory = [
    LoyaltyEntry(
      points: 150,
      reason: '🎁 هدية ترحيبية بمناسبة تسجيلك',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // نظام النقاط يُتحكم به من السوبر أدمن
  bool _loyaltySystemEnabled =
      false; // مُعطَّل افتراضياً حتى يُفعّله السوبر أدمن
  int _adminPointsPerOrder = 10; // نقاط لكل 1000 دينار (يتحكم به السوبر أدمن)

  bool get loyaltySystemEnabled => _loyaltySystemEnabled;
  int get adminPointsPerOrder => _adminPointsPerOrder;

  void setLoyaltySystem({bool? enabled, int? pointsPerOrder}) {
    if (enabled != null) _loyaltySystemEnabled = enabled;
    if (pointsPerOrder != null) _adminPointsPerOrder = pointsPerOrder;
    notifyListeners();
    // حفظ في Firestore لمزامنة الإعداد على جميع الأجهزة
    try {
      FirebaseFirestore.instance.collection('app_settings').doc('loyalty').set({
        'enabled': _loyaltySystemEnabled,
        'pointsPerOrder': _adminPointsPerOrder,
      });
    } catch (_) {}
  }

  int get loyaltyPoints => _loyaltyPoints;
  bool get redeemingPoints => _redeemingPoints;
  List<LoyaltyEntry> get loyaltyHistory => _loyaltyHistory;

  // كل 250 نقطة = 1500 د.ع خصم
  static const int pointsPerReward = 250;
  static const double rewardValue = 1500;

  double get loyaltyDiscount =>
      (_redeemingPoints && _loyaltyPoints >= pointsPerReward) ? rewardValue : 0;
  int get pointsNeededForReward =>
      pointsPerReward - (_loyaltyPoints % pointsPerReward);

  void toggleRedeemPoints() {
    if (_loyaltyPoints < pointsPerReward && !_redeemingPoints) return;
    _redeemingPoints = !_redeemingPoints;
    playFeedbackSound();
    notifyListeners();
  }

  void earnPoints(double orderAmount) {
    final earned = (orderAmount / 1000).floor() * 10;
    if (earned <= 0) return;
    _loyaltyPoints += earned;
    _loyaltyHistory.insert(
      0,
      LoyaltyEntry(
        points: earned,
        reason: '🛵 طلب مكتمل — كسبت $earned نقطة',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // --- Past Orders State ---
  final List<PastOrder> _pastOrders = [
    PastOrder(
      id: 'ORD-#4821',
      restaurantId: 'akkala',
      restaurantName: 'مطعم أكّالة للوجبات السريعة',
      items: [
        CartItem(
          product: Product(
            id: 'ak1',
            restaurantId: 'akkala',
            name: 'برجر لحم دبل جبن كلاسيك',
            description: 'شريحتين لحم مشوي مع الجبن السائل والصلصة السرية',
            price: 6000,
            imageUrl:
                'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
            categoryId: 'burger',
          ),
          quantity: 2,
        ),
      ],
      totalAmount: 13500,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<PastOrder> get pastOrders => _pastOrders;

  void reorder(PastOrder pastOrder, BuildContext context) {
    clearCart();
    for (var item in pastOrder.items) {
      _cartItems.add(CartItem(product: item.product, quantity: item.quantity));
    }
    _activeRestaurant = _restaurants.firstWhere(
      (r) => r.id == pastOrder.restaurantId,
      orElse: () => _restaurants.first,
    );
    setTab(1);
    playFeedbackSound();
    notifyListeners();
  }

  // --- Offers & Proximity ---
  final List<Offer> _offers = [
    Offer(
      id: 'off_1',
      restaurantId: 'akkala',
      restaurantName: 'مطعم أكّالة',
      title: 'عرض الوجبة العائلية 🍔🍟',
      description: '4 برجر دبل لحم + 2 فنجر + لتر كولا بـ 18,000 د.ع فقط!',
      discountTag: 'عرض عائلي 🔥',
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
    ),
    Offer(
      id: 'off_2',
      restaurantId: 'abualabd',
      restaurantName: 'مطعم أبو العبد',
      title: 'خصم 20% على شاورما الفحم 🌯',
      description: 'استمتع بأشهى شاورما فحم في الحمزة بخصم 20% لفترة محدودة',
      discountTag: 'خصم 20% ⚡',
      imageUrl:
          'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&q=80',
    ),
  ];

  List<Offer> get offers => _offers.where((o) => o.isActive).toList();
  List<Offer> get allOffers => _offers;

  void addOffer(Offer offer) {
    _offers.add(offer);
    _saveLocalData();
    try {
      FirebaseFirestore.instance
          .collection('offers')
          .doc(offer.id)
          .set(offer.toMap());
    } catch (_) {}
    notifyListeners();
  }

  void deleteOffer(String offerId) {
    _offers.removeWhere((o) => o.id == offerId);
    _saveLocalData();
    try {
      FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    } catch (_) {}
    notifyListeners();
  }

  void toggleOfferActive(String offerId) {
    final idx = _offers.indexWhere((o) => o.id == offerId);
    if (idx >= 0) {
      _offers[idx].isActive = !_offers[idx].isActive;
      _saveLocalData();
      try {
        FirebaseFirestore.instance.collection('offers').doc(offerId).update({
          'isActive': _offers[idx].isActive,
        });
      } catch (_) {}
      notifyListeners();
    }
  }

  void updateCustomerAvatar(String url) {
    customerAvatarUrl = url;
    saveSession();
    notifyListeners();
  }

  List<Restaurant> get restaurantsSortedByProximity {
    if (customerLat == null || customerLng == null) return _restaurants;
    final sorted = List<Restaurant>.from(_restaurants);
    sorted.sort((a, b) {
      final distA = a.distanceTo(customerLat, customerLng) ?? 999999;
      final distB = b.distanceTo(customerLat, customerLng) ?? 999999;
      return distA.compareTo(distB);
    });
    return sorted;
  }

  // --- Getters ---
  List<Restaurant> get restaurants => restaurantsSortedByProximity;
  List<Restaurant> get allRestaurants => _restaurants;
  List<Product> get products => _products;

  bool get isLoggedIn => _isLoggedIn;
  String? get userRole => _userRole;
  String? get userEmailOrPhone => _userEmailOrPhone;
  String? get userRestaurantId => _userRestaurantId;

  int get currentTab => _currentTab;
  String get selectedCategoryId => _selectedCategoryId;
  Restaurant? get activeRestaurant => _activeRestaurant;
  OrderStatus get orderStatus => _orderStatus;
  int get deliveryCountdown => _deliveryCountdown;
  String get lastOrderToken => _lastOrderToken;

  // --- Restaurant CRUD ---
  void addRestaurant(Restaurant restaurant) {
    _restaurants.add(restaurant);
    _saveLocalData();
    try {
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurant.id)
          .set(restaurant.toMap());
    } catch (_) {}
    notifyListeners();
  }

  void deleteRestaurant(String restaurantId) {
    _restaurants.removeWhere((r) => r.id == restaurantId);
    _products.removeWhere((p) => p.restaurantId == restaurantId);
    _saveLocalData();
    try {
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .delete();
    } catch (_) {}
    notifyListeners();
  }

  /// تحديث موقع المطعم (lat/lng) من صاحبه - يُحفظ في Firestore ليظهر للجميع
  void updateRestaurantLocation(String restaurantId, double lat, double lng) {
    final idx = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (idx >= 0) {
      _restaurants[idx].restaurantLat = lat;
      _restaurants[idx].restaurantLng = lng;
      _saveLocalData();
      try {
        FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .update({'restaurantLat': lat, 'restaurantLng': lng});
      } catch (_) {}
      notifyListeners();
    }
  }

  void toggleRestaurantActive(String restaurantId) {
    final idx = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (idx >= 0) {
      _restaurants[idx].isActive = !_restaurants[idx].isActive;
      try {
        FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .update({'isActive': _restaurants[idx].isActive});
      } catch (_) {}
      notifyListeners();
    }
  }

  /// صاحب المطعم يغلق أو يفتح مطعمه يدوياً
  void toggleRestaurantClosed(String restaurantId) {
    final idx = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (idx >= 0) {
      _restaurants[idx].isClosedManually = !_restaurants[idx].isClosedManually;
      try {
        FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .update({'isClosedManually': _restaurants[idx].isClosedManually});
      } catch (_) {}
      playFeedbackSound();
      notifyListeners();
    }
  }

  void updateRestaurantDetails(
    String restaurantId, {
    String? name,
    String? whatsappNumber,
    double? deliveryFee,
    String? deliveryTime,
    String? description,
    String? imageUrl,
    int? openHour,
    int? closeHour,
  }) {
    final idx = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (idx >= 0) {
      final r = _restaurants[idx];
      _restaurants[idx] = Restaurant(
        id: r.id,
        name: name ?? r.name,
        location: r.location,
        cuisine: r.cuisine,
        rating: r.rating,
        deliveryTime: deliveryTime ?? r.deliveryTime,
        imageUrl: imageUrl ?? r.imageUrl,
        description: description ?? r.description,
        whatsappNumber: whatsappNumber ?? r.whatsappNumber,
        isActive: r.isActive,
        isClosedManually: r.isClosedManually,
        serviceArea: r.serviceArea,
        deliveryFee: deliveryFee ?? r.deliveryFee,
        ownerPhone: r.ownerPhone,
        openHour: openHour ?? r.openHour,
        closeHour: closeHour ?? r.closeHour,
      );
      try {
        FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .update(_restaurants[idx].toMap());
      } catch (_) {}
      playFeedbackSound();
      notifyListeners();
    }
  }

  Future<bool> loginOwnerOrAdmin(String phone, String password) async {
    // 1. سوبر أدمن
    if (phone == '07802019730' && password == '@a20012005b@') {
      _isLoggedIn = true;
      _userRole = 'superadmin';
      saveSession();
      notifyListeners();
      return true;
    }

    // فحص قاعدة البيانات الموحدة للمدراء والمندوبين
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_credentials')
          .doc(phone)
          .get();
      if (doc.exists && doc.data()?['password'] == password) {
        final data = doc.data()!;
        _userRole = data['role'] ?? 'owner';

        if (_userRole == 'owner') {
          _userRestaurantId = data['restaurantId'];
          final rest = _restaurants.firstWhere(
            (r) => r.id == _userRestaurantId,
            orElse: () => _restaurants.first,
          );
          if (rest.id.isNotEmpty && !rest.isActive) {
            _isLoggedIn = false;
            _userRole = 'customer';
            _userRestaurantId = null;
            return false;
          }
          _isLoggedIn = true;
          saveSession();
          // save owner device UID in restaurant doc for push notifications
          if (deviceUid.isNotEmpty && _userRestaurantId != null && _userRestaurantId!.isNotEmpty) {
            FirebaseFirestore.instance
                .collection('restaurants')
                .doc(_userRestaurantId!)
                .set({'ownerDeviceUid': deviceUid}, SetOptions(merge: true));
            _saveOneSignalPlayerId(deviceUid);
          }
          notifyListeners();
          return true;
        } else if (_userRole == 'driver') {
          _isLoggedIn = true;
          _userEmailOrPhone = phone;
          customerName = data['name'] ?? 'المندوب';
          customerPhone = phone;
          saveSession();

          // حفظ جهاز المندوب لإرسال الإشعارات له لاحقاً
          if (deviceUid.isNotEmpty) {
            FirebaseFirestore.instance
                .collection('admin_credentials')
                .doc(phone)
                .set({'deviceUid': deviceUid}, SetOptions(merge: true));
          }

          _addNotification(
            '🛵 مرحباً $customerName! تم تسجيل دخولك كمندوب توصيل.',
          );
          notifyListeners();
          return true;
        } else {
          _isLoggedIn = true;
          _userRestaurantId = null;
          saveSession();
          notifyListeners();
          return true;
        }
      }

      // 4. إمكانية الدخول التلقائي للمطاعم الافتراضية
      final rest = _restaurants.firstWhere(
        (r) => r.ownerPhone == phone,
        orElse: () => Restaurant(
          id: '',
          name: '',
          location: '',
          cuisine: '',
          rating: 0,
          deliveryTime: '',
          imageUrl: '',
          description: '',
          whatsappNumber: '',
        ),
      );
      if (rest.id.isNotEmpty &&
          (password == '123456' || password == '@a20012005b@')) {
        if (!rest.isActive) return false;
        _isLoggedIn = true;
        _userRole = 'owner';
        _userRestaurantId = rest.id;
        FirebaseFirestore.instance
            .collection('admin_credentials')
            .doc(phone)
            .set({
              'role': 'owner',
              'restaurantId': rest.id,
              'password': password,
            });
        saveSession();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    return false;
  }

  void updateDeliveryFee(String restaurantId, double fee) {
    final idx = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (idx >= 0) {
      _restaurants[idx].deliveryFee = fee;
      try {
        FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .update({'deliveryFee': fee});
      } catch (_) {}
      notifyListeners();
    }
  }

  // --- Product CRUD ---
  void addProduct(Product product) {
    _products.add(product);
    _saveLocalData();
    try {
      FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .set(product.toMap());
    } catch (_) {}
    notifyListeners();
  }

  void deleteProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    _saveLocalData();
    try {
      FirebaseFirestore.instance.collection('products').doc(productId).delete();
    } catch (_) {}
    notifyListeners();
  }

  void updateProduct(
    String productId, {
    String? name,
    String? description,
    double? price,
    double? discountPrice,
    String? imageUrl,
    String? categoryId,
    bool? isAvailable,
    bool clearDiscount = false,
  }) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx >= 0) {
      _products[idx] = _products[idx].copyWith(
        name: name,
        description: description,
        price: price,
        discountPrice: discountPrice,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
        clearDiscount: clearDiscount,
      );
      _saveLocalData();
      try {
        FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update(_products[idx].toMap());
      } catch (_) {}
      notifyListeners();
    }
  }

  void toggleProductAvailability(String productId) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx >= 0) {
      _products[idx] = _products[idx].copyWith(
        isAvailable: !_products[idx].isAvailable,
      );
      _saveLocalData();
      try {
        FirebaseFirestore.instance.collection('products').doc(productId).update(
          {'isAvailable': _products[idx].isAvailable},
        );
      } catch (_) {}
      playFeedbackSound();
      notifyListeners();
    }
  }

  List<Product> getProductsByRestaurant(String restaurantId) =>
      _products.where((p) => p.restaurantId == restaurantId).toList();

  // --- Cart ---
  final List<CartItem> _cartItems = [];
  List<CartItem> get cartItems => _cartItems;
  String? get cartRestaurantId =>
      _cartItems.isEmpty ? null : _cartItems.first.product.restaurantId;
  int get cartCount => _cartItems.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _cartItems.fold(0.0, (s, i) => s + i.totalPrice);

  double get totalAmount =>
      (subtotal + deliveryFee - loyaltyDiscount).clamp(0.0, double.infinity);

  void addToCart(Product product, BuildContext context) {
    if (!product.isAvailable) return;
    if (cartRestaurantId != null && cartRestaurantId != product.restaurantId) {
      playFeedbackSound();
      _showMixedCartDialog(context, product);
      return;
    }
    final i = _cartItems.indexWhere((item) => item.product.id == product.id);
    if (i >= 0) {
      _cartItems[i].quantity++;
    } else {
      _cartItems.add(CartItem(product: product));
    }
    playFeedbackSound();
    notifyListeners();
  }

  void _showMixedCartDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Text('سلة مختلطة!', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'سلتك تحتوي وجبات من مطعم آخر.\nهل تريد تفريغ السلة والبدء من هذا المطعم؟',
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                clearCart();
                _cartItems.add(CartItem(product: product));
                notifyListeners();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: context.dynamicWhite,
              ),
              child: Text('نعم، ابدأ من جديد'),
            ),
          ],
        ),
      ),
    );
  }

  void removeFromCart(Product product) {
    final i = _cartItems.indexWhere((item) => item.product.id == product.id);
    if (i >= 0) {
      if (_cartItems[i].quantity > 1) {
        _cartItems[i].quantity--;
      } else {
        _cartItems.removeAt(i);
      }
      playFeedbackSound();
      notifyListeners();
    }
  }

  void deleteFromCart(Product product) {
    _cartItems.removeWhere((item) => item.product.id == product.id);
    playFeedbackSound();
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // --- Sound / Haptic ---
  void playFeedbackSound() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  void playOrderAlarmSound() {
    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 350), () {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
      });
    }
  }

  void _playClickFeedback() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  // --- Navigation ---
  void setTab(int index) {
    _currentTab = index;
    playFeedbackSound();
    notifyListeners();
  }

  void setCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    playFeedbackSound();
    notifyListeners();
  }

  void setActiveRestaurant(Restaurant? restaurant) {
    // لا تسمح بالدخول إذا المطعم مغلق يدوياً أو خارج ساعات العمل
    if (restaurant != null && !restaurant.isOpenNow) return;
    _activeRestaurant = restaurant;
    _selectedCategoryId = 'all';
    playFeedbackSound();
    notifyListeners();
  }

  // --- Notifications ---
  void _addNotification(
    String message, {
    bool isWarning = false,
    bool isOwnerNotification = false,
  }) {
    final notif = AppNotification(
      message: message,
      time: DateTime.now(),
      isWarning: isWarning,
      isOwnerNotification: isOwnerNotification,
    );
    notifications.insert(0, notif);
    unreadNotifications++;
    _saveLocalData();
    // ── حفظ الإشعار في Firestore (دائم وغير قابل للضياع) ─────────
    if (deviceUid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('notification_history')
          .doc(deviceUid)
          .collection('items')
          .add({
            'message': message,
            'isWarning': isWarning,
            'isOwnerNotification': isOwnerNotification,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .catchError((e) {
            debugPrint('Notification Firestore save error: $e');
            return <String, dynamic>{} as dynamic;
          });
    }
  }

  void markNotificationsRead() {
    unreadNotifications = 0;
    saveSession();
    notifyListeners();
  }

  // --- Order ---
  Future<bool> confirmOrder(BuildContext context) async {
    if (!SecurityEngine.checkRateLimit(deviceUid)) {
      _addNotification(
        '⚠️ تم رصد طلبات متكررة مشبوهة! يرجى الانتظار دقيقة قبل إعادة المحاولة.',
        isWarning: true,
      );
      notifyListeners();
      return false;
    }
    if (!SecurityEngine.verifyOrderIntegrity(
      _cartItems,
      totalAmount - deliveryFee,
    )) {
      _addNotification(
        '🔒 تم اكتشاف تلاعب في الأسعار! تم إلغاء الطلب لأسباب أمنية.',
        isWarning: true,
      );
      notifyListeners();
      return false;
    }

    // التحقق الصارم من صلاحيات الموقع وجلب إحداثيات الـ GPS قبل إتمام الطلب
    if (customerLat == null || customerLng == null) {
      await detectLocation();
    }

    _lastOrderToken = SecurityEngine.encryptOrderData({
      'customer': customerName,
      'phone': customerPhone,
      'amount': totalAmount,
      'items': _cartItems
          .map((i) => {'id': i.product.id, 'qty': i.quantity})
          .toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Save customer name and phone in session for future orders
    saveSession();

    return true;
  }

  Future<void> completeOrderAndResetHome() async {
    _isLoggedIn = true;
    _userRole ??= 'customer';
    saveSession();
    _saveLocalData();

    _addNotification('✅ تم إرسال طلبك بنجاح! يتم الآن تجهيزه في المطعم.');

    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    // 📦 حفظ الطلب في Firestore تحت collection 'orders'
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'orderId': orderId,
        'deviceUid': deviceUid,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'restaurantId': cartRestaurantId ?? '',
        'restaurantName': _activeRestaurant?.name ?? '',
        'items': _cartItems
            .map(
              (i) => {
                'name': i.product.name,
                'qty': i.quantity,
                'price': i.totalPrice,
              },
            )
            .toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'totalAmount': totalAmount,
        'neighborhood': selectedNeighborhood,
        'streetDetails': streetDetails,
        'orderNotes': orderNotes,
        'customerLat': customerLat,
        'customerLng': customerLng,
        'status': 'pending',
        'driverName': '',
        'driverPhone': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      activeOrderId = orderId; // حفظ المعرّف لمتابعة الطلب حياً
      saveSession(); // ← احفظ activeOrderId فوراً لبقاء الكارت بعد إغلاق التطبيق
      // ★ ابدأ الاستماع لتغييرات هذا الطلب وأرسل الإشعار للزبون حصراً
      startCustomerOrderListener(orderId);

      // 🔔 أرسل إشعار OneSignal لصاحب المطعم فوراً
      _notifyOwnerNewOrder(
        restaurantId: cartRestaurantId ?? '',
        customerName: customerName,
        totalAmount: totalAmount,
        orderId: orderId,
      );

      debugPrint('✅ تم حفظ الطلب في Firestore: $orderId');
    } catch (e) {
      debugPrint('❌ خطأ في حفظ الطلب: $e');
    }

    if (_cartItems.isNotEmpty) {
      // احفظ الطلب في التاريخ
      _pastOrders.insert(
        0,
        PastOrder(
          id: orderId,
          restaurantId: cartRestaurantId ?? 'akkala',
          restaurantName: _activeRestaurant?.name ?? 'مطعم أكّالة',
          items: _cartItems
              .map((i) => CartItem(product: i.product, quantity: i.quantity))
              .toList(),
          totalAmount: totalAmount,
          date: DateTime.now(),
        ),
      );
      _saveLocalData();
      // اخصم النقاط المستخدمة
      if (_redeemingPoints && _loyaltyPoints >= pointsPerReward) {
        _loyaltyPoints -= pointsPerReward;
        _loyaltyHistory.insert(
          0,
          LoyaltyEntry(
            points: -pointsPerReward,
            reason:
                '🎁 استبدال نقاط — خصم ${rewardValue.toStringAsFixed(0)} د.ع',
            date: DateTime.now(),
          ),
        );
      }
    }
    _redeemingPoints = false;
    _orderStatus = OrderStatus.confirmed;

    // 🔔 إشعار لحظي للزبون عند تأكيد الطلب
    jeebliNotifications.showOrderNotification(
      title: '✅ تم إرسال طلبك بنجاح!',
      body:
          'طلبك من ${_activeRestaurant?.name ?? 'المطعم'} قيد المعالجة 🛵 المبلغ: ${totalAmount.toStringAsFixed(0)} د.ع',
      id: 1001,
    );

    clearCart();
    _activeRestaurant = null;
    _currentTab = 0;
    playFeedbackSound();
    notifyListeners();
  }

  // ignore: unused_element
  void _startDeliverySimulation(BuildContext context) {
    _deliveryCountdown = 25 * 60;

    Future.delayed(const Duration(seconds: 1), () {
      _addNotification(
        '✅ تم استلام طلبك من "${_activeRestaurant?.name ?? 'المطعم'}" وهو قيد التحضير الآن!',
      );
      notifyListeners();
    });

    Future.delayed(const Duration(seconds: 2), () {
      _addNotification('🏪 تم إشعار المطعم بطلبك، جاري التحضير...');
      _orderStatus = OrderStatus.preparing;
      notifyListeners();
    });

    _deliveryTimer?.cancel();
    _deliveryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_deliveryCountdown > 0) {
        _deliveryCountdown--;
        notifyListeners();
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      _addNotification(
        '🛵 المندوب "$driverName" انطلق لتوصيل طلبك، طعامك قريباً سيصل!',
      );
      _orderStatus = OrderStatus.onWay;
      notifyListeners();
    });

    Future.delayed(const Duration(seconds: 10), () {
      _deliveryTimer?.cancel();
      _deliveryCountdown = 0;
      _addNotification(
        '🎉 وصل المندوب "$driverName"! ألف عافية وصحة وعافية 🍔',
      );
      _addNotification(
        '💰 إشعار المطعم: تم تسليم الطلب للزبون "$customerName" واستلام المبلغ ${totalAmount.toStringAsFixed(0)} د.ع. الفاتورة مغلقة ✅',
        isOwnerNotification: true,
      );
      _orderStatus = OrderStatus.arrived;
      playFeedbackSound();
      notifyListeners();
    });
  }

  void submitRating() {
    _addNotification(
      '⭐ شكراً على تقييمك! قيّمت المطعم بـ $restaurantRating نجوم والمندوب بـ $driverRating نجوم.',
    );
    _orderStatus = OrderStatus.rated;
    playFeedbackSound();
    notifyListeners();
  }

  void resetToHome() {
    _deliveryTimer?.cancel();
    _orderStatus = OrderStatus.idle;
    clearCart();
    setActiveRestaurant(null);
    _currentTab = 0;
    restaurantRating = 0;
    driverRating = 0;
    feedbackText = '';
    _lastOrderToken = '';
    _deliveryCountdown = 0;
    notifyListeners();
  }

  void updateCustomerPhone(String newPhone) {
    customerPhone = newPhone;
    if (newPhone.isNotEmpty) {
      _isLoggedIn = true;
      _userRole ??= 'customer';
    }
    saveSession();
    _playClickFeedback();
    notifyListeners();
  }

  void updateCustomerName(String newName) {
    customerName = newName;
    if (newName.isNotEmpty) {
      _isLoggedIn = true;
      _userRole ??= 'customer';
    }
    saveSession();
    _playClickFeedback();
    notifyListeners();
  }

  // --- Auth ---
  Future<bool> login(String loginId, String password, String role) async {
    _playClickFeedback();
    await Future.delayed(const Duration(milliseconds: 1500));

    final idNormalized = loginId.trim();

    if (role == 'customer') {
      // الزبون: loginId = الاسم، password = رقم الهاتف
      final name = idNormalized;
      final phone = password.trim();
      if (name.isEmpty || phone.isEmpty) return false;

      // حفظ/تحديث في Firestore
      try {
        final doc = FirebaseFirestore.instance
            .collection('customers')
            .doc(phone);
        final snap = await doc.get();
        if (!snap.exists) {
          await doc.set({
            'name': name,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          await doc.update({
            'name': name,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Firestore customer save note: $e');
      }

      _isLoggedIn = true;
      _userRole = 'customer';
      _userEmailOrPhone = phone;
      customerName = name;
      customerPhone = phone;
      saveSession();
      _addNotification('🔑 أهلاً بك $name! تم تسجيل الدخول بنجاح.');
      notifyListeners();
      return true;
    }

    if (role == 'owner') {
      // فحص السوبر أدمن أولاً من تبويب أصحاب المطاعم
      if (idNormalized == '07802019730' && password == '@a20012005b@') {
        _isLoggedIn = true;
        _userRole = 'superadmin';
        _userEmailOrPhone = idNormalized;
        saveSession();
        _addNotification('🔑 مرحباً بك في لوحة الإدارة العليا!');
        notifyListeners();
        return true;
      }

      // فحص قاعدة البيانات الموحدة للمدراء والمندوبين
      try {
        final doc = await FirebaseFirestore.instance
            .collection('admin_credentials')
            .doc(idNormalized)
            .get();
        if (doc.exists && doc.data()?['password'] == password) {
          final data = doc.data()!;
          _userRole = data['role'] ?? 'owner';

          if (_userRole == 'owner') {
            _userRestaurantId = data['restaurantId'];
            final rest = _restaurants.firstWhere(
              (r) => r.id == _userRestaurantId,
              orElse: () => _restaurants.first,
            );
            if (rest.id.isNotEmpty && !rest.isActive) {
              _isLoggedIn = false;
              _userRole = 'customer';
              _userRestaurantId = null;
              return false;
            }
            _isLoggedIn = true;
            _userEmailOrPhone = idNormalized;
            saveSession();
            _addNotification(
              '🏪 مرحباً بك! تم تسجيل دخولك كمالك لـ ${rest.name}',
              isOwnerNotification: true,
            );
            notifyListeners();
            return true;
          } else if (_userRole == 'driver') {
            _isLoggedIn = true;
            _userEmailOrPhone = idNormalized;
            customerName = data['name'] ?? 'المندوب';
            customerPhone = idNormalized;
            saveSession();
            _addNotification(
              '🛵 مرحباً $customerName! تم تسجيل دخولك كمندوب توصيل.',
            );
            notifyListeners();
            return true;
          } else {
            _isLoggedIn = true;
            _userRestaurantId = null;
            _userEmailOrPhone = idNormalized;
            saveSession();
            _addNotification('🔑 مرحباً بك في لوحة الإدارة العليا!');
            notifyListeners();
            return true;
          }
        }
      } catch (e) {
        debugPrint('Admin credentials login error: $e');
      }
    }

    return false;
  }
}

class AppNotification {
  final String message;
  final DateTime time;
  final bool isWarning;
  final bool isOwnerNotification;

  AppNotification({
    required this.message,
    required this.time,
    this.isWarning = false,
    this.isOwnerNotification = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'time': time.toIso8601String(),
      'isWarning': isWarning,
      'isOwnerNotification': isOwnerNotification,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      message: map['message'] ?? '',
      time: DateTime.tryParse(map['time']?.toString() ?? '') ?? DateTime.now(),
      isWarning: map['isWarning'] ?? false,
      isOwnerNotification: map['isOwnerNotification'] ?? false,
    );
  }
}

class JeebliProvider extends InheritedNotifier<JeebliController> {
  const JeebliProvider({
    super.key,
    required JeebliController super.notifier,
    required super.child,
  });

  static JeebliController of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<JeebliProvider>();
    assert(p != null);
    return p!.notifier!;
  }
}

/// ============================================================================
/// 4. التطبيق الرئيسي
/// ============================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return JeebliProvider(
      notifier: JeebliController(),
      child: Builder(
        builder: (context) {
          final controller = JeebliProvider.of(context);
          return MaterialApp(
            title: 'جيب لي ديلفري',
            debugShowCheckedModeBanner: false,
            themeMode: controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.light,
                seedColor: const Color(0xFFE65100),
                primary: const Color(0xFFE65100),
                secondary: const Color(0xFFFFB300),
                surface: const Color(0xFFF1F5F9),
              ),
              fontFamily: 'Cairo',
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark,
                seedColor: const Color(0xFFE65100),
                primary: const Color(0xFFE65100),
                secondary: const Color(0xFFFFB300),
                surface: const Color(0xFF0F172A),
              ),
              fontFamily: 'Cairo',
            ),
            builder: (context, child) {
              final controller = JeebliProvider.of(context);
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Stack(
                  children: [
                    ?child,
                    if (controller.isOffline)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.5),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wifi_off_rounded,
                                      color: Colors.redAccent,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا يوجد اتصال بالإنترنت',
                                      style: TextStyle(
                                        color: context.dynamicWhite,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'لا يمكن الطلب بسبب عدم الاتصال بالإنترنت.\nيرجى التحقق من اتصالك والمحاولة مجدداً.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.dynamicWhite70,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// 4.0 شاشة البداية (Splash Screen)
/// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    // --- Logo animation ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // --- Tagline animation (starts 400ms after logo) ---
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _taglineFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // --- Progress bar animation ---
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Start sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _progressController.forward();
    });

    // Navigate after 3.4 seconds — ثم اسأل عن الموقع إذا أول تشغيل
    Future.delayed(const Duration(milliseconds: 3400), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final locationAsked = prefs.getBool('location_asked') ?? false;
      if (!locationAsked && mounted) {
        await prefs.setBool('location_asked', true);
        if (mounted) await _showLocationPrompt(context);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, animation, secondary) => FadeTransition(
              opacity: animation,
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: AppRouteNavigator(),
              ),
            ),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  /// Dialog اختيار تفعيل الموقع عند أول تشغيل
  Future<void> _showLocationPrompt(BuildContext context) async {
    final controller = JeebliProvider.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8F00), Color(0xFFFF6B00)],
                    ),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: context.dynamicWhite,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تفعيل خدمة الموقع',
                  style: TextStyle(
                    color: context.dynamicWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'هل تريد تفعيل الموقع لرؤية أقرب المطاعم إليك؟\nيمكنك تفعيله لاحقاً من صفحتك الشخصية.',
                  style: TextStyle(
                    color: context.dynamicWhite70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.dynamicWhite70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('لاحقاً'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8F00),
                          foregroundColor: context.dynamicWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await controller.detectLocation();
                        },
                        child: Text(
                          'تفعيل',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Stack(
          children: [
            // ── خلفية دوائر زخرفية ──
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF8F00).withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE65100).withOpacity(0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── المحتوى الرئيسي ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // اللوغو
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8F00).withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🛵', style: TextStyle(fontSize: 62)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // اسم التطبيق
                  FadeTransition(
                    opacity: _logoFade,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF8F00), Color(0xFFFFD54F)],
                      ).createShader(bounds),
                      child: Text(
                        'جيب لي',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: context.dynamicWhite,
                          letterSpacing: 2,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Tagline
                  SlideTransition(
                    position: _taglineSlide,
                    child: FadeTransition(
                      opacity: _taglineFade,
                      child: Text(
                        'وجبتك عالبيت بضغطة زر ✨',
                        style: TextStyle(
                          fontSize: 15,
                          color: context.dynamicWhite70,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SlideTransition(
                    position: _taglineSlide,
                    child: FadeTransition(
                      opacity: _taglineFade,
                      child: Text(
                        'أسرع توصيل • أشهى الوجبات 🛵',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF8F00),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── شريط التحميل في الأسفل ──
            Positioned(
              bottom: size.height * 0.1,
              left: 48,
              right: 48,
              child: FadeTransition(
                opacity: _taglineFade,
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (ctx2, child) => Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progressController.value,
                              minHeight: 4,
                              backgroundColor: context.dynamicWhite.withOpacity(0.08),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFFF8F00),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _progressController.value < 0.5
                                ? 'جارٍ تحميل المطاعم...'
                                : _progressController.value < 0.9
                                ? 'تجهيز قائمة الوجبات...'
                                : 'أهلاً وسهلاً! 🎉',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.dynamicWhite70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 4.1 موجه التطبيق (RBAC)
/// ============================================================================

class AppRouteNavigator extends StatelessWidget {
  const AppRouteNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    // ═══ انتظر حتى تنتهي قراءة SharedPreferences ═══
    if (controller.isSessionLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8F00).withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fastfood_rounded,
                  color: context.dynamicWhite,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF8F00),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'جاري تحميل بياناتك...',
                style: TextStyle(color: context.dynamicWhite70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.userRole == 'superadmin') {
      return const SuperAdminShell();
    }

    if (controller.userRole == 'owner') {
      return const RestaurantOwnerAdminScreen();
    }

    if (controller.userRole == 'driver') {
      return const DriverDashboardScreen();
    }

    // الزبائن يدخلون مباشرة إلى التصفح والرئيسية بدون شاشة تسجيل الدخول
    return const MainNavigationShell();
  }
}

/// Shell يفتح super_admin_screen
class SuperAdminShell extends StatelessWidget {
  const SuperAdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    // نستورد من الملف المنفصل
    return const SuperAdminScreenEntry();
  }
}

/// ============================================================================
/// 5. هيكل التنقل للزبون
/// ============================================================================

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key});

  static bool _hasShownWelcome = false;

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final screens = [
      const HomeRestaurantsScreen(),
      const CartScreen(),
      const CustomerNotificationsScreen(),
      const CustomerProfileScreen(),
    ];

    if (!_hasShownWelcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showWelcomeDialog(context, 'customer');
        _hasShownWelcome = true;
      });
    }

    return Scaffold(
      backgroundColor: controller.bgColor,
      body: screens[controller.currentTab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: controller.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                controller.isDarkMode ? 0.3 : 0.08,
              ),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: controller.currentTab,
          onDestinationSelected: controller.setTab,
          indicatorColor: const Color(0xFFFF8F00).withOpacity(0.2),
          backgroundColor: controller.cardColor,
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.restaurant_menu_outlined,
                color: controller.subtextColor,
              ),
              selectedIcon: Icon(
                Icons.restaurant_menu,
                color: Color(0xFFFF8F00),
              ),
              label: 'المطاعم',
            ),
            NavigationDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    color: controller.subtextColor,
                  ),
                  if (controller.cartCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF8F00),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${controller.cartCount}',
                          style: TextStyle(
                            color: context.dynamicWhite,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              selectedIcon: Icon(
                Icons.shopping_cart,
                color: Color(0xFFFF8F00),
              ),
              label: 'السلة',
            ),
            NavigationDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: controller.subtextColor,
                  ),
                  if (controller.unreadNotifications > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${controller.unreadNotifications}',
                          style: TextStyle(
                            color: context.dynamicWhite,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              selectedIcon: Icon(
                Icons.notifications,
                color: Color(0xFFFF8F00),
              ),
              label: 'إشعاراتي',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: controller.subtextColor),
              selectedIcon: Icon(Icons.person, color: Color(0xFFFF8F00)),
              label: 'الحساب',
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// شاشة إشعارات الزبون
/// ============================================================================

class CustomerNotificationsScreen extends StatelessWidget {
  const CustomerNotificationsScreen({super.key});

  Future<void> _clearAllFirestoreNotifications(String deviceUid) async {
    final coll = FirebaseFirestore.instance
        .collection('notification_history')
        .doc(deviceUid)
        .collection('items');
    final snap = await coll.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.unreadNotifications > 0) {
        controller.markNotificationsRead();
      }
    });

    final deviceUid = controller.deviceUid;

    return Scaffold(
      backgroundColor: controller.bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'إشعاراتي 🔔',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: controller.textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: controller.cardColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              controller.clearNotifications();
              if (deviceUid.isNotEmpty) {
                await _clearAllFirestoreNotifications(deviceUid);
              }
            },
            child: Text(
              'مسح الكل',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
      body: deviceUid.isEmpty
          ? _buildEmpty(controller)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notification_history')
                  .doc(deviceUid)
                  .collection('items')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // fallback to local if Firestore not connected
                final firestoreDocs = snapshot.data?.docs ?? [];
                final localNotifs = controller.notifications;

                if (snapshot.connectionState == ConnectionState.waiting &&
                    localNotifs.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF8F00)),
                  );
                }

                if (firestoreDocs.isEmpty && localNotifs.isEmpty) {
                  return _buildEmpty(controller);
                }

                // Use Firestore data if available, else fall back to local
                if (firestoreDocs.isNotEmpty) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: firestoreDocs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = firestoreDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final message = data['message'] as String? ?? '';
                      final isWarning = data['isWarning'] as bool? ?? false;
                      
                      final ts = data['createdAt'] as Timestamp?;
                      final time = ts?.toDate() ?? DateTime.now();
                      
                      return _buildNotifTile(
                        controller,
                        message,
                        isWarning,
                        time,
                      );
                    },
                  );
                }

                // Fallback: local notifications
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: localNotifs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notif = localNotifs[index];
                    return _buildNotifTile(
                      controller,
                      notif.message,
                      notif.isWarning,
                      notif.time,
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmpty(JeebliController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: controller.subtextColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات بعد',
            style: TextStyle(
              color: controller.subtextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا إشعارات طلباتك وعروضك',
            style: TextStyle(
              color: controller.subtextColor.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifTile(
    JeebliController controller,
    String message,
    bool isWarning,
    DateTime time, {
    DocumentReference? docRef,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.withOpacity(0.1) : controller.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWarning
              ? Colors.redAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isWarning
                  ? Colors.redAccent.withOpacity(0.15)
                  : const Color(0xFFFF8F00).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.notifications_rounded,
              color: isWarning ? Colors.redAccent : const Color(0xFFFF8F00),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: controller.textColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}',
                  style: TextStyle(
                    color: controller.subtextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (docRef != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.white70,
              ),
              onPressed: () => docRef.delete(),
              tooltip: 'حذف الإشعار',
            ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 6. شاشة المطاعم
/// ============================================================================

class HomeRestaurantsScreen extends StatefulWidget {
  const HomeRestaurantsScreen({super.key});

  @override
  State<HomeRestaurantsScreen> createState() => _HomeRestaurantsScreenState();
}

class _HomeRestaurantsScreenState extends State<HomeRestaurantsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _selectedCategory = 'الكل';
  final List<Map<String, dynamic>> _categories = [
    {'name': 'الكل', 'icon': Icons.apps_rounded, 'keywords': <String>[]},
    {
      'name': 'وجبات سريعة',
      'icon': Icons.fastfood_rounded,
      'keywords': ['برجر', 'بيتزا', 'فنجر', 'وجبات', 'سريعة'],
    },
    {
      'name': 'مشويات',
      'icon': Icons.kebab_dining_rounded,
      'keywords': ['كباب', 'مشويات', 'تكة', 'شقف'],
    },
    {
      'name': 'أسماك',
      'icon': Icons.set_meal_rounded,
      'keywords': ['سمك', 'مسكوف', 'أسماك', 'بحرية'],
    },
    {
      'name': 'دجاج شوي',
      'icon': Icons.local_fire_department_rounded,
      'keywords': ['دجاج', 'شوي', 'دجاج شوي', 'دياي'],
    },
    {
      'name': 'فلافل',
      'icon': Icons.breakfast_dining_rounded,
      'keywords': ['فلافل', 'مقبلات'],
    },
    {
      'name': 'حلويات وعصائر',
      'icon': Icons.icecream_rounded,
      'keywords': ['حلويات', 'عصير', 'عصائر', 'كيك', 'مرطبات', 'كريب', 'وافل'],
    },
  ];

  bool _matchesCategory(Restaurant r, String categoryName) {
    if (categoryName == 'الكل') return true;
    final cat = _categories.firstWhere((c) => c['name'] == categoryName);
    final List<String> keywords = cat['keywords'];
    final combinedText = '${r.name} ${r.cuisine} ${r.description}'
        .toLowerCase();
    for (String kw in keywords) {
      if (combinedText.contains(kw)) return true;
    }
    return false;
  }

  Widget _buildCategoriesList(JeebliController controller) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['name'];
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                SystemSound.play(SystemSoundType.click);
                setState(() => _selectedCategory = cat['name'] as String);
              },
              borderRadius: BorderRadius.circular(25),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber
                      : (controller.isDarkMode
                            ? Colors.white10
                            : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? Colors.amberAccent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? Colors.black87
                          : controller.subtextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['name'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.black87
                            : controller.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    if (controller.activeRestaurant != null)
      return const RestaurantMenuScreen();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
      builder: (context, snapshot) {
        List<Restaurant> liveRestaurants = controller.restaurants;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          liveRestaurants = snapshot.data!.docs
              .map(
                (doc) => Restaurant.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
          // ترتيب المطاعم حسس الأقرب إذا كانت إحداثيات الزبون متوفرة
          if (controller.customerLat != null &&
              controller.customerLng != null) {
            liveRestaurants.sort((a, b) {
              final dA =
                  a.distanceTo(
                    controller.customerLat,
                    controller.customerLng,
                  ) ??
                  double.infinity;
              final dB =
                  b.distanceTo(
                    controller.customerLat,
                    controller.customerLng,
                  ) ??
                  double.infinity;
              return dA.compareTo(dB);
            });
          }
        }

        final filteredRestaurants = liveRestaurants.where((r) {
          final matchesSearch =
              _searchQuery.isEmpty ||
              r.name.contains(_searchQuery) ||
              r.cuisine.contains(_searchQuery) ||
              r.description.contains(_searchQuery);
          final matchesCat = _matchesCategory(r, _selectedCategory);
          return matchesSearch && matchesCat && r.isActive;
        }).toList();

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFE65100,
                                  ).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.fastfood_rounded,
                              color: context.dynamicWhite,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'جيب لي ديلفري 🍔',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: controller.textColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'اطلب وجبتك من أشهر مطاعم منطقتنا',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: controller.subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _showOwnerLoginModal(context, controller),
                            tooltip: 'دخول الإدارة وأصحاب المطاعم 🔑',
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.vpn_key_rounded,
                                color: Colors.amber,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => controller.toggleTheme(),
                            tooltip: controller.isDarkMode
                                ? 'التحويل للوضع الفاتح ☀️'
                                : 'التحويل للوضع الداكن 🌙',
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.dynamicWhite.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Icon(
                                controller.isDarkMode
                                    ? Icons.wb_sunny_rounded
                                    : Icons.nightlight_round,
                                color: controller.isDarkMode
                                    ? Colors.amber
                                    : Colors.indigoAccent,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── شريط البحث ──
                      Container(
                        decoration: BoxDecoration(
                          color: controller.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: controller.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                controller.isDarkMode ? 0.2 : 0.05,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.trim()),
                          style: TextStyle(
                            color: controller.textColor,
                            fontSize: 14,
                          ),
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن مطعم أو وجبة...',
                            hintStyle: TextStyle(
                              color: controller.subtextColor,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Color(0xFFFF8F00),
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: controller.subtextColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCategoriesList(controller),
                      const SizedBox(height: 16),
                      if (_searchQuery.isEmpty) _buildPromoSlider(context),
                      if (_searchQuery.isEmpty) const SizedBox(height: 16),
                      if (_searchQuery.isNotEmpty &&
                          filteredRestaurants.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  '🔍',
                                  style: TextStyle(fontSize: 48),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد نتائج لـ "$_searchQuery"',
                                  style: TextStyle(
                                    color: context.dynamicWhite70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_searchQuery.isEmpty && filteredRestaurants.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 80,
                                  color: controller.subtextColor.withOpacity(
                                    0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا يوجد مطاعم أو محلات الآن،\nسوف يتم إضافة المطاعم في وقت لاحق',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: controller.subtextColor,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (controller.activeOrderId != null)
                        _buildActiveOrderBanner(controller),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final rest = filteredRestaurants[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: controller.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              controller.isDarkMode ? 0.3 : 0.06,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: controller.borderColor),
                      ),
                      child: InkWell(
                        onTap: () {
                          if (!rest.isOpenNow) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.store_mall_directory_outlined,
                                      color: context.dynamicWhite,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${rest.name} مغلق حالياً 🔴\nالطلب غير متاح في هذا الوقت',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red[800],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            return;
                          }
                          controller.setActiveRestaurant(rest);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  child: CustomAppImage(
                                    imageUrl: rest.imageUrl,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                // overlay مغلق فوق الصورة
                                if (!rest.isOpenNow)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.6),
                                        child: const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.lock_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 40,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'مغلق',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.redAccent,
                                                  letterSpacing: 2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: GestureDetector(
                                    onTap: () => controller
                                        .toggleFavoriteRestaurant(rest.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white24,
                                        ),
                                      ),
                                      child: Icon(
                                        controller.isRestaurantFavorite(rest.id)
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color:
                                            controller.isRestaurantFavorite(
                                              rest.id,
                                            )
                                            ? Colors.redAccent
                                            : context.dynamicWhite,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Color(0xFFFFB300),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              rest.location,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (rest.distanceTo(
                                            controller.customerLat,
                                            controller.customerLng,
                                          ) !=
                                          null) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF16A34A,
                                            ).withOpacity(0.95),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.near_me_rounded,
                                                color: context.dynamicWhite,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Builder(
                                                builder: (_) {
                                                  final d = rest.distanceTo(
                                                    controller.customerLat,
                                                    controller.customerLng,
                                                  )!;
                                                  final str = d < 1
                                                      ? '${(d * 1000).toInt()} متر'
                                                      : '${d.toStringAsFixed(1)} كم';
                                                  return Text(
                                                    'يبعد $str',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rest.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: controller.textColor,
                                          ),
                                        ),
                                      ),
                                      // تقييم النجوم
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: controller.bgColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.star_rounded,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${rest.rating}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.greenAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // شارة مفتوح / مغلق
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: rest.isOpenNow
                                              ? Colors.green.withOpacity(0.15)
                                              : Colors.red.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: rest.isOpenNow
                                                ? Colors.greenAccent
                                                      .withOpacity(0.5)
                                                : Colors.redAccent.withOpacity(
                                                    0.5,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: rest.isOpenNow
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              size: 8,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              rest.isOpenNow ? 'مفتوح' : 'مغلق',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: rest.isOpenNow
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    rest.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.dynamicWhite70,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ساعات العمل: ${rest.workingHoursLabel}',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      height: 1,
                                      color: Colors.white12,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.fastfood_rounded,
                                            size: 16,
                                            color: Color(0xFFFF8F00),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            rest.cuisine,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.dynamicWhite,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.delivery_dining_rounded,
                                            size: 18,
                                            color: Colors.lightBlueAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            rest.deliveryTime,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.lightBlueAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // ساعات العمل
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 15,
                                        color: rest.isOpenNow
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ساعات العمل: ${rest.workingHoursLabel}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: rest.isOpenNow
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: filteredRestaurants.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromoSlider(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('offers').snapshots(),
      builder: (context, snapshot) {
        List<Offer> activeOffers = controller.offers;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          activeOffers = snapshot.data!.docs
              .map(
                (doc) =>
                    Offer.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .where((o) => o.isActive)
              .toList();
        }

        if (activeOffers.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 125,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: activeOffers.length,
            itemBuilder: (ctx, i) {
              final offer = activeOffers[i];
              final gradientColors = (i % 2 == 0)
                  ? [const Color(0xFFE65100), const Color(0xFFFF8F00)]
                  : [const Color(0xFF7C3AED), const Color(0xFF4F46E5)];

              return InkWell(
                onTap: () {
                  final rest = controller.allRestaurants.firstWhere(
                    (r) => r.id == offer.restaurantId,
                    orElse: () => controller.allRestaurants.first,
                  );
                  controller.setActiveRestaurant(rest);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.dynamicWhite.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                offer.discountTag,
                                style: TextStyle(
                                  color: context.dynamicWhite,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              offer.title,
                              style: TextStyle(
                                color: context.dynamicWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              offer.description,
                              style: TextStyle(
                                color: context.dynamicWhite70,
                                fontSize: 10.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CustomAppImage(
                          imageUrl: offer.imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveOrderBanner(JeebliController controller) {
    final orderId = controller.activeOrderId;
    if (orderId == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFFFB300)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.dynamicWhite, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ تم إرسال طلبك للمطعم',
                    style: TextStyle(
                      color: context.dynamicWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'سيتواصل معك المطعم للتأكيد قريباً',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final status = data['status'] ?? 'pending';
        final driverName = data['driverName'] ?? '';
        final driverPhone = data['driverPhone'] ?? '';

        // مراحل التقدم
        final steps = ['pending', 'preparing', 'onTheWay', 'delivered'];
        final stepIndex = steps.indexOf(status);

        final List<Map<String, dynamic>> stepsInfo = [
          {'label': 'تم الإرسال', 'icon': Icons.receipt_long_rounded},
          {'label': 'قيد التحضير', 'icon': Icons.restaurant_rounded},
          {'label': 'في الطريق', 'icon': Icons.delivery_dining_rounded},
          {'label': 'تم التسليم', 'icon': Icons.home_rounded},
        ];

        Color headerColor;
        String headerTitle;
        String headerSub;
        IconData headerIcon;
        switch (status) {
          case 'preparing':
            headerColor = Colors.amber;
            headerTitle = '👨‍🍳 طلبك قيد التحضير';
            headerSub = 'المطعم يحضّر وجبتك الآن';
            headerIcon = Icons.restaurant_rounded;
            break;
          case 'onTheWay':
            headerColor = Colors.lightBlueAccent;
            headerTitle = '🛵 المندوب في الطريق إليك!';
            headerSub = driverName.isNotEmpty
                ? 'المندوب: $driverName'
                : 'وجبتك على الطريق';
            headerIcon = Icons.delivery_dining_rounded;
            break;
          case 'delivered':
            headerColor = Colors.greenAccent;
            headerTitle = '✅ تم التسليم بنجاح!';
            headerSub = 'ألف عافية، ونتمنى تستمتع بوجبتك 🎉';
            headerIcon = Icons.check_circle_rounded;
            break;
          case 'rejected':
            headerColor = Colors.redAccent;
            headerTitle = '❌ تم رفض الطلب';
            headerSub = 'نأسف، يمكنك المحاولة مع مطعم آخر';
            headerIcon = Icons.cancel_rounded;
            break;
          default:
            headerColor = const Color(0xFFFF8F00);
            headerTitle = '⏳ بانتظار موافقة المطعم...';
            headerSub = 'سيتم الرد عليك خلال دقائق';
            headerIcon = Icons.hourglass_top_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: headerColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: headerColor.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // ─── Header ───
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerColor.withOpacity(0.15), Colors.transparent],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: headerColor.withOpacity(0.15),
                        border: Border.all(color: headerColor.withOpacity(0.5)),
                      ),
                      child: Icon(headerIcon, color: headerColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerTitle,
                            style: TextStyle(
                              color: headerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            headerSub,
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (status == 'delivered' || status == 'rejected')
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () {
                          controller.clearActiveOrder();
                        },
                      ),
                  ],
                ),
              ),
              // ─── شريط التقدم ───
              if (status != 'rejected')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: List.generate(stepsInfo.length, (i) {
                      final isActive = i <= stepIndex;
                      final isCurrent = i == stepIndex;
                      return Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      openNativeMap(
                                        destLat: data['driverLat'] as double?,
                                        destLng: data['driverLng'] as double?,
                                        originLat: JeebliProvider.of(
                                          context,
                                        ).customerLat,
                                        originLng: JeebliProvider.of(
                                          context,
                                        ).customerLng,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      width: isCurrent ? 40 : 32,
                                      height: isCurrent ? 40 : 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive
                                            ? headerColor.withOpacity(0.2)
                                            : context.dynamicWhite.withOpacity(0.05),
                                        border: Border.all(
                                          color: isActive
                                              ? headerColor
                                              : Colors.white12,
                                          width: isCurrent ? 2.5 : 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        stepsInfo[i]['icon'] as IconData,
                                        size: isCurrent ? 20 : 15,
                                        color: isActive
                                            ? headerColor
                                            : Colors.white24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stepsInfo[i]['label'] as String,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      color: isActive
                                          ? headerColor
                                          : Colors.white24,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            if (i < stepsInfo.length - 1)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.only(bottom: 18),
                                  color: i < stepIndex
                                      ? headerColor.withOpacity(0.5)
                                      : Colors.white12,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              // ─── بطاقة المندوب مع التتبع الحي ───
              if (status == 'onTheWay' && driverName.isNotEmpty)
                Builder(
                  builder: (ctx) {
                    final driverLat = data['driverLat'] as double?;
                    final driverLng = data['driverLng'] as double?;
                    final controller2 = JeebliProvider.of(ctx);
                    final custLat = controller2.customerLat;
                    final custLng = controller2.customerLng;

                    double? distanceMeters;
                    if (driverLat != null &&
                        driverLng != null &&
                        custLat != null &&
                        custLng != null) {
                      distanceMeters = Geolocator.distanceBetween(
                        custLat,
                        custLng,
                        driverLat,
                        driverLng,
                      );
                    }
                    final hasLiveLocation =
                        driverLat != null && driverLng != null;

                    return Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.lightBlueAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.lightBlueAccent.withOpacity(
                                    0.15,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_pin_circle_rounded,
                                  color: Colors.lightBlueAccent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🛵 المندوب',
                                      style: TextStyle(
                                        color: context.dynamicWhite70,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      driverName,
                                      style: TextStyle(
                                        color: context.dynamicWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (hasLiveLocation)
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                          Text(
                                            distanceMeters != null
                                                ? (distanceMeters < 1000
                                                      ? 'على بُعد ${distanceMeters.toStringAsFixed(0)} متر منك'
                                                      : 'على بُعد ${(distanceMeters / 1000).toStringAsFixed(1)} كم منك')
                                                : 'التتبع الحي نشط 🟢',
                                            style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              if (driverPhone.isNotEmpty)
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse('tel:$driverPhone');
                                    if (await canLaunchUrl(uri)) launchUrl(uri);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlueAccent.withOpacity(
                                        0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.lightBlueAccent
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.call_rounded,
                                          color: Colors.lightBlueAccent,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'اتصال',
                                          style: TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (hasLiveLocation) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  openNativeMap(
                                    destLat: driverLat,
                                    destLng: driverLng,
                                    originLat: custLat,
                                    originLng: custLng,
                                  );
                                },
                                icon: Icon(
                                  Icons.near_me_rounded,
                                  size: 16,
                                  color: Color(0xFFFF8F00),
                                ),
                                label: Text(
                                  '🗺️ تتبع المندوب على الخريطة',
                                  style: TextStyle(
                                    color: Color(0xFFFF8F00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: const Color(
                                      0xFFFF8F00,
                                    ).withOpacity(0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// واجهة المندوب (Driver Dashboard) - تحديثات فورية + إشعار عند طلب جديد
/// ============================================================================

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _prevOrderCount = -1;
  StreamSubscription<Position>? _locationSubscription;
  String? _activeTrackingOrderId;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking(String orderId) async {
    if (_activeTrackingOrderId == orderId) return; // already tracking
    await _locationSubscription?.cancel();
    _activeTrackingOrderId = orderId;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // update every 20 meters
    );
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          Position pos,
        ) {
          FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({
                'driverLat': pos.latitude,
                'driverLng': pos.longitude,
                'driverLocAt': FieldValue.serverTimestamp(),
              })
              .catchError((e) => debugPrint('GPS update error: \$e'));
        });
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _activeTrackingOrderId = null;
  }

  void _checkForNewOrders(int currentCount, String driverName) {
    if (_prevOrderCount == -1) {
      // أول تحميل — فقط احفظ العدد
      _prevOrderCount = currentCount;
      return;
    }
    if (currentCount > _prevOrderCount) {
      // 🔔 طلب جديد وصل!
      if (mounted) {
        JeebliProvider.of(context).playOrderAlarmSound();
      }
      jeebliNotifications.showOrderNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '🛵 لديك طلب توصيل جديد!',
        body: 'وصل طلب جديد إليك $driverName — افتح التطبيق لقبوله',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.delivery_dining_rounded, color: context.dynamicWhite),
                SizedBox(width: 10),
                Expanded(
                  child: Text('🔔 طلب جديد وصل إليك! اضغط هنا للاطلاع عليه'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF8F00),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    _prevOrderCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final driverPhone = controller.customerPhone;
    final driverName = controller.customerName;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'واجهة المندوب 🛵',
              style: TextStyle(
                color: context.dynamicWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              'مرحباً $driverName',
              style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          // مؤشر الاتصال المباشر
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                SizedBox(width: 4),
                Text(
                  'مباشر',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: context.dynamicWhite70),
            onPressed: () => controller.logout(),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('driverPhone', isEqualTo: driverPhone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _prevOrderCount == -1) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8F00)),
            );
          }
          var docs = snapshot.data?.docs ?? [];

          // ترتيب تنازلي برمجياً
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final tA = dataA['createdAt'] as Timestamp?;
            final tB = dataB['createdAt'] as Timestamp?;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });

          // 🔔 تحقق من الطلبات الجديدة
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkForNewOrders(docs.length, driverName);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B),
                      border: Border.all(
                        color: const Color(0xFFFF8F00).withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.delivery_dining_rounded,
                      color: Color(0xFFFF8F00),
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'لا توجد طلبات مسندة إليك الآن',
                    style: TextStyle(
                      color: context.dynamicWhite70,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ستظهر هنا الطلبات عند تعيينك من قبل المطعم',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          color: Colors.greenAccent,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'متصل وينتظر الطلبات...',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docRef = docs[index].reference;
              final status = data['status'] ?? 'preparing';
              final custName = data['customerName'] ?? '---';
              final custPhone = data['customerPhone'] ?? '';
              final neighborhood = data['neighborhood'] ?? '';
              final streetDetails = data['streetDetails'] ?? '';
              final total = (data['totalAmount'] ?? 0).toStringAsFixed(0);
              final deliveryFee = (data['deliveryFee'] ?? 0).toStringAsFixed(0);
              final restName = data['restaurantName'] ?? '';
              final items = (data['items'] as List<dynamic>?) ?? [];
              // 📍 إحداثيات الزبون (إذا وجدت)
              final custLat = data['customerLat'];
              final custLng = data['customerLng'];
              final hasLocation = custLat != null && custLng != null;
              // ⏰ وقت الطلب
              final createdAt = data['createdAt'] as Timestamp?;
              final orderTime = createdAt != null
                  ? '${createdAt.toDate().hour}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
                  : '';

              Color statusColor;
              String statusLabel;
              IconData statusIcon;
              switch (status) {
                case 'preparing':
                  statusColor = Colors.amber;
                  statusLabel = '🧑‍🍳 جاري التحضير في المطعم';
                  statusIcon = Icons.restaurant_rounded;
                  break;
                case 'onTheWay':
                  statusColor = Colors.lightBlueAccent;
                  statusLabel = '🛵 أنت في الطريق';
                  statusIcon = Icons.delivery_dining_rounded;
                  break;
                case 'delivered':
                  statusColor = Colors.greenAccent;
                  statusLabel = '✅ تم التسليم';
                  statusIcon = Icons.check_circle_rounded;
                  break;
                default:
                  statusColor = Colors.orangeAccent;
                  statusLabel = '⏳ انتظار';
                  statusIcon = Icons.hourglass_top_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ─── Header: حالة الطلب + الوقت ───
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.15),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor.withOpacity(0.15),
                              border: Border.all(
                                color: statusColor.withOpacity(0.4),
                              ),
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (orderTime.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.dynamicWhite.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '⏰ $orderTime',
                                style: TextStyle(
                                  color: context.dynamicWhite70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            restName,
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // ─── معلومات الزبون ───
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اسم الزبون
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                color: Color(0xFFFF8F00),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  custName,
                                  style: TextStyle(
                                    color: context.dynamicWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // رقم الهاتف + زر اتصال
                          Row(
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                color: context.dynamicWhite70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                custPhone,
                                style: TextStyle(
                                  color: context.dynamicWhite70,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  final uri = Uri.parse('tel:$custPhone');
                                  if (await canLaunchUrl(uri)) launchUrl(uri);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.greenAccent.withOpacity(
                                        0.4,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.call_rounded,
                                        color: Colors.greenAccent,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'اتصال',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // العنوان + زر الخريطة
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.dynamicWhite.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFFFF8F00),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'المنطقة: $neighborhood',
                                            style: TextStyle(
                                              color: context.dynamicWhite70,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (streetDetails.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              streetDetails,
                                              style: TextStyle(
                                                color: context.dynamicWhite70,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // 📍 زر فتح الخريطة إذا توفرت الإحداثيات
                                if (hasLocation) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        openNativeMap(
                                          destLat: custLat,
                                          destLng: custLng,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.map_rounded,
                                        size: 16,
                                        color: Color(0xFFFF8F00),
                                      ),
                                      label: Text(
                                        '📍 فتح موقع الزبون على الخريطة',
                                        style: TextStyle(
                                          color: Color(0xFFFF8F00),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: const Color(
                                            0xFFFF8F00,
                                          ).withOpacity(0.5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ─── قائمة الوجبات ───
                          Text(
                            '📋 تفاصيل الطلب:',
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...items.map((item) {
                            final iMap = item as Map<String, dynamic>;
                            final iName = iMap['name'] ?? '';
                            final iQty = iMap['qty'] ?? 1;
                            final iPrice = (iMap['price'] ?? 0).toStringAsFixed(
                              0,
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFF8F00,
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$iQty',
                                      style: TextStyle(
                                        color: Color(0xFFFF8F00),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      iName,
                                      style: TextStyle(
                                        color: context.dynamicWhite70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$iPrice د.ع',
                                    style: TextStyle(
                                      color: context.dynamicWhite70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 8),
                          const Divider(color: Colors.white10),

                          // ─── المبلغ الإجمالي ───
                          Row(
                            children: [
                              Text(
                                'رسوم التوصيل:',
                                style: TextStyle(
                                  color: context.dynamicWhite70,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$deliveryFee د.ع',
                                style: TextStyle(
                                  color: context.dynamicWhite70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                color: Colors.greenAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'المبلغ الكلي المطلوب:',
                                style: TextStyle(
                                  color: context.dynamicWhite70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.greenAccent.withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  '$total د.ع',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ─── أزرار الإجراء ───
                          if (status == 'preparing')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await docRef.update({'status': 'onTheWay'});
                                  // 📍 ابدأ إرسال الموقع للزبون
                                  _startLocationTracking(docRef.id);
                                  // 🔔 إشعار للزبون - المندوب في الطريق
                                  final od =
                                      (await docRef.get()).data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  if (context.mounted) {
                                    JeebliProvider.of(context)._notifyCustomer(
                                      custDeviceUid:
                                          od['deviceUid']?.toString() ?? '',
                                      title: '🛵 طلبك في الطريق!',
                                      body:
                                          '${od['driverName'] ?? 'المندوب'} في الطريق إليك الآن 🚀',
                                      orderId: docRef.id,
                                    );
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '🛵 تم تأكيد استلام الطلب! الموقع يُرسل للزبون الآن',
                                        ),
                                        backgroundColor: Colors.amber,
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(
                                  Icons.delivery_dining_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  '✅ استلمت الطلب - أنا في الطريق!',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                          if (status == 'onTheWay') ...[
                            // تذكير بالعنوان
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.lightBlueAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.lightBlueAccent.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.lightBlueAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'اتجه إلى: $neighborhood${streetDetails.isNotEmpty ? " - $streetDetails" : ""}',
                                      style: TextStyle(
                                        color: Colors.lightBlueAccent,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await docRef.update({
                                    'status': 'delivered',
                                    'deliveredAt': FieldValue.serverTimestamp(),
                                    'driverLat': FieldValue.delete(),
                                    'driverLng': FieldValue.delete(),
                                  });
                                  // 🛑 أوقف إرسال الموقع
                                  _stopLocationTracking();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ تم تسليم الطلب بنجاح!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  '📍 وصلت وسلمت الطلب للزبون ✅',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          if (status == 'delivered')
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.greenAccent,
                                    size: 32,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '✅ تم إنهاء هذا الطلب بنجاح',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// 7. شاشة منيو المطعم

/// ============================================================================

class RestaurantMenuScreen extends StatefulWidget {
  const RestaurantMenuScreen({super.key});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  List<Category> _buildCategories(JeebliController ctrl) {
    final rest = ctrl.activeRestaurant;
    final List<Category> cats = [
      Category(id: 'all', name: 'الكل', icon: Icons.grid_view_rounded),
      Category(id: 'favs', name: 'المفضلة ❤️', icon: Icons.favorite_rounded),
    ];
    if (rest != null && rest.customCategories.isNotEmpty) {
      for (var c in rest.customCategories) {
        cats.add(Category(id: c, name: c, icon: Icons.fastfood));
      }
    } else {
      // Fallback
      cats.addAll([
        Category(id: 'burger', name: 'برجر', icon: Icons.lunch_dining),
        Category(id: 'zinger', name: 'زنجر', icon: Icons.restaurant),
        Category(id: 'pizza', name: 'بيتزا', icon: Icons.local_pizza),
        Category(id: 'shawarma', name: 'شاورما', icon: Icons.flatware),
        Category(id: 'fries', name: 'فنجر', icon: Icons.fastfood),
      ]);
    }
    return cats;
  }

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final rest = controller.activeRestaurant!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('restaurantId', isEqualTo: rest.id)
          .snapshots(),
      builder: (context, snapshot) {
        List<Product> liveProducts = controller.getProductsByRestaurant(
          rest.id,
        );
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          liveProducts = snapshot.data!.docs
              .map(
                (doc) =>
                    Product.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();
        }

        final categoryFiltered = controller.selectedCategoryId == 'all'
            ? liveProducts
            : controller.selectedCategoryId == 'favs'
            ? liveProducts
                  .where((p) => controller.isProductFavorite(p.id))
                  .toList()
            : liveProducts
                  .where((p) => p.categoryId == controller.selectedCategoryId || 
                         // دعم التوافقية القديمة
                         (p.categoryId == 'burger' && controller.selectedCategoryId == 'برجر') ||
                         (p.categoryId == 'pizza' && controller.selectedCategoryId == 'بيتزا'))
                  .toList();

        final filtered = _searchQuery.isEmpty
            ? categoryFiltered
            : categoryFiltered
                  .where(
                    (p) =>
                        p.name.contains(_searchQuery) ||
                        p.description.contains(_searchQuery),
                  )
                  .toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: Text(
              rest.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: context.dynamicWhite,
              ),
            ),
            leading: JeebliBackButton(
              onPressed: () => controller.setActiveRestaurant(null),
            ),
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  color: const Color(0xFF1E293B),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          rest.imageUrl,
                          width: 75,
                          height: 75,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Color(0xFFFF8F00),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rest.location,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.dynamicWhite70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rest.cuisine,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.dynamicWhite70,
                              ),
                            ),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${rest.rating}',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ساعات العمل: ${rest.workingHoursLabel}',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── شريط بحث داخل الوجبات ──
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: TextStyle(color: context.dynamicWhite, fontSize: 13),
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن وجبة في ${rest.name}...',
                        hintStyle: TextStyle(
                          color: context.dynamicWhite70,
                          fontSize: 12.5,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Color(0xFFFF8F00),
                          size: 18,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: context.dynamicWhite70,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 58,
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _buildCategories(controller).length,
                    itemBuilder: (context, i) {
                      final cat = _buildCategories(controller)[i];
                      final isSel = controller.selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: () => controller.setCategory(cat.id),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFFFF8F00)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 15,
                                  color: isSel ? context.dynamicWhite : context.dynamicWhite70,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSel
                                        ? context.dynamicWhite
                                        : context.dynamicWhite70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final prod = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.dynamicWhite.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  prod.imageUrl,
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    width: 88,
                                    height: 88,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (!prod.isAvailable)
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'خلصانة 🛑',
                                      style: TextStyle(
                                        color: context.dynamicWhite,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        prod.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: context.dynamicWhite,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => controller
                                          .toggleFavoriteProduct(prod.id),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          controller.isProductFavorite(prod.id)
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color:
                                              controller.isProductFavorite(
                                                prod.id,
                                              )
                                              ? Colors.redAccent
                                              : context.dynamicWhite70,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  prod.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: context.dynamicWhite70,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (prod.discountPrice != null &&
                                            prod.discountPrice! < prod.price)
                                          Text(
                                            '${prod.price.toStringAsFixed(0)} د.ع',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: context.dynamicWhite70,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        Text(
                                          '${(prod.discountPrice ?? prod.price).toStringAsFixed(0)} د.ع',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFF8F00),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (prod.isAvailable)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            controller.addToCart(prod, context),
                                        icon: Icon(
                                          Icons.add_shopping_cart,
                                          size: 13,
                                        ),
                                        label: Text(
                                          'أضف',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFF8F00,
                                          ),
                                          foregroundColor: context.dynamicWhite,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'نَفَدَت',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: filtered.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// 8. شاشة السلة
/// ============================================================================

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final restName = controller.cartItems.isNotEmpty
        ? controller.allRestaurants
              .firstWhere(
                (r) => r.id == controller.cartRestaurantId,
                orElse: () => controller.allRestaurants.first,
              )
              .name
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'سلة المشتريات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.dynamicWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: controller.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.orange.withOpacity(0.3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'السلة فارغة!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.dynamicWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تصفح قوائم الطعام وأضف وجباتك',
                    style: TextStyle(fontSize: 11, color: context.dynamicWhite70),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => controller.setTab(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8F00),
                      foregroundColor: context.dynamicWhite,
                    ),
                    child: Text('ابدأ التسوق'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFFF8F00).withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant,
                        color: Color(0xFFFF8F00),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تطلب من: $restName',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8F00),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.cartItems.length,
                    padding: const EdgeInsets.all(14),
                    itemBuilder: (context, i) {
                      final item = controller.cartItems[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: context.dynamicWhite.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                item.product.imageUrl,
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: context.dynamicWhite,
                                    ),
                                  ),
                                  if (item.product.discountPrice != null &&
                                      item.product.discountPrice! <
                                          item.product.price)
                                    Row(
                                      children: [
                                        Text(
                                          '${item.product.price.toStringAsFixed(0)} د.ع',
                                          style: TextStyle(
                                            color: context.dynamicWhite70,
                                            fontSize: 10,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.product.discountPrice!.toStringAsFixed(0)} د.ع',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      '${item.product.price.toStringAsFixed(0)} د.ع للوجبة',
                                      style: TextStyle(
                                        color: context.dynamicWhite70,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  Text(
                                    'الإجمالي: ${item.totalPrice.toStringAsFixed(0)} د.ع',
                                    style: TextStyle(
                                      color: Color(0xFFFF8F00),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => controller.removeFromCart(
                                        item.product,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: context.dynamicWhite,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: context.dynamicWhite,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => controller.addToCart(
                                        item.product,
                                        context,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFFF8F00,
                                          ).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color: Color(0xFFFF8F00),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () =>
                                      controller.deleteFromCart(item.product),
                                  child: Text(
                                    'حذف',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildOrderSummary(context, controller),
              ],
            ),
    );
  }

  Widget _buildOrderSummary(BuildContext context, JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مجموع الوجبات',
                style: TextStyle(color: context.dynamicWhite70, fontSize: 12.5),
              ),
              Text(
                '${controller.subtotal.toStringAsFixed(0)} د.ع',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.dynamicWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'توصيل جيب لي',
                style: TextStyle(color: context.dynamicWhite70, fontSize: 12.5),
              ),
              Text(
                '${controller.deliveryFee.toStringAsFixed(0)} د.ع',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.dynamicWhite,
                ),
              ),
            ],
          ),
          if (controller.loyaltyDiscount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🌟 خصم النقاط المستبدلة',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '-${controller.loyaltyDiscount.toStringAsFixed(0)} د.ع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ],

          if (controller.loyaltySystemEnabled) ...[
            const SizedBox(height: 10),
            // ── كارت استبدال النقاط ──
            GestureDetector(
              onTap: () => controller.toggleRedeemPoints(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: controller.redeemingPoints
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : const Color(0xFFFF8F00).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: controller.redeemingPoints
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF8F00).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      controller.redeemingPoints
                          ? Icons.check_circle_rounded
                          : Icons.stars_rounded,
                      color: controller.redeemingPoints
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF8F00),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.loyaltyPoints >=
                                    JeebliController.pointsPerReward
                                ? (controller.redeemingPoints
                                      ? 'تم تفعيل خصم 1,500 د.ع! 🎉'
                                      : 'استبدل 250 نقطة بخصم 1,500 د.ع 🎁')
                                : 'لديك ${controller.loyaltyPoints} نقطة (تحتاج ${controller.pointsNeededForReward} نقطة إضافية للخصم)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: controller.redeemingPoints
                                  ? context.dynamicWhite
                                  : (controller.loyaltyPoints >=
                                            JeebliController.pointsPerReward
                                        ? Colors.amber
                                        : context.dynamicWhite70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.loyaltyPoints >=
                        JeebliController.pointsPerReward)
                      Switch(
                        value: controller.redeemingPoints,
                        onChanged: (_) => controller.toggleRedeemPoints(),
                        activeColor: const Color(0xFF10B981),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Promo code removed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المبلغ الكلي',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: context.dynamicWhite,
                ),
              ),
              Text(
                '${controller.totalAmount.toStringAsFixed(0)} د.ع',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFFFF8F00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: CheckoutScreen(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: context.dynamicWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'إتمام الطلب والدفع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 9. شاشة الدفع (Checkout)
/// ============================================================================

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  final TextEditingController _streetDetailsController =
      TextEditingController();
  final TextEditingController _orderNotesController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final controller = JeebliProvider.of(context);
      _nameController.text = controller.customerName;
      _phoneController.text = controller.customerPhone;
      _neighborhoodController.text = controller.selectedNeighborhood;
      _streetDetailsController.text = controller.streetDetails;
      _orderNotesController.text = controller.orderNotes;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _neighborhoodController.dispose();
    _streetDetailsController.dispose();
    _orderNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'تأكيد الطلب والدفع',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.dynamicWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.isLocating
                      ? null
                      : () async {
                          final success = await controller.detectLocation();
                          if (!context.mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ تم تحديد إحداثيات موقعك الجغرافي بنجاح! سيتم إرسال رابط الخريطة للمندوب',
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '⚠️ تعذر تحديد الموقع تلقائياً. يمكنك كتابة موقعك يدويًا بكل سهولة.',
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: controller.isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        )
                      : Icon(
                          controller.customerLat != null
                              ? Icons.my_location_rounded
                              : Icons.location_searching_rounded,
                          color: controller.customerLat != null
                              ? Colors.greenAccent
                              : Colors.amber,
                          size: 20,
                        ),
                  label: Text(
                    controller.isLocating
                        ? 'جاري تحديد موقعك الـ GPS...'
                        : (controller.customerLat != null
                              ? 'موقعك الـ GPS محدد بنجاح ✅ (إعادة التحديد)'
                              : '📍 حدد موقعي الجغرافي الـ GPS تلقائياً'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: controller.customerLat != null
                          ? Colors.greenAccent
                          : Colors.amber,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: controller.customerLat != null
                            ? Colors.greenAccent.withOpacity(0.5)
                            : Colors.amber.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ),
              _sectionTitle('🏠 بيانات التوصيل'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'الاسم الكامل',
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'الرجاء إدخال الاسم'
                          : null,
                      onChanged: (v) {
                        controller.customerName = v;
                        controller.saveSession();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hint: '07800000000',
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'يرجى كتابة رقم هاتف صحيح';
                        }
                        final phoneRegex = RegExp(r'^07[578]\d{8}$');
                        if (!phoneRegex.hasMatch(trimmed)) {
                          return 'يرجى كتابة رقم هاتف صحيح (11 رقماً يبدأ بـ 077 أو 078 أو 075)';
                        }
                        return null;
                      },
                      onChanged: (v) {
                        controller.customerPhone = v;
                        controller.saveSession();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _neighborhoodController,
                      style: TextStyle(color: context.dynamicWhite),
                      onChanged: (value) {
                        controller.selectedNeighborhood = value;
                        controller.saveSession();
                      },
                      decoration: InputDecoration(
                        labelText: 'المنطقة / الحي',
                        labelStyle: TextStyle(color: context.dynamicWhite70),
                        hintText: 'اكتب اسم المنطقة أو الحي...',
                        hintStyle: TextStyle(color: Colors.white30),
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          color: Colors.amber,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF8F00),
                          ),
                        ),
                        filled: true,
                        fillColor: context.dynamicWhite.withOpacity(0.05),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _streetDetailsController,
                      label: 'أقرب نقطة دالة',
                      icon: Icons.home_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'الرجاء إدخال نقطة دالة'
                          : null,
                      onChanged: (v) {
                        controller.streetDetails = v;
                        controller.saveSession();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _orderNotesController,
                      label: 'ملاحظات الطلب (اختياري)',
                      icon: Icons.note_alt_outlined,
                      hint: 'مثال: بدون ثومية، تثقيل صوص، حار...',
                      validator: (v) => null,
                      onChanged: (v) => controller.orderNotes = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('💵 طريقة الدفع'),
              const SizedBox(height: 10),
              // كاش عند الاستلام فقط
              _paymentOption(
                icon: Icons.payments_rounded,
                label: 'كاش عند الاستلام',
                subtitle: 'ادفع لحظة وصول المندوب',
                isSelected: true,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildSecurityBadge(),
              const SizedBox(height: 20),
              _buildOrderSummaryCard(controller),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    _showOrderReviewConfirmationDialog(context, controller);
                  },
                  icon: Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    'إرسال الطلب للمطعم 🚀',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: context.dynamicWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14.5,
      color: context.dynamicWhite,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    required String? Function(String?) validator,
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.dynamicWhite),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: context.dynamicWhite70),
        hintStyle: TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, size: 20, color: Colors.amber),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8F00)),
        ),
        filled: true,
        fillColor: context.dynamicWhite.withOpacity(0.05),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _paymentOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF8F00).withOpacity(0.1)
              : const Color(0xFF1E293B),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8F00) : Colors.white24,
            width: 1.8,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF8F00) : context.dynamicWhite70,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFFF8F00) : context.dynamicWhite70,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9.5, color: context.dynamicWhite70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMastercardForm(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'بيانات الماستركارد',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.dynamicWhite,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEB001B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF79E1B).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            keyboardType: TextInputType.number,
            maxLength: 16,
            style: TextStyle(color: context.dynamicWhite, letterSpacing: 2),
            decoration: InputDecoration(
              labelText: 'رقم البطاقة',
              hintText: 'XXXX XXXX XXXX XXXX',
              labelStyle: TextStyle(color: context.dynamicWhite70),
              hintStyle: TextStyle(color: Colors.white30),
              prefixIcon: Icon(
                Icons.credit_card,
                color: context.dynamicWhite70,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFF8F00)),
              ),
              filled: true,
              fillColor: context.dynamicWhite.withOpacity(0.05),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  style: TextStyle(color: context.dynamicWhite),
                  decoration: InputDecoration(
                    labelText: 'تاريخ الانتهاء',
                    hintText: 'MM/YY',
                    labelStyle: TextStyle(color: context.dynamicWhite70),
                    hintStyle: TextStyle(color: Colors.white30),
                    prefixIcon: Icon(
                      Icons.calendar_month_outlined,
                      color: context.dynamicWhite70,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFFB300)),
                    ),
                    filled: true,
                    fillColor: context.dynamicWhite.withOpacity(0.07),
                  ),
                  onChanged: (v) => controller.cardExpiry = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  maxLength: 3,
                  obscureText: true,
                  style: TextStyle(color: context.dynamicWhite),
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '***',
                    labelStyle: TextStyle(color: context.dynamicWhite70),
                    hintStyle: TextStyle(color: Colors.white30),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: context.dynamicWhite70,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFFB300)),
                    ),
                    counterStyle: TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: context.dynamicWhite.withOpacity(0.07),
                  ),
                  onChanged: (v) => controller.cardCvv = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'محمي بتشفير جيب لي 🔒',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'يتم تشفير بياناتك ومراجعة سلامة أسعار طلبك ضد التلاعب تلقائياً.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.green.shade300,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(JeebliController controller) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.dynamicWhite.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مجموع الوجبات',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 12),
                  ),
                  Text(
                    '${controller.subtotal.toStringAsFixed(0)} د.ع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.dynamicWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'توصيل جيب لي',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 12),
                  ),
                  Text(
                    '${controller.deliveryFee.toStringAsFixed(0)} د.ع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.dynamicWhite,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18, color: Colors.white12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإجمالي الكلي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.dynamicWhite,
                    ),
                  ),
                  Text(
                    '${controller.totalAmount.toStringAsFixed(0)} د.ع',
                    style: TextStyle(
                      color: Color(0xFFFF8F00),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOrderReviewConfirmationDialog(
    BuildContext context,
    JeebliController controller,
  ) {
    final hasGps =
        controller.customerLat != null && controller.customerLng != null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.assignment_turned_in_rounded,
                color: Color(0xFFFF8F00),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'مراجعة وتأكيد الطلب 📋',
                style: TextStyle(
                  color: context.dynamicWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يرجى التأكد من صحة بيانات التوصيل قبل الإرسال:',
                  style: TextStyle(color: context.dynamicWhite70, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.dynamicWhite.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'الاسم: ${controller.customerName}',
                              style: TextStyle(
                                color: context.dynamicWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'الهاتف: ${controller.customerPhone}',
                              style: TextStyle(
                                color: context.dynamicWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'العنوان: ${controller.selectedNeighborhood} - ${controller.streetDetails}',
                              style: TextStyle(
                                color: context.dynamicWhite70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            hasGps
                                ? Icons.gps_fixed_rounded
                                : Icons.gps_off_rounded,
                            color: hasGps
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hasGps
                                  ? 'موقع الخريطة: محدد بنجاح 📍'
                                  : 'موقع الخريطة: غير محدد (سيتم التوصيل حسب العنوان المكتوب)',
                              style: TextStyle(
                                color: hasGps
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المبلغ الكلي:',
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${controller.totalAmount.toStringAsFixed(0)} د.ع',
                            style: TextStyle(
                              color: Color(0xFFFF8F00),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'تعديل ✏️',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                controller.saveSession();
                await controller.completeOrderAndResetHome();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: MainNavigationShell(),
                    ),
                  ),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🎉 تم إرسال طلبك بنجاح للمطعم! متابعة الطلب حية بأسفل الشاشة.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: context.dynamicWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'تأكيد وإرسال ✅',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 10. شاشة التتبع الحي
/// ============================================================================

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _bikeController;
  late AnimationController _pulseController;
  late Animation<double> _bikeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _bikeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _bikeAnim = Tween<double>(begin: 0.05, end: 0.85).animate(
      CurvedAnimation(parent: _bikeController, curve: Curves.easeInOut),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bikeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final minutes = controller.deliveryCountdown ~/ 60;
    final seconds = controller.deliveryCountdown % 60;
    final isArrived = controller.orderStatus == OrderStatus.arrived;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'تتبع الطلب المباشر 🛵',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.dynamicWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: JeebliBackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 250,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    CustomPaint(painter: _MapGridPainter(), child: Container()),
                    CustomPaint(painter: _RoutePainter(), child: Container()),
                    Positioned(
                      top: 40,
                      right: 40,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.store,
                          color: context.dynamicWhite,
                          size: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 40,
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE65100),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.home,
                            color: context.dynamicWhite,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _bikeController,
                      builder: (context, child) {
                        final t = _bikeAnim.value;
                        final double x = 40 + (250 - 80) * (1 - t);
                        final double y = 40 + (250 - 80) * t;
                        return Positioned(
                          left: x,
                          top: y,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB300),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delivery_dining,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الوقت المتبقي المقدر:',
                        style: TextStyle(color: context.dynamicWhite70, fontSize: 13),
                      ),
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8F00),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8F00).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Color(0xFFFF8F00),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getStatusText(controller.orderStatus),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: context.dynamicWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      Icons.person,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.driverName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: context.dynamicWhite,
                          ),
                        ),
                        Text(
                          'مندوب توصيل جيب لي السريع',
                          style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.phone, color: Colors.green),
                    onPressed: () =>
                        launchUrl(Uri.parse('tel:${controller.driverPhone}')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (isArrived) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Directionality(
                                textDirection: TextDirection.rtl,
                                child: RatingScreen(),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'انتقل لتقييم الوجبة والمندوب ⭐',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: context.dynamicWhite70,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'توكن أمان الطلب المشفر',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: context.dynamicWhite70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          controller.lastOrderToken,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: context.dynamicWhite70,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'تم تأكيد طلبك بنجاح من المطعم. جاري التحضير...';
      case OrderStatus.preparing:
        return 'المطعم يقوم بتحضير وجبتك اللذيذة الآن.';
      case OrderStatus.onWay:
        return 'المندوب استلم وجبتك الحارة وهو في الطريق إليك!';
      case OrderStatus.arrived:
        return 'وصل المندوب إلى موقعك! يرجى الاستلام وبالعافية.';
      default:
        return 'جاري معالجة الطلب...';
    }
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFB300).withOpacity(0.4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(size.width * 0.85, size.height * 0.15);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.5,
      size.width * 0.15,
      size.height * 0.8,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ============================================================================
/// 11. شاشة التقييم
/// ============================================================================

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'قيّم تجربتك معنا ⭐',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.dynamicWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildRatingCard(
              title: 'تقييم المطعم 🍔',
              subtitle: controller.activeRestaurant?.name ?? 'المطعم',
              icon: Icons.restaurant,
              iconColor: const Color(0xFFFF8F00),
              currentRating: controller.restaurantRating,
              onRatingChanged: (r) =>
                  setState(() => controller.restaurantRating = r),
            ),
            const SizedBox(height: 16),
            _buildRatingCard(
              title: 'تقييم المندوب 🛵',
              subtitle: controller.driverName,
              icon: Icons.delivery_dining,
              iconColor: Colors.blue,
              currentRating: controller.driverRating,
              onRatingChanged: (r) =>
                  setState(() => controller.driverRating = r),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملاحظاتك وشكاواك 📝',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.dynamicWhite,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    maxLines: 4,
                    style: TextStyle(color: context.dynamicWhite),
                    decoration: InputDecoration(
                      hintText: 'أخبرنا برأيك بصدق...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: context.dynamicWhite70,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFF8F00)),
                      ),
                      filled: true,
                      fillColor: context.dynamicWhite.withOpacity(0.05),
                    ),
                    onChanged: (v) => controller.feedbackText = v,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              'وجبة لذيذة 😋',
                              'توصيل سريع ⚡',
                              'مندوب محترم 👍',
                              'سعر مناسب 💰',
                              'تأخر التوصيل ⏰',
                              'وجبة باردة ❄️',
                            ]
                            .map(
                              (tag) => GestureDetector(
                                onTap: () {
                                  controller.playFeedbackSound();
                                  setState(
                                    () => controller.feedbackText += ' $tag',
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFF8F00,
                                      ).withOpacity(0.4),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    color: const Color(
                                      0xFFFF8F00,
                                    ).withOpacity(0.08),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFFF8F00),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.restaurantRating == 0 ||
                      controller.driverRating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى تقييم المطعم والمندوب قبل الإرسال'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  controller.submitRating();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Directionality(
                        textDirection: TextDirection.rtl,
                        child: ThankYouScreen(),
                      ),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'إرسال التقييم وإغلاق الطلب ✅',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double currentRating,
    required void Function(double) onRatingChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.dynamicWhite,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starVal = (i + 1).toDouble();
              return GestureDetector(
                onTap: () => onRatingChanged(starVal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    currentRating >= starVal
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: currentRating >= starVal
                        ? Colors.amber
                        : Colors.white24,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            currentRating == 0 ? 'اضغط لتقييم' : _ratingLabel(currentRating),
            style: TextStyle(
              color: currentRating == 0
                  ? context.dynamicWhite70
                  : const Color(0xFFFF8F00),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 5) return 'ممتاز جداً ⭐⭐⭐⭐⭐';
    if (rating >= 4) return 'جيد جداً 👍';
    if (rating >= 3) return 'مقبول';
    if (rating >= 2) return 'ضعيف';
    return 'سيء جداً';
  }
}

/// ============================================================================
/// 12. شاشة شكراً
/// ============================================================================

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE65100), Color(0xFFFFB300)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: context.dynamicWhite,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'شكراً لتقييمك! ❤️',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.dynamicWhite,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'آراؤكم تساعدنا في تطوير "جيب لي" وتقديم أفضل خدمة توصيل دائماً ⭐️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.dynamicWhite70,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              size: 14,
                              color: i < controller.restaurantRating
                                  ? Colors.amber
                                  : Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المطعم',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.dynamicWhite,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Colors.white12),
                    Column(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              size: 14,
                              color: i < controller.driverRating
                                  ? Colors.amber
                                  : Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المندوب',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.dynamicWhite,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    controller.resetToHome();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Directionality(
                          textDirection: TextDirection.rtl,
                          child: MainNavigationShell(),
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: context.dynamicWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'طلب وجبة جديدة 🍔',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 13. دالة الترحيب
/// ============================================================================

void showWelcomeDialog(BuildContext context, String userRole) {
  if (userRole == 'customer') {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: context.dynamicWhite,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'أهلاً بك في جيب لي 🖐️',
                    style: TextStyle(
                      color: context.dynamicWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'تصفح أفضل المطاعم القريبة منك، واطلب وجبتك المفضلة وتصلك فوراً بأسرع وقت ⚡',
                    style: TextStyle(
                      color: context.dynamicWhite70,
                      fontSize: 13,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8F00),
                        foregroundColor: context.dynamicWhite,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'اكتشف المطاعم الآن 🚀',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// 14. لوحة تحكم المطعم (Restaurant Owner)
/// ============================================================================

class RestaurantOrdersNotifScreen extends StatelessWidget {
  const RestaurantOrdersNotifScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final restId = controller.userRestaurantId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'الطلبات الواردة 🔔',
          style: TextStyle(color: context.dynamicWhite, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E293B),
        leading: const JeebliBackButton(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantId', isEqualTo: restId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'لا توجد طلبات جديدة حالياً.',
                style: TextStyle(color: context.dynamicWhite70),
              ),
            );
          }
          final orders = snapshot.data!.docs;
          return ListView.builder(
            itemCount: orders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              final custName = data['customerName'] ?? 'مجهول';
              final total = data['totalAmount']?.toString() ?? '0';
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.receipt_long,
                    color: Colors.amber,
                    size: 30,
                  ),
                  title: Text(
                    'طلب جديد من: $custName',
                    style: TextStyle(
                      color: context.dynamicWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'الإجمالي: $total د.ع\nرقم الطلب: ${doc.id.substring(0, 6)}',
                    style: TextStyle(color: context.dynamicWhite70),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: context.dynamicWhite70,
                    size: 16,
                  ),
                  isThreeLine: true,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الرجاء الذهاب إلى لوحة التحكم لقبول الطلب.',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ============================================================================

class RestaurantOwnerAdminScreen extends StatelessWidget {
  const RestaurantOwnerAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'لوحة تحكم المطعم ⚙️',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.dynamicWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('restaurantId', isEqualTo: controller.userRestaurantId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              int pendingCount = 0;
              if (snapshot.hasData) pendingCount = snapshot.data!.docs.length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.amber,
                    ),
                    tooltip: 'الطلبات الواردة',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RestaurantOrdersNotifScreen(),
                      ),
                    ),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$pendingCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.dynamicWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: Colors.amber),
            tooltip: 'تعديل بيانات المطعم',
            onPressed: () => _showOwnerEditRestaurantDialog(
              context,
              controller,
              controller.userRestaurantId ?? 'akkala',
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(context, controller),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOwnerProductDialog(
          context,
          controller,
          controller.userRestaurantId ?? 'akkala',
        ),
        backgroundColor: const Color(0xFFFF8F00),
        icon: Icon(Icons.add, color: context.dynamicWhite),
        label: Text(
          'إضافة وجبة',
          style: TextStyle(color: context.dynamicWhite, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'يمكنك هنا إدارة قائمة مطعمك (إضافة، تعديل، حذف) والتحكم بتوفر الوجبات والإحصائيات.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: context.dynamicWhite70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ─── بطاقة حالة المطعم (مفتوح / مغلق) ───
          _buildRestaurantStatusCard(context, controller),
          const SizedBox(height: 16),
          // 🔔 الطلبات الواردة من الزبائن (Real-time)
          _buildIncomingOrdersCard(context, controller),
          const SizedBox(height: 16),
          _buildRestaurantLocationCard(context, controller),
          const SizedBox(height: 16),
          _buildOwnerOffersCard(context, controller),
          const SizedBox(height: 16),
          _buildVendorAnalyticsCard(
            context,
            controller,
            controller.userRestaurantId ?? 'akkala',
          ),
          const SizedBox(height: 18),
          _buildManageDriversCard(context, controller),
          const SizedBox(height: 18),
          // ─── عرض مطعم صاحبه فقط حسب الـ ID ───
          Builder(
            builder: (ctx) {
              final myId = controller.userRestaurantId ?? '';
              final myRest = controller.allRestaurants
                  .where((r) => r.id == myId)
                  .toList();
              if (myRest.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.store_mall_directory_outlined,
                          color: Colors.white30,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لم يتم العثور على مطعمك.\nتواصل مع الإدارة.',
                          style: TextStyle(color: context.dynamicWhite70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return _buildRestSection(
                ctx,
                controller,
                myId,
                myRest.first.name,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 🛵 بطاقة إدارة المندوبين
  Widget _buildManageDriversCard(
    BuildContext context,
    JeebliController controller,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ManageDriversScreen(
              restaurantId: controller.userRestaurantId ?? '',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.lightBlueAccent.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.two_wheeler_rounded,
              color: Colors.lightBlueAccent,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة المندوبين',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'عرض المندوبين الخاصين بك، تعديل بياناتهم، أو حذفهم',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.lightBlueAccent,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة تحكم حالة المطعم مفتوح / مغلق
  Widget _buildRestaurantStatusCard(
    BuildContext context,
    JeebliController controller,
  ) {
    final restId = controller.userRestaurantId ?? 'akkala';
    final restaurant = controller.allRestaurants.firstWhere(
      (r) => r.id == restId,
      orElse: () => controller.allRestaurants.first,
    );

    final isClosedManually = restaurant.isClosedManually;
    final isClosedByTime = !restaurant.isOpenNow && !isClosedManually;
    final isCurrentlyClosed = !restaurant.isOpenNow; // الحالة الفعلية الآن

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentlyClosed
              ? [const Color(0xFF3D0000), const Color(0xFF1E293B)]
              : [const Color(0xFF003D1E), const Color(0xFF1E293B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentlyClosed
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.greenAccent.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCurrentlyClosed ? Colors.red : Colors.green).withOpacity(
              0.15,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (isCurrentlyClosed
                              ? Colors.redAccent
                              : Colors.greenAccent)
                          .withOpacity(0.15),
                  border: Border.all(
                    color: isCurrentlyClosed
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isCurrentlyClosed
                      ? Icons.store_mall_directory_outlined
                      : Icons.storefront_rounded,
                  color: isCurrentlyClosed
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClosedManually
                          ? '🔴 مغلق حالياً (إغلاق إجباري يدوي)'
                          : isClosedByTime
                          ? '🔴 مغلق حالياً (خارج أوقات العمل)'
                          : '🟢 مطعمك مفتوح للطلبات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCurrentlyClosed
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCurrentlyClosed
                          ? 'الزبائن لا يستطيعون الطلب الآن'
                          : 'الزبائن يستطيعون الطلب منك الآن',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.dynamicWhite70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // التوجل الخاص بالإغلاق اليدوي (يتحكم فقط في isClosedManually)
              GestureDetector(
                onTap: () => controller.toggleRestaurantClosed(restId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 64,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isClosedManually
                        ? Colors.redAccent.withOpacity(0.3)
                        : Colors.white12, // لون محايد إذا لم يكن مغلق يدوياً
                    border: Border.all(
                      color: isClosedManually
                          ? Colors.redAccent
                          : Colors.white30,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        alignment: isClosedManually
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isClosedManually
                                ? Colors.redAccent
                                : Colors.grey,
                          ),
                          child: Icon(
                            isClosedManually ? Icons.lock : Icons.lock_open,
                            size: 14,
                            color: context.dynamicWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                color: context.dynamicWhite70,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'ساعات العمل: ',
                style: TextStyle(color: context.dynamicWhite70, fontSize: 12),
              ),
              Text(
                restaurant.workingHoursLabel,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بطاقة إلقاط وتحديث موقع المطعم الإحداثي (GPS)
  Widget _buildRestaurantLocationCard(
    BuildContext context,
    JeebliController controller,
  ) {
    final restId = controller.userRestaurantId ?? '';
    final rest = controller.allRestaurants.firstWhere(
      (r) => r.id == restId,
      orElse: () => controller.allRestaurants.first,
    );
    final hasLoc = rest.restaurantLat != null && rest.restaurantLng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Colors.amber,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'موقع المطعم الجغرافي (GPS) 📍',
                      style: TextStyle(
                        color: context.dynamicWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'تحديد الموقع بدقة يظهر مطعمك للزبائن القريبين أولاً',
                      style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLoc)
            Text(
              'الإحداثيات الحالية: ${rest.restaurantLat!.toStringAsFixed(4)}, ${rest.restaurantLng!.toStringAsFixed(4)}',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final success = await controller.detectLocation();
                if (!context.mounted) return;
                if (success &&
                    controller.customerLat != null &&
                    controller.customerLng != null) {
                  controller.updateRestaurantLocation(
                    rest.id,
                    controller.customerLat!,
                    controller.customerLng!,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم حفظ موقع المطعم الجغرافي بنجاح!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '⚠️ تعذر التقاط الموقع، تأكد من تفعيل الـ GPS بالجهاز',
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: Icon(
                Icons.my_location_rounded,
                color: context.dynamicWhite,
                size: 18,
              ),
              label: Text(
                hasLoc
                    ? 'تحديث موقع المطعم الحقيقي (GPS)'
                    : 'التقاط موقع المطعم الحالي (GPS)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.dynamicWhite,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة إدارة عروض وتخفيضات المطعم
  Widget _buildOwnerOffersCard(
    BuildContext context,
    JeebliController controller,
  ) {
    final restId = controller.userRestaurantId ?? '';
    final myOffers = controller.allOffers
        .where((o) => o.restaurantId == restId)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    color: Colors.purpleAccent,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'عروض وتخفيضات المطعم 🎁',
                    style: TextStyle(
                      color: context.dynamicWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddOfferDialog(context, controller, restId),
                icon: Icon(Icons.add, size: 16, color: context.dynamicWhite),
                label: Text(
                  'إضافة عرض',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.dynamicWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (myOffers.isEmpty)
            Text(
              'لا توجد عروض نشطة حالياً. أضف عرضك ليظهر للزبائن في أعلى التطبيق!',
              style: TextStyle(color: context.dynamicWhite70, fontSize: 11),
            )
          else
            Column(
              children: myOffers.map((offer) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.dynamicWhite.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomAppImage(
                          imageUrl: offer.imageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.title,
                              style: TextStyle(
                                color: context.dynamicWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              offer.discountTag,
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          offer.isActive
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: offer.isActive
                              ? Colors.greenAccent
                              : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => controller.toggleOfferActive(offer.id),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => controller.deleteOffer(offer.id),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showAddOfferDialog(
    BuildContext context,
    JeebliController controller,
    String restId,
  ) {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final tagC = TextEditingController(text: 'عرض خاص 🔥');
    final imgC = TextEditingController();
    final rest = controller.allRestaurants.firstWhere(
      (r) => r.id == restId,
      orElse: () => controller.allRestaurants.first,
    );

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'إضافة عرض جديد 🎁',
            style: TextStyle(color: context.dynamicWhite, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleC,
                  style: TextStyle(color: context.dynamicWhite),
                  decoration: InputDecoration(
                    labelText: 'عنوان العرض (مثال: وجبة عائلية)',
                    labelStyle: TextStyle(color: context.dynamicWhite70),
                  ),
                ),
                TextField(
                  controller: descC,
                  style: TextStyle(color: context.dynamicWhite),
                  decoration: InputDecoration(
                    labelText: 'تفاصيل العرض',
                    labelStyle: TextStyle(color: context.dynamicWhite70),
                  ),
                ),
                TextField(
                  controller: tagC,
                  style: TextStyle(color: context.dynamicWhite),
                  decoration: InputDecoration(
                    labelText: 'شارة العرض (مثل: خصم 20% / توفير)',
                    labelStyle: TextStyle(color: context.dynamicWhite70),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imgC,
                        style: TextStyle(color: context.dynamicWhite),
                        decoration: InputDecoration(
                          labelText: 'رابط صورة العرض',
                          labelStyle: TextStyle(color: context.dynamicWhite70),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.photo_library,
                        color: Colors.amber,
                      ),
                      onPressed: () {
                        showImagePickerOptions(context, (pathOrUrl) {
                          imgC.text = pathOrUrl;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleC.text.trim().isEmpty) return;
                final newOffer = Offer(
                  id: 'off_${DateTime.now().millisecondsSinceEpoch}',
                  restaurantId: restId,
                  restaurantName: rest.name,
                  title: titleC.text.trim(),
                  description: descC.text.trim(),
                  discountTag: tagC.text.trim(),
                  imageUrl: imgC.text.trim().isEmpty
                      ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80'
                      : imgC.text.trim(),
                );
                controller.addOffer(newOffer);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم نشر العرض بنجاح!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: context.dynamicWhite,
              ),
              child: Text(
                'نشر العرض 🚀',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔔 بطاقة الطلبات الواردة Real-time من Firestore
  Widget _buildIncomingOrdersCard(
    BuildContext context,
    JeebliController controller,
  ) {
    final myId = controller.userRestaurantId ?? '';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8F00).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFFF8F00),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'الطلبات الواردة 🔔',
                  style: TextStyle(
                    color: context.dynamicWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8F00).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF8F00).withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    'مباشر 🔴',
                    style: TextStyle(
                      color: Color(0xFFFF8F00),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('restaurantId', isEqualTo: myId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF8F00),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              var docs = snapshot.data?.docs ?? [];

              // ترتيب تنازلي حسب وقت الإنشاء برمجياً لتجنب مشاكل الـ Index في فايربيس
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final timeA = dataA['createdAt'] as Timestamp?;
                final timeB = dataB['createdAt'] as Timestamp?;
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                return timeB.compareTo(timeA);
              });

              // عرض أحدث 15 طلب فقط
              if (docs.length > 15) {
                docs = docs.take(15).toList();
              }

              if (docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'لا توجد طلبات واردة حتى الآن 📭',
                      style: TextStyle(color: context.dynamicWhite70, fontSize: 13),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final total = (data['totalAmount'] ?? 0).toStringAsFixed(0);
                  final customer = data['customerName'] ?? '---';
                  final phone = data['customerPhone'] ?? '';
                  final neighborhood = data['neighborhood'] ?? '';
                  final streetDetails = data['streetDetails'] ?? '';
                  final items = (data['items'] as List<dynamic>?) ?? [];
                  final custLat = data['customerLat'];
                  final custLng = data['customerLng'];
                  final hasLocation = custLat != null && custLng != null;

                  // ignore: unused_local_variable
                  final orderId = data['orderId'] ?? docs[index].id;

                  Color statusColor;
                  String statusLabel;
                  switch (status) {
                    case 'accepted':
                      statusColor = Colors.greenAccent;
                      statusLabel = '✅ مقبول';
                      break;
                    case 'rejected':
                      statusColor = Colors.redAccent;
                      statusLabel = '❌ مرفوض';
                      break;
                    case 'delivered':
                      statusColor = Colors.blueAccent;
                      statusLabel = '🛵 تم التوصيل';
                      break;
                    default:
                      statusColor = Colors.orangeAccent;
                      statusLabel = '⏳ جديد';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$customer  •  $neighborhood',
                                style: TextStyle(
                                  color: context.dynamicWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Text(
                                        'تأكيد الحذف',
                                        style: TextStyle(color: context.dynamicWhite),
                                      ),
                                      content: Text(
                                        'هل أنت متأكد من حذف هذا الطلب نهائياً؟',
                                        style: TextStyle(color: context.dynamicWhite70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(
                                            'إلغاء',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            'حذف',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (confirm == true) {
                                  await docs[index].reference.delete();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم حذف الطلب بنجاح 🗑️'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (streetDetails.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'أقرب نقطة دالة: $streetDetails',
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '📞 $phone  |  💰 $total د.ع',
                              style: TextStyle(
                                color: context.dynamicWhite70,
                                fontSize: 11.5,
                              ),
                            ),
                            const Spacer(),
                            if (data['createdAt'] != null &&
                                data['createdAt'] is Timestamp)
                              Text(
                                '${(data['createdAt'] as Timestamp).toDate().hour}:${(data['createdAt'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: context.dynamicWhite70,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        if (hasLocation) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final mapUri = Uri.parse(
                                  'https://maps.google.com/?q=$custLat,$custLng',
                                );
                                if (await canLaunchUrl(mapUri)) {
                                  launchUrl(
                                    mapUri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: Icon(
                                Icons.map_rounded,
                                size: 14,
                                color: Color(0xFFFF8F00),
                              ),
                              label: Text(
                                '📍 فتح موقع الزبون على الخريطة',
                                style: TextStyle(
                                  color: Color(0xFFFF8F00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: const Color(
                                    0xFFFF8F00,
                                  ).withOpacity(0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '📋 تفاصيل الطلب:',
                          style: TextStyle(
                            color: context.dynamicWhite70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...items.map((item) {
                          final iMap = item as Map<String, dynamic>;
                          final iName = iMap['name'] ?? '';
                          final iQty = iMap['qty'] ?? 1;
                          final iPrice = (iMap['price'] ?? 0).toStringAsFixed(
                            0,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF8F00,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$iQty',
                                    style: TextStyle(
                                      color: Color(0xFFFF8F00),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    iName,
                                    style: TextStyle(
                                      color: context.dynamicWhite70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$iPrice د.ع',
                                  style: TextStyle(
                                    color: context.dynamicWhite70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        if (status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final driverNameCtrl =
                                        TextEditingController();
                                    final driverPhoneCtrl =
                                        TextEditingController();
                                    final driverPassCtrl =
                                        TextEditingController(text: '123456');
                                    final docRef = docs[index].reference;
                                    final customerName2 =
                                        data['customerName'] ?? '';
                                    await showDialog(
                                      context: context,
                                      builder: (ctx) => Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF1E293B,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          title: Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.greenAccent
                                                      .withOpacity(0.1),
                                                  border: Border.all(
                                                    color: Colors.greenAccent
                                                        .withOpacity(0.4),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.delivery_dining_rounded,
                                                  color: Colors.greenAccent,
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'تعيين مندوب التوصيل',
                                                style: TextStyle(
                                                  color: context.dynamicWhite,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'طلب: $customerName2',
                                                style: TextStyle(
                                                  color: context.dynamicWhite70,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Divider(
                                                color: Colors.white12,
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: driverNameCtrl,
                                                style: TextStyle(
                                                  color: context.dynamicWhite,
                                                ),
                                                textDirection:
                                                    TextDirection.rtl,
                                                decoration: InputDecoration(
                                                  hintText: 'اسم المندوب',
                                                  hintStyle: TextStyle(
                                                    color: context.dynamicWhite70,
                                                  ),
                                                  prefixIcon: Icon(
                                                    Icons.person_rounded,
                                                    color: Color(0xFFFF8F00),
                                                    size: 18,
                                                  ),
                                                  filled: true,
                                                  fillColor: context.dynamicWhite
                                                      .withOpacity(0.05),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color: context.dynamicWhite
                                                          .withOpacity(0.1),
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: context.dynamicWhite
                                                              .withOpacity(0.1),
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Color(
                                                                0xFFFF8F00,
                                                              ),
                                                            ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: driverPhoneCtrl,
                                                style: TextStyle(
                                                  color: context.dynamicWhite,
                                                ),
                                                keyboardType:
                                                    TextInputType.phone,
                                                textDirection:
                                                    TextDirection.rtl,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'رقم هاتف المندوب (07...)',
                                                  hintStyle: TextStyle(
                                                    color: context.dynamicWhite70,
                                                  ),
                                                  prefixIcon: Icon(
                                                    Icons.phone_rounded,
                                                    color: Color(0xFFFF8F00),
                                                    size: 18,
                                                  ),
                                                  filled: true,
                                                  fillColor: context.dynamicWhite
                                                      .withOpacity(0.05),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color: context.dynamicWhite
                                                          .withOpacity(0.1),
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: context.dynamicWhite
                                                              .withOpacity(0.1),
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Color(
                                                                0xFFFF8F00,
                                                              ),
                                                            ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: driverPassCtrl,
                                                style: TextStyle(
                                                  color: context.dynamicWhite,
                                                ),
                                                textDirection:
                                                    TextDirection.ltr,
                                                decoration: InputDecoration(
                                                  hintText: 'كلمة سر المندوب',
                                                  hintStyle: TextStyle(
                                                    color: context.dynamicWhite70,
                                                  ),
                                                  prefixIcon: Icon(
                                                    Icons.lock_rounded,
                                                    color: Color(0xFFFF8F00),
                                                    size: 18,
                                                  ),
                                                  filled: true,
                                                  fillColor: context.dynamicWhite
                                                      .withOpacity(0.05),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color: context.dynamicWhite
                                                          .withOpacity(0.1),
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: context.dynamicWhite
                                                              .withOpacity(0.1),
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Color(
                                                                0xFFFF8F00,
                                                              ),
                                                            ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'سيتم إرسال الطلب لهذا المندوب فوراً وإنشاء حساب له إذا لم يكن موجوداً.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: context.dynamicWhite70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                          actionsAlignment:
                                              MainAxisAlignment.center,
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: Text(
                                                'إلغاء',
                                                style: TextStyle(
                                                  color: context.dynamicWhite70,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () async {
                                                final dName = driverNameCtrl
                                                    .text
                                                    .trim();
                                                final dPhone = driverPhoneCtrl
                                                    .text
                                                    .trim();
                                                final dPass = driverPassCtrl
                                                    .text
                                                    .trim();
                                                if (dName.isEmpty ||
                                                    dPhone.isEmpty ||
                                                    dPass.isEmpty)
                                                  return;
                                                await docRef.update({
                                                  'status': 'preparing',
                                                  'driverName': dName,
                                                  'driverPhone': dPhone,
                                                  'acceptedAt':
                                                      FieldValue.serverTimestamp(),
                                                });

                                                // إنشاء حساب للمندوب في قاعدة البيانات الموحدة
                                                await FirebaseFirestore.instance
                                                    .collection(
                                                      'admin_credentials',
                                                    )
                                                    .doc(dPhone)
                                                    .set({
                                                      'role': 'driver',
                                                      'name': dName,
                                                      'phone': dPhone,
                                                      'password': dPass,
                                                      'restaurantId':
                                                          controller
                                                              .userRestaurantId ??
                                                          '',
                                                    }, SetOptions(merge: true));

                                                // 🔔 إشعار للزبون عبر OneSignal
                                                final orderData =
                                                    (await docRef.get()).data()
                                                        as Map<
                                                          String,
                                                          dynamic
                                                        >? ??
                                                    {};
                                                final custUid =
                                                    orderData['deviceUid']
                                                        ?.toString() ??
                                                    '';
                                                if (context.mounted) {
                                                  JeebliProvider.of(
                                                    context,
                                                  )._notifyCustomer(
                                                    custDeviceUid: custUid,
                                                    title:
                                                        '👨‍🍳 المطعم قبل طلبك!',
                                                    body:
                                                        'وجبتك قيد التحضير الآن! المندوب: $dName',
                                                    orderId: docRef.id,
                                                  );
                                                }
                                                // 🔔 إشعار لجميع مندوبي المطعم عبر OneSignal
                                                if (context.mounted) {
                                                  JeebliProvider.of(
                                                    context,
                                                  )._notifyAllDrivers(
                                                    restaurantId:
                                                        controller
                                                            .userRestaurantId ??
                                                        '',
                                                    title:
                                                        '🛵 طلب جديد بانتظارك!',
                                                    body:
                                                        'تم تعيينك لتوصيل طلب جديد. افتح التطبيق للتفاصيل.',
                                                    orderId: docRef.id,
                                                  );
                                                }


                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx);
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        '✅ تم تعيين المندوب بنجاح!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: Icon(
                                                Icons.delivery_dining_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'قبول وتعيين المندوب',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.greenAccent,
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.delivery_dining_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '✅ قبول + تعيين مندوب',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.greenAccent,
                                    side: const BorderSide(
                                      color: Colors.greenAccent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => docs[index].reference.update(
                                    {'status': 'rejected'},
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    '❌ رفض',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (status == 'preparing') ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delivery_dining_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '🧑‍🍳 جاري التحضير — المندوب: ${data['driverName'] ?? '---'} (${data['driverPhone'] ?? ''})',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVendorAnalyticsCard(
    BuildContext context,
    JeebliController controller,
    String restId,
  ) {
    final products = controller.getProductsByRestaurant(restId);
    final availableCount = products.where((p) => p.isAvailable).length;
    final restaurant = controller.allRestaurants.firstWhere(
      (r) => r.id == restId,
      orElse: () => controller.allRestaurants.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantId', isEqualTo: restId)
            .where('status', isEqualTo: 'delivered')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final totalSales = docs.fold(
            0.0,
            (acc, doc) =>
                acc +
                (((doc.data() as Map<String, dynamic>)['totalAmount'] as num?)
                        ?.toDouble() ??
                    0.0),
          );
          final orderCount = docs.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'إحصائيات المطعم والمبيعات 📊',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.dynamicWhite,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'تقييم ${restaurant.rating} ⭐',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _analyticsItem(
                      'إجمالي مبيعاتك',
                      '${totalSales.toStringAsFixed(0)} د.ع',
                      Icons.payments_outlined,
                      Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _analyticsItem(
                      'الطلبات الناجحة',
                      '$orderCount طلب',
                      Icons.shopping_bag_outlined,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _analyticsItem(
                      'الوجبات المتوفرة',
                      '$availableCount من ${products.length}',
                      Icons.restaurant_menu,
                      Colors.lightBlueAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _analyticsItem(
                      'أجور التوصيل',
                      '${restaurant.deliveryFee.toStringAsFixed(0)} د.ع',
                      Icons.delivery_dining,
                      Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _analyticsItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestSection(
    BuildContext context,
    JeebliController ctrl,
    String restId,
    String title,
  ) {
    final prods = ctrl.getProductsByRestaurant(restId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Colors.amber,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.dynamicWhite.withOpacity(0.05)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prods.length,
            separatorBuilder: (ctx2, i2) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, i) {
              final prod = prods[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    prod.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  prod.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.dynamicWhite,
                  ),
                ),
                subtitle: Text(
                  prod.isAvailable ? '🟢 متوفر للطلب' : '🔴 خلصانة',
                  style: TextStyle(
                    fontSize: 11,
                    color: prod.isAvailable
                        ? Colors.green[300]
                        : Colors.red[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_rounded,
                        color: Colors.blueAccent,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showOwnerProductDialog(
                        context,
                        ctrl,
                        restId,
                        product: prod,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        Icons.delete_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          _showOwnerDeleteDialog(context, ctrl, prod),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => ctrl.toggleProductAvailability(prod.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: prod.isAvailable
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: context.dynamicWhite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: Text(
                        prod.isAvailable ? 'متوفر' : 'خلصانة',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, JeebliController controller) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'تسجيل الخروج',
            style: TextStyle(color: context.dynamicWhite),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            style: TextStyle(color: context.dynamicWhite70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.logout();
              },
              child: Text(
                'نعم، تسجيل خروج',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showOwnerLoginModal(BuildContext context, JeebliController controller) {
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text(
              'بوابة المطاعم والمندوبين 🛵',
              style: TextStyle(
                color: context.dynamicWhite,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سجّل دخولك لمتابعة مطعمك أو استلام طلباتك كمندوب توصيل:',
              style: TextStyle(color: context.dynamicWhite70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: context.dynamicWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                labelStyle: TextStyle(
                  color: context.dynamicWhite70,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.phone_outlined,
                  color: Colors.amber,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: context.dynamicWhite.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: TextStyle(color: context.dynamicWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                labelStyle: TextStyle(
                  color: context.dynamicWhite70,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Colors.amber,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: context.dynamicWhite.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              final pass = passCtrl.text.trim();
              if (phone.isEmpty || pass.isEmpty) return;

              bool success = await controller.loginOwnerOrAdmin(phone, pass);
              if (!context.mounted) return;
              if (success) {
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('رقم الهاتف أو كلمة السر غير صحيحة ❌'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: context.dynamicWhite,
            ),
            child: Text('دخول اللوحة 🚀'),
          ),
        ],
      ),
    ),
  );
}

void _showOwnerEditRestaurantDialog(
  BuildContext context,
  JeebliController ctrl,
  String restId,
) {
  final rest = ctrl.allRestaurants.firstWhere(
    (r) => r.id == restId,
    orElse: () => ctrl.allRestaurants.first,
  );

  final nameCtrl = TextEditingController(text: rest.name);
  final waCtrl = TextEditingController(text: rest.whatsappNumber);
  final feeCtrl = TextEditingController(
    text: rest.deliveryFee.toStringAsFixed(0),
  );
  final timeCtrl = TextEditingController(text: rest.deliveryTime);
  final descCtrl = TextEditingController(text: rest.description);
  final imgCtrl = TextEditingController(text: rest.imageUrl);

  int selectedOpenHour = rest.openHour;
  int selectedCloseHour = rest.closeHour;
  bool is24Hours =
      (rest.openHour == 0 && rest.closeHour == 24) ||
      (rest.openHour == rest.closeHour);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'تعديل بيانات المطعم ✏️',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.dynamicWhite,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _darkInput('اسم المطعم', nameCtrl),
                  const SizedBox(height: 8),
                  _darkInput(
                    'رقم الواتساب لاستقبال الطلبات',
                    waCtrl,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  _darkInput(
                    'أجور التوصيل (د.ع)',
                    feeCtrl,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _darkInput(
                    'وقت التوصيل المتوقع (مثال: 20-30 دقيقة)',
                    timeCtrl,
                  ),
                  const SizedBox(height: 8),
                  _darkInput('وصف المطعم', descCtrl),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _darkInput('صورة المطعم (رابط أو ملف)', imgCtrl),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () async {
                          final newUrl = await _showImagePickerChoice(context);
                          if (newUrl != null && newUrl.isNotEmpty) {
                            setState(() => imgCtrl.text = newUrl);
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        tooltip: 'اختر صورة من الكاميرا أو المعرض',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ساعات وقواعد العمل 🕒',
                    style: TextStyle(
                      color: context.dynamicWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.dynamicWhite.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: is24Hours,
                              activeColor: Colors.amber,
                              onChanged: (val) {
                                setState(() {
                                  is24Hours = val ?? false;
                                  if (is24Hours) {
                                    selectedOpenHour = 0;
                                    selectedCloseHour = 24;
                                  }
                                });
                              },
                            ),
                            const Expanded(
                              child: Text(
                                'يعمل 24 ساعة (ليل ونهار دون إغلاق 🌙☀️)',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!is24Hours) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: selectedOpenHour,
                                  dropdownColor: const Color(0xFF334155),
                                  style: TextStyle(
                                    color: context.dynamicWhite,
                                    fontSize: 11,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'يفتح من الساعة',
                                    labelStyle: TextStyle(
                                      color: context.dynamicWhite70,
                                      fontSize: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: context.dynamicWhite.withOpacity(0.05),
                                  ),
                                  items: List.generate(24, (i) {
                                    final period = i >= 12 ? 'م' : 'ص';
                                    final h12 = i % 12 == 0 ? 12 : i % 12;
                                    return DropdownMenuItem(
                                      value: i,
                                      child: Text('$h12:00 $period'),
                                    );
                                  }),
                                  onChanged: (val) => setState(
                                    () => selectedOpenHour = val ?? 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: selectedCloseHour > 24
                                      ? 24
                                      : selectedCloseHour,
                                  dropdownColor: const Color(0xFF334155),
                                  style: TextStyle(
                                    color: context.dynamicWhite,
                                    fontSize: 11,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'يغلق الساعة',
                                    labelStyle: TextStyle(
                                      color: context.dynamicWhite70,
                                      fontSize: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: context.dynamicWhite.withOpacity(0.05),
                                  ),
                                  items: List.generate(25, (i) {
                                    if (i == 24)
                                      return const DropdownMenuItem(
                                        value: 24,
                                        child: Text('12:00 ص (منتصف الليل)'),
                                      );
                                    final period = i >= 12 ? 'م' : 'ص';
                                    final h12 = i % 12 == 0 ? 12 : i % 12;
                                    return DropdownMenuItem(
                                      value: i,
                                      child: Text('$h12:00 $period'),
                                    );
                                  }),
                                  onChanged: (val) => setState(
                                    () => selectedCloseHour = val ?? 23,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final fee = double.tryParse(feeCtrl.text) ?? rest.deliveryFee;
                  ctrl.updateRestaurantDetails(
                    rest.id,
                    name: nameCtrl.text.trim(),
                    whatsappNumber: waCtrl.text.trim(),
                    deliveryFee: fee,
                    deliveryTime: timeCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    imageUrl: imgCtrl.text.trim(),
                    openHour: is24Hours ? 0 : selectedOpenHour,
                    closeHour: is24Hours ? 24 : selectedCloseHour,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم تحديث بيانات وساعات عمل المطعم بنجاح ✅',
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                  foregroundColor: context.dynamicWhite,
                ),
                child: Text('حفظ التعديلات'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showOwnerProductDialog(
  BuildContext context,
  JeebliController ctrl,
  String restId, {
  Product? product,
}) {
  final isEdit = product != null;
  final nameController = TextEditingController(text: product?.name ?? '');
  final priceController = TextEditingController(
    text: product?.price.toString() ?? '',
  );
  final descController = TextEditingController(
    text: product?.description ?? '',
  );
  final imageController = TextEditingController(text: product?.imageUrl ?? '');
  final discountController = TextEditingController(
    text: product?.discountPrice?.toString() ?? '',
  );
  final percentageController = TextEditingController(
    text: (product?.discountPrice != null && (product?.price ?? 0) > 0)
        ? (((product!.price - product.discountPrice!) / product.price) * 100)
              .toStringAsFixed(0)
        : '',
  );

  final rest = ctrl.activeRestaurant;
  List<String> allowedCategories = rest?.customCategories.isNotEmpty == true 
      ? rest!.customCategories 
      : ['برجر', 'بيتزا', 'شاورما', 'مشروبات', 'أخرى'];
      
  String selectedCategory = product?.categoryId ?? allowedCategories.first;
  if (!allowedCategories.contains(selectedCategory) && product != null && product.categoryId.isNotEmpty) {
    allowedCategories.add(product.categoryId);
    selectedCategory = product.categoryId;
  }
  
  final newCategoryController = TextEditingController();


  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'تعديل الوجبة ✏️' : 'إضافة وجبة جديدة 🍔',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.dynamicWhite,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _darkInput('اسم الوجبة', nameController),
                  const SizedBox(height: 8),
                  _darkInput(
                    'السعر (د.ع)',
                    priceController,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _darkInput('الوصف', descController),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _darkInput(
                          'صورة الوجبة (رابط أو ملف)',
                          imageController,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () async {
                          final newUrl = await _showImagePickerChoice(context);
                          if (newUrl != null && newUrl.isNotEmpty) {
                            setState(() => imageController.text = newUrl);
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        tooltip: 'اختر صورة من الكاميرا أو المعرض',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _darkInput(
                          'نسبة الخصم % (1-100)',
                          percentageController,
                          type: TextInputType.number,
                          onChanged: (val) {
                            final pct = double.tryParse(val);
                            final price =
                                double.tryParse(priceController.text) ?? 0;
                            if (pct != null &&
                                pct > 0 &&
                                pct <= 100 &&
                                price > 0) {
                              final newPrice = price - (price * (pct / 100));
                              setState(() {
                                discountController.text = newPrice
                                    .toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _darkInput(
                          'السعر بعد الخصم (د.ع)',
                          discountController,
                          type: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: allowedCategories.contains(selectedCategory) ? selectedCategory : allowedCategories.first,
                          dropdownColor: const Color(0xFF334155),
                          style: TextStyle(color: context.dynamicWhite),
                          decoration: InputDecoration(
                            labelText: 'القسم',
                            labelStyle: TextStyle(color: context.dynamicWhite70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            filled: true,
                            fillColor: context.dynamicWhite.withOpacity(0.05),
                          ),
                          items: allowedCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFFFF8F00), size: 30),
                        tooltip: 'إضافة قسم جديد',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx2) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: Text('قسم جديد', style: TextStyle(color: Colors.white)),
                              content: TextField(
                                controller: newCategoryController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'اسم القسم (مثال: عصائر)',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx2), child: Text('إلغاء')),
                                ElevatedButton(
                                  onPressed: () {
                                    if (newCategoryController.text.trim().isNotEmpty) {
                                      setState(() {
                                        allowedCategories.add(newCategoryController.text.trim());
                                        selectedCategory = newCategoryController.text.trim();
                                      });
                                    }
                                    Navigator.pop(ctx2);
                                  },
                                  child: Text('إضافة'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  final discount = double.tryParse(discountController.text);
                  if (nameController.text.trim().isEmpty || price <= 0) {
                    return;
                  }
                  final imageUrl = imageController.text.trim().isEmpty
                      ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80'
                      : imageController.text.trim();

                  if (isEdit) {
                    ctrl.updateProduct(
                      product.id,
                      name: nameController.text.trim(),
                      price: price,
                      discountPrice: discount,
                      description: descController.text.trim(),
                      imageUrl: imageUrl,
                      clearDiscount: discountController.text.isEmpty,
                    );
                  } else {
                    ctrl.addProduct(
                      Product(
                        id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                        restaurantId: restId,
                        categoryId: selectedCategory,
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        price: price,
                        discountPrice: discount,
                        imageUrl: imageUrl,
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                  foregroundColor: context.dynamicWhite,
                ),
                child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة الآن'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _darkInput(
  String label,
  TextEditingController c, {
  TextInputType type = TextInputType.text,
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: c,
    keyboardType: type,
    onChanged: onChanged,
    style: TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFF8F00)),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    ),
  );
}

void _showOwnerDeleteDialog(
  BuildContext context,
  JeebliController ctrl,
  Product product,
) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تأكيد الحذف 🗑️',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'هل أنت متأكد من حذف وجبة "${product.name}" نهائياً؟',
          style: TextStyle(color: context.dynamicWhite70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              ctrl.deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: context.dynamicWhite,
            ),
            child: Text('نعم، احذف الوجبة'),
          ),
        ],
      ),
    ),
  );
}

/// ============================================================================
/// 15. الملف الشخصي للزبون
/// ============================================================================

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  late TextEditingController _phoneController;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = JeebliProvider.of(context);
      _phoneController.text = c.customerPhone;
      _nameController.text = c.customerName.isNotEmpty
          ? c.customerName
          : 'زبون جيب لي';
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final name = controller.customerName.isNotEmpty
        ? controller.customerName
        : 'زبون جيب لي';
    final phone = controller.customerPhone;

    return Scaffold(
      backgroundColor: controller.bgColor,
      appBar: AppBar(
        title: Text(
          'الملف الشخصي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: controller.textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: controller.cardColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8F00).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0] : '؟',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: context.dynamicWhite,
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: controller.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Text(
                '🟢 حساب زبون نشط',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (controller.loyaltySystemEnabled) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard(
                    context,
                    'نقطة 🌟',
                    controller.loyaltyPoints.toString(),
                    Icons.stars_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ] else
              const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: controller.cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      controller.isDarkMode ? 0.2 : 0.05,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات الحساب',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: controller.textColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildEditableNameTile(controller, name),
                  const Divider(height: 24, color: Colors.white12),
                  _buildEditablePhoneTile(controller, phone),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (controller.loyaltySystemEnabled) _buildLoyaltyCard(controller),
            if (controller.loyaltySystemEnabled) const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: controller.cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    controller.isDarkMode
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    controller.isDarkMode
                        ? 'الوضع الفاتح ☀️'
                        : 'الوضع الداكن 🌙',
                    controller.isDarkMode
                        ? Colors.orangeAccent
                        : Colors.indigoAccent,
                    onTap: () => controller.toggleTheme(),
                  ),
                  _buildSettingsTile(
                    Icons.notifications_outlined,
                    'إشعارات الطلبات',
                    Colors.amber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerNotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    Icons.share_rounded,
                    'مشاركة التطبيق مع الأصدقاء 📲',
                    Colors.greenAccent,
                    onTap: () {
                      final text = Uri.encodeComponent(
                        '🍔 *تطبيق جيب لي ديلفري* 🛵\nأسرع منصة لتوصيل أشهى وجبات المطاعم إلى باب بيتك بضغطة زر!\nجربه الآن واطلب وجبتك المفضل بسهولة 🚀',
                      );
                      launchUrl(
                        Uri.parse('https://wa.me/?text=$text'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  const Divider(height: 0.5, color: Colors.white12),
                  _buildSettingsTile(
                    Icons.logout_rounded,
                    'تسجيل الخروج',
                    Colors.red,
                    isDestructive: true,
                    onTap: () => _showLogoutDialog(context, controller),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'جيبلي ديلفري — نسخة 2.0.0',
              style: TextStyle(color: context.dynamicWhite70, fontSize: 10.5),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(JeebliController controller) {
    final pts = controller.loyaltyPoints;
    final pointsInCurrentTier = pts % JeebliController.pointsPerReward;
    final progress = pointsInCurrentTier / JeebliController.pointsPerReward;
    final canRedeem = pts >= JeebliController.pointsPerReward;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF8F00).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8F00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFFF8F00),
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نقاط الولاء والمكافآت 🌟',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.dynamicWhite,
                        ),
                      ),
                      Text(
                        'كل 1,000 د.ع طلب = 10 نقاط',
                        style: TextStyle(fontSize: 10.5, color: context.dynamicWhite70),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$pts نقطة',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: context.dynamicWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── شريط التقدم نحو الجائزة التالية ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    canRedeem
                        ? '🎉 لديك مكافأة خصم 1,500 د.ع جاهزة!'
                        : 'تبقى ${controller.pointsNeededForReward} نقطة للمكافأة القادمة',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: canRedeem ? Colors.greenAccent : Colors.amber,
                    ),
                  ),
                  Text(
                    '$pointsInCurrentTier / ${JeebliController.pointsPerReward}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.dynamicWhite70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: canRedeem ? 1.0 : progress,
                  minHeight: 8,
                  backgroundColor: context.dynamicWhite.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(
                    canRedeem
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF8F00),
                  ),
                ),
              ),
            ],
          ),
          if (controller.loyaltyHistory.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Colors.white12),
            ),
            Text(
              'سجل النقاط والمكافآت 📜',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.dynamicWhite70,
              ),
            ),
            const SizedBox(height: 8),
            ...controller.loyaltyHistory
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.reason,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.dynamicWhite70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          entry.points > 0
                              ? '+${entry.points}'
                              : '${entry.points}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: entry.points > 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final controller = JeebliProvider.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: controller.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF8F00), size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: controller.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: controller.subtextColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableNameTile(JeebliController controller, String name) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8F00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: Color(0xFFFF8F00),
            size: 18,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _isEditingName
              ? TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.dynamicWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اسمك الكريم',
                    isDense: true,
                    hintStyle: TextStyle(color: context.dynamicWhite70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFF8F00)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: context.dynamicWhite.withOpacity(0.05),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاسم الشخصي',
                      style: TextStyle(fontSize: 11, color: context.dynamicWhite70),
                    ),
                    Text(
                      name.isNotEmpty ? name : 'لم يُدخل',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.dynamicWhite,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (_isEditingName) {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                controller.updateCustomerName(newName);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تحديث الاسم!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
            setState(() => _isEditingName = !_isEditingName);
          },
          icon: Icon(
            _isEditingName ? Icons.check_circle_rounded : Icons.edit_outlined,
            color: _isEditingName ? Colors.green : const Color(0xFFFF8F00),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildEditablePhoneTile(JeebliController controller, String phone) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8F00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.phone_android_rounded,
            color: Color(0xFFFF8F00),
            size: 18,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _isEditingPhone
              ? TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.dynamicWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: '07XXXXXXXXX',
                    isDense: true,
                    hintStyle: TextStyle(color: context.dynamicWhite70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFF8F00)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: context.dynamicWhite.withOpacity(0.05),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم الهاتف',
                      style: TextStyle(fontSize: 11, color: context.dynamicWhite70),
                    ),
                    Text(
                      phone.isNotEmpty ? phone : 'لم يُدخل',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.dynamicWhite,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (_isEditingPhone) {
              final newPhone = _phoneController.text.trim();
              if (newPhone.isNotEmpty && newPhone.length >= 10) {
                controller.updateCustomerPhone(newPhone);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تحديث رقم الهاتف!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
            setState(() => _isEditingPhone = !_isEditingPhone);
          },
          icon: Icon(
            _isEditingPhone ? Icons.check_circle_rounded : Icons.edit_outlined,
            color: _isEditingPhone ? Colors.green : const Color(0xFFFF8F00),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String label,
    Color color, {
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.redAccent : context.dynamicWhite,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDestructive ? Colors.redAccent : context.dynamicWhite70,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, JeebliController controller) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'تسجيل الخروج',
            style: TextStyle(color: context.dynamicWhite),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            style: TextStyle(color: context.dynamicWhite70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: context.dynamicWhite,
              ),
              child: Text('نعم، خروج'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickAvatarModal(BuildContext context, JeebliController controller) {
    final urlC = TextEditingController(text: controller.customerAvatarUrl);

    showModalBottomSheet(
      context: context,
      backgroundColor: controller.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تغيير صورة الملف الشخصي 📷',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: controller.textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFFFF8F00),
                ),
                title: Text(
                  'اختيار صورة من الاستوديو',
                  style: TextStyle(color: controller.textColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    controller.updateCustomerAvatar(picked.path);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFFFF8F00),
                ),
                title: Text(
                  'التقاط صورة بالكاميرا',
                  style: TextStyle(color: controller.textColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    controller.updateCustomerAvatar(picked.path);
                  }
                },
              ),
              const Divider(),
              TextField(
                controller: urlC,
                style: TextStyle(color: controller.textColor),
                decoration: InputDecoration(
                  labelText: 'أو أدخل رابط الصورة المباشر (URL)',
                  labelStyle: TextStyle(color: controller.subtextColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      if (urlC.text.trim().isNotEmpty) {
                        controller.updateCustomerAvatar(urlC.text.trim());
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 16. شاشة تسجيل الدخول
/// ============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedRole = 'customer';

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final controller = JeebliProvider.of(context);
    final success = await controller.login(
      _idController.text,
      _phoneController.text,
      _selectedRole,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ بيانات الدخول غير صحيحة.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = _selectedRole == 'customer';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE65100).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: context.dynamicWhite,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'جيب لي ديلفري 🍔',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: context.dynamicWhite,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'منصتك الأولى لتوصيل أشهى وجبات المطاعم بضغطة زر 🚀',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.dynamicWhite70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // محدد الدور
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.dynamicWhite.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _roleTab('دخول الزبائن 👤', 'customer'),
                          ),
                          Expanded(
                            child: _roleTab('أصحاب المطاعم 🏪', 'owner'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ---- حقول الإدخال (فقط لأصحاب المطاعم أو الإدارة) ----
                    if (!isCustomer) ...[
                      // الحقل الأول: رقم الهاتف (لأصحاب المطاعم)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildInputField(
                          key: ValueKey('field1_$_selectedRole'),
                          controller: _idController,
                          label: 'رقم الهاتف',
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'الرجاء إدخال رقم الهاتف'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // الحقل الثاني: الباسورد
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildPasswordField(
                          key: const ValueKey('pass_owner'),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // تلميح للمالك / السوبر أدمن
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: Colors.lightBlue,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'لوحة أصحاب المطاعم والإدارة العليا',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.lightBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // زر الدخول للإدارة
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE65100).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  color: context.dynamicWhite,
                                )
                              : Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: context.dynamicWhite,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      // ---- واجهة الزبائن (إدخال الاسم والهاتف مباشرة) ----
                      Icon(
                        Icons.person_rounded,
                        size: 64,
                        color: Color(0xFFFF8F00),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'أدخل معلوماتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.dynamicWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أدخل اسمك ورقم هاتفك لكي يتمكن المندوب من التواصل معك عند توصيل طلبك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.dynamicWhite70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // حقل الاسم
                      TextField(
                        controller: _guestNameController,
                        style: TextStyle(color: context.dynamicWhite),
                        decoration: InputDecoration(
                          labelText: 'الاسم الكريم',
                          labelStyle: TextStyle(color: context.dynamicWhite70),
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFFFF8F00),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // حقل الهاتف
                      TextField(
                        controller: _guestPhoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: context.dynamicWhite),
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          labelStyle: TextStyle(color: context.dynamicWhite70),
                          prefixIcon: Icon(
                            Icons.phone_rounded,
                            color: Color(0xFFFF8F00),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final name = _guestNameController.text.trim();
                            final phone = _guestPhoneController.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يرجى إدخال الاسم ورقم الهاتف'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            final c = JeebliProvider.of(context);
                            c.updateCustomerName(name);
                            c.customerPhone = phone;
                            c.login(name, phone, 'customer');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ تم حفظ معلوماتك بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.save_rounded,
                            color: context.dynamicWhite,
                          ),
                          label: Text(
                            'حفظ المعلومات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: context.dynamicWhite,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8F00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: context.dynamicWhite.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: context.dynamicWhite),
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.dynamicWhite.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: Colors.amber),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField({required Key key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: context.dynamicWhite.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: _phoneController,
        obscureText: _obscurePassword,
        style: TextStyle(color: context.dynamicWhite),
        decoration: InputDecoration(
          labelText: 'الرمز السري',
          labelStyle: TextStyle(color: context.dynamicWhite.withOpacity(0.6)),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: Colors.amber,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: context.dynamicWhite70,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'الرجاء إدخال الرمز السري' : null,
      ),
    );
  }

  Widget _roleTab(String label, String role) {
    final isSel = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _idController.clear();
          _phoneController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSel
              ? const LinearGradient(
                  colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                )
              : null,
          color: isSel ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSel
              ? [
                  BoxShadow(
                    color: const Color(0xFFE65100).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSel ? context.dynamicWhite : context.dynamicWhite70,
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// entry point لـ super admin — يُستدعى من AppRouteNavigator
/// ============================================================================
class SuperAdminScreenEntry extends StatelessWidget {
  const SuperAdminScreenEntry({super.key});

  @override
  Widget build(BuildContext context) {
    // super_admin_screen.dart يُعرِّف SuperAdminScreen
    return const SuperAdminScreen();
  }
}

/// ============================================================================
/// مساعد اختيار الصور (معرض / كاميرا / رابط URL)
/// ============================================================================
void showImagePickerOptions(
  BuildContext context,
  Function(String imagePathOrUrl) onImageSelected,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر طريقة إضافة الصورة 📸',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.dynamicWhite,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const ContainerIcon(
                  icon: Icons.camera_alt_rounded,
                  color: Colors.orangeAccent,
                ),
                title: Text(
                  'التقاط بواسطة الكاميرا 📷',
                  style: TextStyle(color: context.dynamicWhite, fontSize: 14),
                ),
                subtitle: Text(
                  'افتح الكاميرا والتقط صورة مباشرة',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 80,
                    );
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      final b64 = base64Encode(bytes);
                      onImageSelected('data:image/jpeg;base64,$b64');
                    }
                  } catch (e) {
                    debugPrint('Camera pick note: $e');
                  }
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const ContainerIcon(
                  icon: Icons.photo_library_rounded,
                  color: Colors.amber,
                ),
                title: Text(
                  'اختيار من معرض الصور 🖼️',
                  style: TextStyle(color: context.dynamicWhite, fontSize: 14),
                ),
                subtitle: Text(
                  'اختر صورة مخزنة في هاتفك',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 80,
                    );
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      final b64 = base64Encode(bytes);
                      onImageSelected('data:image/jpeg;base64,$b64');
                    }
                  } catch (e) {
                    debugPrint('Gallery pick note: $e');
                  }
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const ContainerIcon(
                  icon: Icons.link_rounded,
                  color: Colors.lightBlueAccent,
                ),
                title: Text(
                  'إدخال رابط صورة (URL) 🌐',
                  style: TextStyle(color: context.dynamicWhite, fontSize: 14),
                ),
                subtitle: Text(
                  'الصق رابط صورة مباشر من الإنترنت',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUrlInputDialog(context, onImageSelected);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ContainerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const ContainerIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

void _showUrlInputDialog(
  BuildContext context,
  Function(String imagePathOrUrl) onImageSelected,
) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'إدخال رابط صورة 🌐',
          style: TextStyle(color: context.dynamicWhite, fontSize: 15),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.dynamicWhite, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'https://example.com/image.jpg',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
            filled: true,
            fillColor: context.dynamicWhite.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.dynamicWhite.withOpacity(0.1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                onImageSelected(text);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: Text(
              'حفظ الصورة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _showImagePickerChoice(BuildContext context) async {
  final picker = ImagePicker();

  final result = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر مصدر الصورة 📸',
              style: TextStyle(
                color: context.dynamicWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: Colors.amber,
                size: 28,
              ),
              title: Text(
                'اختيار من المعرض (الاستوديو) 🖼️',
                style: TextStyle(color: context.dynamicWhite, fontSize: 14),
              ),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                );
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  if (ctx.mounted) Navigator.pop(ctx, 'data:image/jpeg;base64,${base64Encode(bytes)}');
                } else {
                  if (ctx.mounted) Navigator.pop(ctx, null);
                }
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: Colors.greenAccent,
                size: 28,
              ),
              title: Text(
                'التقاط مباشرة بواسطة الكاميرا 📸',
                style: TextStyle(color: context.dynamicWhite, fontSize: 14),
              ),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 800,
                  maxHeight: 800,
                );
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  if (ctx.mounted) Navigator.pop(ctx, 'data:image/jpeg;base64,${base64Encode(bytes)}');
                } else {
                  if (ctx.mounted) Navigator.pop(ctx, null);
                }
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Icon(
                Icons.link_rounded,
                color: Colors.lightBlueAccent,
                size: 28,
              ),
              title: Text(
                'إدخال رابط URL من الإنترنت 🌐',
                style: TextStyle(color: context.dynamicWhite, fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(ctx, 'USE_URL');
              },
            ),
          ],
        ),
      ),
    ),
  );

  if (result == 'USE_URL') {
    return await _showUrlInputDialogAsync(context);
  }

  return result;
}

Future<String?> _showUrlInputDialogAsync(BuildContext context) async {
  final controller = TextEditingController();
  return await showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'إدخال رابط صورة 🌐',
          style: TextStyle(color: context.dynamicWhite, fontSize: 15),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.dynamicWhite, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'https://example.com/image.jpg',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
            filled: true,
            fillColor: context.dynamicWhite.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.dynamicWhite.withOpacity(0.1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx, text.isNotEmpty ? text : null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: Text(
              'حفظ الصورة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class CustomAppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CustomAppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, stack) => _errorPlaceholder(),
        );
      } catch (_) {
        return _errorPlaceholder();
      }
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, stack) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF0F172A),
      child: Icon(
        Icons.fastfood_rounded,
        color: Colors.white24,
        size: 40,
      ),
    );
  }
}

/// ============================================================================
/// شاشة إدارة المندوبين (لصاحب المطعم)
/// ============================================================================
class ManageDriversScreen extends StatefulWidget {
  final String restaurantId;
  const ManageDriversScreen({super.key, required this.restaurantId});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  Future<void> _deleteDriver(String driverPhone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'تأكيد الحذف',
            style: TextStyle(color: context.dynamicWhite),
          ),
          content: Text(
            'هل أنت متأكد من حذف هذا المندوب نهائياً؟\n\n(لن يتمكن من تسجيل الدخول بعد الآن)',
            style: TextStyle(color: context.dynamicWhite70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'حذف',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('admin_credentials')
            .doc(driverPhone)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم حذف المندوب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في الحذف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editDriver(
    Map<String, dynamic> driverData,
    String docId,
  ) async {
    final nameCtrl = TextEditingController(text: driverData['name']);
    final passCtrl = TextEditingController(text: driverData['password']);
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'تعديل بيانات المندوب',
                style: TextStyle(color: Colors.lightBlueAccent),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: context.dynamicWhite),
                    decoration: InputDecoration(
                      labelText: 'اسم المندوب',
                      labelStyle: TextStyle(color: context.dynamicWhite70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.lightBlueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    style: TextStyle(color: context.dynamicWhite),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      labelStyle: TextStyle(color: context.dynamicWhite70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.lightBlueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ملاحظة: لا يمكن تغيير رقم هاتف المندوب، احذفه وأضفه من جديد برقم آخر إذا أردت.',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 10),
                  ),
                ],
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final n = nameCtrl.text.trim();
                          final p = passCtrl.text.trim();
                          if (n.isEmpty || p.isEmpty) return;
                          setStateDialog(() => isSaving = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('admin_credentials')
                                .doc(docId)
                                .update({'name': n, 'password': p});
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setStateDialog(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black87,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.black87,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'إدارة المندوبين',
          style: TextStyle(color: context.dynamicWhite, fontSize: 16),
        ),
        leading: const JeebliBackButton(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_credentials')
            .where('role', isEqualTo: 'driver')
            .where('restaurantId', isEqualTo: widget.restaurantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.lightBlueAccent),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.two_wheeler_rounded,
                    size: 64,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'لا يوجد مندوبين مسجلين لهذا المطعم',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'يمكنك تعيين المندوبين أثناء قبول الطلبات الجديدة.',
                    style: TextStyle(color: context.dynamicWhite70, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'بدون اسم';
              final phone = data['phone'] ?? docs[index].id;
              final password = data['password'] ?? '---';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.dynamicWhite.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: Colors.lightBlueAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: context.dynamicWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '📞 $phone',
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🔑 $password',
                            style: TextStyle(
                              color: context.dynamicWhite70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _editDriver(data, docs[index].id),
                          icon: Icon(
                            Icons.edit_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          tooltip: 'تعديل',
                        ),
                        IconButton(
                          onPressed: () => _deleteDriver(docs[index].id),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          tooltip: 'حذف',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
