// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'super_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyJeebliAppKey1234567890abcdef',
        appId: '1:100000000000:android:jeebliapp12345',
        messagingSenderId: '100000000000',
        projectId: 'jeebli-app',
      ),
    );
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }
  runApp(const MyApp());
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
  String? ownerPassword;
  final int openHour;   // 0-23
  final int closeHour;  // 0-23
  double? restaurantLat;  // موقع المطعم
  double? restaurantLng;

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
    this.ownerPassword,
    this.openHour = 0,
    this.closeHour = 24,
    this.restaurantLat,
    this.restaurantLng,
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
      'ownerPassword': ownerPassword,
      'openHour': openHour,
      'closeHour': closeHour,
      'restaurantLat': restaurantLat,
      'restaurantLng': restaurantLng,
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
      ownerPassword: map['ownerPassword'],
      openHour: map['openHour'] ?? 0,
      closeHour: map['closeHour'] ?? 24,
      restaurantLat: map['restaurantLat'] != null ? (map['restaurantLat'] as num).toDouble() : null,
      restaurantLng: map['restaurantLng'] != null ? (map['restaurantLng'] as num).toDouble() : null,
    );
  }

  /// حساب المسافة بالكيلومتر بين المطعم والزبون
  double? distanceTo(double? lat, double? lng) {
    if (restaurantLat == null || restaurantLng == null || lat == null || lng == null) return null;
    const R = 6371.0;
    final dLat = _toRad(lat - restaurantLat!);
    final dLng = _toRad(lng - restaurantLng!);
    final a = _sin2(dLat / 2) +
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
      discountPrice: map['discountPrice'] != null ? (map['discountPrice'] as num).toDouble() : null,
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
    bool? isAvailable,
    bool clearDiscount = false,
  }) {
    return Product(
      id: id,
      restaurantId: restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountPrice: clearDiscount ? null : (discountPrice ?? this.discountPrice),
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
  double get totalPrice => product.price * quantity;
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
}

class LoyaltyEntry {
  final int points;
  final String reason;
  final DateTime date;
  LoyaltyEntry({required this.points, required this.reason, required this.date});
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
enum PaymentMethod { cod, mastercard }

class JeebliController extends ChangeNotifier {

  JeebliController() {
    _loadLocalData().then((_) {
      _initFirebaseSync();
      _loadSavedSession();
    });
  }

  void _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool('is_logged_in') ?? false;
      if (loggedIn) {
        _isLoggedIn = true;
        _userRole = prefs.getString('user_role');
        customerName = prefs.getString('customer_name') ?? '';
        customerPhone = prefs.getString('customer_phone') ?? '';
        _userRestaurantId = prefs.getString('user_restaurant_id');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Session load note: $e');
    }
  }

  void saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', _isLoggedIn);
      if (_userRole != null) await prefs.setString('user_role', _userRole!);
      await prefs.setString('customer_name', customerName);
      await prefs.setString('customer_phone', customerPhone);
      if (_userRestaurantId != null) await prefs.setString('user_restaurant_id', _userRestaurantId!);
    } catch (e) {
      debugPrint('Session save note: $e');
    }
  }

  void logout() async {
    _deliveryTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Session clear note: $e');
    }
    _isLoggedIn = false;
    _userRole = null;
    _userEmailOrPhone = null;
    _userRestaurantId = null;
    _activeRestaurant = null;
    _currentTab = 0;
    _playClickFeedback();
    notifyListeners();
  }

  // ─── حفظ وتحميل البيانات محلياً ───────────────────────────────────────
  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restsJson = _restaurants.map((r) => jsonEncode(r.toMap())).toList();
      await prefs.setStringList('local_restaurants', restsJson);
      final prodsJson = _products.map((p) => jsonEncode(p.toMap())).toList();
      await prefs.setStringList('local_products', prodsJson);
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
      }
      final prodsJson = prefs.getStringList('local_products') ?? [];
      if (prodsJson.isNotEmpty) {
        _products.clear();
        for (var j in prodsJson) {
          final map = jsonDecode(j) as Map<String, dynamic>;
          _products.add(Product.fromMap(map, map['id'] ?? ''));
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

      // Listen to real-time restaurant changes from Firebase
      firestore.collection('restaurants').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          _restaurants.clear();
          for (var doc in snapshot.docs) {
            _restaurants.add(Restaurant.fromMap(doc.data(), doc.id));
          }
          _saveLocalData();
          notifyListeners();
        }
        // إذا Firestore فارغ نبقي البيانات المحلية كما هي
      }, onError: (e) => debugPrint('Firestore restaurants sync note: $e'));

      // Listen to real-time product changes from Firebase
      firestore.collection('products').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          _products.clear();
          for (var doc in snapshot.docs) {
            _products.add(Product.fromMap(doc.data(), doc.id));
          }
          _saveLocalData();
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Firestore products sync note: $e'));
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
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
      ownerPhone: '07802019730',
      ownerPassword: '123456',
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
      description: 'معلم الوجبات السريعة في الحمزة، خلطات سرية مميزة وشاورما الفحم.',
      whatsappNumber: '07800108275',
      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80',
      ownerPhone: '07800108275',
      ownerPassword: '123456',
      deliveryFee: 1500,
      openHour: 0,
      closeHour: 24,
    ),
  ];

  final List<Product> _products = [
    Product(id: 'ak1', restaurantId: 'akkala', name: 'برجر لحم دبل جبن كلاسيك', description: 'شريحتين لحم مشوي مع الجبن السائل والصلصة السرية', price: 6000, imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80', categoryId: 'burger'),
    Product(id: 'ak2', restaurantId: 'akkala', name: 'وجبة زنجر سبايسي عملاق', description: 'صدر دجاج مقرمش حار مع الجبنة والبطاطس', price: 5500, imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=400&q=80', categoryId: 'zinger'),
    Product(id: 'ak3', restaurantId: 'akkala', name: 'بيتزا إيطالية وسط', description: 'عجينة رقيقة بصلصة الطماطم وجبن الموزاريلا', price: 8000, imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80', categoryId: 'pizza', isAvailable: false),
    Product(id: 'ak4', restaurantId: 'akkala', name: 'شاورما لحم عراقية بالصاج', description: 'قص لحم متبل ملفوف بخبز الصاج مع ثومية ومخلل', price: 4500, imageUrl: 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=400&q=80', categoryId: 'shawarma'),
    Product(id: 'ak5', restaurantId: 'akkala', name: 'فنجر بطاطس عائلي بالبهارات', description: 'بطاطس ذهبية مع بهارات البابريكا والكاتشب', price: 2500, imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&q=80', categoryId: 'fries'),
    Product(id: 'aa1', restaurantId: 'abualabd', name: 'برجر دجاج كريسبي بالجبن', description: 'صدر دجاج مقرمش ذهبي مع الجبنة والمايونيز المدخن', price: 5000, imageUrl: 'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=400&q=80', categoryId: 'burger'),
    Product(id: 'aa2', restaurantId: 'abualabd', name: 'صاج زنجر ملكي أبو العبد', description: 'قطع زنجر حارة بخبز الصاج العراقي مع الجبن السائل', price: 6000, imageUrl: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=400&q=80', categoryId: 'zinger'),
    Product(id: 'aa3', restaurantId: 'abualabd', name: 'شاورما دجاج بالفرن', description: 'قص دجاج مشوي متبل لبناني مع صوص الثوم', price: 4000, imageUrl: 'https://images.unsplash.com/photo-1561651823-34fed0225408?w=400&q=80', categoryId: 'shawarma', isAvailable: false),
    Product(id: 'aa4', restaurantId: 'abualabd', name: 'بيتزا لحم بابلية كبير', description: 'عجينة هشة بقطع اللحم المفروم وموزاريلا كثيفة', price: 10000, imageUrl: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=400&q=80', categoryId: 'pizza'),
    Product(id: 'aa5', restaurantId: 'abualabd', name: 'فنجر غرقان بالجبن الساخن', description: 'أصابع بطاطس مقرمشة بجبنة شيدر ذائبة وهالبينو', price: 3500, imageUrl: 'https://images.unsplash.com/photo-1585109649139-366815a0d713?w=400&q=80', categoryId: 'fries'),
  ];

  // --- Theme State ---
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  Color get bgColor => _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get cardColor => _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get subtextColor => _isDarkMode ? Colors.white70 : const Color(0xFF475569);
  Color get borderColor => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.08);

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

  String customerId = 'user_${Random().nextInt(99999)}';
  String customerName = '';
  String customerPhone = '';
  String selectedNeighborhood = '';
  String streetDetails = '';
  String orderNotes = '';
  bool isLocating = false;
  double? customerLat;
  double? customerLng;

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
          desiredAccuracy: LocationAccuracy.high);
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

  final double deliveryFee = 1500;

  OrderStatus _orderStatus = OrderStatus.idle;
  List<AppNotification> notifications = [];
  int unreadNotifications = 0;

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
        date: DateTime.now().subtract(const Duration(days: 2))),
  ];

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
            date: DateTime.now()));
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
            imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
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

  // --- Getters ---
  List<Restaurant> get restaurants => _restaurants;
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

  /// تحديث موقع المطعم (lat/lng) من صاحبه
  void updateRestaurantLocation(String restaurantId, double lat, double lng) {
    final idx = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (idx >= 0) {
      _restaurants[idx].restaurantLat = lat;
      _restaurants[idx].restaurantLng = lng;
      _saveLocalData();
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
        ownerPassword: r.ownerPassword,
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

  bool loginOwnerOrAdmin(String phone, String password) {
    if (phone == '07802019730' && password == '@a20012005b@') {
      _isLoggedIn = true;
      _userRole = 'superadmin';
      saveSession();
      notifyListeners();
      return true;
    }

    final rest = _restaurants.firstWhere(
      (r) => r.ownerPhone == phone && r.ownerPassword == password,
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

    if (rest.id.isNotEmpty) {
      _isLoggedIn = true;
      _userRole = 'owner';
      _userRestaurantId = rest.id;
      saveSession();
      notifyListeners();
      return true;
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
      FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();
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
      notifyListeners();
    }
  }

  void toggleProductAvailability(String productId) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx >= 0) {
      _products[idx] = _products[idx].copyWith(isAvailable: !_products[idx].isAvailable);
      _saveLocalData();
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
  double get totalAmount => subtotal + deliveryFee - loyaltyDiscount;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('سلة مختلطة!', style: TextStyle(fontSize: 16))
          ]),
          content: const Text(
              'سلتك تحتوي وجبات من مطعم آخر.\nهل تريد تفريغ السلة والبدء من هذا المطعم؟',
              style: TextStyle(fontSize: 13.5, height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                clearCart();
                _cartItems.add(CartItem(product: product));
                notifyListeners();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white),
              child: const Text('نعم، ابدأ من جديد'),
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
  void _addNotification(String message,
      {bool isWarning = false, bool isOwnerNotification = false}) {
    notifications.insert(
        0,
        AppNotification(
          message: message,
          time: DateTime.now(),
          isWarning: isWarning,
          isOwnerNotification: isOwnerNotification,
        ));
    unreadNotifications++;
  }

  void markNotificationsRead() {
    unreadNotifications = 0;
    notifyListeners();
  }

  // --- Order ---
  Future<bool> confirmOrder(BuildContext context) async {
    if (!SecurityEngine.checkRateLimit(customerId)) {
      _addNotification(
          '⚠️ تم رصد طلبات متكررة مشبوهة! يرجى الانتظار دقيقة قبل إعادة المحاولة.',
          isWarning: true);
      notifyListeners();
      return false;
    }
    if (!SecurityEngine.verifyOrderIntegrity(_cartItems, totalAmount - deliveryFee)) {
      _addNotification('🔒 تم اكتشاف تلاعب في الأسعار! تم إلغاء الطلب لأسباب أمنية.',
          isWarning: true);
      notifyListeners();
      return false;
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

    final restName = _activeRestaurant?.name ?? 'المطعم';
    final rawPhone = _activeRestaurant?.whatsappNumber.isNotEmpty == true
        ? _activeRestaurant!.whatsappNumber
        : '07802019730';

    String phoneNumber = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '964${phoneNumber.substring(1)}';
    } else if (!phoneNumber.startsWith('964')) {
      phoneNumber = '964$phoneNumber';
    }

    final itemsText = _cartItems
        .map((i) => '• ${i.quantity}× ${i.product.name} (${i.totalPrice.toStringAsFixed(0)} د.ع)')
        .join('\n');

    final notesSection = orderNotes.trim().isNotEmpty
        ? '\n📝 *ملاحظات الطلب:* ${orderNotes.trim()}'
        : '';

    final mapLinkSection = (customerLat != null && customerLng != null)
        ? '\n📍 *موقع الزبون المباشر على الخريطة:* https://maps.google.com/?q=$customerLat,$customerLng'
        : '';

    final message = '''
🧾 *طلب جديد - جيب لي ديلفري* 🛵
--------------------------------
🏪 *المطعم:* $restName
--------------------------------
👤 *اسم الزبون:* $customerName
📞 *رقم الهاتف:* $customerPhone
📍 *المنطقة:* $selectedNeighborhood
🏠 *أقرب نقطة دالة:* $streetDetails$notesSection$mapLinkSection
--------------------------------
🍔 *الوجبات المطلوبة:*
$itemsText
--------------------------------
💵 *مجموع الوجبات:* ${subtotal.toStringAsFixed(0)} د.ع
🛵 *أجور التوصيل:* ${deliveryFee.toStringAsFixed(0)} د.ع${loyaltyDiscount > 0 ? '\n🌟 *خصم النقاط:* -${loyaltyDiscount.toStringAsFixed(0)} د.ع' : ''}
💰 *المبلغ الصافي المطلوب:* ${totalAmount.toStringAsFixed(0)} د.ع

💳 *طريقة الدفع:* ${paymentMethod == PaymentMethod.cod ? 'كاش عند الاستلام' : 'ماستركارد'}
--------------------------------
شكراً لطلبكم عبر تطبيق جيب لي! 🚀
''';

    final uri = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    });

    // Save customer name and phone in session for future orders
    saveSession();

    return true;
  }

  void completeOrderAndResetHome() {
    final earned = (subtotal / 1000).floor() * 10;
    _addNotification(
        '✅ تم إرسال طلبك عبر الواتساب!${earned > 0 ? ' كسبت $earned نقطة 🌟' : ''}');
    if (_cartItems.isNotEmpty) {
      // احفظ الطلب في التاريخ
      _pastOrders.insert(
        0,
        PastOrder(
          id: 'ORD-#${Random().nextInt(9000) + 1000}',
          restaurantId: cartRestaurantId ?? 'akkala',
          restaurantName: _activeRestaurant?.name ?? 'مطعم أكّالة',
          items: _cartItems.map((i) => CartItem(product: i.product, quantity: i.quantity)).toList(),
          totalAmount: totalAmount,
          date: DateTime.now(),
        ),
      );
      // اكسب النقاط
      earnPoints(subtotal);
      // اخصم النقاط المستخدمة
      if (_redeemingPoints && _loyaltyPoints >= pointsPerReward) {
        _loyaltyPoints -= pointsPerReward;
        _loyaltyHistory.insert(
            0,
            LoyaltyEntry(
                points: -pointsPerReward,
                reason: '🎁 استبدال نقاط — خصم ${rewardValue.toStringAsFixed(0)} د.ع',
                date: DateTime.now()));
      }
    }
    _redeemingPoints = false;
    _orderStatus = OrderStatus.confirmed;
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
          '✅ تم استلام طلبك من "${_activeRestaurant?.name ?? 'المطعم'}" وهو قيد التحضير الآن!');
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
          '🛵 المندوب "$driverName" انطلق لتوصيل طلبك، طعامك قريباً سيصل!');
      _orderStatus = OrderStatus.onWay;
      notifyListeners();
    });

    Future.delayed(const Duration(seconds: 10), () {
      _deliveryTimer?.cancel();
      _deliveryCountdown = 0;
      _addNotification(
          '🎉 وصل المندوب "$driverName"! ألف عافية وصحة وعافية 🍔');
      _addNotification(
          '💰 إشعار المطعم: تم تسليم الطلب للزبون "$customerName" واستلام المبلغ ${totalAmount.toStringAsFixed(0)} د.ع. الفاتورة مغلقة ✅',
          isOwnerNotification: true);
      _orderStatus = OrderStatus.arrived;
      playFeedbackSound();
      notifyListeners();
    });
  }

  void submitRating() {
    _addNotification(
        '⭐ شكراً على تقييمك! قيّمت المطعم بـ $restaurantRating نجوم والمندوب بـ $driverRating نجوم.');
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
        final doc = FirebaseFirestore.instance.collection('customers').doc(phone);
        final snap = await doc.get();
        if (!snap.exists) {
          await doc.set({
            'name': name,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          await doc.update({'name': name, 'lastLogin': FieldValue.serverTimestamp()});
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

      // فحص أصحاب المطاعم ديناميكياً
      for (var r in _restaurants) {
        if (r.ownerPhone == idNormalized && r.ownerPassword == password) {
          _isLoggedIn = true;
          _userRole = 'owner';
          _userEmailOrPhone = idNormalized;
          _userRestaurantId = r.id;
          saveSession();
          _addNotification('🏪 مرحباً بك! تم تسجيل دخولك كمالك لـ ${r.name}',
              isOwnerNotification: true);
          notifyListeners();
          return true;
        }
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
}

class JeebliProvider extends InheritedNotifier<JeebliController> {
  const JeebliProvider(
      {super.key,
      required JeebliController super.notifier,
      required super.child});

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
      child: MaterialApp(
        title: 'جيب لي ديلفري',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE65100),
            primary: const Color(0xFFE65100),
            secondary: const Color(0xFFFFB300),
            surface: const Color(0xFFFFFDF9),
          ),
          fontFamily: 'Cairo',
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: SplashScreen(),
        ),
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
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));

    // --- Tagline animation (starts 400ms after logo) ---
    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // --- Progress bar animation ---
    _progressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تفعيل خدمة الموقع',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'هل تريد تفعيل الموقع لرؤية أقرب المطاعم إليك؟\nيمكنك تفعيله لاحقاً من صفحتك الشخصية.',
                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('لاحقاً'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8F00),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await controller.detectLocation();
                        },
                        child: const Text('تفعيل', style: TextStyle(fontWeight: FontWeight.bold)),
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
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
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
                  gradient: RadialGradient(colors: [
                    const Color(0xFFFF8F00).withOpacity(0.12),
                    Colors.transparent,
                  ]),
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
                  gradient: RadialGradient(colors: [
                    const Color(0xFFE65100).withOpacity(0.10),
                    Colors.transparent,
                  ]),
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
                          child: Text(
                            '🛵',
                            style: TextStyle(fontSize: 62),
                          ),
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
                      child: const Text(
                        'جيب لي',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                      child: const Text(
                        'وجبتك عالبيت بضغطة زر ✨',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white60,
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
                      child: const Text(
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
                              backgroundColor:
                                  Colors.white.withOpacity(0.08),
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFFF8F00)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _progressController.value < 0.5
                                ? 'جارٍ تحميل المطاعم...'
                                : _progressController.value < 0.9
                                    ? 'تجهيز قائمة الوجبات...'
                                    : 'أهلاً وسهلاً! 🎉',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
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

    if (controller.userRole == 'superadmin') {
      return const SuperAdminShell();
    }

    if (controller.userRole == 'owner') {
      return const RestaurantOwnerAdminScreen();
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
                color: Colors.black.withOpacity(controller.isDarkMode ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, -5))
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
              icon: Icon(Icons.restaurant_menu_outlined, color: controller.subtextColor),
              selectedIcon:
                  const Icon(Icons.restaurant_menu, color: Color(0xFFFF8F00)),
              label: 'المطاعم',
            ),
            NavigationDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.shopping_cart_outlined, color: controller.subtextColor),
                  if (controller.cartCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF8F00), shape: BoxShape.circle),
                        child: Text('${controller.cartCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                ],
              ),
              selectedIcon:
                  const Icon(Icons.shopping_cart, color: Color(0xFFFF8F00)),
              label: 'السلة',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: controller.subtextColor),
              selectedIcon: const Icon(Icons.person, color: Color(0xFFFF8F00)),
              label: 'الحساب',
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    if (controller.activeRestaurant != null) return const RestaurantMenuScreen();

    final filteredRestaurants = _searchQuery.isEmpty
        ? controller.restaurants
        : controller.restaurants
            .where((r) =>
                r.name.contains(_searchQuery) ||
                r.cuisine.contains(_searchQuery) ||
                r.description.contains(_searchQuery))
            .toList();

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
                              colors: [Color(0xFFFF8F00), Color(0xFFE65100)]),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    const Color(0xFFE65100).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Icon(Icons.fastfood_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('جيب لي ديلفري 🍔',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: controller.textColor,
                                    letterSpacing: 0.5)),
                            Text('اطلب وجبتك من أشهر مطاعم منطقتنا',
                                style: TextStyle(
                                    fontSize: 12, color: controller.subtextColor)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showOwnerLoginModal(context, controller),
                        tooltip: 'دخول الإدارة وأصحاب المطاعم 🔑',
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: const Icon(
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
                            color: Colors.white.withOpacity(0.08),
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
                            color: Colors.black.withOpacity(controller.isDarkMode ? 0.2 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: TextStyle(color: controller.textColor, fontSize: 14),
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن مطعم أو وجبة...',
                        hintStyle:
                            TextStyle(color: controller.subtextColor, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFFFF8F00), size: 22),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: controller.subtextColor, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_searchQuery.isEmpty) _buildPromoSlider(context),
                  if (_searchQuery.isEmpty) const SizedBox(height: 16),
                  if (_searchQuery.isNotEmpty && filteredRestaurants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد نتائج لـ "$_searchQuery"',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (controller.orderStatus != OrderStatus.idle &&
                      controller.orderStatus != OrderStatus.rated)
                    _buildActiveOrderBanner(controller),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final rest = filteredRestaurants[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: controller.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(controller.isDarkMode ? 0.3 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
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
                                  const Icon(Icons.store_mall_directory_outlined,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${rest.name} مغلق حالياً 🔴\nالطلب غير متاح في هذا الوقت',
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red[800],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                                    top: Radius.circular(24)),
                                child: CustomAppImage(
                                    imageUrl: rest.imageUrl,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover),
                              ),
                              // overlay مغلق فوق الصورة
                              if (!rest.isOpenNow)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24)),
                                    child: Container(
                                      color: Colors.black.withOpacity(0.6),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 40),
                                            SizedBox(height: 8),
                                            Text('مغلق',
                                                style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.redAccent,
                                                    letterSpacing: 2)),
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
                                  onTap: () => controller.toggleFavoriteRestaurant(rest.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24)),
                                    child: Icon(
                                      controller.isRestaurantFavorite(rest.id)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: controller.isRestaurantFavorite(rest.id)
                                          ? Colors.redAccent
                                          : Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(16),
                                      border:
                                          Border.all(color: Colors.white24)),
                                  child: Row(children: [
                                    const Icon(Icons.location_on,
                                        color: Color(0xFFFFB300), size: 14),
                                    const SizedBox(width: 4),
                                    Text(rest.location,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ]),
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
                                        child: Text(rest.name,
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: controller.textColor))),
                                    // تقييم النجوم
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: controller.bgColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.green
                                                  .withOpacity(0.3))),
                                      child: Row(children: [
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text('${rest.rating}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.greenAccent)),
                                      ]),
                                    ),
                                    const SizedBox(width: 8),
                                    // شارة مفتوح / مغلق
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: rest.isOpenNow
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.red.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: rest.isOpenNow
                                              ? Colors.greenAccent.withOpacity(0.5)
                                              : Colors.redAccent.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Row(children: [
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
                                                  : Colors.redAccent),
                                        ),
                                      ]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(rest.description,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        height: 1.5)),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                      height: 1, color: Colors.white12),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.fastfood_rounded,
                                          size: 16,
                                          color: Color(0xFFFF8F00)),
                                      const SizedBox(width: 6),
                                      Text(rest.cuisine,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white)),
                                    ]),
                                    Row(children: [
                                      const Icon(
                                          Icons.delivery_dining_rounded,
                                          size: 18,
                                          color: Colors.lightBlueAccent),
                                      const SizedBox(width: 6),
                                      Text(rest.deliveryTime,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.lightBlueAccent,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ]),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // ساعات العمل
                                Row(children: [
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
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: filteredRestaurants.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildPromoSlider(BuildContext context) {
    final deals = [
      {
        'title': '🔥 خصم 25% من مطعم أكّالة',
        'desc': 'استخدم كود الخصم JEEBLI25 على الوجبات السريعة',
        'badge': 'عرض حصري',
        'colors': [const Color(0xFFE65100), const Color(0xFFFF8F00)],
        'icon': Icons.local_fire_department_rounded,
      },
      {
        'title': '🍕 عرض العائلة من أبو العبد',
        'desc': 'بيتزا عائلية كبيرة + بطاطس فنجر مجاناً اليوم',
        'badge': 'توفير عائلي',
        'colors': [const Color(0xFF1E293B), const Color(0xFF475569)],
        'icon': Icons.local_offer_rounded,
      },
      {
        'title': '🛵 توصيل فوري وسريع لجميع الوجبات',
        'desc': 'للطلبات التي تتجاوز 15,000 د.ع طوال هذا الأسبوع',
        'badge': 'توصيل مجاني',
        'colors': [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
        'icon': Icons.delivery_dining_rounded,
      },
    ];

    return SizedBox(
      height: 120,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: deals.length,
        itemBuilder: (ctx, i) {
          final deal = deals[i];
          final colors = deal['colors'] as List<Color>;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: colors.first.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 5))
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
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(deal['badge'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Text(deal['title'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(deal['desc'] as String,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10.5)),
                    ],
                  ),
                ),
                Icon(deal['icon'] as IconData,
                    color: Colors.white.withOpacity(0.85), size: 42),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveOrderBanner(JeebliController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFFFB300)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ تم إرسال طلبك للمطعم عبر الواتساب',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text('سيتواصل معك المطعم للتأكيد قريباً',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
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
  final List<Category> categories = [
    Category(id: 'all', name: 'الكل', icon: Icons.grid_view_rounded),
    Category(id: 'favs', name: 'المفضلة ❤️', icon: Icons.favorite_rounded),
    Category(id: 'burger', name: 'برجر', icon: Icons.lunch_dining),
    Category(id: 'zinger', name: 'زنجر', icon: Icons.restaurant),
    Category(id: 'pizza', name: 'بيتزا', icon: Icons.local_pizza),
    Category(id: 'shawarma', name: 'شاورما', icon: Icons.flatware),
    Category(id: 'fries', name: 'فنجر', icon: Icons.fastfood),
  ];

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
    final all = controller.getProductsByRestaurant(rest.id);
    final categoryFiltered = controller.selectedCategoryId == 'all'
        ? all
        : controller.selectedCategoryId == 'favs'
            ? all.where((p) => controller.isProductFavorite(p.id)).toList()
            : all
                .where((p) => p.categoryId == controller.selectedCategoryId)
                .toList();

    final filtered = _searchQuery.isEmpty
        ? categoryFiltered
        : categoryFiltered
            .where((p) =>
                p.name.contains(_searchQuery) ||
                p.description.contains(_searchQuery))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(rest.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => controller.setActiveRestaurant(null)),
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
                      child: Image.network(rest.imageUrl,
                          width: 75, height: 75, fit: BoxFit.cover)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFFF8F00), size: 13),
                          const SizedBox(width: 4),
                          Text(rest.location,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold))
                        ]),
                        const SizedBox(height: 4),
                        Text(rest.cuisine,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white54)),
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text('${rest.rating}',
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ]),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن وجبة في ${rest.name}...',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFFFF8F00), size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white38, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  final isSel = controller.selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () => controller.setCategory(cat.id),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFFF8F00)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          Icon(cat.icon,
                              size: 15,
                              color: isSel
                                  ? Colors.white
                                  : Colors.white54),
                          const SizedBox(width: 5),
                          Text(cat.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSel
                                      ? Colors.white
                                      : Colors.white54)),
                        ]),
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
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final prod = filtered[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(prod.imageUrl,
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                      width: 88,
                                      height: 88,
                                      color:
                                          const Color(0xFF0F172A))),
                            ),
                            if (!prod.isAvailable)
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                child: const Center(
                                    child: Text('خلصانة 🛑',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight:
                                                FontWeight.bold))),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(prod.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.white)),
                                  ),
                                  GestureDetector(
                                    onTap: () => controller.toggleFavoriteProduct(prod.id),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        controller.isProductFavorite(prod.id)
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: controller.isProductFavorite(prod.id)
                                            ? Colors.redAccent
                                            : Colors.white38,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(prod.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white54,
                                      height: 1.3)),
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
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white38,
                                                decoration: TextDecoration
                                                    .lineThrough)),
                                      Text(
                                          '${(prod.discountPrice ?? prod.price).toStringAsFixed(0)} د.ع',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF8F00))),
                                    ],
                                  ),
                                  if (prod.isAvailable)
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          controller.addToCart(prod, context),
                                      icon: const Icon(
                                          Icons.add_shopping_cart,
                                          size: 13),
                                      label: const Text('أضف',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF8F00),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.red
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Text('نَفَدَت',
                                          style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 10.5,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
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
            .firstWhere((r) => r.id == controller.cartRestaurantId,
                orElse: () => controller.allRestaurants.first)
            .name
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('سلة المشتريات',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: controller.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 80, color: Colors.orange.withOpacity(0.3)),
                  const SizedBox(height: 14),
                  const Text('السلة فارغة!',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('تصفح قوائم الطعام وأضف وجباتك',
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => controller.setTab(0),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8F00),
                        foregroundColor: Colors.white),
                    child: const Text('ابدأ التسوق'),
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
                  child: Row(children: [
                    const Icon(Icons.restaurant,
                        color: Color(0xFFFF8F00), size: 15),
                    const SizedBox(width: 8),
                    Text('تطلب من: $restName',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF8F00))),
                  ]),
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
                              color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(item.product.imageUrl,
                                    width: 65,
                                    height: 65,
                                    fit: BoxFit.cover)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.white)),
                                  Text(
                                      '${item.product.price.toStringAsFixed(0)} د.ع للوجبة',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10.5)),
                                  Text(
                                      'الإجمالي: ${item.totalPrice.toStringAsFixed(0)} د.ع',
                                      style: const TextStyle(
                                          color: Color(0xFFFF8F00),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                        onTap: () => controller
                                            .removeFromCart(item.product),
                                        child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A),
                                                shape: BoxShape.circle),
                                            child: const Icon(Icons.remove,
                                                size: 14,
                                                color: Colors.white))),
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text('${item.quantity}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.white))),
                                    GestureDetector(
                                        onTap: () => controller.addToCart(
                                            item.product, context),
                                        child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFFFF8F00)
                                                    .withOpacity(0.2),
                                                shape: BoxShape.circle),
                                            child: const Icon(Icons.add,
                                                size: 14,
                                                color:
                                                    Color(0xFFFF8F00)))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                    onTap: () => controller
                                        .deleteFromCart(item.product),
                                    child: const Text('حذف',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 10.5,
                                            fontWeight:
                                                FontWeight.w500))),
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

  Widget _buildOrderSummary(
      BuildContext context, JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('مجموع الوجبات',
                style: TextStyle(color: Colors.white54, fontSize: 12.5)),
            Text('${controller.subtotal.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('توصيل جيب لي',
                style: TextStyle(color: Colors.white54, fontSize: 12.5)),
            Text('${controller.deliveryFee.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          if (controller.loyaltyDiscount > 0) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('🌟 خصم النقاط المستبدلة',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12.5, fontWeight: FontWeight.bold)),
              Text('-${controller.loyaltyDiscount.toStringAsFixed(0)} د.ع',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            ]),
          ],
          const SizedBox(height: 10),
          // ── كارت استبدال النقاط ──
          GestureDetector(
            onTap: () => controller.toggleRedeemPoints(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          controller.loyaltyPoints >= JeebliController.pointsPerReward
                              ? (controller.redeemingPoints
                                  ? 'تم تفعيل خصم 1,500 د.ع! 🎉'
                                  : 'استبدل 250 نقطة بخصم 1,500 د.ع 🎁')
                              : 'لديك ${controller.loyaltyPoints} نقطة (تحتاج ${controller.pointsNeededForReward} نقطة إضافية للخصم)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: controller.redeemingPoints
                                ? Colors.white
                                : (controller.loyaltyPoints >= JeebliController.pointsPerReward
                                    ? Colors.amber
                                    : Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.loyaltyPoints >= JeebliController.pointsPerReward)
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
          const Divider(height: 20, color: Colors.white12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('المبلغ الكلي',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white)),
            Text('${controller.totalAmount.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFFFF8F00))),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const Directionality(
                          textDirection: TextDirection.rtl,
                          child: CheckoutScreen()))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('إتمام الطلب والدفع',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('تأكيد الطلب والدفع',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
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
                                content: Text('✅ تم تحديد إحداثيات موقعك الجغرافي بنجاح! سيتم إرسال رابط الخريطة للمندوب'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ تعذر تحديد الموقع تلقائياً. يمكنك كتابة موقعك يدويًا بكل سهولة.'),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
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
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _buildTextField(
                        label: 'الاسم الكامل',
                        icon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'الرجاء إدخال الاسم'
                            : null,
                        onChanged: (v) => controller.customerName = v),
                    const SizedBox(height: 12),
                    _buildTextField(
                        label: 'رقم الهاتف',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        hint: '07800000000',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'الرجاء إدخال الهاتف';
                          }
                          if (v.length < 10) return 'رقم هاتف غير صحيح';
                          return null;
                        },
                        onChanged: (v) => controller.customerPhone = v),
                    const SizedBox(height: 12),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) =>
                          controller.selectedNeighborhood = value,
                      decoration: InputDecoration(
                        labelText: 'المنطقة / الحي',
                        labelStyle:
                            const TextStyle(color: Colors.white54),
                        hintText: 'اكتب اسم المنطقة أو الحي...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            color: Colors.amber),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFFF8F00))),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                        label: 'أقرب نقطة دالة',
                        icon: Icons.home_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'الرجاء إدخال نقطة دالة'
                            : null,
                        onChanged: (v) => controller.streetDetails = v),
                    const SizedBox(height: 12),
                    _buildTextField(
                        label: 'ملاحظات الطلب (اختياري)',
                        icon: Icons.note_alt_outlined,
                        hint: 'مثال: بدون ثومية، تثقيل صوص، حار...',
                        validator: (v) => null,
                        onChanged: (v) => controller.orderNotes = v),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('💳 طريقة الدفع'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _paymentOption(
                    icon: Icons.delivery_dining,
                    label: 'كاش عند الاستلام',
                    subtitle: 'ادفع لحظة وصول المندوب',
                    isSelected:
                        controller.paymentMethod == PaymentMethod.cod,
                    onTap: () => setState(() {
                      controller.paymentMethod = PaymentMethod.cod;
                    }),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _paymentOption(
                    icon: Icons.credit_card,
                    label: 'ماستركارد',
                    subtitle: 'بطاقة ائتمانية آمنة',
                    isSelected: controller.paymentMethod ==
                        PaymentMethod.mastercard,
                    onTap: () => setState(() {
                      controller.paymentMethod = PaymentMethod.mastercard;
                    }),
                  )),
                ],
              ),
              if (controller.paymentMethod == PaymentMethod.mastercard) ...[
                const SizedBox(height: 14),
                _buildMastercardForm(controller),
              ],
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
                    if (controller.paymentMethod == PaymentMethod.mastercard) {
                      if (controller.cardNumber.length < 16 ||
                          controller.cardExpiry.isEmpty ||
                          controller.cardCvv.length < 3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'يرجى إدخال بيانات البطاقة الصحيحة'),
                                behavior: SnackBarBehavior.floating));
                        return;
                      }
                    }
                    final success =
                        await controller.confirmOrder(context);
                    if (!context.mounted) return;
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              controller.notifications.isNotEmpty
                                  ? controller.notifications.first.message
                                  : 'فشل تأكيد الطلب'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.red));
                      return;
                    }
                    _showWhatsAppConfirmationDialog(context, controller);
                  },
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('تأكيد الطلب بأمان',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14.5,
          color: Colors.white));

  Widget _buildTextField(
      {required String label,
      required IconData icon,
      TextInputType? keyboardType,
      String? hint,
      required String? Function(String?) validator,
      required void Function(String) onChanged}) {
    return TextFormField(
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, size: 20, color: Colors.amber),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF8F00))),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _paymentOption(
      {required IconData icon,
      required String label,
      required String subtitle,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF8F00).withOpacity(0.1)
              : const Color(0xFF1E293B),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF8F00)
                  : Colors.white24,
              width: 1.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFFFF8F00)
                    : Colors.white54,
                size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFFFF8F00)
                        : Colors.white54)),
            Text(subtitle,
                style: const TextStyle(fontSize: 9.5, color: Colors.white38),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildMastercardForm(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('بيانات البطاقة الائتمانية',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Row(children: [
              Container(
                  width: 30,
                  height: 20,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEB001B),
                      borderRadius: BorderRadius.circular(4))),
              Container(
                  width: 30,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF79E1B).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4))),
            ]),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            keyboardType: TextInputType.number,
            maxLength: 16,
            style: const TextStyle(color: Colors.white, letterSpacing: 2),
            decoration: InputDecoration(
              labelText: 'رقم البطاقة',
              hintText: 'XXXX XXXX XXXX XXXX',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.credit_card,
                  color: Colors.white70, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFFB300))),
              counterStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
            ),
            onChanged: (v) => controller.cardNumber = v,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'تاريخ الانتهاء',
                  hintText: 'MM/YY',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.calendar_month_outlined,
                      color: Colors.white70, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white24)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFFFB300))),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                ),
                onChanged: (v) => controller.cardExpiry = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                maxLength: 3,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'CVV',
                  hintText: '***',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: Colors.white70, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white24)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFFFB300))),
                  counterStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                ),
                onChanged: (v) => controller.cardCvv = v,
              ),
            ),
          ]),
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
      child: Row(children: [
        const Icon(Icons.shield_outlined, color: Colors.green, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('محمي بتشفير جيب لي 🔒',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green)),
              Text(
                  'يتم تشفير بياناتك ومراجعة سلامة أسعار طلبك ضد التلاعب تلقائياً.',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.green.shade300,
                      height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildOrderSummaryCard(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('مجموع الوجبات',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('${controller.subtotal.toStringAsFixed(0)} د.ع',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('توصيل جيب لي',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('${controller.deliveryFee.toStringAsFixed(0)} د.ع',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        const Divider(height: 18, color: Colors.white12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الإجمالي الكلي',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
          Text('${controller.totalAmount.toStringAsFixed(0)} د.ع',
              style: const TextStyle(
                  color: Color(0xFFFF8F00),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ]),
    );
  }

  void _showWhatsAppConfirmationDialog(
      BuildContext context, JeebliController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.mark_chat_read_rounded,
                  color: Color(0xFFFF8F00), size: 24),
              SizedBox(width: 8),
              Text('تأكيد إرسال الطلب 💬',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'هل قمت بإرسال الرسالة إلى المطعم عبر الواتساب؟',
            style: TextStyle(
                color: Colors.white70, fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'ℹ️ لم يتم تفريغ السلة. يمكنك تعديل الطلب أو إعادة المحاولة.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('لم أرسل / تراجعت ❌',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.completeOrderAndResetHome();
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
                        '🎉 تم تأكيد إرسال طلبك بنجاح! بالعافية والصحة.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('نعم، تم الإرسال ✅',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _bikeAnim = Tween<double>(begin: 0.05, end: 0.85).animate(
        CurvedAnimation(parent: _bikeController, curve: Curves.easeInOut));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
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
        title: const Text('تتبع الطلب المباشر 🛵',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
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
                      offset: const Offset(0, 10))
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
                            color: Colors.green, shape: BoxShape.circle),
                        child: const Icon(Icons.store,
                            color: Colors.white, size: 20),
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
                              shape: BoxShape.circle),
                          child: const Icon(Icons.home,
                              color: Colors.white, size: 20),
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
                                shape: BoxShape.circle),
                            child: const Icon(Icons.delivery_dining,
                                color: Colors.black, size: 24),
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
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الوقت المتبقي المقدر:',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      Text(
                          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF8F00))),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF8F00).withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.info_outline,
                            color: Color(0xFFFF8F00), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_getStatusText(controller.orderStatus),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white))),
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
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    radius: 24,
                    child: const Icon(Icons.person,
                        color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.driverName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white)),
                        const Text('مندوب توصيل جيب لي السريع',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green),
                    onPressed: () => launchUrl(
                        Uri.parse('tel:${controller.driverPhone}')),
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
                                      child: RatingScreen())));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('انتقل لتقييم الوجبة والمندوب ⭐',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12)),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 14, color: Colors.white54),
                            SizedBox(width: 6),
                            Text('توكن أمان الطلب المشفر',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          controller.lastOrderToken,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Colors.white38,
                              fontWeight: FontWeight.bold),
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
        size.width * 0.5, size.height * 0.5, size.width * 0.15, size.height * 0.8);
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
        title: const Text('قيّم تجربتك معنا ⭐',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
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
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملاحظاتك وشكاواك 📝',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white)),
                  const SizedBox(height: 10),
                  TextField(
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'أخبرنا برأيك بصدق...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Colors.white38),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white24)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFFF8F00))),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    onChanged: (v) => controller.feedbackText = v,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'وجبة لذيذة 😋',
                      'توصيل سريع ⚡',
                      'مندوب محترم 👍',
                      'سعر مناسب 💰',
                      'تأخر التوصيل ⏰',
                      'وجبة باردة ❄️'
                    ]
                        .map((tag) => GestureDetector(
                              onTap: () {
                                controller.playFeedbackSound();
                                setState(() =>
                                    controller.feedbackText += ' $tag');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFFF8F00)
                                          .withOpacity(0.4)),
                                  borderRadius: BorderRadius.circular(20),
                                  color: const Color(0xFFFF8F00)
                                      .withOpacity(0.08),
                                ),
                                child: Text(tag,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFFF8F00))),
                              ),
                            ))
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'يرجى تقييم المطعم والمندوب قبل الإرسال'),
                        behavior: SnackBarBehavior.floating));
                    return;
                  }
                  controller.submitRating();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const Directionality(
                              textDirection: TextDirection.rtl,
                              child: ThankYouScreen())),
                      (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('إرسال التقييم وإغلاق الطلب ✅',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
            ]),
          ]),
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
                    ? Colors.white38
                    : const Color(0xFFFF8F00),
                fontWeight: FontWeight.bold,
                fontSize: 13),
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
                      colors: [Color(0xFFE65100), Color(0xFFFFB300)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 64),
              ),
              const SizedBox(height: 24),
              const Text('شكراً لتقييمك! ❤️',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text(
                'آراؤكم تساعدنا في تطوير "جيب لي" وتقديم أفضل خدمة توصيل دائماً ⭐️',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.white54, height: 1.6),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.3))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Row(
                          children: List.generate(
                              5,
                              (i) => Icon(Icons.star,
                                  size: 14,
                                  color: i < controller.restaurantRating
                                      ? Colors.amber
                                      : Colors.white24))),
                      const SizedBox(height: 4),
                      const Text('المطعم',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ]),
                    Container(
                        width: 1, height: 30, color: Colors.white12),
                    Column(children: [
                      Row(
                          children: List.generate(
                              5,
                              (i) => Icon(Icons.star,
                                  size: 14,
                                  color: i < controller.driverRating
                                      ? Colors.amber
                                      : Colors.white24))),
                      const SizedBox(height: 4),
                      const Text('المندوب',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ]),
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
                                child: MainNavigationShell())),
                        (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('طلب وجبة جديدة 🍔',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
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
                borderRadius: BorderRadius.circular(24)),
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
                    child: const Icon(Icons.stars_rounded,
                        color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'أهلاً بك في جيب لي 🖐️',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تصفح أفضل المطاعم القريبة منك، واطلب وجبتك المفضلة وتصلك فوراً بأسرع وقت ⚡',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.6),
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
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'اكتشف المطاعم الآن 🚀',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
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

class RestaurantOwnerAdminScreen extends StatelessWidget {
  const RestaurantOwnerAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final isAkkalaOwner = controller.userRestaurantId == 'akkala';
    final isAbuAlAbdOwner = controller.userRestaurantId == 'abualabd';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('لوحة تحكم المطعم ⚙️',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.amber),
            tooltip: 'تعديل بيانات المطعم',
            onPressed: () => _showOwnerEditRestaurantDialog(
                context, controller, controller.userRestaurantId ?? 'akkala'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(context, controller),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOwnerProductDialog(
            context, controller, controller.userRestaurantId ?? 'akkala'),
        backgroundColor: const Color(0xFFFF8F00),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة وجبة',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            child: const Row(children: [
              Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'يمكنك هنا إدارة قائمة مطعمك (إضافة، تعديل، حذف) والتحكم بتوفر الوجبات والإحصائيات.',
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: Colors.white70),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // ─── بطاقة حالة المطعم (مفتوح / مغلق) ───
          _buildRestaurantStatusCard(context, controller),
          const SizedBox(height: 16),
          _buildVendorAnalyticsCard(context, controller, controller.userRestaurantId ?? 'akkala'),
          const SizedBox(height: 18),
          // ─── عرض مطعم صاحبه فقط حسب الـ ID ───
          Builder(builder: (ctx) {
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
                      const Icon(Icons.store_mall_directory_outlined,
                          color: Colors.white30, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'لم يتم العثور على مطعمك.\nتواصل مع الإدارة.',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return _buildRestSection(ctx, controller, myId, myRest.first.name);
          }),
        ],
      ),
    );
  }

  /// بطاقة تحكم حالة المطعم مفتوح / مغلق
  Widget _buildRestaurantStatusCard(
      BuildContext context, JeebliController controller) {
    final restId = controller.userRestaurantId ?? 'akkala';
    final restaurant = controller.allRestaurants.firstWhere(
      (r) => r.id == restId,
      orElse: () => controller.allRestaurants.first,
    );
    final isClosed = restaurant.isClosedManually;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClosed
              ? [const Color(0xFF3D0000), const Color(0xFF1E293B)]
              : [const Color(0xFF003D1E), const Color(0xFF1E293B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClosed
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.greenAccent.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isClosed ? Colors.red : Colors.green).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isClosed ? Colors.redAccent : Colors.greenAccent)
                  .withOpacity(0.15),
              border: Border.all(
                color: isClosed ? Colors.redAccent : Colors.greenAccent,
                width: 1.5,
              ),
            ),
            child: Icon(
              isClosed ? Icons.store_mall_directory_outlined : Icons.storefront_rounded,
              color: isClosed ? Colors.redAccent : Colors.greenAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClosed ? '🔴 مطعمك مغلق حالياً' : '🟢 مطعمك مفتوح للطلبات',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isClosed ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isClosed
                      ? 'الزبائن لا يستطيعون الطلب الآن'
                      : 'الزبائن يستطيعون الطلب منك الآن',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => controller.toggleRestaurantClosed(restId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 64,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isClosed
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.greenAccent.withOpacity(0.3),
                border: Border.all(
                  color: isClosed ? Colors.redAccent : Colors.greenAccent,
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    alignment: isClosed
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isClosed ? Colors.redAccent : Colors.greenAccent,
                      ),
                      child: Icon(
                        isClosed ? Icons.close : Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorAnalyticsCard(
      BuildContext context, JeebliController controller, String restId) {
    final products = controller.getProductsByRestaurant(restId);
    final availableCount = products.where((p) => p.isAvailable).length;
    final restaurant = controller.allRestaurants.firstWhere(
      (r) => r.id == restId,
      orElse: () => controller.allRestaurants.first,
    );

    final restaurantOrders = controller.pastOrders
        .where((o) => o.restaurantId == restId)
        .toList();
    final totalSales =
        restaurantOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Text('إحصائيات المطعم والمبيعات 📊',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('تقييم ${restaurant.rating} ⭐',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber)),
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
                    Colors.greenAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analyticsItem('عدد الطلبات', '${restaurantOrders.length} طلب',
                    Icons.shopping_bag_outlined, Colors.amber),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _analyticsItem('الوجبات المتوفرة',
                    '$availableCount من ${products.length}', Icons.restaurant_menu, Colors.lightBlueAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analyticsItem(
                    'أجور التوصيل',
                    '${restaurant.deliveryFee.toStringAsFixed(0)} د.ع',
                    Icons.delivery_dining,
                    Colors.orangeAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _analyticsItem(
      String label, String value, IconData icon, Color color) {
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
                child: Text(label,
                    style:
                        const TextStyle(fontSize: 10.5, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRestSection(BuildContext context, JeebliController ctrl,
      String restId, String title) {
    final prods = ctrl.getProductsByRestaurant(restId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Colors.amber)),
        ),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.05))),
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
                    horizontal: 14, vertical: 8),
                leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(prod.imageUrl,
                        width: 48, height: 48, fit: BoxFit.cover)),
                title: Text(prod.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                subtitle: Text(
                  prod.isAvailable ? '🟢 متوفر للطلب' : '🔴 خلصانة',
                  style: TextStyle(
                      fontSize: 11,
                      color: prod.isAvailable
                          ? Colors.green[300]
                          : Colors.red[300],
                      fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: Colors.blueAccent, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showOwnerProductDialog(
                          context, ctrl, restId,
                          product: prod),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded,
                          color: Colors.redAccent, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          _showOwnerDeleteDialog(context, ctrl, prod),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ctrl.toggleProductAvailability(prod.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: prod.isAvailable
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(60, 30),
                      ),
                      child: Text(prod.isAvailable ? 'متوفر' : 'خلصانة',
                          style: const TextStyle(fontSize: 10)),
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

  void _showLogoutDialog(
      BuildContext context, JeebliController controller) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج',
              style: TextStyle(color: Colors.white)),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              style: TextStyle(color: Colors.white54)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.logout();
              },
              child: const Text('نعم، تسجيل خروج',
                  style: TextStyle(color: Colors.red)),
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('دخول الإدارة وأصحاب المطاعم 🔑',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سجّل دخولك لمتابعة لوحة تحكم مطعمك أو إدارة التطبيق:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                prefixIcon: const Icon(Icons.phone_outlined, color: Colors.amber, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.amber, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              final pass = passCtrl.text.trim();
              if (phone.isEmpty || pass.isEmpty) return;

              bool success = controller.loginOwnerOrAdmin(phone, pass);
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
                backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white),
            child: const Text('دخول اللوحة 🚀'),
          ),
        ],
      ),
    ),
  );
}

