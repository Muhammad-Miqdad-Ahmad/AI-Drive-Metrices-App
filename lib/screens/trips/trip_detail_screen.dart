import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trip_repository_provider.dart';
import '../../core/services/trip_report_pdf_service.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripDetailScreen
//
// Displays full report for a completed trip:
//   1. Score card with grade + breakdown bars
//   2. Trip stats (distance, time, speed)
//   3. AI Detection Breakdown — per-class counts from the Random Forest model
//   4. Events timeline — each harsh event with GPS coords + confidence
//   5. Route map placeholder (swap for flutter_map when GPS is live)
//   6. Download / Share PDF button
//
// Route: '/trips/:id'
// Receives tripId (required) and an optional pre-loaded TripModel via GoRouter.
// ─────────────────────────────────────────────────────────────────────────────

class TripDetailScreen extends ConsumerStatefulWidget {
  /// The trip ID, always provided by GoRouter path parameter.
  final String tripId;

  /// Optional pre-loaded model passed via GoRouter's [extra].
  /// If null the screen will look up the trip from the repository.
  final TripModel? trip;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  bool _pdfLoading = false;

  Future<void> _downloadPdf(TripModel trip) async {
    setState(() => _pdfLoading = true);
    try {
      final path = await TripReportPdfService.generate(trip);
      await TripReportPdfService.share(path, trip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the pre-loaded trip if available, otherwise look up by id.
    final trip = widget.trip ?? ref.watch(tripByIdProvider(widget.tripId));

    if (trip == null) {
      return const Scaffold(
        body: Center(child: Text('Trip not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0E1A),
            pinned: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Report',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  _formatDate(trip.startTime),
                  style:
                      const TextStyle(color: Color(0xFF5B6889), fontSize: 12),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _pdfLoading ? null : () => _downloadPdf(trip),
                icon: _pdfLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4B7BF5),
                        ),
                      )
                    : const Icon(Icons.download_rounded,
                        color: Color(0xFF4B7BF5)),
                tooltip: 'Download PDF Report',
              ),
              IconButton(
                onPressed: () => _downloadPdf(trip),
                icon: const Icon(Icons.share_rounded, color: Color(0xFF5B6889)),
                tooltip: 'Share Report',
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Score card ───────────────────────────────────────────
                _ScoreCard(score: trip.score),
                const SizedBox(height: 16),

                // ── Trip stats ───────────────────────────────────────────
                _TripStatsRow(trip: trip),
                const SizedBox(height: 16),

                // ── AI Detection Breakdown ───────────────────────────────
                _AiDetectionBreakdown(
                  classCounts: trip.classCounts,
                  totalFrames: trip.classCounts.values.fold(0, (s, v) => s + v),
                ),
                const SizedBox(height: 16),

                // ── Score breakdown bars ─────────────────────────────────
                _ScoreBreakdown(score: trip.score),
                const SizedBox(height: 16),

                // ── Events timeline ──────────────────────────────────────
                _EventsTimeline(events: trip.events),
                const SizedBox(height: 16),

                // ── Route map ────────────────────────────────────────────
                _RouteMapSection(route: trip.route),
                const SizedBox(height: 24),

                // ── Download PDF button ───────────────────────────────────
                _PdfButton(
                  onPressed: () => _downloadPdf(trip),
                  loading: _pdfLoading,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Score Card ─────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final DriverScoreModel score;
  const _ScoreCard({required this.score});

  Color get _scoreColor {
    if (score.overall >= 80) return const Color(0xFF00E676);
    if (score.overall >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _scoreColor.withOpacity(0.15),
            const Color(0xFF141826),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _scoreColor.withOpacity(0.25), width: 0.8),
      ),
      child: Row(children: [
        // Score ring
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: score.overall / 100,
              strokeWidth: 6,
              backgroundColor: _scoreColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(_scoreColor),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score.overall.toInt().toString(),
                  style: TextStyle(
                    color: _scoreColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('/100',
                    style: TextStyle(
                        color: _scoreColor.withOpacity(0.6), fontSize: 10)),
              ],
            ),
          ]),
        ),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Grade  ${score.grade}',
            style: TextStyle(
              color: _scoreColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _gradeLabel(score.overall),
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13),
          ),
        ]),
      ]),
    );
  }

  String _gradeLabel(double s) {
    if (s >= 90) return 'Excellent Driver';
    if (s >= 80) return 'Good Driver';
    if (s >= 70) return 'Average Driver';
    if (s >= 60) return 'Needs Improvement';
    return 'Poor Driving Habits';
  }
}

