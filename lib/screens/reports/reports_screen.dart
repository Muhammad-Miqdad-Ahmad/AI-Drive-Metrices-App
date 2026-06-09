import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../widgets/common/score_gauge_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String? _error;
  List<TripModel> _trips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await LocalStorageService.getDeviceToken();
      if (token == null) {
        setState(() { _trips = []; _loading = false; });
        return;
      }
      final svc = SupabaseService(deviceToken: token);
      final trips = await svc.getRecentTrips(limit: 100);
      setState(() { _trips = trips; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip Reports'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            label: const Text('Filter'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_trips.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('No reports yet', style: AppTextStyles.h3),
            SizedBox(height: 8),
            Text('Reports will appear after your first trip syncs.',
                style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ReportCard(trip: _trips[index]),
      ),
    );
  }
}

// ── Report card with PDF download ─────────────────────────────────────────

class _ReportCard extends StatefulWidget {
  final TripModel trip;
  const _ReportCard({required this.trip});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _isDownloading = false;

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      final pdfBytes = await _generateTripReportPdf(widget.trip);
      final fileName =
          'trip_report_${widget.trip.id}_${widget.trip.startTime.millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<Uint8List> _generateTripReportPdf(TripModel trip) async {
    final pdf = pw.Document();
    const brandBlue = PdfColor.fromInt(0xFF0057FF);
    const textDark = PdfColor.fromInt(0xFF0D1B3E);
    const textGrey = PdfColor.fromInt(0xFF5A6B8A);
    const borderColor = PdfColor.fromInt(0xFFE4E8F0);
    const bgLight = PdfColor.fromInt(0xFFF7F9FC);

    final score = trip.score.overall;
    final scoreColor = score >= 80
        ? const PdfColor.fromInt(0xFF34C759)
        : score >= 60
            ? const PdfColor.fromInt(0xFFFF9500)
            : const PdfColor.fromInt(0xFFFF3B30);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('DRIVE METRICS AI',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: brandBlue)),
                pw.SizedBox(height: 4),
                pw.Text('Trip Safety Report',
                    style: const pw.TextStyle(fontSize: 11, color: textGrey)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(DateFormatter.tripDate(trip.startTime),
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark)),
                pw.Text(trip.durationLabel,
                    style: const pw.TextStyle(fontSize: 10, color: textGrey)),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: borderColor),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat('Safety Score',
                    '${score.toInt()} / 100', scoreColor),
                _pdfStat('Grade', trip.score.grade, scoreColor),
                _pdfStat('Distance', '${trip.distanceKm.toStringAsFixed(1)} km', textDark),
                _pdfStat('Max Speed', '${trip.maxSpeedKmh.toInt()} km/h', textDark),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Score Breakdown',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark)),
          pw.SizedBox(height: 10),
          ...[
            ('Braking', trip.score.braking),
            ('Cornering', trip.score.cornering),
            ('Acceleration', trip.score.acceleration),
            ('Smoothness', trip.score.smoothness),
          ].map((s) => _pdfScoreRow(s.$1, s.$2, borderColor, textDark, textGrey)),
          if (trip.harshEventCount > 0) ...[
            pw.SizedBox(height: 20),
            pw.Text('Harsh Events: ${trip.harshEventCount}',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark)),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(children: [
      pw.Text(value,
          style: pw.TextStyle(
              fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF5A6B8A))),
    ]);
  }

  pw.Widget _pdfScoreRow(String label, double value, PdfColor border,
      PdfColor textDark, PdfColor textGrey) {
    final color = value >= 80
        ? const PdfColor.fromInt(0xFF34C759)
        : value >= 60
            ? const PdfColor.fromInt(0xFFFF9500)
            : const PdfColor.fromInt(0xFFFF3B30);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 11, color: textDark)),
          pw.Text('${value.toInt()} / 100',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final color = AppColors.scoreColor(trip.score.overall);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                ScoreGaugeWidget(score: trip.score.overall, size: 64, showLabel: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormatter.tripDate(trip.startTime),
                          style: AppTextStyles.labelLarge),
                      Text(
                        '${trip.durationLabel}  ·  ${trip.distanceKm.toStringAsFixed(1)} km',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.scoreColorLight(trip.score.overall),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trip.score.grade,
                    style: AppTextStyles.labelLarge.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Score rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _ScoreChip('Braking', trip.score.braking),
                const SizedBox(width: 8),
                _ScoreChip('Cornering', trip.score.cornering),
                const SizedBox(width: 8),
                _ScoreChip('Accel', trip.score.acceleration),
                const Spacer(),
                Text(
                  '${trip.harshEventCount} events',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.warning),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Download button
          InkWell(
            onTap: _isDownloading ? null : _downloadReport,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.download_rounded,
                        size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _isDownloading ? 'Generating PDF…' : 'Download Report',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final double value;
  const _ScoreChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('${value.toInt()}',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.scoreColor(value))),
          Text(label, style: AppTextStyles.overline),
        ],
      ),
    );
  }
}
