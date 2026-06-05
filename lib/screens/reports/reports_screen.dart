import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../widgets/common/score_gauge_widget.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = MockDataService.trips;

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
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ReportCard(trip: trips[index]),
      ),
    );
  }
}

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

    // Brand colors
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
          // ── Header ──────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: brandBlue,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRIP REPORT',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormatter.fullDateTime(trip.startTime),
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFCCDDFF),
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(
                      'Trip ID: ${trip.id}',
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFCCDDFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                // Score badge
                pw.Container(
                  width: 72,
                  height: 72,
                  decoration: pw.BoxDecoration(
                    color: scoreColor,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          score.toInt().toString(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Grade ${trip.score.grade}',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── Trip Summary ─────────────────────────────────────────
          pw.Text(
            'Trip Summary',
            style: pw.TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Table(
              children: [
                _pdfTableRow(
                    'Distance',
                    '${trip.distanceKm.toStringAsFixed(1)} km',
                    textDark,
                    textGrey),
                _pdfTableRow(
                    'Duration', trip.durationLabel, textDark, textGrey),
                _pdfTableRow('Max Speed', '${trip.maxSpeedKmh.toInt()} km/h',
                    textDark, textGrey),
                _pdfTableRow(
                    'Avg Speed',
                    '${trip.avgSpeedKmh.toStringAsFixed(1)} km/h',
                    textDark,
                    textGrey),
                _pdfTableRow(
                  'Start Time',
                  DateFormatter.time(trip.startTime),
                  textDark,
                  textGrey,
                ),
                if (trip.endTime != null)
                  _pdfTableRow(
                    'End Time',
                    DateFormatter.time(trip.endTime!),
                    textDark,
                    textGrey,
                  ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── Driver Score Breakdown ────────────────────────────────
          pw.Text(
            'Driver Score Breakdown',
            style: pw.TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Column(
              children: [
                _pdfScoreBar('Overall', trip.score.overall, scoreColor),
                pw.SizedBox(height: 10),
                _pdfScoreBar('Braking', trip.score.braking,
                    _pdfScoreColor(trip.score.braking)),
                pw.SizedBox(height: 10),
                _pdfScoreBar('Cornering', trip.score.cornering,
                    _pdfScoreColor(trip.score.cornering)),
                pw.SizedBox(height: 10),
                _pdfScoreBar('Speeding', trip.score.speeding,
                    _pdfScoreColor(trip.score.speeding)),
                pw.SizedBox(height: 10),
                _pdfScoreBar('Smoothness', trip.score.smoothness,
                    _pdfScoreColor(trip.score.smoothness)),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── Safety Events ─────────────────────────────────────────
          pw.Text(
            'Safety Events',
            style: pw.TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: borderColor),
            ),
            child: trip.events.isEmpty
                ? pw.Row(
                    children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFF34C759),
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'No safety events detected — excellent driving!',
                        style: const pw.TextStyle(
                          color: PdfColor.fromInt(0xFF34C759),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : pw.Table(
                    border:const pw.TableBorder(
                      horizontalInside:
                          pw.BorderSide(color: borderColor, width: 0.5),
                    ),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFE4E8F0),
                        ),
                        children: [
                          _pdfTableHeader('Event Type'),
                          _pdfTableHeader('Time'),
                          _pdfTableHeader('Details'),
                        ],
                      ),
                      ...trip.events.map((e) => pw.TableRow(
                            children: [
                              _pdfTableCell(e.label),
                              _pdfTableCell(DateFormatter.time(e.timestamp)),
                              _pdfTableCell(e.value != null
                                  ? e.value!.toStringAsFixed(1)
                                  : '—'),
                            ],
                          )),
                    ],
                  ),
          ),

          pw.SizedBox(height: 20),

          // ── Event Counts ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Table(
              children: [
                _pdfTableRow(
                  'Harsh Braking',
                  '${trip.harshBrakingCount}x',
                  textDark,
                  textGrey,
                  valueColor: trip.harshBrakingCount == 0
                      ? const PdfColor.fromInt(0xFF34C759)
                      : const PdfColor.fromInt(0xFFFF3B30),
                ),
                _pdfTableRow(
                  'Sharp Turns',
                  '${trip.sharpTurnCount}x',
                  textDark,
                  textGrey,
                  valueColor: trip.sharpTurnCount == 0
                      ? const PdfColor.fromInt(0xFF34C759)
                      : const PdfColor.fromInt(0xFFFF9500),
                ),
                _pdfTableRow(
                  'Speeding Incidents',
                  '${trip.speedingCount}x',
                  textDark,
                  textGrey,
                  valueColor: trip.speedingCount == 0
                      ? const PdfColor.fromInt(0xFF34C759)
                      : const PdfColor.fromInt(0xFFFF3B30),
                ),
                _pdfTableRow(
                  'Total Events',
                  '${trip.events.length} detected',
                  textDark,
                  textGrey,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // ── Footer ───────────────────────────────────────────────
          pw.Divider(color: borderColor),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated on ${DateFormatter.fullDateTime(DateTime.now())}',
                style: const pw.TextStyle(color: textGrey, fontSize: 9),
              ),
              pw.Text(
                'Confidential — Driver Report',
                style: const pw.TextStyle(color: textGrey, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.TableRow _pdfTableRow(
    String label,
    String value,
    PdfColor textDark,
    PdfColor textGrey, {
    PdfColor? valueColor,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            label,
            style: pw.TextStyle(color: textGrey, fontSize: 11),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              color: valueColor ?? textDark,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfScoreBar(String label, double value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                color: PdfColor.fromInt(0xFF0D1B3E),
                fontSize: 11,
              ),
            ),
            pw.Text(
              value.toInt().toString(),
              style: pw.TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Stack(
          children: [
            pw.Container(
              height: 6,
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE4E8F0),
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
            pw.LayoutBuilder(
              builder: (ctx, constraints) {
                // Safely handle if constraints or maxWidth is null
                final maxWidth = constraints?.maxWidth ?? 400.0;
                return pw.Container(
                  width: maxWidth * (value / 100),
                  height: 6,
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0D1B3E),
        ),
      ),
    );
  }

  pw.Widget _pdfTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromInt(0xFF5A6B8A),
        ),
      ),
    );
  }

  PdfColor _pdfScoreColor(double score) {
    if (score >= 80) return const PdfColor.fromInt(0xFF34C759);
    if (score >= 60) return const PdfColor.fromInt(0xFFFF9500);
    return const PdfColor.fromInt(0xFFFF3B30);
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.trip.score.overall;
    final color = AppColors.scoreColor(score);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.scoreColorLight(score),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ScoreBadge(score: score, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip Report',
                        style: AppTextStyles.labelLarge,
                      ),
                      Text(
                        DateFormatter.fullDateTime(widget.trip.startTime),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Grade ${widget.trip.score.grade}',
                    style: AppTextStyles.labelMedium.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportRow(
                  label: 'Distance',
                  value: '${widget.trip.distanceKm.toStringAsFixed(1)} km',
                  icon: Icons.route_rounded,
                ),
                _ReportRow(
                  label: 'Duration',
                  value: widget.trip.durationLabel,
                  icon: Icons.timer_outlined,
                ),
                _ReportRow(
                  label: 'Max Speed',
                  value: '${widget.trip.maxSpeedKmh.toInt()} km/h',
                  icon: Icons.speed_rounded,
                ),
                _ReportRow(
                  label: 'Events',
                  value: '${widget.trip.events.length} detected',
                  icon: Icons.warning_amber_rounded,
                  valueColor: widget.trip.events.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
                _ReportRow(
                  label: 'Harsh Braking',
                  value: '${widget.trip.harshBrakingCount}x',
                  icon: Icons.car_crash_rounded,
                  valueColor: widget.trip.harshBrakingCount == 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
                _ReportRow(
                  label: 'Sharp Turns',
                  value: '${widget.trip.sharpTurnCount}x',
                  icon: Icons.turn_right_rounded,
                  valueColor: widget.trip.sharpTurnCount == 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _downloadReport,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 16),
                    label: Text(_isDownloading ? 'Generating…' : 'Download'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _ReportRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
