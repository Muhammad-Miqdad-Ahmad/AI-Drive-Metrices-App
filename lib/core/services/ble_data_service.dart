import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BleDataService
//
// Wraps flutter_blue_plus to:
//   1. Scan for "DriveMetrics-" prefixed devices
//   2. Connect and subscribe to the notify characteristic
//   3. Parse incoming JSON frames → SensorFrame stream
//   4. Accumulate a LiveTripState during an active session
//   5. Finalise the trip and expose the completed TripModel
//
// HOW TO USE:
//   final ble = BleDataService();
//   ble.frames.listen((frame) { ... });      // raw sensor frames
//   ble.tripEvents.listen((event) { ... });  // harsh-event alerts
//   await ble.startTrip();
//   final trip = await ble.endTrip();
//
// NOTE: Replace the stub FlutterBluePlus calls below with the real package
// API once you add flutter_blue_plus to pubspec.yaml:
//
//   dependencies:
//     flutter_blue_plus: ^1.31.0
//
// The service is designed so the rest of the app never imports flutter_blue_plus
// directly — only this file does.
// ─────────────────────────────────────────────────────────────────────────────

/// UUIDs must match what you programmed into the ESP32/STM32 firmware.
class BleUuids {
  BleUuids._();
  static const String service        = '12345678-1234-1234-1234-123456789abc';
  static const String rxCharacteristic = '12345678-1234-1234-1234-123456789abd'; // notify
  static const String txCharacteristic = '12345678-1234-1234-1234-123456789abe'; // write
}

enum BleStatus { idle, scanning, connecting, connected, disconnected, error }

class BleDataService extends ChangeNotifier {
  // ── Public state ──────────────────────────────────────────────────────────
  BleStatus status = BleStatus.idle;
  String? connectedDeviceName;
  bool get isConnected => status == BleStatus.connected;

  // ── Streams ───────────────────────────────────────────────────────────────
  final _frameController = StreamController<SensorFrame>.broadcast();
  Stream<SensorFrame> get frames => _frameController.stream;

  final _eventController = StreamController<TripEvent>.broadcast();
  Stream<TripEvent> get tripEvents => _eventController.stream;

  // ── Live trip state ───────────────────────────────────────────────────────
  LiveTripState? _liveTrip;
  bool get isTripActive => _liveTrip != null;
  LiveTripState? get liveTrip => _liveTrip;

  // ── Latest frame (for UI that just wants the current reading) ─────────────
  SensorFrame? latestFrame;

  // ── Internal ──────────────────────────────────────────────────────────────
  StreamSubscription<List<int>>? _notifySub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // ─────────────────────────────────────────────────────────────────────────
  // Scanning
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a stream of discovered device names + ids.
  /// Replace body with real flutter_blue_plus scan when integrating.
  Stream<DiscoveredDevice> startScan({Duration timeout = const Duration(seconds: 10)}) async* {
    _setStatus(BleStatus.scanning);

    // ── STUB: simulate device discovery ──────────────────────────────────
    // TODO: replace with:
    //   FlutterBluePlus.startScan(timeout: timeout);
    //   yield* FlutterBluePlus.scanResults
    //     .expand((results) => results)
    //     .where((r) => r.device.platformName.startsWith('DriveMetrics-'))
    //     .map((r) => DiscoveredDevice(
    //           id: r.device.remoteId.str,
    //           name: r.device.platformName,
    //           rssi: r.rssi,
    //         ));
    await Future.delayed(const Duration(milliseconds: 800));
    yield DiscoveredDevice(id: '00:1A:7D:DA:71:13', name: 'DriveMetrics-A1B2', rssi: -62);
    await Future.delayed(const Duration(milliseconds: 600));
    yield DiscoveredDevice(id: '00:1A:7D:DA:71:14', name: 'DriveMetrics-C3D4', rssi: -75);
    await Future.delayed(const Duration(seconds: 2));
    _setStatus(BleStatus.idle);
    // ── END STUB ──────────────────────────────────────────────────────────
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Connection
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> connect(DiscoveredDevice device) async {
    _setStatus(BleStatus.connecting);
    _reconnectAttempts = 0;

    try {
      // ── STUB: simulate connection ─────────────────────────────────────
      // TODO: replace with:
      //   final bleDevice = BluetoothDevice.fromId(device.id);
      //   await bleDevice.connect(timeout: const Duration(seconds: 10));
      //   final services = await bleDevice.discoverServices();
      //   final svc = services.firstWhere((s) => s.uuid.str == BleUuids.service);
      //   final char = svc.characteristics.firstWhere((c) => c.uuid.str == BleUuids.rxCharacteristic);
      //   await char.setNotifyValue(true);
      //   _notifySub = char.onValueReceived.listen(_onRawBytes);
      //   bleDevice.connectionState.listen((state) {
      //     if (state == BluetoothConnectionState.disconnected) _onDisconnected(device);
      //   });
      await Future.delayed(const Duration(milliseconds: 1500));
      connectedDeviceName = device.name;
      _setStatus(BleStatus.connected);
      _startMockDataFeed(); // remove when using real BLE
      return true;
      // ── END STUB ──────────────────────────────────────────────────────
    } catch (e) {
      _setStatus(BleStatus.error);
      return false;
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _notifySub?.cancel();
    _mockTimer?.cancel();
    connectedDeviceName = null;
    _setStatus(BleStatus.disconnected);
    // TODO: await bleDevice.disconnect();
  }

  void _onDisconnected(DiscoveredDevice device) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      _setStatus(BleStatus.connecting);
      _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, () {
        connect(device);
      });
    } else {
      _setStatus(BleStatus.disconnected);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Frame parsing
  // ─────────────────────────────────────────────────────────────────────────

  void _onRawBytes(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final frame = SensorFrame.fromJson(json);
      _processFrame(frame);
    } catch (e) {
      debugPrint('[BLE] parse error: $e');
    }
  }

