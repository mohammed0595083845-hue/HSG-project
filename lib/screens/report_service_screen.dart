import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../data/category_repository.dart';
import '../data/report_repository.dart';
import '../data/service_repository.dart';
import '../models/report_model.dart';
import '../models/service_model.dart';
import '../widgets/app_header.dart';
import 'reports_history_screen.dart';

class ReportServiceScreen extends StatefulWidget {
  /// خدمة محددة مسبقاً (لما نوصل من زر Report ببطاقة الخدمة)
  final ServiceModel? initialService;
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
  ReportIssue? _selectedIssue;
  bool _isSubmitting = false;

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

  Future<void> _submitReport() async {
    final service = _selectedService;
    final issue = _selectedIssue;

    if (service == null || issue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a service and report type.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final category = CategoryRepository.instance.byId(service.categoryId);

    setState(() => _isSubmitting = true);

    final ok = await ReportRepository.instance.submitReport(
      ReportModel(
        reportId: '',
        serviceId: service.serviceId,
        reportedBy: user?.uid ?? '',
        reportType: category.name,
        description: _descriptionController.text.trim(),
        status: ReportStatus.pending,
        reportDate: DateTime.now(),
        serviceName: service.serviceName,
        issue: issue,
        reportedByName: user?.displayName ?? '',
        reportedByEmail: user?.email ?? '',
      ),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the report. Please try again.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted successfully. Thank you!'),
      ),
    );

    setState(() {
      _selectedService = null;
      _selectedIssue = null;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Report Service',
        showBack: widget.showBackButton,
      ),
      body: ListenableBuilder(
        listenable: ServiceRepository.instance.services,
        builder: (context, _) {
          // نقدر نبلّغ فقط عن الخدمات الموافق عليها
          final services = ServiceRepository.instance
              .viewServices()
              .where((s) => s.status == ServiceStatus.approved)
              .toList();
          final current = services.contains(_selectedService)
              ? _selectedService
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Service',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
                      hint: const Text(
                        'Choose a service',
                        style: TextStyle(color: AppColors.hintGrey),
                      ),
                      value: current,
                      items: services
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.serviceName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedService = value),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Report Type',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ReportIssue.values.map((issue) {
                    final isLast = issue == ReportIssue.values.last;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 10),
                        child: _issueChip(issue),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue...',
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.fieldBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.fieldBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.history,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                    label: const Text(
                      'View My Reports',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _issueChip(ReportIssue issue) {
    final isSelected = _selectedIssue == issue;
    final color = issue.color;
    return GestureDetector(
      onTap: () => setState(() => _selectedIssue = issue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          border: Border.all(color: isSelected ? color : AppColors.fieldBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(issue.icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              issue.label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
