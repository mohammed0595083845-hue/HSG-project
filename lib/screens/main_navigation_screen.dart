import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/auth_service.dart';
import '../models/app_user.dart';
import 'admin_screen.dart';
import 'map_screen.dart';
import 'report_service_screen.dart';
import 'services_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: AuthService.instance.currentUser,
      builder: (context, user, _) {
        final isAdmin = user?.isAdmin ?? false;

        final screens = <Widget>[
          const MapScreen(),
          const ServicesListScreen(),
          const ReportServiceScreen(),
          if (isAdmin) const AdminScreen(),
        ];

        final index = _selectedIndex >= screens.length ? 0 : _selectedIndex;

        return Scaffold(
          body: IndexedStack(index: index, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) => setState(() => _selectedIndex = i),
            selectedItemColor: AppColors.primaryBlue,
            unselectedItemColor: AppColors.hintGrey,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Map',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: 'Services',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Report',
              ),
              if (isAdmin)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  activeIcon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
            ],
          ),
        );
      },
    );
  }
}
