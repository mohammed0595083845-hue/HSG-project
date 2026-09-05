import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../data/service_repository.dart';
import '../models/service_model.dart';
import 'add_service_screen.dart';
import 'report_service_screen.dart';
import 'login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // إحداثيات مركز قطاع غزة لفتح الخريطة عليها مباشرة
  final LatLng _gazaCenterPosition = const LatLng(31.4424, 34.3856);

  // بناء العلامات (Markers) للخدمات في غزة
  // كل خدمة بتاخد أيقونة ولون نوعها الخاص (s.type.icon / s.type.color)
  // بنفس الأيقونات المستخدمة بشاشة إضافة خدمة، بدل أيقونة موحدة لكل الأنواع
  List<Marker> _buildMarkers(List<ServiceModel> services) {
    return services.map((s) {
      return Marker(
        point: LatLng(s.latitude, s.longitude),
        width: 45,
        height: 45,
        child: GestureDetector(
          onTap: () => _showServiceCard(context, s),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // شكل الدبوس (Pin) الأساسي بلون نوع الخدمة
                Icon(
                  Icons.location_on,
                  color: s.type.color,
                  size: 44,
                ),
                // الأيقونة البيضاء الصغيرة الخاصة بنوع الخدمة، توضع بمنتصف الجزء الدائري العلوي من الدبوس
                Positioned(
                  top: 7,
                  child: Icon(
                    s.type.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // بطاقة تفاصيل الخدمة اللي بتطلع لما تدوس على أي ماركر عالخريطة
  // مركزية بالشاشة، بحواف دائرية بكل الاتجاهات، متل التصميم المطلوب
  void _showServiceCard(BuildContext context, ServiceModel s) {
    final bool isWorking = s.status == ServiceStatus.working;
    final Color statusColor = isWorking ? const Color(0xFF2E9E5B) : const Color(0xFFE53935);
    final String statusLabel = isWorking ? 'Working' : 'Not working';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // صف علوي فيه زر حذف صغير وزر إغلاق البطاقة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      splashRadius: 20,
                      onPressed: () {
                        Navigator.pop(dialogContext); // اقفل البطاقة أولاً
                        _confirmDelete(context, s);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                      splashRadius: 20,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                // دائرة الأيقونة الملونة بنفس نوع الخدمة
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: s.type.color),
                  child: Icon(s.type.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  s.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                ),
                const SizedBox(height: 4),
                Text(
                  s.type.label,
                  style: TextStyle(fontSize: 14, color: s.type.color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                if (s.address.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          s.address,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext); // اقفل البطاقة
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ReportServiceScreen(initialService: s, showBackButton: true)),
                      );
                    },
                    icon: const Icon(Icons.flag, color: Colors.white, size: 18),
                    label: const Text('Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // نافذة تأكيد قبل حذف الخدمة نهائياً، عشان نتجنب أي حذف بالغلط
  void _confirmDelete(BuildContext context, ServiceModel s) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Service'),
          content: Text('هل أنت متأكد أنك تريد حذف "${s.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                ServiceRepository.instance.removeService(s.id);
                Navigator.pop(dialogContext);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // نافذة تأكيد قبل تسجيل الخروج فعلياً
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // اقفل نافذة التأكيد أولاً
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                // بنمسح كل الشاشات السابقة من الـ Stack ونوديه مباشرة لصفحة تسجيل الدخول
                // عشان ما يقدر يرجع بزر الرجوع لشاشات كانت تحتاج تسجيل دخول
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
              child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: Stack(
              children: [
                ValueListenableBuilder<List<ServiceModel>>(
                  valueListenable: ServiceRepository.instance.services,
                  builder: (context, services, _) {
                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _gazaCenterPosition,
                        initialZoom: 11.5, // مستوى زووم مثالي يوضح كامل قطاع غزة من رفح حتى بيت حانون
                        minZoom: 4,        // أقل مستوى تصغير مسموح به
                        maxZoom: 18,       // أعلى مستوى تكبير لرؤية الشوارع بدقة شديدة

                        // تفعيل التكبير والتصغير عبر لمس الشاشة بالإصبعين أو النقر المزدوج
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all, // تفعيل التكبير، التصغير، والتحريك بالكامل
                        ),
                      ),
                      children: [
                        // هذا السيرفر الألماني السريع والمفتوح ممتاز جداً ومجاني لعرض تفاصيل الشوارع العربية
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mapping',
                        ),
                        MarkerLayer(
                          markers: _buildMarkers(services),
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _circleButton(
                    icon: Icons.filter_list,
                    onTap: () {
                      // TODO: افتح نافذة تصفية أنواع الخدمات
                    },
                  ),
                ),
                Positioned(
                  bottom: 90,
                  right: 16,
                  child: _circleButton(
                    icon: Icons.my_location,
                    onTap: () {
                      // العودة لمركز قطاع غزة عند الضغط على زر الموقع
                      _mapController.move(_gazaCenterPosition, 11.5);
                    },
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primaryBlue,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddServiceScreen()),
                      );
                    },
                    child: const Icon(Icons.add, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.darkNavy, size: 22),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: AppColors.darkNavy,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 36, height: 36),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HSG',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Humanitarian Services Guide',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 22),
              tooltip: 'Logout',
              splashRadius: 20,
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }
}