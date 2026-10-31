import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/location_model.dart';
import '../models/service_model.dart';
import 'auth_service.dart';
import 'category_repository.dart';

class ServiceRepository {
  ServiceRepository._() {
    _init();
  }
  static final ServiceRepository instance = ServiceRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('services');

  /// كل الخدمات (بدون فلترة). الشاشات بتستخدم viewServices() للفلترة حسب الصلاحية
  final ValueNotifier<List<ServiceModel>> services = ValueNotifier([]);

  StreamSubscription? _sub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isAdmin => AuthService.instance.currentUser.value?.isAdmin ?? false;

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _sub?.cancel();
      _sub = null;

      if (user == null) {
        services.value = [];
        return;
      }

      await _seedIfEmpty();

      _sub = _col.snapshots().listen((snap) {
        services.value = snap.docs
            .map((d) => ServiceModel.fromMap(d.id, d.data()))
            .toList();
      }, onError: (e) => debugPrint('ServiceRepository error: $e'));
    });
  }

  Future<void> _seedIfEmpty() async {
    try {
      final snap = await _col.limit(1).get();
      if (snap.docs.isNotEmpty) return;

      final batch = _db.batch();
      final seeds = [
        ServiceModel(
          serviceId: '1',
          serviceName: 'Al Shifa Medical Point',
          status: ServiceStatus.approved,
          createdBy: 'system',
          categoryId: 'medical',
          location: const LocationModel(
            locationId: '1_loc',
            latitude: 31.5017,
            longitude: 34.4668,
            address: 'Al-Shifa Street, Gaza',
          ),
        ),
        ServiceModel(
          serviceId: '2',
          serviceName: 'Water Station 1',
          status: ServiceStatus.approved,
          createdBy: 'system',
          categoryId: 'water',
          location: const LocationModel(
            locationId: '2_loc',
            latitude: 31.5030,
            longitude: 34.4650,
            address: 'Al-Nasr Street, Gaza',
          ),
        ),
        ServiceModel(
          serviceId: '3',
          serviceName: 'Community Kitchen',
          status: ServiceStatus.approved,
          createdBy: 'system',
          categoryId: 'food',
          location: const LocationModel(
            locationId: '3_loc',
            latitude: 31.4990,
            longitude: 34.4720,
            address: 'Omar Al-Mukhtar Street, Gaza',
          ),
        ),
      ];
      for (final s in seeds) {
        batch.set(_col.doc(s.serviceId), s.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('ServiceRepository seed failed: $e');
    }
  }

  // ───────────── User ─────────────

  /// viewServices() من الداياجرام: الخدمات الموافق عليها + خدمات المستخدم نفسه
  List<ServiceModel> viewServices({String keyword = ''}) {
    final uid = _uid;
    final q = keyword.trim().toLowerCase();

    return services.value.where((s) {
      final visible = s.status == ServiceStatus.approved || s.createdBy == uid;
      if (!visible) return false;
      if (q.isEmpty) return true;

      final categoryName = CategoryRepository.instance
          .byId(s.categoryId)
          .name
          .toLowerCase();
      return s.serviceName.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.location.address.toLowerCase().contains(q) ||
          categoryName.contains(q);
    }).toList();
  }

  /// searchServices(keyword) من الداياجرام
  List<ServiceModel> searchServices(String keyword) =>
      viewServices(keyword: keyword);

  /// addService(service) من الداياجرام
  Future<bool> addService(ServiceModel service) async {
    try {
      await _col.doc(service.serviceId).set(service.toMap());
      return true;
    } catch (e) {
      debugPrint('addService failed: $e');
      return false;
    }
  }

  /// editOwnService(serviceId, data): فقط خدمات المستخدم وهي Pending
  Future<bool> editOwnService(
    String serviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final doc = await _col.doc(serviceId).get();
      final raw = doc.data();
      if (raw == null) return false;

      final service = ServiceModel.fromMap(doc.id, raw);
      if (service.createdBy != _uid ||
          service.status != ServiceStatus.pending) {
        return false;
      }

      await _col.doc(serviceId).update({...data, 'updatedAt': Timestamp.now()});
      return true;
    } catch (e) {
      debugPrint('editOwnService failed: $e');
      return false;
    }
  }

  /// deleteOwnService(serviceId): فقط خدمات المستخدم وهي Pending
  Future<bool> deleteOwnService(String serviceId) async {
    try {
      final doc = await _col.doc(serviceId).get();
      final raw = doc.data();
      if (raw == null) return false;

      final service = ServiceModel.fromMap(doc.id, raw);
      if (service.createdBy != _uid ||
          service.status != ServiceStatus.pending) {
        return false;
      }

      await _col.doc(serviceId).delete();
      return true;
    } catch (e) {
      debugPrint('deleteOwnService failed: $e');
      return false;
    }
  }

  // ───────────── Admin ─────────────

  /// reviewServices(): كل الخدمات، الـ Pending أولاً
  List<ServiceModel> reviewServices() {
    final list = [...services.value];
    list.sort((a, b) {
      final aPending = a.status == ServiceStatus.pending;
      final bPending = b.status == ServiceStatus.pending;
      if (aPending && !bPending) return -1;
      if (!aPending && bPending) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// updateStatus(status) من الداياجرام (Service)
  Future<bool> updateStatus(
    String serviceId,
    ServiceStatus status, {
    String reason = '',
  }) async {
    if (!_isAdmin) return false;
    try {
      await _col.doc(serviceId).update({
        'status': status.name,
        'rejectionReason': status == ServiceStatus.rejected ? reason : '',
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('updateStatus failed: $e');
      return false;
    }
  }

  Future<bool> approveService(String serviceId) =>
      updateStatus(serviceId, ServiceStatus.approved);

  Future<bool> rejectService(String serviceId, String reason) =>
      updateStatus(serviceId, ServiceStatus.rejected, reason: reason);

  Future<bool> removeService(String serviceId) async {
    if (!_isAdmin) return false;
    try {
      await _col.doc(serviceId).delete();
      return true;
    } catch (e) {
      debugPrint('removeService failed: $e');
      return false;
    }
  }
}
