import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/auth_service.dart';
import '../data/category_repository.dart';
import '../data/report_repository.dart';
import '../data/service_repository.dart';
import '../models/app_user.dart';
import '../models/category_model.dart';
import '../models/report_model.dart';
import '../models/service_model.dart';
import '../utils/date_format.dart';
import '../widgets/status_chip.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.darkNavy,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: ValueListenableBuilder<AppUser?>(
            valueListenable: AuthService.instance.currentUser,
            builder: (context, user, _) {
              final level = user is Admin ? ' (${user.adminLevel})' : '';
              return Text(
                'Admin Panel$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              );
            },
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Services'),
              Tab(text: 'Reports'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ServicesReviewTab(),
            _ReportsReviewTab(),
            _CategoriesReviewTab(),
          ],
        ),
      ),
    );
  }
}

// ───────────── أدوات مشتركة ─────────────

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Confirm',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _toast(BuildContext context, bool ok) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? 'Done.' : 'Action failed. Please try again.')),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ],
);

// ───────────── تبويب الخدمات ─────────────

class _ServicesReviewTab extends StatelessWidget {
  const _ServicesReviewTab();

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject service'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          ServiceRepository.instance.services,
          CategoryRepository.instance.categories,
        ]),
        builder: (context, _) {
          final list = ServiceRepository.instance.reviewServices();
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No services to review',
                style: TextStyle(color: AppColors.hintGrey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _card(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, ServiceModel s) {
    final category = CategoryRepository.instance.byId(s.categoryId);
    final repo = ServiceRepository.instance;
    final isPending = s.status == ServiceStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: category.colorValue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.iconData, color: category.colorValue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: AppColors.hintGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: s.status.label, color: s.status.color),
            ],
          ),
          if (s.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              s.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          if (s.location.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s.location.address,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (isPending) ...[
                ElevatedButton(
                  onPressed: () async =>
                      _toast(context, await repo.approveService(s.serviceId)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final reason = await _askReason(context);
                    if (reason == null || !context.mounted) return;
                    _toast(
                      context,
                      await repo.rejectService(s.serviceId, reason),
                    );
                  },
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  if (await _confirm(
                        context,
                        'Remove "${s.serviceName}" permanently?',
                      ) &&
                      context.mounted) {
                    _toast(context, await repo.removeService(s.serviceId));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────── تبويب التقارير ─────────────

class _ReportsReviewTab extends StatelessWidget {
  const _ReportsReviewTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: ValueListenableBuilder<List<ReportModel>>(
        valueListenable: ReportRepository.instance.allReports,
        builder: (context, _, __) {
          final list = ReportRepository.instance.reviewReports();
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No reports yet',
                style: TextStyle(color: AppColors.hintGrey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _card(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, ReportModel r) {
    final repo = ReportRepository.instance;
    final isPending = r.status == ReportStatus.pending;
    final reporter = [
      r.reportedByName,
      r.reportedByEmail,
    ].where((t) => t.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: r.issue.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(r.issue.icon, color: r.issue.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.reportType.isEmpty
                          ? r.issue.label
                          : '${r.issue.label} • ${r.reportType}',
                      style: TextStyle(
                        color: r.issue.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: r.status.label, color: r.status.color),
            ],
          ),
          if (r.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 8),
          if (reporter.isNotEmpty)
            Text(
              'By $reporter',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          Text(
            formatDateTime(r.reportDate),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async => _toast(
                    context,
                    await repo.reviewReport(r.reportId, ReportStatus.resolved),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                  ),
                  child: const Text(
                    'Resolve',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async => _toast(
                    context,
                    await repo.reviewReport(r.reportId, ReportStatus.rejected),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────── تبويب الفئات ─────────────

class _CategoriesReviewTab extends StatelessWidget {
  const _CategoriesReviewTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: ValueListenableBuilder<List<CategoryModel>>(
        valueListenable: CategoryRepository.instance.categories,
        builder: (context, categories, _) {
          // الفئات المنتظرة موافقة أولاً
          final list = [...categories]
            ..sort((a, b) {
              if (a.isPendingApproval && !b.isPendingApproval) return -1;
              if (!a.isPendingApproval && b.isPendingApproval) return 1;
              return a.name.compareTo(b.name);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _card(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, CategoryModel c) {
    final repo = CategoryRepository.instance;

    final String chipLabel;
    final Color chipColor;
    if (c.isSystem) {
      chipLabel = 'System';
      chipColor = AppColors.hintGrey;
    } else if (c.isDefault) {
      chipLabel = 'Approved';
      chipColor = AppColors.accentGreen;
    } else {
      chipLabel = 'Pending';
      chipColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.colorValue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(c.iconData, color: c.colorValue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.type,
                  style: const TextStyle(
                    color: AppColors.hintGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(label: chipLabel, color: chipColor),
          if (c.isPendingApproval)
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(
                Icons.check_circle,
                color: AppColors.accentGreen,
              ),
              onPressed: () async =>
                  _toast(context, await repo.approveCategory(c.categoryId)),
            ),
          if (!c.isSystem)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                if (await _confirm(context, 'Remove category "${c.name}"?') &&
                    context.mounted) {
                  _toast(context, await repo.removeCategory(c.categoryId));
                }
              },
            ),
        ],
      ),
    );
  }
}