// ── Trip Stats Row ─────────────────────────────────────────────────────────

class _TripStatsRow extends StatelessWidget {
  final TripModel trip;
  const _TripStatsRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(Icons.route_rounded, '${trip.distanceKm.toStringAsFixed(1)} km',
              'Distance'),
          _divider(),
          _stat(Icons.timer_rounded, trip.durationLabel, 'Duration'),
          _divider(),
          _stat(Icons.speed_rounded, '${trip.maxSpeedKmh.toInt()} km/h',
              'Max Speed'),
          _divider(),
          _stat(Icons.trending_up_rounded, '${trip.avgSpeedKmh.toInt()} km/h',
              'Avg Speed'),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String val, String lbl) => Column(children: [
        Icon(icon, color: const Color(0xFF4B7BF5), size: 18),
        const SizedBox(height: 6),
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        Text(lbl,
            style: const TextStyle(color: Color(0xFF5B6889), fontSize: 11)),
      ]);

  Widget _divider() => Container(
        height: 40,
        width: 0.5,
        color: const Color(0xFF2A2F45),
      );
}

// ── AI Detection Breakdown ─────────────────────────────────────────────────

class _AiDetectionBreakdown extends StatelessWidget {
  final Map<BehaviourClass, int> classCounts;
  final int totalFrames;

  const _AiDetectionBreakdown({
    required this.classCounts,
    required this.totalFrames,
  });

