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
    url: 'https://feyzscuouqzzhulbgwfw.supabase.co/',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZleXpzY3VvdXF6emh1bGJnd2Z3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2OTAxNzYsImV4cCI6MjA5NzI2NjE3Nn0.1P0wP8xBoiax9vso2kHIBrBFLkhSPMvbRUf9qdghed4',
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
