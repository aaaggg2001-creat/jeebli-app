import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // To access JeebliProvider and JeebliBackButton

class CustomerPhoneLoginScreen extends StatefulWidget {
  const CustomerPhoneLoginScreen({super.key});

  @override
  State<CustomerPhoneLoginScreen> createState() => _CustomerPhoneLoginScreenState();
}

class _CustomerPhoneLoginScreenState extends State<CustomerPhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String _verificationId = '';

  Future<void> _verifyPhone() async {
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.isEmpty) return;

    // Validate Iraqi phone (starts with 07 and is 11 digits)
    if (!RegExp(r'^07[3-9]\d{8}$').hasMatch(rawPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ أدخل رقم عراقي صحيح (مثال: 07801234567)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Convert to international format for Firebase: +9647...
    final intlPhone = '+964${rawPhone.substring(1)}';

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: intlPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (often works on Android)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ فشل التحقق: ${e.message}'), backgroundColor: Colors.red),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => CustomerOtpScreen(
                verificationId: _verificationId,
                originalPhone: rawPhone,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted && userCred.user != null) {
        // Proceed to check firestore and login
        await _handleSuccessfulLogin(context, userCred.user!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في الدخول التلقائي: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const JeebliBackButton(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phonelink_ring_rounded, size: 80, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                'تسجيل الدخول / إنشاء حساب',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل رقم هاتفك لنرسل لك كود التحقق (SMS)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '07X XXXX XXXX',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), letterSpacing: 2),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.amber)),
                  prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyPhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                    : const Text('إرسال الكود 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerOtpScreen extends StatefulWidget {
  final String verificationId;
  final String originalPhone;
  const CustomerOtpScreen({super.key, required this.verificationId, required this.originalPhone});

  @override
  State<CustomerOtpScreen> createState() => _CustomerOtpScreenState();
}

class _CustomerOtpScreenState extends State<CustomerOtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) return;

    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted && userCred.user != null) {
        await _handleSuccessfulLogin(context, userCred.user!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ الكود غير صحيح، حاول مرة أخرى'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const JeebliBackButton(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.message_rounded, size: 80, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                'أدخل كود التحقق',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'أرسلنا كود SMS إلى الرقم:\n${widget.originalPhone}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.amber, fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.amber)),
                ),
                onChanged: (v) {
                  if (v.length == 6) {
                    _verifyOtp();
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                    : const Text('تأكيد الكود ✅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _handleSuccessfulLogin(BuildContext context, User firebaseUser) async {
  // Extract phone number in standard 07 format if possible
  String rawPhone = firebaseUser.phoneNumber ?? '';
  if (rawPhone.startsWith('+964')) {
    rawPhone = '0${rawPhone.substring(4)}';
  } else if (rawPhone.startsWith('+')) {
    rawPhone = rawPhone.substring(1);
  }

  // Check if customer exists in Firestore
  final doc = await FirebaseFirestore.instance.collection('customers').doc(rawPhone).get();
  
  String customerName = '';
  
  if (!doc.exists) {
    // New User! Ask for name
    if (context.mounted) {
      customerName = await _askForNameDialog(context) ?? 'مستخدم جيبلي';
      await FirebaseFirestore.instance.collection('customers').doc(rawPhone).set({
        'name': customerName,
        'phone': rawPhone,
        'uid': firebaseUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  } else {
    // Existing user
    customerName = doc.data()?['name'] ?? 'مستخدم جيبلي';
    await FirebaseFirestore.instance.collection('customers').doc(rawPhone).update({
      'lastLogin': FieldValue.serverTimestamp(),
      'uid': firebaseUser.uid,
    });
  }

// Update JeebliProvider and login
  if (context.mounted) {
    final controller = JeebliProvider.of(context);
    controller.updateCustomerName(customerName);
    controller.customerPhone = rawPhone;
    controller.saveSession(); // Explicitly save to shared_prefs
    
    // Use the basic login method to finalize state internally
    await controller.login(customerName, rawPhone, 'customer');
    
    // Pop back to root and then push Main
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
    }
  }
}

Future<String?> _askForNameDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('أهلاً بك في جيبلي! 🎉', style: TextStyle(color: Colors.amber)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال اسمك الكريم لإكمال إنشاء الحساب.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, nameCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87),
            child: const Text('حفظ الدخول'),
          ),
        ],
      ),
    ),
  );
}
