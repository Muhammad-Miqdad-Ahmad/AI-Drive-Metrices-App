import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/ble_data_service.dart';
import '../../core/services/trip_repository.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LiveTripScreen
//
// Shows real-time:
//   • GPS speed gauge
//   • Current behaviour class badge (from model output)
//   • Live event counter
//   • Elapsed time & distance
//   • Mini event feed (last 5 harsh events)
//
// Tapping "End Trip" finalises the session, saves to TripRepository,
// and navigates to TripDetailScreen.
// ─────────────────────────────────────────────────────────────────────────────

class LiveTripScreen extends StatefulWidget {
  const LiveTripScreen({super.key});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _clockTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startTime;
  final List<TripEvent> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start the trip
    final ble = context.read<BleDataService>();
    ble.startTrip();
    _startTime = DateTime.now();

    // Clock ticker
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _startTime != null) {
        setState(() => _elapsed = DateTime.now().difference(_startTime!));
      }
    });

    // Listen for harsh events to show in the feed
    ble.tripEvents.listen((event) {
      if (mounted) {
        setState(() {
          _recentEvents.insert(0, event);
          if (_recentEvents.length > 5) _recentEvents.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  Future<void> _endTrip() async {
    final ble = context.read<BleDataService>();
    final repo = context.read<TripRepository>();

    final trip = ble.endTrip();
    if (trip == null) {
      Navigator.of(context).pop();
      return;
    }

    await repo.saveTrip(trip);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        '/trip-detail',
        arguments: trip.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleDataService>();
    final frame = ble.latestFrame;
    final liveTrip = ble.liveTrip;

    final speed = frame?.speedKmh ?? 0.0;
    final cls = frame?.detectedClass ?? BehaviourClass.idle;
    final confidence = frame?.confidence ?? 0.0;
    final distance = liveTrip?.distanceKm ?? 0.0;
    final eventCount = liveTrip?.events.length ?? 0;
    final gpsFix = frame?.gpsFix ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFF00E676),
                  const Color(0xFF69F0AE),
                  _pulseController.value,
                ),
              ),
            ),
          ),
          const Text('Live Trip', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              _formatElapsed(_elapsed),
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontSize: 16,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Speed gauge ────────────────────────────────────────────────
          _SpeedGauge(speedKmh: speed, gpsFix: gpsFix),
          const SizedBox(height: 8),

          // ── Behaviour class badge ──────────────────────────────────────
          _BehaviourBadge(cls: cls, confidence: confidence),
          const SizedBox(height: 20),

          // ── Stats row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.route,
                  label: '${distance.toStringAsFixed(2)} km',
                  sublabel: 'Distance',
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.warning_amber_rounded,
                  label: '$eventCount',
                  sublabel: 'Events',
                  highlight: eventCount > 0,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.speed,
                  label: '${(liveTrip?.maxSpeedKmh ?? 0).toInt()} km/h',
                  sublabel: 'Max Speed',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── IMU readings ───────────────────────────────────────────────
          if (frame != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ImuReadings(frame: frame),
            ),

          const SizedBox(height: 20),

          // ── Recent events feed ─────────────────────────────────────────
          Expanded(
            child: _RecentEventFeed(events: _recentEvents),
          ),

          // ── End trip button ────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _endTrip,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Trip & View Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Speed Gauge ────────────────────────────────────────────────────────────

class _SpeedGauge extends StatelessWidget {
  final double speedKmh;
  final bool gpsFix;
  const _SpeedGauge({required this.speedKmh, required this.gpsFix});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F35), Color(0xFF141826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Column(children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: speedKmh.toInt().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -4,
                ),
              ),
              const TextSpan(
                text: ' km/h',
                style: TextStyle(
                  color: Color(0xFF8892A4),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gpsFix ? const Color(0xFF00E676) : const Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            gpsFix ? 'GPS Fix' : 'Acquiring GPS…',
            style: TextStyle(
              color: gpsFix ? const Color(0xFF00E676) : const Color(0xFFFF9800),
              fontSize: 12,
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Behaviour Badge ────────────────────────────────────────────────────────

class _BehaviourBadge extends StatelessWidget {
  final BehaviourClass cls;
  final double confidence;
  const _BehaviourBadge({required this.cls, required this.confidence});

  Color get _color {
    if (cls == BehaviourClass.normal || cls == BehaviourClass.idle) {
      return const Color(0xFF00E676);
    }
    if (cls == BehaviourClass.suddenBrake) return const Color(0xFFEF5350);
    return const Color(0xFFFF9800);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(cls.isHarsh ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: _color, size: 20),
          const SizedBox(width: 10),
          Text(cls.label,
              style: TextStyle(color: _color, fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
        Text(
          '${(confidence * 100).toInt()}%',
          style: TextStyle(color: _color.withOpacity(0.7), fontSize: 13),
        ),
      ]),
    );
  }
}

// ── Stat Chip ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool highlight;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFF9800).withOpacity(0.12)
              : const Color(0xFF1A1F35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? const Color(0xFFFF9800).withOpacity(0.3)
                : const Color(0xFF2A2F45),
            width: 0.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              size: 16,
              color: highlight ? const Color(0xFFFF9800) : const Color(0xFF5B6889)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                color: highlight ? const Color(0xFFFF9800) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
          Text(sublabel,
              style: const TextStyle(color: Color(0xFF5B6889), fontSize: 11)),
        ]),
      ),
    );
  }
}

