import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportRepository {
  ReportRepository._() {
    _listenToReports();
  }
  static final ReportRepository instance = ReportRepository._();

  final CollectionReference<Map<String, dynamic>> _reportsCollection =
  FirebaseFirestore.instance.collection('reports');

  // نفس الـ ValueNotifier القديم، هلأ بينحدث تلقائياً من Firestore
  final ValueNotifier<List<ReportModel>> reports = ValueNotifier([]);

  void _listenToReports() {
    // بنرتبهم حسب تاريخ التسليم تنازلياً (الأحدث فوق)، مباشرة من Firestore
    _reportsCollection
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      reports.value = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // إضافة تقرير جديد: بنكتبه مباشرة كمستند جديد على Firestore
  Future<void> addReport(ReportModel report) async {
    await _reportsCollection.doc(report.id).set(report.toMap());
  }
}