import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category_model.dart';
import 'auth_service.dart';

class CategoryRepository {
  CategoryRepository._() {
    _init();
  }
  static final CategoryRepository instance = CategoryRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('categories');

  // نبدأ بالفئات الافتراضية عشان الأيقونات تظهر فوراً قبل ما Firestore يحمّل
  final ValueNotifier<List<CategoryModel>> categories = ValueNotifier(
    CategoryModel.defaults,
  );

  StreamSubscription? _sub;

  bool get _isAdmin => AuthService.instance.currentUser.value?.isAdmin ?? false;

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _sub?.cancel();
      _sub = null;

      if (user == null) {
        categories.value = CategoryModel.defaults;
        return;
      }

      await _seedIfEmpty();

      _sub = _col.snapshots().listen((snap) {
        final list = snap.docs
            .map((d) => CategoryModel.fromMap(d.id, d.data()))
            .toList();
        categories.value = list.isEmpty ? CategoryModel.defaults : list;
      }, onError: (e) => debugPrint('CategoryRepository error: $e'));
    });
  }

  Future<void> _seedIfEmpty() async {
    try {
      final snap = await _col.limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final batch = _db.batch();
      for (final c in CategoryModel.defaults) {
        batch.set(_col.doc(c.categoryId), c.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('CategoryRepository seed failed: $e');
    }
  }

  CategoryModel byId(String id) {
    for (final c in categories.value) {
      if (c.categoryId == id) return c;
    }
    for (final c in CategoryModel.defaults) {
      if (c.categoryId == id) return c;
    }
    return CategoryModel.unknown;
  }

  CategoryModel? byName(String name) {
    for (final c in categories.value) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// فئة جديدة من مستخدم: isDefault=false لحد ما الأدمن يوافق
  Future<CategoryModel?> suggestCategory({
    required String name,
    required String icon,
    required String color,
  }) async {
    try {
      final ref = _col.doc();
      final category = CategoryModel(
        categoryId: ref.id,
        name: name,
        icon: icon,
        color: color,
        type: CategoryModel.typeUserCreated,
        isDefault: false,
      );
      await ref.set(category.toMap());
      return category;
    } catch (e) {
      debugPrint('suggestCategory failed: $e');
      return null;
    }
  }

  /// approveCategory(categoryId) من الداياجرام (Admin)
  Future<bool> approveCategory(String categoryId) async {
    if (!_isAdmin) return false;
    try {
      await _col.doc(categoryId).update({'isDefault': true});
      return true;
    } catch (e) {
      debugPrint('approveCategory failed: $e');
      return false;
    }
  }

  /// removeCategory(categoryId) من الداياجرام (Admin): فئات النظام محمية
  Future<bool> removeCategory(String categoryId) async {
    if (!_isAdmin) return false;
    final category = byId(categoryId);
    if (category.isSystem) return false;
    try {
      await _col.doc(categoryId).delete();
      return true;
    } catch (e) {
      debugPrint('removeCategory failed: $e');
      return false;
    }
  }
}
