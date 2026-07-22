# -*- coding: utf-8 -*-
"""
Restore clean backup + apply dark theme upgrades to Cart, Checkout, Profile screens.
Writes UTF-8 without BOM. Uses line-based replacement to handle CRLF safely.
"""

import sys, re

BACKUP = r'C:\Users\ALayham\AppData\Roaming\Code\User\History\-4533e631\wNC9.dart'
OUTPUT = r'lib\main.dart'

# ── Load backup ───────────────────────────────────────────────────────────────
with open(BACKUP, 'rb') as f:
    raw = f.read()
if raw[:3] == b'\xef\xbb\xbf':
    raw = raw[3:]
content = raw.decode('utf-8')
# Normalize line endings to LF
content = content.replace('\r\n', '\n').replace('\r', '\n')
lines = content.split('\n')
print(f"Backup loaded: {len(lines)} lines, {sum(1 for c in content if '\u0600'<=c<='\u06ff'):,} Arabic chars")

# ── Helper: replace a line range (1-indexed, inclusive) ──────────────────────
def replace_lines(lines, start, end, new_text):
    """Replace lines[start-1 : end] with new_text lines."""
    new_lines = new_text.split('\n')
    return lines[:start-1] + new_lines + lines[end:]

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 1 — CartScreen  (backup lines 1069-1216, replacing with dark version)
# ─────────────────────────────────────────────────────────────────────────────
CART = """\
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
        title: const Text('🛒 سلة المشتريات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.white12)),
      ),
      body: controller.cartItems.isEmpty
          ? _buildEmptyCart(context, controller)
          : Column(children: [
              // شريط اسم المطعم
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFE65100)]),
                ),
                child: Row(children: [
                  const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text('تطلب من: $restName',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
              ),
              // قائمة العناصر
              Expanded(
                child: ListView.builder(
                  itemCount: controller.cartItems.length,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  itemBuilder: (context, i) {
                    final item = controller.cartItems[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                          child: Image.network(item.product.imageUrl, width: 90, height: 90, fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(width: 90, height: 90, color: const Color(0xFF0F172A),
                                  child: const Icon(Icons.fastfood, color: Colors.white30))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('${item.product.price.toStringAsFixed(0)} د.ع / وجبة',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text('${item.totalPrice.toStringAsFixed(0)} د.ع',
                                  style: const TextStyle(color: Color(0xFFFF8F00), fontWeight: FontWeight.w900, fontSize: 16)),
                            ]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Column(children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                GestureDetector(
                                  onTap: () => controller.removeFromCart(item.product),
                                  child: const Padding(padding: EdgeInsets.all(10),
                                      child: Icon(Icons.remove_rounded, size: 18, color: Colors.white70)),
                                ),
                                SizedBox(
                                  width: 28,
                                  child: Text('${item.quantity}', textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                ),
                                GestureDetector(
                                  onTap: () => controller.addToCart(item.product, context),
                                  child: const Padding(padding: EdgeInsets.all(10),
                                      child: Icon(Icons.add_rounded, size: 18, color: Color(0xFFFF8F00))),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => controller.deleteFromCart(item.product),
                              child: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
              ),
              _buildOrderSummary(context, controller),
            ]),
    );
  }

  Widget _buildEmptyCart(BuildContext context, JeebliController controller) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E293B),
            border: Border.all(color: Colors.white12, width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFFFF8F00).withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
          ),
          child: const Icon(Icons.shopping_bag_outlined, size: 60, color: Color(0xFFFF8F00)),
        ),
        const SizedBox(height: 24),
        const Text('سلتك فارغة!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        const Text('أضف وجباتك اللذيذة من قائمة المطاعم', style: TextStyle(fontSize: 14, color: Colors.white54)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => controller.setTab(0),
          icon: const Icon(Icons.restaurant_menu_rounded),
          label: const Text('تصفح المطاعم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 10, shadowColor: const Color(0xFFFF8F00).withOpacity(0.5),
          ),
        ),
      ]),
    );
  }

  Widget _buildOrderSummary(BuildContext context, JeebliController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, -8))],
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        _row('مجموع الوجبات', '${controller.subtotal.toStringAsFixed(0)} د.ع'),
        const SizedBox(height: 10),
        _row('رسوم التوصيل', '${controller.deliveryFee.toStringAsFixed(0)} د.ع'),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('المبلغ الكلي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          Text('${controller.totalAmount.toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFFFF8F00))),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 58,
          child: ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: CheckoutScreen()))),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 10, shadowColor: const Color(0xFFFF8F00).withOpacity(0.5),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline, size: 20),
              SizedBox(width: 10),
              Text('إتمام الطلب والدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
    ]);
  }
}"""

