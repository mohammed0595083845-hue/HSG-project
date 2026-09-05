import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/service_repository.dart';
import '../models/service_model.dart';
import '../widgets/app_header.dart';

class ServicesListScreen extends StatelessWidget {
  const ServicesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Services', showBack: false),
      body: ValueListenableBuilder<List<ServiceModel>>(
        valueListenable: ServiceRepository.instance.services,
        builder: (context, services, _) {
          if (services.isEmpty) {
            return const Center(
              child: Text(
                'No services yet',
                style: TextStyle(color: AppColors.hintGrey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final service = services[index];
              final isWorking = service.status == ServiceStatus.working;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: service.type.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(service.type.icon, color: service.type.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.type.label,
                            style: const TextStyle(
                              color: AppColors.hintGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isWorking
                            ? const Color(0xFFE3F6EA)
                            : const Color(0xFFFCE8E7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isWorking ? 'Working' : 'Not working',
                        style: TextStyle(
                          color: isWorking
                              ? AppColors.accentGreen
                              : AppColors.accentRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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
