import 'package:flutter/material.dart';

enum ServiceType { water, food, medical, internet, dangerZone }
enum ServiceStatus { working, notWorking }

extension ServiceTypeExtension on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.water:
        return 'Water';
      case ServiceType.food:
        return 'Food';
      case ServiceType.medical:
        return 'Medical';
      case ServiceType.internet:
        return 'Internet';
      case ServiceType.dangerZone:
        return 'Danger Zone';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceType.water:
        return Icons.water_drop;
      case ServiceType.food:
        return Icons.restaurant;
      case ServiceType.medical:
        return Icons.medical_services;
      case ServiceType.internet:
        return Icons.wifi;
      case ServiceType.dangerZone:
        return Icons.warning;
    }
  }

  Color get color {
    switch (this) {
      case ServiceType.food:
        return const Color(0xFF2E9E5B);
      case ServiceType.dangerZone:
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF1560F5);
    }
  }
}

class ServiceModel {
  final String id;
  final String name;
  final ServiceType type;
  final ServiceStatus status;
  final double latitude;
  final double longitude;
  // العنوان النصي المختصر (مثلاً "Al-Nasr Street, Gaza")، يُعرض ببطاقة تفاصيل الخدمة عالخريطة
  final String address;

  ServiceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.address = '',
  });

  // بنحوّل الخدمة لصيغة Map عشان نقدر نخزّنها بمستند (document) على Firestore
  // ملاحظة: مش بنخزّن الـ id جوا الـ Map، لأنه أصلاً هو اسم المستند نفسه على Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  // بنبني كائن ServiceModel من بيانات جايّة من Firestore (id المستند + محتواه)
  factory ServiceModel.fromMap(String id, Map<String, dynamic> map) {
    return ServiceModel(
      id: id,
      name: map['name'] as String? ?? '',
      type: ServiceType.values.byName(map['type'] as String? ?? 'water'),
      status: ServiceStatus.values.byName(map['status'] as String? ?? 'working'),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String? ?? '',
    );
  }
}
