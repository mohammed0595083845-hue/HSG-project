import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // مسؤول عن التقاط ضغطة المستخدم على كلمة "Login" داخل الـ RichText
  late final TapGestureRecognizer _loginTapRecognizer;

  @override
  void initState() {
    super.initState();
    _loginTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        // بنستخدم pushReplacement بدل push عشان ما تضل صفحة Sign Up متراكمة بالـ Stack
        // فلو ضغط المستخدم "رجوع" من صفحة تسجيل الدخول، يرجعله عالصفحة يلي قبل Sign Up (مش لصفحة Sign Up نفسها)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      };
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginTapRecognizer.dispose();
    super.dispose();
  }

  // تحقق بسيط من الحقول، وبعدها إنشاء حساب حقيقي على Firebase Authentication
  Future<void> _handleSignUp() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Conditions.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // بننشئ الحساب فعلياً على Firebase Authentication بالإيميل وكلمة السر
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // بنحفظ الاسم الكامل مع الحساب (يظهر بالكونسول وبأي مكان بنستخدم فيه اسم المستخدم لاحقاً)
      await credential.user?.updateDisplayName(fullName);

      // بنخزّن كمان نسخة من بيانات المستخدم بمجموعة "users" على Firestore
      // عشان نقدر نشوف قائمة واضحة بكل المستخدمين (بالاسم والإيميل) بنفس مكان services و reports
      // بنستخدم الـ uid تبع المستخدم كمعرف للمستند، عشان يضل مرتبط بحسابه بشكل دائم
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fullName': fullName,
          'email': email,
          'createdAt': Timestamp.now(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully! Please log in.'), backgroundColor: Colors.green),
      );

      // بعد نجاح إنشاء الحساب، منسجل خروج فوراً (Firebase بيسجل دخول تلقائي بعد الإنشاء)
      // عشان نضمن المستخدم يسجل دخول يدوياً من صفحة Login زي ما هو مطلوب بالتصميم
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Please choose a stronger one.';
          break;
        default:
          message = 'Sign up failed. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 90,
                      height: 90,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'HSG',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create your account',
                      style: TextStyle(fontSize: 15, color: AppColors.hintGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildTextField(
                controller: _fullNameController,
                hint: 'Full Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.hintGrey,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                hint: 'Confirm Password',
                icon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.hintGrey,
                  ),
                  onPressed: () {
                    setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _agreeToTerms,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (value) {
                        setState(() => _agreeToTerms = value ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.textDark),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Login',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                        // هون بنربط الضغطة بالتنقل لصفحة تسجيل الدخول
                        recognizer: _loginTapRecognizer,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.hintGrey),
        prefixIcon: Icon(icon, color: AppColors.hintGrey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue),
        ),
      ),
    );
  }

  Widget buildLogo({double size = 100}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.favorite, color: AppColors.darkNavy, size: size),
          Icon(Icons.favorite, color: Colors.white, size: size * 0.55),
          Positioned(
            top: 0,
            left: size * 0.15,
            child: Icon(
              Icons.add,
              color: AppColors.accentRed,
              size: size * 0.28,
            ),
          ),
          Positioned(
            top: size * 0.05,
            right: 0,
            child: Icon(
              Icons.wifi,
              color: AppColors.primaryBlue,
              size: size * 0.3,
            ),
          ),
          Positioned(
            bottom: size * 0.22,
            left: size * 0.22,
            child: Icon(
              Icons.water_drop,
              color: AppColors.accentGreen,
              size: size * 0.22,
            ),
          ),
        ],
      ),
    );
  }
}