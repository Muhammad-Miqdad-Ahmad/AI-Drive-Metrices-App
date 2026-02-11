import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const DriveMetricApp());
}

class DriveMetricApp extends StatelessWidget {
  const DriveMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drive Metrics AI',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
