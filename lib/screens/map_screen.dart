import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../data/auth_service.dart';
import '../data/category_repository.dart';
import '../data/service_repository.dart';
import '../models/service_model.dart';
import '../widgets/status_chip.dart';
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
  final LatLng _gazaCenterPosition = const LatLng(31.4424, 34.3856);

  // الخدمات غير الموافق عليها (Pending) بتظهر باهتة لصاحبها فقط
  List<Marker> _buildMarkers(List<ServiceModel> services) {
    return services.map((s) {
      final category = CategoryRepository.instance.byId(s.categoryId);
      final isPending = s.status != ServiceStatus.approved;
      return Marker(
        point: LatLng(s.location.latitude, s.location.longitude),
        width: 45,
        height: 45,
        child: GestureDetector(
          onTap: () => _showServiceCard(context, s),
          child: Opacity(
            opacity: isPending ? 0.55 : 1,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Icon(Icons.location_on, color: category.colorValue, size: 44),
                  Positioned(
                    top: 7,
                    child: Icon(
                      category.iconData,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showServiceCard(BuildContext context, ServiceModel s) {
    final category = CategoryRepository.instance.byId(s.categoryId);
    final me = AuthService.instance.currentUser.value;
    final isAdmin = me?.isAdmin ?? false;
    final isOwnPending =
        me != null &&
        s.createdBy == me.userId &&
        s.status == ServiceStatus.pending;
    final canDelete = isAdmin || isOwnPending;
    final isApproved = s.status == ServiceStatus.approved;

    final statusLabel = isApproved ? s.availability.label : s.status.label;
    final statusColor = isApproved ? s.availability.color : s.status.color;

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      canDelete
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              splashRadius: 20,
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _confirmDelete(context, s, isAdmin);
                              },
                            )
                          : const SizedBox(width: 48, height: 48),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 22,
                        ),
                        splashRadius: 20,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: category.colorValue,
                    ),
                    child: Icon(
                      category.iconData,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.serviceName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: category.colorValue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatusChip(label: statusLabel, color: statusColor),
                  if (s.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      s.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  if (s.status == ServiceStatus.rejected &&
                      s.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Reason: ${s.rejectionReason}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (s.location.address.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            s.location.address,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (isApproved || isOwnPending)
                    Row(
                      children: [
                        if (isApproved)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReportServiceScreen(
                                      initialService: s,
                                      showBackButton: true,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.flag,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (isApproved && isOwnPending)
                          const SizedBox(width: 10),
                        if (isOwnPending)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddServiceScreen(existing: s),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text(
                                'Edit',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ServiceModel s, bool asAdmin) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Service'),
          content: Text('هل أنت متأكد أنك تريد حذف "${s.serviceName}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final repo = ServiceRepository.instance;
                final ok = asAdmin
                    ? await repo.removeService(s.serviceId)
                    : await repo.deleteOwnService(s.serviceId);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not delete this service.'),
                    ),
                  );
                }
              },
              child: const Text(
                'حذف',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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
                Navigator.pop(dialogContext);
                await AuthService.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                ListenableBuilder(
                  listenable: Listenable.merge([
                    ServiceRepository.instance.services,
                    CategoryRepository.instance.categories,
                  ]),
                  builder: (context, _) {
                    final services = ServiceRepository.instance.viewServices();
                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _gazaCenterPosition,
                        initialZoom: 11.5,
                        minZoom: 4,
                        maxZoom: 18,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mapping',
                        ),
                        MarkerLayer(markers: _buildMarkers(services)),
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
                      // TODO: نافذة تصفية حسب الفئة
                    },
                  ),
                ),
                Positioned(
                  bottom: 90,
                  right: 16,
                  child: _circleButton(
                    icon: Icons.my_location,
                    onTap: () => _mapController.move(_gazaCenterPosition, 11.5),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primaryBlue,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddServiceScreen(),
                        ),
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
                Text(
                  'HSG',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Humanitarian Services Guide',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
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