void _showOwnerEditRestaurantDialog(
    BuildContext context, JeebliController ctrl, String restId) {
  final rest = ctrl.allRestaurants.firstWhere(
    (r) => r.id == restId,
    orElse: () => ctrl.allRestaurants.first,
  );

  final nameCtrl = TextEditingController(text: rest.name);
  final waCtrl = TextEditingController(text: rest.whatsappNumber);
  final feeCtrl = TextEditingController(text: rest.deliveryFee.toStringAsFixed(0));
  final timeCtrl = TextEditingController(text: rest.deliveryTime);
  final descCtrl = TextEditingController(text: rest.description);
  final imgCtrl = TextEditingController(text: rest.imageUrl);

  int selectedOpenHour = rest.openHour;
  int selectedCloseHour = rest.closeHour;
  bool is24Hours = (rest.openHour == 0 && rest.closeHour == 24) || (rest.openHour == rest.closeHour);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تعديل بيانات المطعم ✏️',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _darkInput('اسم المطعم', nameCtrl),
                  const SizedBox(height: 8),
                  _darkInput('رقم الواتساب لاستقبال الطلبات', waCtrl, type: TextInputType.phone),
                  const SizedBox(height: 8),
                  _darkInput('أجور التوصيل (د.ع)', feeCtrl, type: TextInputType.number),
                  const SizedBox(height: 8),
                  _darkInput('وقت التوصيل المتوقع (مثال: 20-30 دقيقة)', timeCtrl),
                  const SizedBox(height: 8),
                  _darkInput('وصف المطعم', descCtrl),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _darkInput('صورة المطعم (رابط أو ملف)', imgCtrl)),
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
                          child: const Icon(Icons.add_a_photo_rounded, color: Colors.amber, size: 20),
                        ),
                        tooltip: 'اختر صورة من الكاميرا أو المعرض',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('ساعات وقواعد العمل 🕒',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
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
                              child: Text('يعمل 24 ساعة (ليل ونهار دون إغلاق 🌙☀️)',
                                  style: TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  decoration: InputDecoration(
                                    labelText: 'يفتح من الساعة',
                                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                  ),
                                  items: List.generate(24, (i) {
                                    final period = i >= 12 ? 'م' : 'ص';
                                    final h12 = i % 12 == 0 ? 12 : i % 12;
                                    return DropdownMenuItem(value: i, child: Text('$h12:00 $period'));
                                  }),
                                  onChanged: (val) => setState(() => selectedOpenHour = val ?? 10),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: selectedCloseHour > 24 ? 24 : selectedCloseHour,
                                  dropdownColor: const Color(0xFF334155),
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  decoration: InputDecoration(
                                    labelText: 'يغلق الساعة',
                                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                  ),
                                  items: List.generate(25, (i) {
                                    if (i == 24) return const DropdownMenuItem(value: 24, child: Text('12:00 ص (منتصف الليل)'));
                                    final period = i >= 12 ? 'م' : 'ص';
                                    final h12 = i % 12 == 0 ? 12 : i % 12;
                                    return DropdownMenuItem(value: i, child: Text('$h12:00 $period'));
                                  }),
                                  onChanged: (val) => setState(() => selectedCloseHour = val ?? 23),
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
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
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
                      content: Text('تم تحديث بيانات وساعات عمل المطعم بنجاح ✅'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white),
                child: const Text('حفظ التعديلات'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showOwnerProductDialog(
    BuildContext context, JeebliController ctrl, String restId,
    {Product? product}) {
  final isEdit = product != null;
  final nameController = TextEditingController(text: product?.name ?? '');
  final priceController =
      TextEditingController(text: product?.price.toString() ?? '');
  final descController =
      TextEditingController(text: product?.description ?? '');
  final imageController =
      TextEditingController(text: product?.imageUrl ?? '');
  final discountController =
      TextEditingController(text: product?.discountPrice?.toString() ?? '');

  final allowedCategories = [
    'burger', 'zinger', 'shawarma', 'pizza', 'fries', 'drinks', 'other'
  ];
  String selectedCategory = product?.categoryId ?? 'burger';
  if (!allowedCategories.contains(selectedCategory)) {
    selectedCategory = 'burger';
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(
                isEdit ? 'تعديل الوجبة ✏️' : 'إضافة وجبة جديدة 🍔',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _darkInput('اسم الوجبة', nameController),
                  const SizedBox(height: 8),
                  _darkInput('السعر (د.ع)', priceController,
                      type: TextInputType.number),
                  const SizedBox(height: 8),
                  _darkInput('الوصف', descController),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _darkInput('صورة الوجبة (رابط أو ملف)', imageController)),
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
                          child: const Icon(Icons.add_a_photo_rounded, color: Colors.amber, size: 20),
                        ),
                        tooltip: 'اختر صورة من الكاميرا أو المعرض',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _darkInput('سعر التخفيض (اختياري)', discountController,
                      type: TextInputType.number),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF334155),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'القسم',
                      labelStyle:
                          const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.white24)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'burger', child: Text('برجر')),
                      DropdownMenuItem(
                          value: 'zinger', child: Text('زنجر')),
                      DropdownMenuItem(
                          value: 'shawarma', child: Text('شاورما')),
                      DropdownMenuItem(
                          value: 'pizza', child: Text('بيتزا')),
                      DropdownMenuItem(
                          value: 'fries', child: Text('فنجر')),
                      DropdownMenuItem(
                          value: 'drinks', child: Text('مشروبات')),
                      DropdownMenuItem(
                          value: 'other', child: Text('أخرى')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedCategory = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  final price =
                      double.tryParse(priceController.text) ?? 0.0;
                  final discount =
                      double.tryParse(discountController.text);
                  if (nameController.text.trim().isEmpty || price <= 0) {
                    return;
                  }
                  final imageUrl = imageController.text.trim().isEmpty
                      ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80'
                      : imageController.text.trim();

                  if (isEdit) {
                    ctrl.updateProduct(product.id,
                        name: nameController.text.trim(),
                        price: price,
                        discountPrice: discount,
                        description: descController.text.trim(),
                        imageUrl: imageUrl,
                        clearDiscount: discountController.text.isEmpty);
                  } else {
                    ctrl.addProduct(Product(
                      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                      restaurantId: restId,
                      categoryId: selectedCategory,
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      price: price,
                      discountPrice: discount,
                      imageUrl: imageUrl,
                    ));
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: Colors.white),
                child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة الآن'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _darkInput(String label, TextEditingController c,
    {TextInputType type = TextInputType.text}) {
  return TextField(
    controller: c,
    keyboardType: type,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF8F00))),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    ),
  );
}

