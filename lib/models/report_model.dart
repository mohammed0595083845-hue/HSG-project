import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_model.dart';

// نوع البلاغ اللي بيقدمه المستخدم عن خدمة معينة
enum ReportType { notWorking, wrongLocation, doesNotExist }

extension ReportTypeExtension on ReportType {
  String get label {
    switch (this) {
      case ReportType.notWorking:
        return 'Not working';
      case ReportType.wrongLocation:
        return 'Wrong location';
      case ReportType.doesNotExist:
        return 'Does not exist';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportType.notWorking:
        return Icons.cancel;
      case ReportType.wrongLocation:
        return Icons.location_pin;
      case ReportType.doesNotExist:
        return Icons.delete_outline;
    }
  }

  Color get color {
    switch (this) {
      case ReportType.notWorking:
        return const Color(0xFFE53935);
      case ReportType.wrongLocation:
        return const Color(0xFF1560F5);
      case ReportType.doesNotExist:
        return const Color(0xFF9E9E9E);
    }
  }
}

// بلاغ واحد قدّمه المستخدم عن خدمة معينة
// بنحتفظ بنسخة من اسم ونوع الخدمة وقت تقديم البلاغ (مش بس الـ id)
// عشان لو انحذفت الخدمة الأصلية لاحقاً، يضل التقرير القديم واضح ومفهوم بالسجل
class ReportModel {
  final String id;
  final String serviceId;
  final String serviceName;
  final ServiceType serviceType;
  final ReportType reportType;
  final String description;
  final DateTime submittedAt;
  // اسم وإيميل المستخدم يلي قدّم التقرير (ماخوذين تلقائياً من حساب تسجيل الدخول الحالي وقت التسليم)
  final String submittedByName;
  final String submittedByEmail;

  ReportModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.serviceType,
    required this.reportType,
    required this.description,
    required this.submittedAt,
    this.submittedByName = '',
    this.submittedByEmail = '',
  });

  // بنحوّل التقرير لصيغة Map عشان نخزّنه بمستند على Firestore
  // التاريخ (DateTime) لازم يتحوّل لنوع Timestamp الخاص بـ Firestore
  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceType': serviceType.name,
      'reportType': reportType.name,
      'description': description,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'submittedByName': submittedByName,
      'submittedByEmail': submittedByEmail,
    };
  }

  // بنبني كائن ReportModel من بيانات جايّة من Firestore
  // ملاحظة: submittedByName/submittedByEmail بيرجعوا فاضيين لو التقرير قديم من قبل هالتعديل (مافي القيم أصلاً)
  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    return ReportModel(
      id: id,
      serviceId: map['serviceId'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      serviceType: ServiceType.values.byName(map['serviceType'] as String? ?? 'water'),
      reportType: ReportType.values.byName(map['reportType'] as String? ?? 'notWorking'),
      description: map['description'] as String? ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedByName: map['submittedByName'] as String? ?? '',
      submittedByEmail: map['submittedByEmail'] as String? ?? '',
    );
  }
}