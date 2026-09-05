import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  // لازم هاد السطر قبل أي استخدام لـ plugins (متل Firebase) عشان يجهّز محرك Flutter نفسه أولاً
  WidgetsFlutterBinding.ensureInitialized();

  // نفعّل Firebase بالإعدادات يلي اتولّدت تلقائياً لكل منصة (Android/iOS/Web) عن طريق flutterfire configure
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HSG - Humanitarian Services Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1560F5),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
