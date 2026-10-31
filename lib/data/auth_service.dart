import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService._() {
    _listen();
  }
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// المستخدم الحالي مع دوره (user / admin)
  final ValueNotifier<AppUser?> currentUser = ValueNotifier(null);

  StreamSubscription? _profileSub;

  void _listen() {
    _auth.authStateChanges().listen((user) {
      _profileSub?.cancel();
      _profileSub = null;

      if (user == null) {
        currentUser.value = null;
        return;
      }

      _profileSub = _db.collection('users').doc(user.uid).snapshots().listen((
        doc,
      ) {
        final data = doc.data();
        if (data == null) {
          // حساب قديم بدون مستند: نعتبره مستخدم عادي
          currentUser.value = AppUser(
            userId: user.uid,
            fullName: user.displayName ?? '',
            email: user.email ?? '',
            role: AppUser.roleUser,
            createdAt: DateTime.now(),
          );
        } else {
          currentUser.value = AppUser.fromMap(doc.id, data);
        }
      }, onError: (e) => debugPrint('AuthService profile error: $e'));
    });
  }

  /// login() من الداياجرام: بترجع true، وبترمي FirebaseAuthException لو فشلت
  Future<bool> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return true;
  }

  /// signUp() من الداياجرام
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(fullName);

    final uid = credential.user?.uid;
    if (uid != null) {
      final user = AppUser(
        userId: uid,
        fullName: fullName,
        email: email,
        role: AppUser.roleUser,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toMap());
    }
    return true;
  }

  Future<void> signOut() => _auth.signOut();
}