// ── IMU Readings ───────────────────────────────────────────────────────────

class _ImuReadings extends StatelessWidget {
  final SensorFrame frame;
  const _ImuReadings({required this.frame});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _imuVal('Ax', frame.ax, 'g'),
          _imuVal('Ay', frame.ay, 'g'),
          _imuVal('Az', frame.az, 'g'),
          const SizedBox(width: 1,
              child: VerticalDivider(color: Color(0xFF2A2F45), thickness: 0.5)),
          _imuVal('Gx', frame.gx, '°/s'),
          _imuVal('Gy', frame.gy, '°/s'),
          _imuVal('Gz', frame.gz, '°/s'),
        ],
      ),
    );
  }

  Widget _imuVal(String axis, double v, String unit) => Column(children: [
        Text(axis,
            style: const TextStyle(color: Color(0xFF5B6889), fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}',
          style: TextStyle(
            color: v.abs() > 0.5 ? const Color(0xFFFF9800) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
        Text(unit,
            style: const TextStyle(color: Color(0xFF3A4060), fontSize: 10)),
      ]);
}

// ── Recent Event Feed ──────────────────────────────────────────────────────

class _RecentEventFeed extends StatelessWidget {
  final List<TripEvent> events;
  const _RecentEventFeed({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            'Recent Events',
            style: TextStyle(
              color: Color(0xFF8892A4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? const Center(
                  child: Text(
                    'No harsh events detected',
                    style: TextStyle(color: Color(0xFF3A4060), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _EventTile(event: events[i]),
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final TripEvent event;
  const _EventTile({required this.event});

  Color get _color {
    switch (event.type) {
      case TripEventType.harshBraking: return const Color(0xFFEF5350);
      case TripEventType.sharpTurn:    return const Color(0xFFFF9800);
      case TripEventType.hardAccel:    return const Color(0xFFFFEB3B);
      case TripEventType.speeding:     return const Color(0xFFAB47BC);
      default:                         return const Color(0xFF5B6889);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${event.timestamp.hour.toString().padLeft(2, '0')}:'
        '${event.timestamp.minute.toString().padLeft(2, '0')}:'
        '${event.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.25), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 3, height: 36,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.label,
                style: TextStyle(
                  color: _color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 2),
            Text(
              event.sourceClass != null
                  ? 'Model: ${event.sourceClass!.label}  •  '
                      'Conf: ${((event.confidence ?? 0) * 100).toInt()}%'
                  : '',
              style: const TextStyle(color: Color(0xFF5B6889), fontSize: 11),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(timeStr,
              style: const TextStyle(
                  color: Color(0xFF5B6889),
                  fontSize: 11,
                  fontFamily: 'monospace')),
          if (event.value != null)
            Text(
              '${event.value!.toStringAsFixed(2)} g',
              style: TextStyle(
                  color: _color.withOpacity(0.8), fontSize: 12),
            ),
        ]),
      ]),
    );
  }
}
