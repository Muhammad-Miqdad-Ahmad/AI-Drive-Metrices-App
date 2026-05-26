import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/trip_repository_provider.dart';
import 'core/services/trip_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialise repository before runApp so mock/DB data is ready
  final repo = TripRepository();
  await repo.init();

  runApp(
    ProviderScope(
      overrides: [
        // ── Riverpod 2.x: use overrideWith instead of overrideWithValue ──
        tripRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: const DriveMetricsApp(),
    ),
  );
}