# CartScreen: backup lines 1069-1216 (0-indexed: 1068-1215)
lines = replace_lines(lines, 1069, 1216, CART)
print(f"CartScreen replaced. New total lines: {len(lines)}")

# Recalculate line numbers for CheckoutScreen after replacement
content_tmp = '\n'.join(lines)
checkout_idx = content_tmp.find('class CheckoutScreen extends StatefulWidget {')
checkout_line = content_tmp[:checkout_idx].count('\n') + 1
print(f"CheckoutScreen now at line: {checkout_line}")

# Find end of CheckoutScreen (next section)
next_sec_after_checkout = content_tmp.find('/// ====', checkout_idx + 500)
checkout_end_line = content_tmp[:next_sec_after_checkout].count('\n') + 1
print(f"CheckoutScreen ends before line: {checkout_end_line}")

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 2 — CheckoutScreen dark theme
# ─────────────────────────────────────────────────────────────────────────────
CHECKOUT = """\
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.white12)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _sectionHeader('🏠', 'بيانات التوصيل'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecor(),
              child: Column(children: [
                _darkField(label: 'الاسم الكامل', icon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال الاسم' : null,
                    onChanged: (v) => controller.customerName = v),
                const SizedBox(height: 16),
                _darkField(label: 'رقم الهاتف', icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone, hint: '07800000000',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'الرجاء إدخال الهاتف';
                      if (v.length < 10) return 'رقم هاتف غير صحيح';
                      return null;
                    },
                    onChanged: (v) => controller.customerPhone = v),
                const SizedBox(height: 16),
                TextFormField(
                  onChanged: (v) => controller.selectedNeighborhood = v,
                  style: const TextStyle(color: Colors.white),
                  decoration: _darkInputDecor(label: 'المنطقة / الحي',
                      hint: 'اكتب اسم منطقتك هنا...', icon: Icons.location_on_outlined),
                ),
                const SizedBox(height: 16),
                _darkField(label: 'أقرب نقطة دالة', icon: Icons.home_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال نقطة دالة' : null,
                    onChanged: (v) => controller.streetDetails = v),
              ]),
            ),

            const SizedBox(height: 28),
            _sectionHeader('💳', 'طريقة الدفع'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _paymentCard(
                icon: Icons.delivery_dining_rounded, label: 'كاش', subtitle: 'عند الاستلام',
                isSelected: controller.paymentMethod == PaymentMethod.cod,
                onTap: () => setState(() { controller.paymentMethod = PaymentMethod.cod; controller.playFeedbackSound(); }),
              )),
              const SizedBox(width: 14),
              Expanded(child: _paymentCard(
                icon: Icons.credit_card_rounded, label: 'ماستركارد', subtitle: 'بطاقة ائتمانية',
                isSelected: controller.paymentMethod == PaymentMethod.mastercard,
                onTap: () => setState(() { controller.paymentMethod = PaymentMethod.mastercard; controller.playFeedbackSound(); }),
              )),
            ]),

            if (controller.paymentMethod == PaymentMethod.mastercard) ...[
              const SizedBox(height: 20),
              _buildMastercardForm(controller),
            ],

            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 32),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('محمي بتشفير جيب لي 🔒',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                  const SizedBox(height: 4),
                  Text('يتم تشفير بياناتك ومراجعة سلامة أسعار طلبك ضد التلاعب قبل الإرسال.',
                      style: TextStyle(fontSize: 11, color: Colors.green[200], height: 1.5)),
                ])),
              ]),
            ),

            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecor(),
              child: Column(children: [
                _summaryRow('مجموع الوجبات', '${controller.subtotal.toStringAsFixed(0)} د.ع'),
                const SizedBox(height: 10),
                _summaryRow('رسوم التوصيل', '${controller.deliveryFee.toStringAsFixed(0)} د.ع'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('الإجمالي الكلي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  Text('${controller.totalAmount.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(color: Color(0xFFFF8F00), fontWeight: FontWeight.w900, fontSize: 20)),
                ]),
              ]),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 58,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (controller.paymentMethod == PaymentMethod.mastercard) {
                    if (controller.cardNumber.length < 16 || controller.cardExpiry.isEmpty || controller.cardCvv.length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('يرجى إدخال بيانات البطاقة الصحيحة'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                  }
                  bool success = await controller.confirmOrder(context);
                  if (!success) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(controller.notifications.isNotEmpty
                              ? controller.notifications.first.message : 'فشل تأكيد الطلب'),
                          behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
                    }
                    return;
                  }
                  if (context.mounted) { Navigator.of(context).popUntil((route) => route.isFirst); }
                },
                icon: const Icon(Icons.lock_outline_rounded, size: 22),
                label: const Text('تأكيد الطلب بأمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 10, shadowColor: const Color(0xFFFF8F00).withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 20)),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
  ]);

  BoxDecoration _cardDecor() => BoxDecoration(
    color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.06)),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 6))],
  );

  InputDecoration _darkInputDecor({required String label, String? hint, required IconData icon}) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: Colors.white54),
      hintText: hint, hintStyle: const TextStyle(color: Colors.white30),
      prefixIcon: Icon(icon, color: const Color(0xFFFF8F00), size: 22),
      filled: true, fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF8F00), width: 1.5)),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  Widget _darkField({required String label, required IconData icon, TextInputType? keyboardType,
      String? hint, required String? Function(String?) validator, required void Function(String) onChanged}) {
    return TextFormField(
      onChanged: onChanged, keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _darkInputDecor(label: label, hint: hint, icon: icon),
      validator: validator,
    );
  }

  Widget _paymentCard({required IconData icon, required String label, required String subtitle,
      required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8F00).withOpacity(0.15) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? const Color(0xFFFF8F00) : Colors.white12, width: 1.8),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF8F00).withOpacity(0.25), blurRadius: 14)] : [],
        ),
        child: Column(children: [
          Icon(icon, size: 38, color: isSelected ? const Color(0xFFFF8F00) : Colors.white54),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.white : Colors.white70)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white54 : Colors.white30)),
        ]),
      ),
    );
  }

  Widget _buildMastercardForm(JeebliController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('بيانات البطاقة الائتمانية',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Row(children: [
            Container(width: 36, height: 24, decoration: BoxDecoration(color: const Color(0xFFEB001B), borderRadius: BorderRadius.circular(5))),
            Container(width: 36, height: 24, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: const Color(0xFFF79E1B).withOpacity(0.9), borderRadius: BorderRadius.circular(5))),
          ]),
        ]),
        const SizedBox(height: 18),
        TextFormField(
          keyboardType: TextInputType.number, maxLength: 16,
          style: const TextStyle(color: Colors.white, letterSpacing: 3),
          decoration: _cardFieldDecor('رقم البطاقة', 'XXXX XXXX XXXX XXXX', Icons.credit_card_rounded),
          onChanged: (v) => controller.cardNumber = v,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _cardFieldDecor('الانتهاء', 'MM/YY', Icons.calendar_today_rounded),
            onChanged: (v) => controller.cardExpiry = v,
          )),
          const SizedBox(width: 14),
          Expanded(child: TextFormField(
            maxLength: 3, obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _cardFieldDecor('CVV', '***', Icons.lock_outline_rounded),
            onChanged: (v) => controller.cardCvv = v,
          )),
        ]),
      ]),
    );
  }

  InputDecoration _cardFieldDecor(String label, String hint, IconData icon) => InputDecoration(
    labelText: label, hintText: hint,
    labelStyle: const TextStyle(color: Colors.white60), hintStyle: const TextStyle(color: Colors.white30),
    prefixIcon: Icon(icon, color: Colors.white54, size: 20), counterStyle: const TextStyle(color: Colors.white30),
    filled: true, fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8F00))),
  );

  Widget _summaryRow(String label, String value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
  ]);
}"""

