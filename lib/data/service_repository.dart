import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';

class ServiceRepository {
  ServiceRepository._() {
    _init();
  }
  static final ServiceRepository instance = ServiceRepository._();

  final CollectionReference<Map<String, dynamic>> _servicesCollection =
  FirebaseFirestore.instance.collection('services');

  // نفس الـ ValueNotifier القديم بالضبط اللي كانت كل الشاشات (الخريطة، التقارير...) تستمع له
  // بس هلأ بينحدث تلقائياً كل ما تتغيّر البيانات على Firestore، بدل ما يكون مصدر البيانات الوحيد
  // هيك كل الشاشات تضل شغالة زي ما هي بدون أي تعديل عليها
  final ValueNotifier<List<ServiceModel>> services = ValueNotifier([]);

  Future<void> _init() async {
    // أول مرة يفتح فيها التطبيق: نتحقق مرة وحدة بس إذا القائمة فاضية على Firestore
    // (يعني ولا خدمة انضافت أو انحذفت قبل هيك)، ولو فاضية نزرع بيانات تجريبية أولية
    final snapshot = await _servicesCollection.get();
    if (snapshot.docs.isEmpty) {
      await _seedInitialData();
    }

    // بعدين منبلش نستمع لأي تغيير حي (Realtime) عالمجموعة، ونحدث الـ ValueNotifier تلقائياً
    _servicesCollection.snapshots().listen((snapshot) {
      services.value = snapshot.docs
          .map((doc) => ServiceModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> _seedInitialData() async {
    final batch = FirebaseFirestore.instance.batch();
    final seedServices = [
      ServiceModel(
        id: '1',
        name: 'Al Shifa Medical Point',
        type: ServiceType.medical,
        status: ServiceStatus.working,
        latitude: 31.5017,
        longitude: 34.4668,
        address: 'Al-Shifa Street, Gaza',
      ),
      ServiceModel(
        id: '2',
        name: 'Water Station 1',
        type: ServiceType.water,
        status: ServiceStatus.working,
        latitude: 31.5030,
        longitude: 34.4650,
        address: 'Al-Nasr Street, Gaza',
      ),
      ServiceModel(
        id: '3',
        name: 'Community Kitchen',
        type: ServiceType.food,
        status: ServiceStatus.working,
        latitude: 31.4990,
        longitude: 34.4720,
        address: 'Omar Al-Mukhtar Street, Gaza',
      ),
    ];
    for (final s in seedServices) {
      batch.set(_servicesCollection.doc(s.id), s.toMap());
    }
    await batch.commit();
  }

  // إضافة خدمة جديدة: بنكتبها مباشرة كمستند جديد على Firestore
  // الـ ValueNotifier بيتحدث تلقائياً بعدها بفضل الاستماع الحي (listen) يلي فوق، بدون ما نضطر نحدثه يدوياً هون
  Future<void> addService(ServiceModel service) async {
    await _servicesCollection.doc(service.id).set(service.toMap());
  }

  // حذف خدمة: بنمسح المستند مباشرة من Firestore بالاعتماد على الـ id
  Future<void> removeService(String id) async {
    await _servicesCollection.doc(id).delete();
  }
}