void _showOwnerDeleteDialog(
    BuildContext context, JeebliController ctrl, Product product) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف 🗑️',
            style: TextStyle(color: Colors.redAccent)),
        content: Text(
            'هل أنت متأكد من حذف وجبة "${product.name}" نهائياً؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              ctrl.deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('نعم، احذف الوجبة'),
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
      _nameController.text =
          c.customerName.isNotEmpty ? c.customerName : 'زبون جيب لي';
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
    final location = controller.selectedNeighborhood.isNotEmpty
        ? controller.selectedNeighborhood
        : 'لم يُحدد بعد';
    final orderCount = controller.notifications.length;

    return Scaffold(
      backgroundColor: controller.bgColor,
      appBar: AppBar(
        title: Text('الملف الشخصي',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: controller.textColor)),
        centerTitle: true,
        backgroundColor: controller.cardColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.bottomRight,
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
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0] : '؟',
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              '📷 ميزة رفع الصورة ستُفعَّل قريباً'),
                          behavior: SnackBarBehavior.floating)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6)
                        ]),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Color(0xFFFF8F00)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: controller.textColor)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Text('🟢 حساب زبون نشط',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatCard(context, 'طلب', orderCount.toString(),
                    Icons.shopping_bag_outlined),
                const SizedBox(width: 12),
                _buildStatCard(
                    context,
                    'حي',
                    location.contains('(')
                        ? location.split('(').first.trim()
                        : location.split(' ').first,
                    Icons.location_city_outlined),
                const SizedBox(width: 12),
                _buildStatCard(context, 'نقطة 🌟', controller.loyaltyPoints.toString(),
                    Icons.stars_rounded),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: controller.cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(controller.isDarkMode ? 0.2 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('معلومات الحساب',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: controller.textColor)),
                  const SizedBox(height: 14),
                  _buildEditablePhoneTile(controller, phone),
                  const Divider(height: 24, thickness: 0.5, color: Colors.white12),
                  _buildInfoTile(Icons.alternate_email_rounded, 'المعرف',
                      controller.userEmailOrPhone ?? phone,
                      color: const Color(0xFF6366F1)),
                  const Divider(height: 24, thickness: 0.5, color: Colors.white12),
                  _buildInfoTile(Icons.location_on_rounded, 'المنطقة',
                      location,
                      color: const Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildLoyaltyCard(controller),
            const SizedBox(height: 16),
            _buildOrderHistorySection(context, controller),
            const SizedBox(height: 20),
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
                      controller.isDarkMode ? 'الوضع الفاتح ☀️' : 'الوضع الداكن 🌙',
                      controller.isDarkMode ? Colors.orangeAccent : Colors.indigoAccent,
                      onTap: () => controller.toggleTheme()),
                  _buildSettingsTile(Icons.notifications_outlined,
                      'إشعارات الطلبات', Colors.amber,
                      onTap: () {}),
                  _buildSettingsTile(Icons.history_rounded,
                      'سجل الطلبات', Colors.indigo,
                      onTap: () {}),
                  _buildSettingsTile(Icons.share_rounded,
                      'مشاركة التطبيق مع الأصدقاء 📲', Colors.greenAccent,
                      onTap: () {
                        final text = Uri.encodeComponent(
                            '🍔 *تطبيق جيب لي ديلفري* 🛵\nأسرع منصة لتوصيل أشهى وجبات المطاعم إلى باب بيتك بضغطة زر!\nجربه الآن واطلب وجبتك المفضل بسهولة 🚀');
                        launchUrl(Uri.parse('https://wa.me/?text=$text'),
                            mode: LaunchMode.externalApplication);
                      }),
                  _buildSettingsTile(Icons.help_outline_rounded,
                      'الدعم والمساعدة', Colors.teal, onTap: () {}),
                  const Divider(height: 0.5, color: Colors.white12),
                  _buildSettingsTile(Icons.logout_rounded,
                      'تسجيل الخروج', Colors.red,
                      isDestructive: true,
                      onTap: () =>
                          _showLogoutDialog(context, controller)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('جيبلي ديلفري — نسخة 2.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 10.5)),
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
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF8F00).withOpacity(0.3),
        ),
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
                    child: const Icon(Icons.stars_rounded,
                        color: Color(0xFFFF8F00), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نقاط الولاء والمكافآت 🌟',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('كل 1,000 د.ع طلب = 10 نقاط',
                          style:
                              TextStyle(fontSize: 10.5, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$pts نقطة',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
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
                    style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: canRedeem ? 1.0 : progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(
                    canRedeem ? const Color(0xFF10B981) : const Color(0xFFFF8F00),
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
            const Text('سجل النقاط والمكافآت 📜',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70)),
            const SizedBox(height: 8),
            ...controller.loyaltyHistory.take(3).map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.reason,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        entry.points > 0 ? '+${entry.points}' : '${entry.points}',
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
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
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
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: controller.textColor)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: controller.subtextColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditablePhoneTile(
      JeebliController controller, String phone) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFFFF8F00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.phone_android_rounded,
              color: Color(0xFFFF8F00), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _isEditingPhone
              ? TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '07XXXXXXXXX',
                    isDense: true,
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFFF8F00))),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رقم الهاتف',
                        style: TextStyle(
                            fontSize: 11, color: Colors.white54)),
                    Text(phone.isNotEmpty ? phone : 'لم يُدخل',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ تم تحديث رقم الهاتف!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green));
              }
            }
            setState(() => _isEditingPhone = !_isEditingPhone);
          },
          icon: Icon(
            _isEditingPhone
                ? Icons.check_circle_rounded
                : Icons.edit_outlined,
            color: _isEditingPhone ? Colors.green : const Color(0xFFFF8F00),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value,
      {Color? color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: (color ?? const Color(0xFFFF8F00)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon,
              color: color ?? const Color(0xFFFF8F00), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white54)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String label, Color color,
      {bool isDestructive = false, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  isDestructive ? Colors.redAccent : Colors.white)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14,
          color:
              isDestructive ? Colors.redAccent : Colors.white38),
    );
  }

  void _showLogoutDialog(
      BuildContext context, JeebliController controller) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج',
              style: TextStyle(color: Colors.white)),
          content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              style: TextStyle(color: Colors.white54)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.logout();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              child: const Text('نعم، خروج'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistorySection(
      BuildContext context, JeebliController controller) {
    if (controller.pastOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('سجل الطلبات وإعادة الطلب السريع 📜',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.pastOrders.length,
          itemBuilder: (ctx, i) {
            final order = controller.pastOrders[i];
            final itemsSummary = order.items
                .map((item) => '${item.quantity}× ${item.product.name}')
                .join(', ');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(order.restaurantName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Colors.amber)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(order.id,
                            style: const TextStyle(
                                fontSize: 10.5, color: Colors.white54)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(itemsSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70, height: 1.3)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Colors.white12),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${order.totalAmount.toStringAsFixed(0)} د.ع',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFFFF8F00))),
                      ElevatedButton.icon(
                        onPressed: () => controller.reorder(order, context),
                        icon: const Icon(Icons.autorenew_rounded, size: 14),
                        label: const Text('إعادة الطلب 🔄',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8F00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
  // للزبائن: _idController = الاسم، _phoneController = رقم الهاتف
  // لأصحاب المطاعم: _idController = رقم الهاتف، _phoneController = الباسورد
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedRole = 'customer';

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final controller = JeebliProvider.of(context);
    final success = await controller.login(
        _idController.text, _phoneController.text, _selectedRole);

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ بيانات الدخول غير صحيحة.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 36),
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
                            colors: [Color(0xFFFF8F00), Color(0xFFE65100)]),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFE65100).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: const Icon(Icons.fastfood_rounded,
                          color: Colors.white, size: 56),
                    ),
                    const SizedBox(height: 24),
                    const Text('جيب لي ديلفري 🍔',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    const Text(
                      'منصتك الأولى لتوصيل أشهى وجبات المطاعم بضغطة زر 🚀',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500),
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
                            color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: _roleTab('دخول الزبائن 👤', 'customer')),
                          Expanded(
                              child: _roleTab('أصحاب المطاعم 🏪', 'owner')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ---- الحقل الأول ----
                    // زبون → اسمه الكامل | مالك → رقم هاتفه
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildInputField(
                        key: ValueKey('field1_$_selectedRole'),
                        controller: _idController,
                        label: isCustomer ? 'اسمك الكامل' : 'رقم الهاتف',
                        icon: isCustomer
                            ? Icons.person_outline_rounded
                            : Icons.phone_android_rounded,
                        keyboardType: isCustomer
                            ? TextInputType.name
                            : TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (isCustomer ? 'الرجاء إدخال اسمك' : 'الرجاء إدخال رقم الهاتف')
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---- الحقل الثاني ----
                    // زبون → رقم هاتفه | مالك → الباسورد
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isCustomer
                          ? _buildInputField(
                              key: const ValueKey('phone_customer'),
                              controller: _phoneController,
                              label: 'رقم هاتفك (07xxxxxxxxx)',
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'الرجاء إدخال رقم هاتفك';
                                }
                                final phone = v.trim().replaceAll(RegExp(r'\s+'), '');
                                // الرقم العراقي: 11 رقم يبدأ بـ 07
                                if (!RegExp(r'^07[3-9]\d{8}$').hasMatch(phone)) {
                                  return '❌ رقم غير صحيح — أدخل رقم عراقي صحيح (مثال: 07801234567)';
                                }
                                return null;
                              },
                            )
                          : _buildPasswordField(
                              key: const ValueKey('pass_owner'),
                            ),
                    ),
                    const SizedBox(height: 36),

                    // تلميح للزبائن
                    if (isCustomer) ...
                    [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.amber, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'إذا كنت زبوناً جديداً ستُسجَّل تلقائياً 🎉',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // تلميح للمالك / السوبر أدمن
                    if (!isCustomer) ...
                    [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.admin_panel_settings_outlined,
                                color: Colors.lightBlue, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'لوحة أصحاب المطاعم والإدارة العليا',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.lightBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // زر الدخول
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF8F00), Color(0xFFE65100)]),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFE65100).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                isCustomer ? 'دخول / تسجيل 🚀' : 'تسجيل الدخول',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                    letterSpacing: 1.0)),
                      ),
                    ),
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
              offset: const Offset(0, 6))
        ],
        border:
            Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: Colors.amber),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
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
              offset: const Offset(0, 6))
        ],
        border:
            Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: _phoneController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'الرمز السري',
          labelStyle:
              TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.amber),
          suffixIcon: IconButton(
            icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white54),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'الرجاء إدخال الرمز السري'
            : null,
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
                  colors: [Color(0xFFFF8F00), Color(0xFFE65100)])
              : null,
          color: isSel ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSel
              ? [
                  BoxShadow(
                      color: const Color(0xFFE65100).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSel ? Colors.white : Colors.white54)),
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
    BuildContext context, Function(String imagePathOrUrl) onImageSelected) {
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
              const Text(
                'اختر طريقة إضافة الصورة 📸',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const ContainerIcon(
                    icon: Icons.camera_alt_rounded, color: Colors.orangeAccent),
                title: const Text('التقاط بواسطة الكاميرا 📷',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('افتح الكاميرا والتقط صورة مباشرة',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 80);
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
                    icon: Icons.photo_library_rounded, color: Colors.amber),
                title: const Text('اختيار من معرض الصور 🖼️',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('اختر صورة مخزنة في هاتفك',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 80);
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
                    icon: Icons.link_rounded, color: Colors.lightBlueAccent),
                title: const Text('إدخال رابط صورة (URL) 🌐',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('الصق رابط صورة مباشر من الإنترنت',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
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
    BuildContext context, Function(String imagePathOrUrl) onImageSelected) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إدخال رابط صورة 🌐',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'https://example.com/image.jpg',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
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
                backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('حفظ الصورة',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _showImagePickerChoice(BuildContext context) async {
  final picker = ImagePicker();
  String? resultUrl;

  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر مصدر الصورة 📸',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.amber, size: 28),
              title: const Text('اختيار من المعرض (الاستوديو) 🖼️',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () async {
                final file = await picker.pickImage(
                    source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  resultUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.greenAccent, size: 28),
              title: const Text('التقاط مباشرة بواسطة الكاميرا 📸',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () async {
                final file = await picker.pickImage(
                    source: ImageSource.camera, maxWidth: 800, maxHeight: 800);
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  resultUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Colors.lightBlueAccent, size: 28),
              title: const Text('إدخال رابط URL من الإنترنت 🌐',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showUrlInputDialog(context, (url) {
                  resultUrl = url;
                });
              },
            ),
          ],
        ),
      ),
    ),
  );

  return resultUrl;
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
      child: const Icon(Icons.fastfood_rounded, color: Colors.white24, size: 40),
    );
  }
}