lines = replace_lines(lines, checkout_line, checkout_end_line - 1, CHECKOUT)
print(f"CheckoutScreen replaced. New total lines: {len(lines)}")

# Recalculate line numbers for ProfileScreen
content_tmp = '\n'.join(lines)
profile_idx = content_tmp.find('class CustomerProfileScreen extends StatelessWidget {')
profile_line = content_tmp[:profile_idx].count('\n') + 1
print(f"CustomerProfileScreen now at line: {profile_line}")
next_sec_after_profile = content_tmp.find('/// ====', profile_idx + 500)
profile_end_line = content_tmp[:next_sec_after_profile].count('\n') + 1
print(f"CustomerProfileScreen ends before line: {profile_end_line}")

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 3 — CustomerProfileScreen (StatelessWidget → StatefulWidget + dark)
# ─────────────────────────────────────────────────────────────────────────────
PROFILE = """\
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
      _nameController.text = c.customerName.isNotEmpty ? c.customerName : 'زبون جيب لي';
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
    final name = controller.customerName.isNotEmpty ? controller.customerName : 'زبون جيب لي';
    final phone = controller.customerPhone;
    final location = controller.selectedNeighborhood.isNotEmpty ? controller.selectedNeighborhood : 'لم يُحدد بعد';
    final orderCount = controller.notifications.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('الملف الشخصي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.white12)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          const SizedBox(height: 32),

          // صورة شخصية
          Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: const Color(0xFFE65100).withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '؟',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('📷 ميزة رفع الصورة ستُفعَّل قريباً'), behavior: SnackBarBehavior.floating)),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1E293B),
                    border: Border.all(color: Colors.white24, width: 2)),
                child: const Icon(Icons.camera_alt_rounded, size: 18, color: Color(0xFFFF8F00)),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Text('🟢 حساب نشط — منطقة الهاشمية',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 28),

          // إحصائيات
          Row(children: [
            _statCard(Icons.shopping_bag_outlined, 'الطلبات', '$orderCount', const Color(0xFFFF8F00)),
            const SizedBox(width: 12),
            _statCard(Icons.location_city_outlined, 'الحي', location.split(' ').first, const Color(0xFF818CF8)),
            const SizedBox(width: 12),
            _statCard(Icons.star_rounded, 'النقاط', '0', const Color(0xFFFBBF24)),
          ]),
          const SizedBox(height: 28),

          // معلومات الحساب
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardTitle('معلومات الحساب'),
            const SizedBox(height: 18),
            _editablePhoneTile(controller, phone),
            _divider(),
            _infoTile(Icons.alternate_email_rounded, 'المعرف / البريد',
                controller.userEmailOrPhone ?? phone, const Color(0xFF818CF8)),
            _divider(),
            _infoTile(Icons.location_on_rounded, 'المنطقة', location, const Color(0xFF34D399)),
            if (controller.streetDetails.isNotEmpty) ...[
              _divider(),
              _infoTile(Icons.home_rounded, 'نقطة التوصيل', controller.streetDetails, const Color(0xFFFBBF24)),
            ],
          ])),
          const SizedBox(height: 20),

          // إعدادات
          _card(child: Column(children: [
            _settingsTile(Icons.notifications_outlined, 'إشعارات الطلبات', const Color(0xFFFBBF24), onTap: () {}),
            _divider(),
            _settingsTile(Icons.history_rounded, 'سجل الطلبات', const Color(0xFF818CF8), onTap: () {}),
            _divider(),
            _settingsTile(Icons.help_outline_rounded, 'الدعم والمساعدة', const Color(0xFF34D399), onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('💬 للتواصل مع الدعم الفني عبر واتساب، اضغط على أي مطعم'),
                  behavior: SnackBarBehavior.floating));
            }),
            _divider(),
            _settingsTile(Icons.logout_rounded, 'تسجيل الخروج', Colors.redAccent,
                isDestructive: true, onTap: () => _showLogoutDialog(context, controller)),
          ])),

          const SizedBox(height: 40),
          Text('جيبلي ديلفري — نسخة 2.0.0',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: child,
  );

  Widget _cardTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white60));

  Widget _divider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(color: Colors.white12, height: 1));

  Widget _infoTile(IconData icon, String title, String value, Color color) => Row(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 22),
    ),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, color: Colors.white38)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis),
    ])),
  ]);

  Widget _editablePhoneTile(JeebliController controller, String phone) => Row(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFF8F00).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.phone_android_rounded, color: Color(0xFFFF8F00), size: 22),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: _isEditingPhone
          ? TextField(
              controller: _phoneController, keyboardType: TextInputType.phone, autofocus: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: InputDecoration(
                hintText: '07XXXXXXXXX', hintStyle: const TextStyle(color: Colors.white30), isDense: true,
                filled: true, fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF8F00))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رقم الهاتف', style: TextStyle(fontSize: 11, color: Colors.white38)),
              const SizedBox(height: 2),
              Text(phone.isNotEmpty ? phone : 'لم يُدخل',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
    ),
    IconButton(
      onPressed: () {
        if (_isEditingPhone) {
          final newPhone = _phoneController.text.trim();
          if (newPhone.isNotEmpty && newPhone.length >= 10) {
            controller.updateCustomerPhone(newPhone);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('تم تحديث رقم الهاتف'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.green));
          }
        }
        setState(() => _isEditingPhone = !_isEditingPhone);
      },
      icon: Icon(
        _isEditingPhone ? Icons.check_circle_rounded : Icons.edit_outlined,
        color: _isEditingPhone ? const Color(0xFF10B981) : const Color(0xFFFF8F00), size: 26,
      ),
    ),
  ]);

  Widget _settingsTile(IconData icon, String label, Color color,
      {bool isDestructive = false, required VoidCallback onTap}) => ListTile(
    contentPadding: EdgeInsets.zero, onTap: onTap,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
        color: isDestructive ? Colors.redAccent : Colors.white)),
    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16,
        color: isDestructive ? Colors.red[300] : Colors.white24),
  );

  void _showLogoutDialog(BuildContext context, JeebliController controller) {
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12)),
        title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); controller.logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('نعم، خروج', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ));
  }
}"""

lines = replace_lines(lines, profile_line, profile_end_line - 1, PROFILE)
print(f"CustomerProfileScreen replaced. New total lines: {len(lines)}")

# ── Write UTF-8 without BOM ───────────────────────────────────────────────────
final_content = '\n'.join(lines)
with open(OUTPUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write(final_content)

# Verify
with open(OUTPUT, 'rb') as f:
    check = f.read()
has_bom = check[:3] == b'\xef\xbb\xbf'
arabic_count = sum(1 for c in final_content if '\u0600' <= c <= '\u06ff')
print(f"\nBOM: {'NONE (clean)' if not has_bom else 'PRESENT - ERROR'}")
print(f"Arabic chars: {arabic_count:,}")
print(f"File size: {len(check):,} bytes")
print(f"Total lines: {len(lines)}")
print("\nDone! Run: flutter analyze lib/main.dart")
