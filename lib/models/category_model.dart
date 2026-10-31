import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  static const String typeSystem = 'system';
  static const String typeUserCreated = 'user-created';

  /// الأيقونات المتاحة (المفتاح هو اللي بيتخزن بـ Firestore)
  static const Map<String, IconData> iconOptions = {
    'water_drop': Icons.water_drop,
    'restaurant': Icons.restaurant,
    'medical_services': Icons.medical_services,
    'wifi': Icons.wifi,
    'warning': Icons.warning,
    'local_gas_station': Icons.local_gas_station,
    'home': Icons.home,
    'school': Icons.school,
    'shopping_basket': Icons.shopping_basket,
    'bolt': Icons.bolt,
    'place': Icons.place,
  };

  static const List<String> colorOptions = [
    '#1560F5',
    '#2E9E5B',
    '#E53935',
    '#F59E0B',
    '#8B5CF6',
    '#0B1F4C',
  ];

  final String categoryId;
  final String name;
  final String icon; // مفتاح من iconOptions
  final String color; // hex مثل #1560F5
  final String type; // system / user-created
  final bool isDefault;
  final DateTime createdAt;

  CategoryModel({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isDefault,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isSystem => type == typeSystem;

  /// فئة أنشأها مستخدم وما وافق عليها الأدمن بعد
  bool get isPendingApproval => type == typeUserCreated && !isDefault;

  IconData get iconData => iconOptions[icon] ?? Icons.place;

  Color get colorValue => parseColor(color);

  static Color parseColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF1560F5);
  }

  /// فئة احتياطية لو الفئة انحذفت أو مش موجودة
  static final CategoryModel unknown = CategoryModel(
    categoryId: 'unknown',
    name: 'Other',
    icon: 'place',
    color: '#9AA0AC',
    type: typeSystem,
    isDefault: true,
  );

  /// الفئات الافتراضية (الـ id نفس أسماء أنواع الخدمات القديمة عشان البيانات القديمة تضل شغالة)
  static List<CategoryModel> get defaults => [
    CategoryModel(
      categoryId: 'water',
      name: 'Water',
      icon: 'water_drop',
      color: '#1560F5',
      type: typeSystem,
      isDefault: true,
    ),
    CategoryModel(
      categoryId: 'food',
      name: 'Food',
      icon: 'restaurant',
      color: '#2E9E5B',
      type: typeSystem,
      isDefault: true,
    ),
    CategoryModel(
      categoryId: 'medical',
      name: 'Medical',
      icon: 'medical_services',
      color: '#1560F5',
      type: typeSystem,
      isDefault: true,
    ),
    CategoryModel(
      categoryId: 'internet',
      name: 'Internet',
      icon: 'wifi',
      color: '#1560F5',
      type: typeSystem,
      isDefault: true,
    ),
    CategoryModel(
      categoryId: 'dangerZone',
      name: 'Danger Zone',
      icon: 'warning',
      color: '#E53935',
      type: typeSystem,
      isDefault: true,
    ),
  ];

  Map<String, dynamic> toMap() => {
    'name': name,
    'icon': icon,
    'color': color,
    'type': type,
    'isDefault': isDefault,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      categoryId: id,
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String? ?? 'place',
      color: map['color'] as String? ?? '#1560F5',
      type: map['type'] as String? ?? typeUserCreated,
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