  void _processFrame(SensorFrame frame) {
    latestFrame = frame;
    _frameController.add(frame);
    if (_liveTrip != null) {
      final before = _liveTrip!.events.length;
      _liveTrip!.addFrame(frame);
      // If a new event was added, broadcast it
      if (_liveTrip!.events.length > before) {
        _eventController.add(_liveTrip!.events.last);
      }
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Trip lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  void startTrip() {
    _liveTrip = LiveTripState(
      tripId: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
    );
    notifyListeners();
  }

  /// Finalise the trip and return the completed TripModel.
  TripModel? endTrip() {
    if (_liveTrip == null) return null;
    final trip = _liveTrip!.toTripModel();
    _liveTrip = null;
    notifyListeners();
    return trip;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mock data feed (for development without hardware)
  // Remove _startMockDataFeed and _mockTimer once real BLE works.
  // ─────────────────────────────────────────────────────────────────────────

  Timer? _mockTimer;
  int _mockSeq = 0;
  final _rng = _SimpleRng(seed: 42);

  void _startMockDataFeed() {
    _mockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final cls = _rng.nextBehaviourClass();
      final frame = SensorFrame(
        seqNo: _mockSeq++,
        timestamp: DateTime.now(),
        ax: _rng.nextDouble(-0.3, 0.3),
        ay: _rng.nextDouble(-0.2, 0.2),
        az: 1.0 + _rng.nextDouble(-0.05, 0.05),
        gx: _rng.nextDouble(-5, 5),
        gy: _rng.nextDouble(-5, 5),
        gz: _rng.nextDouble(-3, 3),
        detectedClass: cls,
        confidence: _rng.nextDouble(0.55, 0.99),
        latitude: 31.5204 + _mockSeq * 0.00005,
        longitude: 74.3587 + _mockSeq * 0.00003,
        speedKmh: _rng.nextDouble(30, 80),
        gpsFix: true,
      );
      _processFrame(frame);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _setStatus(BleStatus s) {
    status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _frameController.close();
    _eventController.close();
    _notifySub?.cancel();
    _reconnectTimer?.cancel();
    _mockTimer?.cancel();
    super.dispose();
  }
}

// ── Supporting types ──────────────────────────────────────────────────────

class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  const DiscoveredDevice({required this.id, required this.name, required this.rssi});

  int get signalBars {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }
}

/// Minimal seeded RNG — only used by the mock data feed.
class _SimpleRng {
  int _state;
  _SimpleRng({required int seed}) : _state = seed;

  double nextDouble(double min, double max) {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return min + (_state / 0xFFFFFFFF) * (max - min);
  }

  BehaviourClass nextBehaviourClass() {
    final r = nextDouble(0, 1);
    if (r < 0.50) return BehaviourClass.normal;
    if (r < 0.65) return BehaviourClass.idle;
    if (r < 0.75) return BehaviourClass.suddenBrake;
    if (r < 0.83) return BehaviourClass.rightTurn;
    if (r < 0.91) return BehaviourClass.leftTurn;
    return BehaviourClass.suddenAccel;
  }
}
