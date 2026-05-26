import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/trip_repository.dart';
import '../../core/services/trip_report_pdf_service.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportsScreen
//
// Lists all completed trips sorted by date (newest first).
// Each card shows:
//   • Score + grade
//   • Distance / duration / max speed
//   • Event count badges (brake / turn / accel)
//   • Quick "Download PDF" button
//   • Tap → TripDetailScreen
//
// Header shows aggregate stats from TripRepository.
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _filter = 'All'; // All | Good | Poor
  final Set<String> _downloadingIds = {};

  List<TripModel> _filtered(List<TripModel> trips) {
    switch (_filter) {
      case 'Good': return trips.where((t) => t.score.overall >= 80).toList();
      case 'Poor': return trips.where((t) => t.score.overall < 70).toList();
      default:     return trips;
    }
  }

  Future<void> _download(TripModel trip) async {
    setState(() => _downloadingIds.add(trip.id));
    try {
      final path = await TripReportPdfService.generate(trip);
      await TripReportPdfService.share(path, trip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(trip.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TripRepository>();
    final filtered = _filtered(repo.trips);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0E1A),
            pinned: true,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
                child: _SummaryRow(repo: repo),
              ),
            ),
            title: const Text('Reports',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),

          // ── Filter chips ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                for (final f in ['All', 'Good', 'Poor'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: const Color(0xFF4B7BF5).withOpacity(0.25),
                      backgroundColor: const Color(0xFF1A1F35),
                      labelStyle: TextStyle(
                        color: _filter == f
                            ? const Color(0xFF4B7BF5)
                            : const Color(0xFF8892A4),
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: _filter == f
                            ? const Color(0xFF4B7BF5).withOpacity(0.5)
                            : const Color(0xFF2A2F45),
                        width: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                    ),
                  ),
                const Spacer(),
                Text(
                  '${filtered.length} trip${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Color(0xFF5B6889), fontSize: 12),
                ),
              ]),
            ),
          ),

          // ── Trip list ──────────────────────────────────────────────────
          filtered.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.route_rounded,
                              size: 48, color: Color(0xFF2A2F45)),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'All'
                                ? 'No trips yet.\nStart a trip to see reports here.'
                                : 'No ${_filter.toLowerCase()}-score trips.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF5B6889), fontSize: 14),
                          ),
                        ]),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(
                          trip: filtered[i],
                          downloading: _downloadingIds.contains(filtered[i].id),
                          onDownload: () => _download(filtered[i]),
                          onTap: () => Navigator.of(context).pushNamed(
                            '/trip-detail',
                            arguments: filtered[i].id,
                          ),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Summary Row ────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final TripRepository repo;
  const _SummaryRow({required this.repo});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _summaryCard(
        '${repo.averageScore.toInt()}',
        'Avg Score',
        const Color(0xFF4B7BF5),
      ),
      const SizedBox(width: 10),
      _summaryCard(
        '${repo.totalDistanceKm.toStringAsFixed(0)} km',
        'Total Dist',
        const Color(0xFF00E676),
      ),
      const SizedBox(width: 10),
      _summaryCard(
        '${repo.trips.length}',
        'Trips',
        const Color(0xFFFF9800),
      ),
      const SizedBox(width: 10),
      _summaryCard(
        '${repo.totalEvents}',
        'Events',
        const Color(0xFFEF5350),
      ),
    ]);
  }

  Widget _summaryCard(String val, String lbl, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          ),
          child: Column(children: [
            Text(val,
                style: TextStyle(
                    color: color, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(lbl,
                style: const TextStyle(
                    color: Color(0xFF5B6889), fontSize: 11)),
          ]),
        ),
      );
}

// ── Trip Card ──────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onTap;
  const _TripCard({
    required this.trip,
    required this.downloading,
    required this.onDownload,
    required this.onTap,
  });

  Color get _scoreColor {
    if (trip.score.overall >= 80) return const Color(0xFF00E676);
    if (trip.score.overall >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141826),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2F45), width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row: date + score ────────────────────────────────────
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _formatDate(trip.startTime),
                style: const TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                trip.durationLabel,
                style: const TextStyle(
                    color: Color(0xFF5B6889), fontSize: 12),
              ),
            ]),
            const Spacer(),
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _scoreColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _scoreColor.withOpacity(0.3), width: 0.5),
              ),
              child: Text(
                '${trip.score.overall.toInt()}  ${trip.score.grade}',
                style: TextStyle(
                    color: _scoreColor, fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A2F45), height: 1, thickness: 0.5),
          const SizedBox(height: 12),

          // ── Stats row ────────────────────────────────────────────────
          Row(children: [
            _statPill(Icons.route_rounded,
                '${trip.distanceKm.toStringAsFixed(1)} km'),
            const SizedBox(width: 8),
            _statPill(Icons.speed_rounded,
                '${trip.maxSpeedKmh.toInt()} km/h'),
            const Spacer(),
            // Event badges
            if (trip.harshBrakingCount > 0)
              _eventBadge('${trip.harshBrakingCount}🔴', 'brake'),
            if (trip.sharpTurnCount > 0)
              _eventBadge('${trip.sharpTurnCount}🟠', 'turn'),
            if (trip.hardAccelCount > 0)
              _eventBadge('${trip.hardAccelCount}🟡', 'accel'),
            if (trip.events.isEmpty)
              const Text('✅ Clean',
                  style: TextStyle(
                      color: Color(0xFF00E676), fontSize: 12)),
          ]),

          const SizedBox(height: 12),

          // ── AI detection summary mini bar ────────────────────────────
          if (trip.classCounts.isNotEmpty) ...[
            _MiniDetectionBar(classCounts: trip.classCounts),
            const SizedBox(height: 12),
          ],

          // ── Bottom row: view + download ───────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.bar_chart_rounded, size: 15),
                label: const Text('View Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4B7BF5),
                  side: const BorderSide(
                      color: Color(0xFF4B7BF5), width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: downloading ? null : onDownload,
                icon: downloading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 15),
                label:
                    Text(downloading ? 'Exporting…' : 'PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2D5A),
                  foregroundColor: const Color(0xFF4B7BF5),
                  disabledBackgroundColor: const Color(0xFF2A2F45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _statPill(IconData icon, String label) => Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF5B6889)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
      ]);

  Widget _eventBadge(String label, String type) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(label,
            style: const TextStyle(fontSize: 12)),
      );

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
  }
}

// ── Mini Detection Bar ─────────────────────────────────────────────────────

class _MiniDetectionBar extends StatelessWidget {
  final Map<BehaviourClass, int> classCounts;
  const _MiniDetectionBar({required this.classCounts});

  Color _clsColor(BehaviourClass cls) {
    switch (cls) {
      case BehaviourClass.normal:      return const Color(0xFF00E676);
      case BehaviourClass.idle:        return const Color(0xFF3A4060);
      case BehaviourClass.suddenBrake: return const Color(0xFFEF5350);
      case BehaviourClass.rightTurn:   return const Color(0xFFFF9800);
      case BehaviourClass.leftTurn:    return const Color(0xFFFFB74D);
      case BehaviourClass.suddenAccel: return const Color(0xFFFFEB3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = classCounts.values.fold(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();
    final entries = classCounts.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Model detections:',
          style: TextStyle(color: Color(0xFF5B6889), fontSize: 11)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Row(
            children: entries.map((e) => Flexible(
              flex: (e.value / total * 100).round(),
              child: Container(color: _clsColor(e.key)),
            )).toList(),
          ),
        ),
      ),
    ]);
  }
}