  Color _classColor(BehaviourClass cls) {
    switch (cls) {
      case BehaviourClass.normal:
        return const Color(0xFF00E676);
      case BehaviourClass.idle:
        return const Color(0xFF5B6889);
      case BehaviourClass.suddenBrake:
        return const Color(0xFFEF5350);
      case BehaviourClass.rightTurn:
        return const Color(0xFFFF9800);
      case BehaviourClass.leftTurn:
        return const Color(0xFFFFB74D);
      case BehaviourClass.suddenAccel:
        return const Color(0xFFFFEB3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (classCounts.isEmpty) return const SizedBox.shrink();

    final entries = classCounts.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.psychology_rounded,
              color: Color(0xFF4B7BF5), size: 18),
          const SizedBox(width: 8),
          const Text('AI Detection Breakdown',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
          const Spacer(),
          Text(
            '$totalFrames windows',
            style: const TextStyle(color: Color(0xFF5B6889), fontSize: 12),
          ),
        ]),
        const SizedBox(height: 14),
        if (totalFrames > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: entries.map((e) {
                  final pct = e.value / totalFrames;
                  return Flexible(
                    flex: (pct * 1000).round(),
                    child: Container(color: _classColor(e.key)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        ...entries.map((e) {
          final pct = totalFrames > 0 ? (e.value / totalFrames * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _classColor(e.key),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(e.key.label,
                    style: const TextStyle(
                        color: Color(0xFFCDD5E0), fontSize: 13)),
              ),
              Text('${e.value}×',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: _classColor(e.key).withOpacity(0.8), fontSize: 12),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Score Breakdown ────────────────────────────────────────────────────────

class _ScoreBreakdown extends StatelessWidget {
  final DriverScoreModel score;
  const _ScoreBreakdown({required this.score});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Braking', score.braking, Icons.disc_full_rounded),
      ('Cornering', score.cornering, Icons.turn_right_rounded),
      ('Speeding', score.speeding, Icons.speed_rounded),
      ('Smoothness', score.smoothness, Icons.waves_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Score Breakdown',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        ...items.map((item) {
          final (label, value, icon) = item;
          final color = value >= 80
              ? const Color(0xFF00E676)
              : value >= 60
                  ? const Color(0xFFFF9800)
                  : const Color(0xFFEF5350);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              SizedBox(
                width: 86,
                child: Text(label,
                    style: const TextStyle(
                        color: Color(0xFF8892A4), fontSize: 13)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2A2F45),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 32,
                child: Text(
                  '${value.toInt()}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Events Timeline ────────────────────────────────────────────────────────

class _EventsTimeline extends StatelessWidget {
  final List<TripEvent> events;
  const _EventsTimeline({required this.events});

  Color _eventColor(TripEventType type) {
    switch (type) {
      case TripEventType.harshBraking:
        return const Color(0xFFEF5350);
      case TripEventType.sharpTurn:
        return const Color(0xFFFF9800);
      case TripEventType.hardAccel:
        return const Color(0xFFFFEB3B);
      case TripEventType.speeding:
        return const Color(0xFFAB47BC);
      case TripEventType.collision:
        return const Color(0xFFEF5350);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timeline_rounded,
              color: Color(0xFF4B7BF5), size: 18),
          const SizedBox(width: 8),
          Text(
            'Events  (${events.length})',
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                '🎉  No harsh events detected on this trip',
                style: TextStyle(color: Color(0xFF5B6889), fontSize: 14),
              ),
            ),
          )
        else
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final ev = entry.value;
            final color = _eventColor(ev.type);
            final timeStr = '${ev.timestamp.hour.toString().padLeft(2, '0')}:'
                '${ev.timestamp.minute.toString().padLeft(2, '0')}:'
                '${ev.timestamp.second.toString().padLeft(2, '0')}';

            return IntrinsicHeight(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Timeline spine
                Column(children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  if (i < events.length - 1)
                    Expanded(
                      child:
                          Container(width: 1, color: const Color(0xFF2A2F45)),
                    ),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(bottom: i < events.length - 1 ? 14 : 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withOpacity(0.2), width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(ev.label,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(timeStr,
                                style: const TextStyle(
                                    color: Color(0xFF5B6889),
                                    fontSize: 11,
                                    fontFamily: 'monospace')),
                          ]),
                          if (ev.sourceClass != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Model: ${ev.sourceClass!.label}'
                              '  •  Confidence: ${((ev.confidence ?? 0) * 100).toInt()}%'
                              '${ev.value != null ? '  •  ${ev.value!.toStringAsFixed(2)} g' : ''}',
                              style: const TextStyle(
                                  color: Color(0xFF5B6889), fontSize: 11),
                            ),
                          ],
                          if (ev.latitude != 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'GPS: ${ev.latitude.toStringAsFixed(5)}, '
                              '${ev.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                  color: Color(0xFF3A4060), fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Route Map Section ──────────────────────────────────────────────────────

class _RouteMapSection extends StatelessWidget {
  final List<LatLngPoint> route;
  const _RouteMapSection({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
      ),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            size: Size.infinite,
            painter: _RoutePainter(route: route),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 12, color: Color(0xFF5B6889)),
              SizedBox(width: 4),
              Text(
                'Add flutter_map for live map',
                style: TextStyle(color: Color(0xFF5B6889), fontSize: 11),
              ),
            ]),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.map_rounded, size: 13, color: Color(0xFF4B7BF5)),
              const SizedBox(width: 6),
              Text(
                '${route.length} GPS points',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<LatLngPoint> route;
  const _RoutePainter({required this.route});

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;

    final lats = route.map((p) => p.latitude).toList();
    final lngs = route.map((p) => p.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final dLat = (maxLat - minLat).abs().clamp(0.001, 999);
    final dLng = (maxLng - minLng).abs().clamp(0.001, 999);

    double px(LatLngPoint p) =>
        ((p.longitude - minLng) / dLng) * (size.width - 48) + 24;
    double py(LatLngPoint p) =>
        size.height -
        (((p.latitude - minLat) / dLat) * (size.height - 48) + 24);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2438)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), gridPaint);
      canvas.drawLine(Offset(size.width * i / 4, 0),
          Offset(size.width * i / 4, size.height), gridPaint);
    }

    // Route line
    final linePaint = Paint()
      ..color = const Color(0xFF4B7BF5)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(px(route.first), py(route.first));
    for (final pt in route.skip(1)) {
      path.lineTo(px(pt), py(pt));
    }
    canvas.drawPath(path, linePaint);

    // Start dot
    canvas.drawCircle(Offset(px(route.first), py(route.first)), 5,
        Paint()..color = const Color(0xFF00E676));
    // End dot
    canvas.drawCircle(Offset(px(route.last), py(route.last)), 5,
        Paint()..color = const Color(0xFFEF5350));
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route != route;
}

// ── PDF Button ─────────────────────────────────────────────────────────────

class _PdfButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  const _PdfButton({required this.onPressed, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.picture_as_pdf_rounded),
        label: Text(loading ? 'Generating PDF…' : 'Download PDF Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4B7BF5),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2A2F45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
