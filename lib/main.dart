import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/storage/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://gsgmyvdszgejcadgrvgs.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdzZ215dmRzemdlamNhZGdydmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5MTk3NTIsImV4cCI6MjA5NjQ5NTc1Mn0.2IJohd6T1WK1QpXD_yvWHpTaCmh6U30qrgeMbzVQYys',
  );

  // Seed default demo account (user@gmail.com / 111111)
  await LocalStorageService.seedDefaultUser();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: DriveMetricsApp(),
    ),
  );
}
