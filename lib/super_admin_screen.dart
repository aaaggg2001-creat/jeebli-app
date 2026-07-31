// ============================================================================
// super_admin_screen.dart — لوحة التحكم الخاصة بمالك المشروع (Super Admin)
// الوصول: رقم 07802019730 + رمز @a20012005b@
// الصلاحيات: إضافة/حذف/تعطيل المطاعم، إدارة الوجبات والمالكين
// ============================================================================

// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';

/// واجهة الإدارة العليا لصاحب المشروع تتيح تحكماً كاملاً
class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  // تحكم بالتبويبات الأربعة: المطاعم، الوجبات، الإشعارات، الإعدادات
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // خلفية داكنة تعكس الطابع الاحترافي للادمن
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة الإدارة العليا ⚙️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                Text('Super Admin — جيبلي ديلفري',
                    style: TextStyle(fontSize: 10, color: Colors.amber)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(context, controller),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey[500],
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.store_rounded, size: 18), text: 'المطاعم'),
            Tab(icon: Icon(Icons.fastfood_rounded, size: 18), text: 'الوجبات'),
            Tab(icon: Icon(Icons.notifications_rounded, size: 18), text: 'الإشعارات'),
            Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'الإعدادات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RestaurantsTab(controller: controller),
          _ProductsTab(controller: controller),
          _NotificationsTab(controller: controller),
          _SettingsTab(controller: controller),
        ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          content: const Text('هل تريد الخروج من لوحة الإدارة العليا؟',
              style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.logout();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('نعم، خروج'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// تبويب إدارة المطاعم
// ============================================================================
class _RestaurantsTab extends StatelessWidget {
  final JeebliController controller;
  const _RestaurantsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final allRests = controller.restaurants;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بانر ترحيبي
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('صلاحية الإدارة المطلقة 🔑',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    Text('${allRests.length} مطاعم مسجلة • يمكنك التحكم الكامل بها',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // زر إضافة مطعم جديد
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _showAddRestaurantDialog(context, controller),
            icon: const Icon(Icons.add_business_rounded, size: 18),
            label: const Text('إضافة مطعم جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // قائمة المطاعم
        ...allRests.map((rest) => _buildRestaurantCard(context, controller, rest)),
      ],
    );
  }

  Widget _buildRestaurantCard(
      BuildContext context, JeebliController ctrl, Restaurant rest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rest.isActive
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(rest.imageUrl,
                  width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (ctx2, err, stack) =>
                      Container(width: 50, height: 50, color: Colors.grey[800],
                          child: const Icon(Icons.store, color: Colors.grey))),
            ),
            title: Text(rest.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rest.location,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: rest.isActive
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rest.isActive ? '🟢 نشط' : '🔴 موقف مؤقتاً',
                        style: TextStyle(
                          fontSize: 10,
                          color: rest.isActive ? Colors.green[300] : Colors.red[300],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('توصيل: ${rest.deliveryFee.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              color: const Color(0xFF334155),
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (val) {
                if (val == 'toggle') ctrl.toggleRestaurantActive(rest.id);
                if (val == 'delete') _showDeleteRestaurantDialog(context, ctrl, rest);
                if (val == 'delivery') _showEditDeliveryDialog(context, ctrl, rest);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(rest.isActive ? Icons.pause_circle : Icons.play_circle,
                        color: rest.isActive ? Colors.orange : Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(rest.isActive ? 'تعطيل مؤقت' : 'إعادة تفعيل',
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delivery',
                  child: Row(children: [
                    const Icon(Icons.delivery_dining, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Text('تعديل سعر التوصيل',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    const Text('حذف المطعم نهائياً',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ),
          // معلومات المالك
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.grey, size: 14),
                  const SizedBox(width: 6),
                  Text('المالك: ${rest.ownerPhone}  •  كلمة السر: ${rest.ownerPassword}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10.5, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRestaurantDialog(BuildContext context, JeebliController ctrl) {
    final nameC = TextEditingController();
    final locationC = TextEditingController();
    final cuisineC = TextEditingController();
    final imgC = TextEditingController();
    final descC = TextEditingController();
    final waC = TextEditingController();
    final ownerPhoneC = TextEditingController();
    final ownerPassC = TextEditingController();
    final deliveryC = TextEditingController(text: '1500');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إضافة مطعم جديد 🍽️',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                const SizedBox(height: 16),
                _darkField('اسم المطعم *', nameC, Icons.store),
                _darkField('المنطقة (مثل: الهاشمية، بابل)', locationC, Icons.location_on_outlined),
                _darkField('أنواع الوجبات (مثل: برجر • شاورما)', cuisineC, Icons.restaurant_menu),
                _darkField('رابط صورة المطعم', imgC, Icons.image_outlined),
                _darkField('وصف قصير للمطعم', descC, Icons.description_outlined),
                _darkField('رقم الواتساب (07XXXXXXXXX)', waC, Icons.phone),
                _darkField('رقم هاتف المالك', ownerPhoneC, Icons.person_outline),
                _darkField('كلمة مرور المالك', ownerPassC, Icons.lock_outline),
                _darkField('سعر التوصيل (بالدينار)', deliveryC, Icons.delivery_dining),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameC.text.isEmpty || waC.text.isEmpty || ownerPhoneC.text.isEmpty) return;
                          final newRest = Restaurant(
                            id: 'rest_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameC.text.trim(),
                            location: locationC.text.trim().isEmpty ? 'الهاشمية، بابل' : locationC.text.trim(),
                            cuisine: cuisineC.text.trim().isEmpty ? 'وجبات متنوعة' : cuisineC.text.trim(),
                            rating: 4.5,
                            deliveryTime: '20-35 دقيقة',
                            description: descC.text.trim().isEmpty ? 'مطعم مميز في الهاشمية' : descC.text.trim(),
                            whatsappNumber: formatWhatsAppNumber(waC.text.trim()),
                            imageUrl: imgC.text.trim().isEmpty
                                ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80'
                                : imgC.text.trim(),
                            ownerPhone: ownerPhoneC.text.trim(),
                            ownerPassword: ownerPassC.text.trim().isEmpty ? '123456' : ownerPassC.text.trim(),
                            deliveryFee: double.tryParse(deliveryC.text) ?? 1500,
                          );
                          ctrl.addRestaurant(newRest);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ تم إضافة مطعم "${newRest.name}" بنجاح!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        child: const Text('إضافة المطعم', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showDeleteRestaurantDialog(
      BuildContext context, JeebliController ctrl, Restaurant rest) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('⚠️ حذف المطعم', style: TextStyle(color: Colors.redAccent)),
          content: Text(
            'هل أنت متأكد من حذف "${rest.name}" نهائياً؟\nلا يمكن التراجع عن هذا الإجراء.',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                ctrl.deleteRestaurant(rest.id);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('نعم، حذف نهائياً'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeliveryDialog(
      BuildContext context, JeebliController ctrl, Restaurant rest) {
    final feeC = TextEditingController(text: rest.deliveryFee.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل توصيل: ${rest.name}',
              style: const TextStyle(color: Colors.amber, fontSize: 13)),
          content: _darkField('سعر التوصيل الجديد (د.ع)', feeC, Icons.delivery_dining),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                final newFee = double.tryParse(feeC.text.trim());
                if (newFee != null) {
                  ctrl.updateDeliveryFee(rest.id, newFee);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkField(String label, TextEditingController c, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        keyboardType: label.contains('سعر') || label.contains('رقم')
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.amber, size: 18),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.amber),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// تبويب إدارة الوجبات لجميع المطاعم
// ============================================================================
class _ProductsTab extends StatelessWidget {
  final JeebliController controller;
  const _ProductsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final allRests = controller.restaurants;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // زر إضافة وجبة جديدة
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _showAddProductDialog(context, controller, allRests),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('إضافة وجبة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // قوائم الوجبات حسب كل مطعم
        ...allRests.map((rest) {
          final prods = controller.getProductsByRestaurant(rest.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 20,
                      decoration: BoxDecoration(
                          color: Colors.amber, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    Text(rest.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${prods.length} وجبة',
                          style: const TextStyle(color: Colors.amber, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              ...prods.map((prod) => _buildProductCard(context, controller, prod)),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, JeebliController ctrl, Product prod) {
    final hasDiscount = prod.discountPrice != null && prod.discountPrice! < prod.price;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: prod.isAvailable
              ? Colors.white.withOpacity(0.05)
              : Colors.red.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(prod.imageUrl,
                  width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (ctx2, err, stack) => Container(
                      width: 48, height: 48,
                      color: Colors.grey[800],
                      child: const Icon(Icons.fastfood, color: Colors.grey))),
            ),
            if (hasDiscount)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.local_offer, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Text(prod.name,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: prod.isAvailable ? Colors.white : Colors.grey,
                fontSize: 12)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDiscount)
              Row(children: [
                Text('${prod.discountPrice!.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(width: 6),
                Text('${prod.price.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10)),
              ])
            else
              Text('${prod.price.toStringAsFixed(0)} د.ع',
                  style: const TextStyle(color: Colors.amber, fontSize: 11)),
            Text(prod.isAvailable ? '🟢 متوفر' : '🔴 غير متوفر',
                style: TextStyle(
                    fontSize: 10,
                    color: prod.isAvailable ? Colors.green[300] : Colors.red[300])),
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF334155),
          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
          onSelected: (val) {
            if (val == 'toggle') ctrl.toggleProductAvailability(prod.id);
            if (val == 'edit') _showEditProductDialog(context, ctrl, prod);
            if (val == 'delete') ctrl.deleteProduct(prod.id);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(prod.isAvailable ? Icons.hide_source : Icons.check_circle_outline,
                    color: prod.isAvailable ? Colors.orange : Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(prod.isAvailable ? 'تعطيل الوجبة' : 'تفعيل الوجبة',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
            PopupMenuItem(
              value: 'edit',
              child: const Row(children: [
                Icon(Icons.edit_outlined, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Text('تعديل / إضافة خصم', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: const Row(children: [
                Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text('حذف الوجبة', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog(
      BuildContext context, JeebliController ctrl, List<Restaurant> rests) {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    final priceC = TextEditingController();
    final imgC = TextEditingController();
    String selectedRestId = rests.isNotEmpty ? rests.first.id : '';
    String selectedCategory = 'burger';

    final categories = ['burger', 'zinger', 'shawarma', 'pizza', 'fries', 'drinks', 'other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إضافة وجبة جديدة 🍔',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 16),
                  // اختيار المطعم
                  DropdownButtonFormField<String>(
                    value: selectedRestId.isEmpty ? null : selectedRestId,
                    dropdownColor: const Color(0xFF334155),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'المطعم المستهدف *',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.store, color: Colors.amber, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    items: rests.map((r) =>
                      DropdownMenuItem(value: r.id, child: Text(r.name))
                    ).toList(),
                    onChanged: (v) => setD(() => selectedRestId = v ?? selectedRestId),
                  ),
                  const SizedBox(height: 12),
                  // التصنيف
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF334155),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'تصنيف الوجبة *',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.category_outlined, color: Colors.amber, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    items: categories.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c))
                    ).toList(),
                    onChanged: (v) => setD(() => selectedCategory = v ?? selectedCategory),
                  ),
                  const SizedBox(height: 12),
                  _darkFieldLocal('اسم الوجبة *', nameC, Icons.fastfood),
                  _darkFieldLocal('وصف الوجبة والمكونات', descC, Icons.description_outlined),
                  _darkFieldLocal('السعر الأصلي (د.ع) *', priceC, Icons.attach_money),
                  _darkFieldLocal('رابط صورة الوجبة (اختياري)', imgC, Icons.image_outlined),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameC.text.isEmpty || priceC.text.isEmpty || selectedRestId.isEmpty) return;
                            final price = double.tryParse(priceC.text) ?? 0;
                            if (price <= 0) return;
                            ctrl.addProduct(Product(
                              id: 'prod_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
                              restaurantId: selectedRestId,
                              name: nameC.text.trim(),
                              description: descC.text.trim(),
                              price: price,
                              imageUrl: imgC.text.trim().isEmpty
                                  ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80'
                                  : imgC.text.trim(),
                              categoryId: selectedCategory,
                            ));
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber, foregroundColor: Colors.black),
                          child: const Text('إضافة الوجبة', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, JeebliController ctrl, Product prod) {
    final nameC = TextEditingController(text: prod.name);
    final descC = TextEditingController(text: prod.description);
    final priceC = TextEditingController(text: prod.price.toStringAsFixed(0));
    final discountC = TextEditingController(text: prod.discountPrice?.toStringAsFixed(0) ?? '');
    final imgC = TextEditingController(text: prod.imageUrl);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تعديل الوجبة ✏️',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                const SizedBox(height: 16),
                _darkFieldLocal('اسم الوجبة', nameC, Icons.fastfood),
                _darkFieldLocal('الوصف والمكونات', descC, Icons.description_outlined),
                _darkFieldLocal('السعر الأصلي (د.ع)', priceC, Icons.attach_money),
                _darkFieldLocal('سعر التخفيض (اتركه فارغاً لإلغاء التخفيض)', discountC, Icons.local_offer_outlined),
                _darkFieldLocal('رابط الصورة الجديد', imgC, Icons.image_outlined),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final price = double.tryParse(priceC.text) ?? prod.price;
                          final discount = discountC.text.trim().isEmpty
                              ? null
                              : double.tryParse(discountC.text);
                          ctrl.updateProduct(prod.id,
                            name: nameC.text.trim().isEmpty ? prod.name : nameC.text.trim(),
                            description: descC.text.trim(),
                            price: price,
                            discountPrice: discount,
                            imageUrl: imgC.text.trim().isEmpty ? prod.imageUrl : imgC.text.trim(),
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        child: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _darkFieldLocal(String label, TextEditingController c, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        keyboardType: label.contains('سعر') || label.contains('رقم')
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.amber, size: 18),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.amber),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// تبويب الإشعارات في لوحة الإدارة
// ============================================================================
class _NotificationsTab extends StatelessWidget {
  final JeebliController controller;
  const _NotificationsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final notifications = controller.notifications;
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, color: Colors.grey[700], size: 64),
            const SizedBox(height: 16),
            const Text('لا توجد إشعارات حتى الآن',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (_, i) {
        final n = notifications[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: n.isWarning
                ? Colors.red.withOpacity(0.1)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: n.isWarning
                  ? Colors.red.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                n.isWarning ? Icons.warning_amber_rounded : Icons.notifications_rounded,
                color: n.isWarning ? Colors.red[300] : Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.message,
                        style: TextStyle(
                            color: n.isWarning ? Colors.red[200] : Colors.white70,
                            fontSize: 12.5,
                            height: 1.4)),
                    const SizedBox(height: 4),
                    Text(
                      '${n.time.hour}:${n.time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// تبويب الإعدادات — التحكم بنظام النقاط وإعدادات التطبيق
// ============================================================================
class _SettingsTab extends StatefulWidget {
  final JeebliController controller;
  const _SettingsTab({required this.controller});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late TextEditingController _pointsCtrl;

  @override
  void initState() {
    super.initState();
    _pointsCtrl = TextEditingController(
        text: widget.controller.adminPointsPerOrder.toString());
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── إعدادات نظام النقاط ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('نظام نقاط الولاء 🌟',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Text('تحكم بتفعيل النقاط وعدد النقاط لكل طلب',
                            style: TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // مفتاح التفعيل
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ctrl.loyaltySystemEnabled
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ctrl.loyaltySystemEnabled
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctrl.loyaltySystemEnabled
                              ? '✅ نظام النقاط مُفعَّل'
                              : '⏸ نظام النقاط مُعطَّل',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ctrl.loyaltySystemEnabled
                                ? const Color(0xFF10B981)
                                : Colors.white70,
                          ),
                        ),
                        Text(
                          ctrl.loyaltySystemEnabled
                              ? 'الزبائن يكسبون نقاطاً على كل طلب'
                              : 'النقاط مخفية عن الزبائن حالياً',
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    ),
                    Switch(
                      value: ctrl.loyaltySystemEnabled,
                      onChanged: (val) {
                        ctrl.setLoyaltySystem(enabled: val);
                        setState(() {});
                      },
                      activeColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
              if (ctrl.loyaltySystemEnabled) ...[
                const SizedBox(height: 14),
                const Text('🎯 عدد النقاط لكل 1,000 د.ع طلب:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pointsCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          hintText: 'مثال: 10',
                          hintStyle: const TextStyle(color: Colors.white30),
                          suffixText: 'نقطة',
                          suffixStyle: const TextStyle(color: Colors.amber),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        final pts = int.tryParse(_pointsCtrl.text.trim());
                        if (pts != null && pts > 0) {
                          ctrl.setLoyaltySystem(pointsPerOrder: pts);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ تم تحديث النقاط: $pts نقطة لكل 1,000 د.ع'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber, foregroundColor: Colors.black),
                      child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الحالي: كل 1,000 د.ع = ${ctrl.adminPointsPerOrder} نقطة • 250 نقطة = خصم 1,500 د.ع',
                          style: const TextStyle(fontSize: 11, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── إعدادات عامة ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Text('إعدادات عامة للتطبيق',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded, color: Colors.purpleAccent, size: 18),
                ),
                title: const Text('المطاعم النشطة',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${ctrl.allRestaurants.where((r) => r.isActive).length} / ${ctrl.allRestaurants.length}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
