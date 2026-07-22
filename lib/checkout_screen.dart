// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutScreen extends StatefulWidget {
  final List<dynamic> cartItems; // تستقبل السلة الخاصة بتطبيقك مباشرة مهما كان نوعها
  final String restaurantName;   // اسم المطعم المحدد

  const CheckoutScreen({
    super.key, 
    required this.cartItems, 
    required this.restaurantName
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  String selectedNeighborhood = 'الجمعية';
  final double deliveryFee = 3000.0; 

  final List<String> neighborhoods = [
    'الجمعية', 'النجدة', 'الكرامة', 'نادر', 'شارع 60', 'شارع 40', 'الإسكان', 'المحاربين'
  ];

  // دالة ذكية لحساب المجموع مهما كانت تسمية المتغيرات في السلة الخاصة بك
  double calculateTotal() {
    double sum = 0;
    for (var item in widget.cartItems) {
      // تحاول الدالة قراءة السعر والكمية سواء كانت Map أو Class Object
      try {
        double price = item.price ?? 0.0;
        int qty = item.quantity ?? 1;
        sum += (price * qty);
      } catch (_) {
        try {
          double price = item['price'] ?? 0.0;
          int qty = item['quantity'] ?? 1;
          sum += (price * qty);
        } catch (_) {}
      }
    }
    return sum;
  }

  void sendOrderToWhatsApp() async {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة لتأكيد الطلب!')),
      );
      return;
    }

    String restaurantWhatsApp = '9647800108275'; 
    if (widget.restaurantName.contains('أكّالة')) {
      restaurantWhatsApp = '9647865448004'; 
    }

    StringBuffer message = StringBuffer();
    message.writeln('🔔 *طلب جديد من تطبيق جيبلي للتوصيل*');
    message.writeln('👤 *الزبون:* ${nameController.text.trim()}');
    message.writeln('📞 *الهاتف:* ${phoneController.text.trim()}');
    message.writeln('📍 *المنطقة:* $selectedNeighborhood');
    message.writeln('🏠 *العنوان بالتفصيل وأقرب دالة:* ${detailsController.text.trim()}');
    message.writeln('\n🍔 *الوجبات المطلوبة مسبقاً:*');

    for (var item in widget.cartItems) {
      String name = '';
      int qty = 1;
      try { name = item.name; qty = item.quantity; } catch(_) {
        try { name = item['name']; qty = item['quantity']; } catch(_) {}
      }
      message.writeln('- $name (عدد: $qty)');
    }

    double finalTotal = calculateTotal() + deliveryFee;
    message.writeln('\n💵 *توصيل الحلة:* ${deliveryFee.toStringAsFixed(0)} د.ع');
    message.writeln('💰 *المجموع الكلي النهائي:* ${finalTotal.toStringAsFixed(0)} دينار عراقي');
    message.writeln('\n*شكراً لاختياركم منصة جيبلي السريعة!*');

    var whatsappUrl = Uri.parse("https://wa.me/$restaurantWhatsApp?text=${Uri.encodeComponent(message.toString())}");
    
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، تعذر فتح تطبيق واتساب.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة وتأكيد طلبك 🛒'),
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),

child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📍 نافذة إرسال معلومات الزبون ومكانه:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'اسم الزبون الكريم', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف المباشر', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedNeighborhood,
                        decoration: const InputDecoration(labelText: 'اختر المنطقة السكنية داخل الحلة', border: OutlineInputBorder()),
                        items: neighborhoods.map((String area) {
                          return DropdownMenuItem<String>(value: area, child: Text(area));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => selectedNeighborhood = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailsController,
                        decoration: const InputDecoration(labelText: 'مكانك بالتفصيل (أقرب نقطة دالة / معالم مميزة)', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('مجموع سعر الوجبات:'),
                          Text('${calculateTotal().toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('أجور توصيل الحلة الثابتة:'),
                          Text('${deliveryFee.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(thickness: 1.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع النهائي المطلق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                          Text('${(calculateTotal() + deliveryFee).toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: sendOrderToWhatsApp,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text('إرسال الطلب إلى واتساب المطعم', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}