import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'location_model.dart';

/// status حسب الداياجرام: Pending / Approved / Rejected
enum ServiceStatus { pending, approved, rejected }

/// حقل إضافي من تصميم شاشة Add Service: Working / Not working
enum Availability { working, notWorking }

ServiceStatus serviceStatusFromString(String? v) {
  for (final s in ServiceStatus.values) {
    if (s.name == v) return s;
  }
  return ServiceStatus.pending;
}

Availability availabilityFromString(String? v) {
  for (final a in Availability.values) {
    if (a.name == v) return a;
  }
  return Availability.working;
}

extension ServiceStatusX on ServiceStatus {
  String get label {
    switch (this) {
      case ServiceStatus.pending:
        return 'Pending';
      case ServiceStatus.approved:
        return 'Approved';
      case ServiceStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ServiceStatus.pending:
        return const Color(0xFFF59E0B);
      case ServiceStatus.approved:
        return const Color(0xFF2E9E5B);
      case ServiceStatus.rejected:
        return const Color(0xFFE53935);
    }
  }
}

extension AvailabilityX on Availability {
  String get label => this == Availability.working ? 'Working' : 'Not working';

  Color get color => this == Availability.working
      ? const Color(0xFF2E9E5B)
      : const Color(0xFFE53935);
}

class ServiceModel {
  final String serviceId;
  final String serviceName;
  final ServiceStatus status;
  final String createdBy; // userId
  final String categoryId;
  final LocationModel location; // Composition: الموقع جزء من الخدمة
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  // حقول إضافية (مش بالداياجرام)
  final Availability availability;
  final String rejectionReason;

  ServiceModel({
    required this.serviceId,
    required this.serviceName,
    required this.status,
    required this.createdBy,
    required this.categoryId,
    required this.location,
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.availability = Availability.working,
    this.rejectionReason = '',
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  /// locationId من الداياجرام
  String get locationId => location.locationId;

  /// getDetails() من الداياجرام
  ServiceModel getDetails() => this;

  // المقارنة بالـ serviceId عشان الـ Dropdown ما يضيع الاختيار لما Firestore يرجّع نسخة جديدة
  @override
  bool operator ==(Object other) =>
      other is ServiceModel && other.serviceId == serviceId;

  @override
  int get hashCode => serviceId.hashCode;

  Map<String, dynamic> toMap() => {
    'serviceName': serviceName,
    'status': status.name,
    'createdBy': createdBy,
    'categoryId': categoryId,
    'locationId': location.locationId,
    'location': location.toMap(),
    'description': description,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'availability': availability.name,
    'rejectionReason': rejectionReason,
  };

  /// بتقرأ الصيغة الجديدة والقديمة (الخدمات القديمة بتنعتبر Approved)
  factory ServiceModel.fromMap(String id, Map<String, dynamic> map) {
    final rawStatus = map['status'] as String?;
    final isLegacy = rawStatus == 'working' || rawStatus == 'notWorking';

    final LocationModel location = map['location'] is Map
        ? LocationModel.fromMap(
            Map<String, dynamic>.from(map['location'] as Map),
          )
        : LocationModel(
            locationId: '${id}_loc',
            latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
            address: map['address'] as String? ?? '',
          );

    return ServiceModel(
      serviceId: id,
      serviceName:
          map['serviceName'] as String? ?? map['name'] as String? ?? '',
      status: isLegacy
          ? ServiceStatus.approved
          : serviceStatusFromString(rawStatus),
      createdBy: map['createdBy'] as String? ?? map['addedBy'] as String? ?? '',
      categoryId:
          map['categoryId'] as String? ?? map['type'] as String? ?? 'water',
      location: location,
      description: map['description'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      availability: availabilityFromString(
        map['availability'] as String? ?? (isLegacy ? rawStatus : null),
      ),
      rejectionReason: map['rejectionReason'] as String? ?? '',
    );
  }
}
