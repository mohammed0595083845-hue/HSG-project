import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// status حسب الداياجرام: Pending / Resolved / Rejected
enum ReportStatus { pending, resolved, rejected }

/// نوع المشكلة (من تصميم شاشة Report): حقل إضافي
enum ReportIssue { notWorking, wrongLocation, doesNotExist }

ReportStatus reportStatusFromString(String? v) {
  for (final s in ReportStatus.values) {
    if (s.name == v) return s;
  }
  return ReportStatus.pending;
}

ReportIssue reportIssueFromString(String? v) {
  for (final i in ReportIssue.values) {
    if (i.name == v) return i;
  }
  return ReportIssue.notWorking;
}

extension ReportStatusX on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ReportStatus.pending:
        return const Color(0xFFF59E0B);
      case ReportStatus.resolved:
        return const Color(0xFF2E9E5B);
      case ReportStatus.rejected:
        return const Color(0xFFE53935);
    }
  }
}

extension ReportIssueX on ReportIssue {
  String get label {
    switch (this) {
      case ReportIssue.notWorking:
        return 'Not working';
      case ReportIssue.wrongLocation:
        return 'Wrong location';
      case ReportIssue.doesNotExist:
        return 'Does not exist';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportIssue.notWorking:
        return Icons.cancel;
      case ReportIssue.wrongLocation:
        return Icons.location_pin;
      case ReportIssue.doesNotExist:
        return Icons.delete_outline;
    }
  }

  Color get color {
    switch (this) {
      case ReportIssue.notWorking:
        return const Color(0xFFE53935);
      case ReportIssue.wrongLocation:
        return const Color(0xFF1560F5);
      case ReportIssue.doesNotExist:
        return const Color(0xFF9E9E9E);
    }
  }
}

class ReportModel {
  final String reportId;
  final String serviceId;
  final String reportedBy; // userId
  final String reportType; // اسم فئة الخدمة: Water / Food / ...
  final String description;
  final ReportStatus status;
  final DateTime reportDate;
  final String? reviewedBy; // adminId (nullable)
  final DateTime? reviewedAt; // nullable

  // حقول إضافية
  final String serviceName;
  final ReportIssue issue;
  final String reportedByName;
  final String reportedByEmail;

  ReportModel({
    required this.reportId,
    required this.serviceId,
    required this.reportedBy,
    required this.reportType,
    required this.description,
    required this.status,
    required this.reportDate,
    this.reviewedBy,
    this.reviewedAt,
    this.serviceName = '',
    this.issue = ReportIssue.notWorking,
    this.reportedByName = '',
    this.reportedByEmail = '',
  });

  Map<String, dynamic> toMap() => {
    'serviceId': serviceId,
    'reportedBy': reportedBy,
    'reportType': reportType,
    'description': description,
    'status': status.name,
    'reportDate': Timestamp.fromDate(reportDate),
    'reviewedBy': reviewedBy,
    'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
    'serviceName': serviceName,
    'issue': issue.name,
    'reportedByName': reportedByName,
    'reportedByEmail': reportedByEmail,
  };

  /// بتقرأ الصيغة الجديدة والقديمة
  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    final rawType = map['reportType'] as String? ?? '';
    final legacyIssue = ReportIssue.values.any((i) => i.name == rawType);

    return ReportModel(
      reportId: id,
      serviceId: map['serviceId'] as String? ?? '',
      reportedBy:
          map['reportedBy'] as String? ?? map['userId'] as String? ?? '',
      reportType: legacyIssue ? '' : rawType,
      description: map['description'] as String? ?? '',
      status: reportStatusFromString(map['status'] as String?),
      reportDate:
          (map['reportDate'] as Timestamp?)?.toDate() ??
          (map['submittedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      serviceName: map['serviceName'] as String? ?? '',
      issue: reportIssueFromString(map['issue'] as String? ?? rawType),
      reportedByName:
          map['reportedByName'] as String? ??
          map['submittedByName'] as String? ??
          '',
      reportedByEmail:
          map['reportedByEmail'] as String? ??
          map['submittedByEmail'] as String? ??
          '',
    );
  }
}
