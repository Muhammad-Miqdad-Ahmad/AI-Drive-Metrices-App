import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── All imports & exports MUST come before any declarations ──────────────────
import '../core/services/ble_data_service.dart';
import '../core/services/trip_repository.dart';
import '../models/models.dart';

export '../core/services/ble_data_service.dart';
export '../core/services/trip_repository.dart';
export '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BLE provider — ChangeNotifierProvider so widgets rebuild on BLE state changes
// ─────────────────────────────────────────────────────────────────────────────
final bleProvider = ChangeNotifierProvider<BleDataService>((ref) {
  final service = BleDataService();
  ref.onDispose(service.dispose);
  return service;
});

// Convenience: just the latest frame
final latestFrameProvider = Provider((ref) {
  return ref.watch(bleProvider).latestFrame;
});

// Convenience: is a trip currently being recorded?
final isTripActiveProvider = Provider((ref) {
  return ref.watch(bleProvider).isTripActive;
});

// ─────────────────────────────────────────────────────────────────────────────
// TripRepository provider
// Overridden in main.dart with the already-initialised instance.
// ─────────────────────────────────────────────────────────────────────────────
final tripRepositoryProvider = ChangeNotifierProvider<TripRepository>((ref) {
  // Fallback (should always be overridden in main.dart)
  return TripRepository();
});

// Convenience: sorted trip list
final tripsProvider = Provider((ref) {
  return ref.watch(tripRepositoryProvider).trips;
});

// Single trip by id
final tripByIdProvider = Provider.family<TripModel?, String>((ref, id) {
  return ref.watch(tripRepositoryProvider).getTrip(id);
});

// Vehicle health derived from trip history
final vehicleHealthProvider = Provider((ref) {
  return ref.watch(tripRepositoryProvider).vehicleHealth;
});

// Weekly scores for dashboard chart
final weeklyScoresProvider = Provider((ref) {
  return ref.watch(tripRepositoryProvider).weeklyScores;
});
