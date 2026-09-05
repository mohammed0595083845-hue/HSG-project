import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../data/service_repository.dart';
import '../data/report_repository.dart';
import '../models/service_model.dart';
import '../models/report_model.dart';
import '../widgets/app_header.dart';
import 'reports_history_screen.dart';

class ReportServiceScreen extends StatefulWidget {
  // خدمة محددة مسبقاً (اختياري): لما توصل من زر "Report" ببطاقة الخدمة عالخريطة،
  // بتنعبى تلقائياً بالـ Dropdown بدل ما يضطر المستخدم يدور عليها من جديد
  final ServiceModel? initialService;

  // لما الشاشة توصلها من التبويب السفلي "Report" منخليها false (مافي صفحة سابقة نرجعلها).
  // ولما توصلها من كرت الخدمة عالخريطة (Navigator.push) منخليها true عشان يظهر سهم الرجوع.
  final bool showBackButton;

  const ReportServiceScreen({
    super.key,
    this.initialService,
    this.showBackButton = false,
  });

  @override
  State<ReportServiceScreen> createState() => _ReportServiceScreenState();
}

class _ReportServiceScreenState extends State<ReportServiceScreen> {
  final _descriptionController = TextEditingController();
  ServiceModel? _selectedService;
  ReportType? _selectedReportType;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (_selectedService == null || _selectedReportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a service and report type.')),
      );
      return;
    }

    // بناخد بيانات المستخدم المسجل دخول حالياً (اسمه وإيميله) عشان نعرف مين قدّم التقرير
    final currentUser = FirebaseAuth.instance.currentUser;

    // نخزن التقرير بالسجل عشان يقدر المستخدم يراجعه لاحقاً من "My Reports"
    ReportRepository.instance.addReport(
      ReportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        serviceId: _selectedService!.id,
        serviceName: _selectedService!.name,
        serviceType: _selectedService!.type,
        reportType: _selectedReportType!,
        description: _descriptionController.text.trim(),
        submittedAt: DateTime.now(),
        submittedByName: currentUser?.displayName ?? '',
        submittedByEmail: currentUser?.email ?? '',
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted successfully. Thank you!')),
    );

    setState(() {
      _selectedService = null;
      _selectedReportType = null;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: 'Report Service', showBack: widget.showBackButton),
      body: Stack(
        children: [
          ValueListenableBuilder<List<ServiceModel>>(
            valueListenable: ServiceRepository.instance.services,
            builder: (context, services, _) {
              // إذا الخدمة يلي وصلتنا محذوفة أو مش موجودة بالقائمة الحالية، منتجاهلها بدل ما نكسر الـ Dropdown
              final ServiceModel? currentSelection =
              services.contains(_selectedService) ? _selectedService : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Service', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        border: Border.all(color: AppColors.fieldBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ServiceModel>(
                          isExpanded: true,
                          hint: const Text('Choose a service', style: TextStyle(color: AppColors.hintGrey)),
                          value: currentSelection,
                          items: services
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedService = value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Report Type', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _reportTypeChip('Not working', Icons.cancel, AppColors.accentRed, ReportType.notWorking)),
                        const SizedBox(width: 10),
                        Expanded(child: _reportTypeChip('Wrong location', Icons.location_pin, AppColors.primaryBlue, ReportType.wrongLocation)),
                        const SizedBox(width: 10),
                        Expanded(child: _reportTypeChip('Does not exist', Icons.delete_outline, AppColors.hintGrey, ReportType.doesNotExist)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe the issue...',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Submit Report',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // رابط لفتح سجل التقارير اللي سلمها المستخدم سابقاً
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReportsHistoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.history, size: 18, color: AppColors.primaryBlue),
                        label: const Text('View My Reports', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reportTypeChip(String label, IconData icon, Color color, ReportType value) {
    final isSelected = _selectedReportType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedReportType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          border: Border.all(color: isSelected ? color : AppColors.fieldBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}