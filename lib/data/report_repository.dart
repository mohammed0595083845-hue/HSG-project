import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_model.dart';
import 'auth_service.dart';

class ReportRepository {
  ReportRepository._() {
    _init();
  }
  static final ReportRepository instance = ReportRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('reports');

  /// تقارير المستخدم الحالي فقط
  final ValueNotifier<List<ReportModel>> myReports = ValueNotifier([]);

  /// كل التقارير (للأدمن فقط)
  final ValueNotifier<List<ReportModel>> allReports = ValueNotifier([]);

  StreamSubscription? _mySub;
  StreamSubscription? _allSub;

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _mySub?.cancel();
      _mySub = null;

      if (user == null) {
        myReports.value = [];
        return;
      }

      _mySub = _col
          .where('reportedBy', isEqualTo: user.uid)
          .snapshots()
          .listen(
            (snap) => myReports.value = _parse(snap),
            onError: (e) => debugPrint('ReportRepository my error: $e'),
          );
    });

    // الأدمن بس بيسمع لكل التقارير
    AuthService.instance.currentUser.addListener(_syncAdminListener);
    _syncAdminListener();
  }

  void _syncAdminListener() {
    final isAdmin = AuthService.instance.currentUser.value?.isAdmin ?? false;

    if (isAdmin && _allSub == null) {
      _allSub = _col.snapshots().listen(
        (snap) => allReports.value = _parse(snap),
        onError: (e) => debugPrint('ReportRepository all error: $e'),
      );
    } else if (!isAdmin && _allSub != null) {
      _allSub!.cancel();
      _allSub = null;
      allReports.value = [];
    }
  }

  List<ReportModel> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs
        .map((d) => ReportModel.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.reportDate.compareTo(a.reportDate));
    return list;
  }

  /// submitReport(report) من الداياجرام
  Future<bool> submitReport(ReportModel report) async {
    try {
      await _col.doc().set(report.toMap());
      return true;
    } catch (e) {
      debugPrint('submitReport failed: $e');
      return false;
    }
  }

  /// reviewReports() من الداياجرام (Admin): الـ Pending أولاً
  List<ReportModel> reviewReports() {
    final list = [...allReports.value];
    list.sort((a, b) {
      final aPending = a.status == ReportStatus.pending;
      final bPending = b.status == ReportStatus.pending;
      if (aPending && !bPending) return -1;
      if (!aPending && bPending) return 1;
      return b.reportDate.compareTo(a.reportDate);
    });
    return list;
  }

  /// الأدمن بيحسم التقرير: Resolved أو Rejected (reviewedBy / reviewedAt)
  Future<bool> reviewReport(String reportId, ReportStatus status) async {
    final admin = AuthService.instance.currentUser.value;
    if (admin == null || !admin.isAdmin) return false;
    try {
      await _col.doc(reportId).update({
        'status': status.name,
        'reviewedBy': admin.userId,
        'reviewedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('reviewReport failed: $e');
      return false;
    }
  }
}
