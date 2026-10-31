import 'package:cloud_firestore/cloud_firestore.dart';

/// User من الداياجرام
class AppUser {
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';

  final String userId;
  final String fullName;
  final String email;
  final String role; // user / admin
  final DateTime createdAt;

  const AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == roleAdmin;

  // password مش بنخزنه: Firebase Authentication بيديره مشفّر
  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'email': email,
    'role': role,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  /// بيرجّع Admin أو AppUser حسب الدور المخزن
  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final fullName = map['fullName'] as String? ?? '';
    final email = map['email'] as String? ?? '';
    final createdAt =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    if (map['role'] == roleAdmin) {
      return Admin(
        userId: id,
        fullName: fullName,
        email: email,
        createdAt: createdAt,
        adminLevel: map['adminLevel'] as String? ?? 'standard',
      );
    }
    return AppUser(
      userId: id,
      fullName: fullName,
      email: email,
      role: roleUser,
      createdAt: createdAt,
    );
  }
}

/// Admin يرث من User
class Admin extends AppUser {
  final String adminLevel;

  const Admin({
    required super.userId,
    required super.fullName,
    required super.email,
    required super.createdAt,
    this.adminLevel = 'standard',
  }) : super(role: AppUser.roleAdmin);

  @override
  Map<String, dynamic> toMap() => {...super.toMap(), 'adminLevel': adminLevel};
}
