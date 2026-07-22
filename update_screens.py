import re

def update():
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update CartScreen
    cart_pattern = re.compile(r'class CartScreen extends StatelessWidget \{.*?Widget _buildOrderSummary.*?\}\n\}', re.DOTALL)
    cart_replacement = """class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);
    final restName = controller.cartItems.isNotEmpty
        ? controller.allRestaurants.firstWhere(
            (r) => r.id == controller.cartRestaurantId,
            orElse: () => controller.allRestaurants.first,
          ).name
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('سلة المشتريات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: controller.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1E293B), border: Border.all(color: Colors.white12)),
                    child: const Icon(Icons.shopping_bag_outlined, size: 90, color: Colors.white54),
                  ),
                  const SizedBox(height: 20),
                  const Text('السلة فارغة!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text('تصفح قوائم الطعام وأضف وجباتك اللذيذة', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => controller.setTab(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8, shadowColor: const Color(0xFFFF8F00).withOpacity(0.5)
                    ),
                    child: const Text('ابدأ التسوق الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFE65100)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFE65100).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(children: [
                    const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('تطلب من: $restName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.cartItems.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, i) {
                      final item = controller.cartItems[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(16),
                                child: Image.network(item.product.imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: const Color(0xFF0F172A)))),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text('${item.product.price.toStringAsFixed(0)} د.ع للوجبة', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Text('الإجمالي: ${item.totalPrice.toStringAsFixed(0)} د.ع', style: const TextStyle(color: Color(0xFFFF8F00), fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                                  child: Row(
                                    children: [
                                      GestureDetector(onTap: () => controller.removeFromCart(item.product),
                                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.remove_rounded, size: 18, color: Colors.white70))),
                                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                      GestureDetector(onTap: () => controller.addToCart(item.product, context),
                                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add_rounded, size: 18, color: Color(0xFFFF8F00)))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(onTap: () => controller.deleteFromCart(item.product),
                                    child: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -8))],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('مجموع الوجبات', style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text('${controller.subtotal.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('توصيل جيب لي', style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text('${controller.deliveryFee.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('المبلغ الكلي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
            Text('${controller.totalAmount.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFFFF8F00))),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: CheckoutScreen()))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8, shadowColor: const Color(0xFFFF8F00).withOpacity(0.5)
              ),
              child: const Text('إتمام الطلب والدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}"""
    content = cart_pattern.sub(cart_replacement, content)

    # 2. Update CheckoutScreen
    checkout_pattern = re.compile(r'class CheckoutScreen extends StatefulWidget \{.*?Widget _buildOrderSummaryCard.*?\}\n\}', re.DOTALL)
    checkout_replacement = """class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final neighborhoods = [
    'حي العسكري (الهاشمية)',
    'حي الرافدين (الهاشمية)',
    'حي المعلمين (الهاشمية)',
    'شارع السوق الرئيسي (الهاشمية)',
    'حي الصدر (الهاشمية)',
    'حي البلديات (الهاشمية)',
    'حي العرضيات (الهاشمية)',
    'منطقة وسط الهاشمية',
    'حي المدينة القديمة (الهاشمية)',
    'ناحية المشروع (تابعة للهاشمية)',
    'قضاء الهاشمية - مداخل المدينة',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = JeebliProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('تأكيد الطلب والدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true, backgroundColor: const Color(0xFF1E293B), elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('🏠 بيانات التوصيل'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                child: Column(
                  children: [
                    _buildTextField(label: 'الاسم الكامل', icon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال الاسم' : null,
                        onChanged: (v) => controller.customerName = v),
                    const SizedBox(height: 16),
                    _buildTextField(label: 'رقم الهاتف', icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone, hint: '07800000000',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'الرجاء إدخال الهاتف';
                          if (v.length < 10) return 'رقم هاتف غير صحيح';
                          return null;
                        },
                        onChanged: (v) => controller.customerPhone = v),
                    const SizedBox(height: 16),
                    TextFormField(
                      onChanged: (value) => controller.selectedNeighborhood = value,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'المنطقة / الحي', labelStyle: const TextStyle(color: Colors.white54),
                        hintText: 'اكتب اسم المنطقة أو الحي هنا...', hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFFF8F00)),
                        filled: true, fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF8F00))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(label: 'أقرب نقطة دالة', icon: Icons.home_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال نقطة دالة' : null,
                        onChanged: (v) => controller.streetDetails = v),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('💳 طريقة الدفع'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _paymentOption(
                    icon: Icons.delivery_dining, label: 'كاش عند الاستلام',
                    subtitle: 'ادفع لحظة وصول المندوب',
                    isSelected: controller.paymentMethod == PaymentMethod.cod,
                    onTap: () => setState(() { controller.paymentMethod = PaymentMethod.cod; controller.playFeedbackSound(); }),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _paymentOption(
                    icon: Icons.credit_card, label: 'ماستركارد',
                    subtitle: 'بطاقة ائتمانية آمنة',
                    isSelected: controller.paymentMethod == PaymentMethod.mastercard,
                    onTap: () => setState(() { controller.paymentMethod = PaymentMethod.mastercard; controller.playFeedbackSound(); }),
                  )),
                ],
              ),
              if (controller.paymentMethod == PaymentMethod.mastercard) ...[
                const SizedBox(height: 16),
                _buildMastercardForm(controller),
              ],

              const SizedBox(height: 24),
              _buildSecurityBadge(controller),

              const SizedBox(height: 24),
              _buildOrderSummaryCard(controller),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    if (controller.paymentMethod == PaymentMethod.mastercard) {
                      if (controller.cardNumber.length < 16 || controller.cardExpiry.isEmpty || controller.cardCvv.length < 3) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال بيانات البطاقة الصحيحة'), behavior: SnackBarBehavior.floating));
                        return;
                      }
                    }
                    bool success = await controller.confirmOrder(context);
                    if (!success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(controller.notifications.isNotEmpty ? controller.notifications.first.message : 'فشل تأكيد الطلب'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
                        );
                      }
                      return;
                    }
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.lock_outline, size: 20),
                  label: const Text('تأكيد الطلب بأمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8, shadowColor: const Color(0xFFFF8F00).withOpacity(0.5)
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildTextField({required String label, required IconData icon, TextInputType? keyboardType, String? hint, required String? Function(String?) validator, required void Function(String) onChanged}) {
    return TextFormField(
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint, hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: const Color(0xFFFF8F00)),
        filled: true, fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF8F00))),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: validator,
    );
  }

  Widget _paymentOption({required IconData icon, required String label, required String subtitle, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8F00).withOpacity(0.15) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFFF8F00) : Colors.white12, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF8F00).withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: isSelected ? const Color(0xFFFF8F00) : Colors.white54),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.white : Colors.white70)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white54 : Colors.white30), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildMastercardForm(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white12)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('بيانات البطاقة الائتمانية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Row(children: [
                Container(width: 32, height: 22, decoration: BoxDecoration(color: const Color(0xFFEB001B), borderRadius: BorderRadius.circular(4))),
                Container(width: 32, height: 22, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: const Color(0xFFF79E1B).withOpacity(0.9), borderRadius: BorderRadius.circular(4))),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            keyboardType: TextInputType.number,
            maxLength: 16,
            decoration: InputDecoration(
              labelText: 'رقم البطاقة', hintText: 'XXXX XXXX XXXX XXXX',
              labelStyle: const TextStyle(color: Colors.white70), hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.credit_card, color: Colors.white70, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8F00))),
              counterStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: Colors.white.withOpacity(0.07),
            ),
            style: const TextStyle(color: Colors.white, letterSpacing: 2),
            onChanged: (v) => controller.cardNumber = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'تاريخ الانتهاء', hintText: 'MM/YY',
                    labelStyle: const TextStyle(color: Colors.white70), hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8F00))),
                    filled: true, fillColor: Colors.white.withOpacity(0.07),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => controller.cardExpiry = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  maxLength: 3,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'CVV', hintText: '***',
                    labelStyle: const TextStyle(color: Colors.white70), hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8F00))),
                    counterStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: Colors.white.withOpacity(0.07),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => controller.cardCvv = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('محمي بتشفير جيب لي 🔒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                const SizedBox(height: 4),
                Text('يتم تشفير بياناتك ومراجعة سلامة أسعار طلبك ضد التلاعب تلقائياً قبل الإرسال.', style: TextStyle(fontSize: 11, color: Colors.green[200], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('مجموع الوجبات', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text('${controller.subtotal.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('توصيل جيب لي', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text('${controller.deliveryFee.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الإجمالي الكلي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          Text('${controller.totalAmount.toStringAsFixed(0)} د.ع', style: const TextStyle(color: Color(0xFFFF8F00), fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
      ]),
    );
  }
}"""
    content = checkout_pattern.sub(checkout_replacement, content)

    # 3. Update CustomerProfileScreen
    profile_pattern = re.compile(r'class CustomerProfileScreen extends StatefulWidget \{.*?\n\}\n\n\n/// ============================================================================', re.DOTALL)
    profile_replacement = """class CustomerProfileScreen extends StatefulWidget {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = JeebliProvider.of(context);
      _phoneController.text = c.customerPhone;
      _nameController.text = c.customerName.isNotEmpty ? c.customerName : 'زبون جيب لي';
    });
    _phoneController = TextEditingController();
    _nameController = TextEditingController();
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
    final name = controller.customerName.isNotEmpty ? controller.customerName : 'زبون جيب لي';
    final phone = controller.customerPhone;
    final location = controller.selectedNeighborhood.isNotEmpty
        ? controller.selectedNeighborhood
        : 'لم يُحدد بعد';
    final orderCount = controller.notifications.length; 

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white12),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ===== قسم الصورة الشخصية =====
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE65100).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '؟',
                      style: const TextStyle(
                          fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📷 ميزة رفع الصورة ستُفعَّل قريباً (Firebase Storage)'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFFFF8F00)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الاسم
            Text(name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Text(
                '🟢 حساب زبون نشط في الهاشمية',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // ===== إحصائيات سريعة =====
            Row(
              children: [
                _buildStatCard('طلب', orderCount.toString(), Icons.shopping_bag_outlined),
                const SizedBox(width: 12),
                _buildStatCard('حي', location.contains('(') ? location.split('(').first.trim() : location.split(' ').first, Icons.location_city_outlined),
                const SizedBox(width: 12),
                _buildStatCard('نقطة', '0', Icons.star_outline_rounded),
              ],
            ),
            const SizedBox(height: 24),

            // ===== بطاقة المعلومات =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('معلومات الحساب',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 16),

                  _buildEditablePhoneTile(controller, phone),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),

                  _buildInfoTile(
                    Icons.alternate_email_rounded,
                    'المعرف / البريد',
                    controller.userEmailOrPhone ?? phone,
                    color: const Color(0xFF818CF8),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),

                  _buildInfoTile(
                    Icons.location_on_rounded,
                    'المنطقة المحددة',
                    location,
                    color: const Color(0xFF34D399),
                  ),
                  if (controller.streetDetails.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),
                    _buildInfoTile(
                      Icons.home_rounded,
                      'نقطة التوصيل',
                      controller.streetDetails,
                      color: const Color(0xFFFBBF24),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===== بطاقة إعدادات التطبيق =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsTile(Icons.notifications_outlined, 'إشعارات الطلبات', const Color(0xFFFBBF24), onTap: () {}),
                  _buildSettingsTile(Icons.history_rounded, 'سجل الطلبات', const Color(0xFF818CF8), onTap: () {}),
                  _buildSettingsTile(Icons.help_outline_rounded, 'الدعم والمساعدة', const Color(0xFF34D399), onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💬 للتواصل مع الدعم الفني عبر واتساب، اضغط على أي مطعم وأرسل طلبك'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
                  _buildSettingsTile(Icons.logout_rounded, 'تسجيل الخروج', Colors.redAccent,
                      isDestructive: true, onTap: () => _showLogoutDialog(context, controller)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('جيبلي ديلفري — نسخة 2.0.0',
                style: TextStyle(color: Colors.white30, fontSize: 11)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16)],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF8F00), size: 26),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditablePhoneTile(JeebliController controller, String phone) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8F00).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.phone_android_rounded, color: Color(0xFFFF8F00), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _isEditingPhone
              ? TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '07XXXXXXXXX',
                    hintStyle: const TextStyle(color: Colors.white30),
                    isDense: true,
                    filled: true, fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF8F00)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رقم الهاتف', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 2),
                    Text(phone.isNotEmpty ? phone : 'لم يُدخل',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () {
            if (_isEditingPhone) {
              final newPhone = _phoneController.text.trim();
              if (newPhone.isNotEmpty && newPhone.length >= 10) {
                controller.updateCustomerPhone(newPhone);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تحديث رقم الهاتف بنجاح!'),
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
            color: _isEditingPhone ? const Color(0xFF10B981) : const Color(0xFFFF8F00),
            size: 24,
          ),
          tooltip: _isEditingPhone ? 'حفظ الرقم' : 'تعديل الرقم',
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, {Color? color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFFFF8F00)).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? const Color(0xFFFF8F00), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDestructive ? Colors.redAccent : Colors.white)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 16, color: isDestructive ? Colors.red[300] : Colors.white30),
    );
  }

  void _showLogoutDialog(BuildContext context, JeebliController controller) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.logout();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('نعم، خروج', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}


/// ============================================================================"""
    content = profile_pattern.sub(profile_replacement, content)

    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("UI screens updated successfully")

if __name__ == '__main__':
    update()
