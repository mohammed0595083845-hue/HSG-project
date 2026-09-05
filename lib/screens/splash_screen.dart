import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      // بنتأكد إذا في مستخدم مسجّل دخول أصلاً من قبل (جلسة Firebase محفوظة على الجهاز)
      // لو موجود، بندخله مباشرة عالتطبيق بدون ما نطلب منه يسجّل دخول من جديد كل مرة
      // لو مافي، منوديه لصفحة تسجيل الدخول إجبارياً
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 130, height: 130),
                const SizedBox(height: 16),
                const Text(
                  'HSG',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Humanitarian Services Guide',
                  style: TextStyle(fontSize: 14, color: AppColors.hintGrey),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Container(height: 140, color: AppColors.darkNavy),
            ),
          ),
          Positioned(
            bottom: 55,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(active: true),
                _dot(active: false),
                _dot(active: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot({required bool active}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.darkNavy : Colors.white,
        border: Border.all(color: AppColors.darkNavy, width: 1),
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

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width / 2,
      -size.height * 0.4,
      size.width,
      size.height * 0.4,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}