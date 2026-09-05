import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/report_repository.dart';
import '../models/report_model.dart';
import '../widgets/app_header.dart';
import '../models/service_model.dart';

class ReportsHistoryScreen extends StatelessWidget {
  const ReportsHistoryScreen({super.key});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: const AppHeader(title: 'My Reports', showBack: true),
      body: ValueListenableBuilder<List<ReportModel>>(
        valueListenable: ReportRepository.instance.reports,
        builder: (context, reports, _) {
          if (reports.isEmpty) {
            // حالة عدم وجود أي تقارير مقدّمة بعد
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'You haven\'t submitted any reports yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final r = reports[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // دائرة ملونة بأيقونة نوع البلاغ، بنفس أسلوب دليل الأيقونات
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: r.reportType.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(r.reportType.icon, color: r.reportType.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.serviceName,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                                ),
                              ),
                              Icon(r.serviceType.icon, color: r.serviceType.color, size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.reportType.label,
                            style: TextStyle(fontSize: 13, color: r.reportType.color, fontWeight: FontWeight.w600),
                          ),
                          if (r.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.description,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(r.submittedAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}