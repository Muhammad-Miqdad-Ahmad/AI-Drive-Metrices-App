import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/trips/trips_screen.dart';
import '../../screens/reports/report_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/alerts/alerts_screen.dart'; // Import the new screen

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const TripsScreen(),
    const AlertsScreen(), // Added here
    const ReportScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryPurple,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_filled),
              label: "Trips",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active_rounded), // Alerts Icon
              label: "Alerts",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: "Reports",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}
