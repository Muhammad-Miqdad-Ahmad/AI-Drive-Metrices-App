import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import 'dart:typed_data';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await LocalStorageService.getDeviceToken();
      if (token == null) {
        setState(() {
          _trips = [];
          _loading = false;
        });
        return;
      }
      final svc = SupabaseService(deviceToken: token);
      final trips = await svc.getRecentTrips(limit: 100);
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48.r, color: AppColors.danger),
            SizedBox(height: 12.h),
            Text(_error!, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 48.r, color: AppColors.textTertiary),
            SizedBox(height: 12.h),
            Text('No reports yet', style: AppTextStyles.h3),
            SizedBox(height: 8.h),
            Text('Reports will appear after your first trip syncs.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: EdgeInsets.all(20.r),
        itemCount: _trips.length,
        separatorBuilder: (_, __) => SizedBox(height: 14.h),
        itemBuilder: (context, index) => _ReportCard(trip: _trips[index]),
      ),
    );
  }
}

// ---- Report card ----------------------------------------------------------

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
      TripModel trip = widget.trip;
      final token = await LocalStorageService.getDeviceToken();
      if (token != null) {
        final svc = SupabaseService(deviceToken: token);
        final full = await svc.getTripDetail(widget.trip.id);
        if (full != null) trip = full;
      }
      final pdfBytes = await _generateTripReportPdf(trip);
      final fileName =
          'trip_report_${trip.id}_${trip.startTime.millisecondsSinceEpoch}.pdf';
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

  // ---- Colours -------------------------------------------------------------

  static const _brandBlue = PdfColor.fromInt(0xFF0057FF);
  static const _darkNavy = PdfColor.fromInt(0xFF0A2463);
  static const _textDark = PdfColor.fromInt(0xFF0D1B3E);
  static const _textGrey = PdfColor.fromInt(0xFF5A6B8A);
  static const _borderColor = PdfColor.fromInt(0xFFE4E8F0);
  static const _bgLight = PdfColor.fromInt(0xFFF7F9FC);
  static const _green = PdfColor.fromInt(0xFF34C759);
  static const _orange = PdfColor.fromInt(0xFFFF9500);
  static const _red = PdfColor.fromInt(0xFFFF3B30);
  static const _blue = PdfColor.fromInt(0xFF007AFF);
  static const _white = PdfColors.white;

  // ---- Solid semantic background colours (no alpha) -----------------------

  static const _redBg = PdfColor.fromInt(0xFFFFF0EF);
  static const _redBorder = PdfColor.fromInt(0xFFFFCCCA);

  static const _orangeBg = PdfColor.fromInt(0xFFFFF8EE);
  static const _orangeBorder = PdfColor.fromInt(0xFFFFDFA8);

  static const _blueBg = PdfColor.fromInt(0xFFEEF3FF);
  static const _blueBorder = PdfColor.fromInt(0xFFB3CAFF);

  static const _greenBg = PdfColor.fromInt(0xFFEDFBF2);
  static const _greenBorder = PdfColor.fromInt(0xFFAAEBC4);

  static const _insightBg = PdfColor.fromInt(0xFFEEF4FF);
  static const _insightBorder = PdfColor.fromInt(0xFF9AB8FF);

  // ---- Colour helpers ------------------------------------------------------

  PdfColor _scoreColor(double v) => v >= 80
      ? _green
      : v >= 60
          ? _orange
          : _red;

  Color _flutterScoreColor(double v) => v >= 80
      ? const Color(0xFF34C759)
      : v >= 60
          ? const Color(0xFFFF9500)
          : const Color(0xFFFF3B30);

  PdfColor _scoreBg(double v) => v >= 80
      ? _greenBg
      : v >= 60
          ? _orangeBg
          : _redBg;

  PdfColor _scoreBorder(double v) => v >= 80
      ? _greenBorder
      : v >= 60
          ? _orangeBorder
          : _redBorder;

  PdfColor _eventColor(TripEventType t) {
    switch (t) {
      case TripEventType.harshBraking:
        return _red;
      case TripEventType.leftTurn:
      case TripEventType.rightTurn:
        return _orange;
      case TripEventType.hardAccel:
        return _blue;
      default:
        return _green;
    }
  }

  (PdfColor, PdfColor) _eventBgBorder(TripEventType t) {
    switch (t) {
      case TripEventType.harshBraking:
        return (_redBg, _redBorder);
      case TripEventType.leftTurn:
      case TripEventType.rightTurn:
        return (_orangeBg, _orangeBorder);
      case TripEventType.hardAccel:
        return (_blueBg, _blueBorder);
      default:
        return (_greenBg, _greenBorder);
    }
  }

  // ---- Icon helpers --------------------------------------------------------

  pw.Widget _iconChip(
      PdfColor bg, PdfColor border, _IconType icon, PdfColor iconColor) {
    return pw.Container(
      width: 28,
      height: 28,
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Center(
        child: pw.CustomPaint(
          size: const PdfPoint(16, 16),
          painter: (canvas, size) => _drawIcon(canvas, size, icon, iconColor),
        ),
      ),
    );
  }

  static void _drawIcon(
      PdfGraphics g, PdfPoint size, _IconType icon, PdfColor color) {
    g.setFillColor(color);
    g.setStrokeColor(color);
    final cx = size.x / 2;
    final cy = size.y / 2;

    switch (icon) {
      case _IconType.braking:
        g.setLineWidth(1.8);
        g.moveTo(cx, cy + 5);
        g.lineTo(cx, cy);
        g.strokePath();
        g.drawEllipse(cx - 1.2, cy - 4, 2.4, 2.4);
        g.fillPath();
        break;

      case _IconType.cornering:
        g.setLineWidth(1.6);
        g.moveTo(cx - 4, cy + 4);
        g.lineTo(cx - 4, cy - 2);
        g.lineTo(cx + 4, cy - 2);
        g.strokePath();
        g.moveTo(cx + 2, cy - 5);
        g.lineTo(cx + 6, cy - 2);
        g.lineTo(cx + 2, cy + 1);
        g.fillAndStrokePath();
        break;

      case _IconType.acceleration:
        g.setLineWidth(1.6);
        g.moveTo(cx, cy + 5);
        g.lineTo(cx, cy - 3);
        g.strokePath();
        g.moveTo(cx - 3, cy);
        g.lineTo(cx, cy - 4);
        g.lineTo(cx + 3, cy);
        g.fillAndStrokePath();
        break;

      case _IconType.smoothness:
        g.setLineWidth(1.5);
        const steps = 20;
        for (var i = 0; i < steps; i++) {
          final t0 = i / steps;
          final t1 = (i + 1) / steps;
          final x0 = cx - 6 + 12 * t0;
          final y0 = cy + 3 * (i % 2 == 0 ? 1.0 : -1.0);
          final x1 = cx - 6 + 12 * t1;
          final y1 = cy + 3 * (i % 2 == 0 ? -1.0 : 1.0);
          g.moveTo(x0, y0);
          g.lineTo(x1, y1);
          g.strokePath();
        }
        break;

      case _IconType.route:
        g.drawEllipse(cx - 3, cy, 6, 6);
        g.fillPath();
        g.setLineWidth(1.4);
        g.moveTo(cx, cy);
        g.lineTo(cx, cy - 5);
        g.strokePath();
        break;

      case _IconType.timer:
        g.setLineWidth(1.4);
        g.drawEllipse(cx - 5, cy - 5, 10, 10);
        g.strokePath();
        g.moveTo(cx, cy);
        g.lineTo(cx, cy + 3);
        g.moveTo(cx, cy);
        g.lineTo(cx + 3, cy - 1);
        g.strokePath();
        break;

      case _IconType.speedMax:
        g.setLineWidth(1.5);
        g.drawEllipse(cx - 5, cy - 3, 10, 8);
        g.strokePath();
        g.moveTo(cx, cy + 2);
        g.lineTo(cx + 4, cy - 2);
        g.strokePath();
        break;

      case _IconType.speedAvg:
        g.setLineWidth(1.3);
        g.drawEllipse(cx - 5, cy - 3, 10, 8);
        g.strokePath();
        g.moveTo(cx - 3, cy + 1);
        g.lineTo(cx + 3, cy + 1);
        g.strokePath();
        break;

      case _IconType.warning:
        g.setLineWidth(1.5);
        g.moveTo(cx, cy - 5);
        g.lineTo(cx + 6, cy + 4);
        g.lineTo(cx - 6, cy + 4);
        g.closePath();
        g.strokePath();
        g.setLineWidth(1.6);
        g.moveTo(cx, cy - 1);
        g.lineTo(cx, cy + 2);
        g.strokePath();
        g.drawEllipse(cx - 0.8, cy - 3.5, 1.6, 1.6);
        g.fillPath();
        break;

      case _IconType.lightbulb:
        g.setLineWidth(1.4);
        g.drawEllipse(cx - 5, cy - 4, 10, 10);
        g.strokePath();
        g.drawEllipse(cx - 1.5, cy - 1.5, 3, 3);
        g.fillPath();
        break;

      case _IconType.trophy:
        g.setLineWidth(1.5);
        g.moveTo(cx - 4, cy + 5);
        g.lineTo(cx + 4, cy + 5);
        g.strokePath();
        g.moveTo(cx, cy + 5);
        g.lineTo(cx, cy + 1);
        g.strokePath();
        g.moveTo(cx - 3, cy + 1);
        g.lineTo(cx - 4, cy - 4);
        g.lineTo(cx + 4, cy - 4);
        g.lineTo(cx + 3, cy + 1);
        g.closePath();
        g.strokePath();
        break;

      case _IconType.check:
        g.setLineWidth(1.8);
        g.moveTo(cx - 4, cy);
        g.lineTo(cx - 1, cy + 3);
        g.lineTo(cx + 4, cy - 3);
        g.strokePath();
        break;
    }
  }

  // ---- Section heading -----------------------------------------------------

  pw.Widget _sectionHeading(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 16),
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _textDark)),
          pw.SizedBox(height: 3),
          pw.Container(height: 2.5, width: 32, color: _brandBlue),
          pw.SizedBox(height: 8),
        ],
      );

  // ---- Score bar -----------------------------------------------------------

  pw.Widget _scoreBar(String label, double value) {
    final color = _scoreColor(value);
    final bgColor = _scoreBg(value);
    final bdColor = _scoreBorder(value);

    final iconType = label == 'Braking'
        ? _IconType.braking
        : label == 'Cornering'
            ? _IconType.cornering
            : label == 'Acceleration'
                ? _IconType.acceleration
                : _IconType.smoothness;

    final descriptions = {
      'Braking': 'How smoothly you slow down',
      'Cornering': 'Lateral forces during turns',
      'Acceleration': 'Smoothness when speeding up',
      'Smoothness': 'Overall ride consistency',
    };

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        children: [
          _iconChip(bgColor, bdColor, iconType, color),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(label,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _textDark)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: bgColor,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: bdColor),
                      ),
                      child: pw.Text('${value.toInt()} / 100',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: color)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(descriptions[label] ?? '',
                    style: const pw.TextStyle(fontSize: 7.5, color: _textGrey)),
                pw.SizedBox(height: 5),
                pw.LinearProgressIndicator(
                  value: (value / 100).clamp(0.0, 1.0),
                  backgroundColor: _borderColor,
                  valueColor: color,
                  minHeight: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Stat card -----------------------------------------------------------

  pw.Widget _statCard(String label, String value, _IconType iconType,
          PdfColor iconColor, PdfColor iconBg) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: _bgLight,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _borderColor),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _iconChip(iconBg, _borderColor, iconType, iconColor),
              pw.SizedBox(height: 6),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _textDark)),
              pw.SizedBox(height: 3),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
            ],
          ),
        ),
      );

  // ---- Behaviour tile ------------------------------------------------------

  pw.Widget _behaviourTile(String label, int count, PdfColor color,
          PdfColor bgColor, PdfColor borderColor) =>
      pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: pw.BoxDecoration(
            color: bgColor,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(count.toString(),
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              pw.SizedBox(height: 4),
              pw.Text(label,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
            ],
          ),
        ),
      );

  // ---- Insight bubble ------------------------------------------------------

  pw.Widget _insightBubble(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _insightBg,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _insightBorder),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 20,
              height: 20,
              decoration: const pw.BoxDecoration(
                color: _brandBlue,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.CustomPaint(
                  size: const PdfPoint(12, 12),
                  painter: (canvas, size) =>
                      _drawIcon(canvas, size, _IconType.lightbulb, _white),
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Text(text,
                  style: const pw.TextStyle(fontSize: 9, color: _textDark)),
            ),
          ],
        ),
      );

  // ---- Event row -----------------------------------------------------------

  pw.Widget _eventRow(TripEvent event) {
    final color = _eventColor(event.type);
    final (bgColor, bdColor) = _eventBgBorder(event.type);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: bdColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                  width: 9,
                  height: 9,
                  decoration: pw.BoxDecoration(
                      color: color, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 7),
              pw.Text(event.label,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              pw.Spacer(),
              if (event.speedKmh != null)
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: bgColor,
                    borderRadius: pw.BorderRadius.circular(5),
                    border: pw.Border.all(color: bdColor),
                  ),
                  child: pw.Text(
                    '${event.speedKmh!.toInt()} km/h',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: color),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              pw.Text(DateFormatter.time(event.timestamp),
                  style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
              if (event.confidence > 0) ...[
                pw.SizedBox(width: 8),
                pw.Text('·',
                    style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
                pw.SizedBox(width: 8),
                pw.Text('Confidence: ${event.confidence.toInt()}%',
                    style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
              ],
              if (event.latitude != 0) ...[
                pw.Spacer(),
                pw.Text(
                  '${event.latitude.toStringAsFixed(5)}, '
                  '${event.longitude.toStringAsFixed(5)}',
                  style: const pw.TextStyle(fontSize: 8, color: _textGrey),
                ),
              ],
            ],
          ),
          if (event.accelX != null) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                _accelBadge('X', event.accelX!, color, bgColor, bdColor),
                pw.SizedBox(width: 5),
                _accelBadge('Y', event.accelY ?? 0, color, bgColor, bdColor),
                pw.SizedBox(width: 5),
                _accelBadge('Z', event.accelZ ?? 0, color, bgColor, bdColor),
                if (event.gWorst != null && event.gWorst! > 0) ...[
                  pw.SizedBox(width: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: bgColor,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: color),
                    ),
                    child: pw.Text(
                      'Peak: ${event.gWorst!.toStringAsFixed(2)}g'
                      '${event.harshnessLabel != null ? " · ${event.harshnessLabel}" : ""}',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: color,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- Accel badge ---------------------------------------------------------

  pw.Widget _accelBadge(String axis, double val, PdfColor color,
          PdfColor bgColor, PdfColor borderColor) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: borderColor),
        ),
        child: pw.Text('$axis: ${val.toStringAsFixed(2)}g',
            style: pw.TextStyle(
                fontSize: 8, color: color, fontWeight: pw.FontWeight.bold)),
      );

  // ---- Tip row -------------------------------------------------------------

  pw.Widget _tipRow(String title, String body, PdfColor color) {
    final bgColor = color == _red
        ? _redBg
        : color == _orange
            ? _orangeBg
            : color == _blue
                ? _blueBg
                : _greenBg;
    final bdColor = color == _red
        ? _redBorder
        : color == _orange
            ? _orangeBorder
            : color == _blue
                ? _blueBorder
                : _greenBorder;
    final iconType = color == _red
        ? _IconType.braking
        : color == _orange
            ? _IconType.cornering
            : color == _blue
                ? _IconType.acceleration
                : _IconType.trophy;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: bdColor),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _iconChip(bgColor, bdColor, iconType, color),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _textDark)),
                pw.SizedBox(height: 3),
                pw.Text(body,
                    style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Header chip (PDF Layout) --------------------------------------------

  pw.Widget _headerChip(String text, {bool danger = false}) {
    final bg = danger
        ? const PdfColor.fromInt(0xBFFF3B30)
        : const PdfColor.fromInt(0x33000000);
    final brd = danger
        ? const PdfColor.fromInt(0x80FF3B30)
        : const PdfColor.fromInt(0x26FFFFFF);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: brd),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8, color: _white, fontWeight: pw.FontWeight.bold)),
    );
  }

  // ---- Event summary badge -------------------------------------------------

  pw.Widget _eventBadge(String text, PdfColor color, PdfColor bgColor,
          PdfColor borderColor) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: borderColor),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
      );

  // ---- GPS row in route summary -------------------------------------------

  pw.Widget _dot(PdfColor c) => pw.Container(
        width: 7,
        height: 7,
        decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
      );

  pw.Widget _gpsRow(String label, PdfColor dot, LatLngPoint pt) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.Container(
                width: 8,
                height: 8,
                decoration:
                    pw.BoxDecoration(color: dot, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 8),
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
            pw.Spacer(),
            pw.Text(
              '${pt.latitude.toStringAsFixed(5)}, '
              '${pt.longitude.toStringAsFixed(5)}'
              '${pt.speedKmh != null ? '  ${pt.speedKmh!.toInt()} km/h' : ''}',
              style: const pw.TextStyle(fontSize: 9, color: _textDark),
            ),
          ],
        ),
      );

  // ---- Speed chart ---------------------------------------------------------

  pw.Widget _speedChart(List<LatLngPoint> route) {
    final pts =
        route.where((p) => p.speedKmh != null && p.speedKmh! > 0).toList();
    if (pts.isEmpty) return pw.SizedBox(height: 0);
    final maxSpeed =
        pts.map((p) => p.speedKmh!).reduce((a, b) => a > b ? a : b);
    if (maxSpeed == 0) return pw.SizedBox(height: 0);

    final step = ((pts.length / 80).ceil()).clamp(1, pts.length);
    final sampled = <LatLngPoint>[];
    for (var i = 0; i < pts.length; i += step) {
      sampled.add(pts[i]);
    }

    const chartH = 55.0;
    const barW = 3.5;
    const barGap = 0.8;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bgLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Speed Profile',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _textDark)),
              pw.Text('Max ${maxSpeed.toInt()} km/h',
                  style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.SizedBox(
            height: chartH,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: sampled.map((p) {
                final ratio = (p.speedKmh! / maxSpeed).clamp(0.0, 1.0);
                final h = (ratio * chartH).clamp(2.0, chartH);
                final color = ratio > 0.85
                    ? _red
                    : ratio > 0.6
                        ? _orange
                        : _brandBlue;
                return pw.Container(
                  width: barW,
                  height: h,
                  margin: const pw.EdgeInsets.only(right: barGap),
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(1),
                      topRight: pw.Radius.circular(1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _dot(_brandBlue),
              pw.SizedBox(width: 4),
              pw.Text('Normal',
                  style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
              pw.SizedBox(width: 10),
              _dot(_orange),
              pw.SizedBox(width: 4),
              pw.Text('Moderate',
                  style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
              pw.SizedBox(width: 10),
              _dot(_red),
              pw.SizedBox(width: 4),
              pw.Text('High',
                  style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Logic helpers -------------------------------------------------------

  String _insight(TripModel t) {
    if (t.score.overall >= 90) {
      return 'Excellent drive! Your smooth and controlled style is very fuel-efficient and reduces vehicle wear.';
    }
    if (t.harshBrakingCount > 2) {
      return 'You braked harshly ${t.harshBrakingCount} times. Try to anticipate stops earlier for a smoother ride.';
    }
    if (t.sharpTurnCount > 3) {
      return 'You took ${t.sharpTurnCount} sharp turns. Slowing down before corners improves safety and tyre life.';
    }
    if (t.score.overall >= 70) {
      return 'Good trip overall! Minor improvements in braking smoothness could push your score higher.';
    }
    return 'Focus on smoother braking and steady acceleration. Consistency over time greatly improves your score.';
  }

  List<_PdfTip> _tips(TripModel t) {
    final list = <_PdfTip>[];
    if (t.score.braking < 70) {
      list.add(const _PdfTip(
          color: _red,
          title: 'Improve Braking',
          body:
              'Anticipate stops 3-4 seconds earlier. Gradual pressure reduces brake wear and improves your score.'));
    }
    if (t.score.cornering < 70) {
      list.add(const _PdfTip(
          color: _orange,
          title: 'Smoother Cornering',
          body:
              'Reduce speed before corners, not during. Enter slow, exit fast for better control.'));
    }
    if (t.score.acceleration < 70) {
      list.add(const _PdfTip(
          color: _blue,
          title: 'Steady Acceleration',
          body:
              'Avoid flooring the pedal. Gradual acceleration is more fuel-efficient and comfortable.'));
    }
    if (t.score.smoothness < 70) {
      list.add(const _PdfTip(
          color: _brandBlue,
          title: 'Improve Smoothness',
          body:
              'Avoid sudden steering and pedal inputs. Smooth transitions protect passengers and the vehicle.'));
    }
    if (t.score.overall >= 85) {
      list.add(_PdfTip(
          color: _green,
          title: 'Great Drive!',
          body:
              'You scored ${t.score.overall.toInt()}/100. Keep this consistency to maintain a top-tier rating.'));
    }
    return list;
  }

  // ---- Main PDF builder ----------------------------------------------------

  Future<Uint8List> _generateTripReportPdf(TripModel trip) async {
    final pdf = pw.Document();
    final score = trip.score.overall;
    final scoreColor = _scoreColor(score);
    final harsh = trip.events.where((e) => e.type.isHarsh).toList();
    final allEvents = trip.events;
    final tips = _tips(trip);
    final hasSpeed =
        trip.route.any((p) => p.speedKmh != null && p.speedKmh! > 0);
    final hasRoute = trip.route.length >= 2;

    final timeRange = trip.endTime != null
        ? '${DateFormatter.time(trip.startTime)} - ${DateFormatter.time(trip.endTime!)}'
        : DateFormatter.time(trip.startTime);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 50),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Drive Metrics AI',
                style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _textGrey)),
          ],
        ),
        build: (ctx) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [_darkNavy, _brandBlue],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 78,
                  height: 78,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0x4D0B1B3E),
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: scoreColor, width: 3.5),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(score.toInt().toString(),
                            style: pw.TextStyle(
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold,
                                color: _white)),
                        pw.Text(trip.score.grade,
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: scoreColor)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DRIVE METRICS AI - Trip Safety Report',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: _white)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          '${DateFormatter.tripDate(trip.startTime)}  $timeRange',
                          style:
                              const pw.TextStyle(fontSize: 10, color: _white)),
                      pw.SizedBox(height: 8),
                      pw.Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _headerChip(
                              '${trip.distanceKm.toStringAsFixed(1)} km'),
                          _headerChip(trip.durationLabel),
                          _headerChip('Max ${trip.maxSpeedKmh.toInt()} km/h'),
                          _headerChip('Avg ${trip.avgSpeedKmh.toInt()} km/h'),
                          if (trip.harshEventCount > 0)
                            _headerChip('${trip.harshEventCount} harsh events',
                                danger: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _sectionHeading('Trip Statistics'),
          pw.Row(
            children: [
              _statCard('Distance', '${trip.distanceKm.toStringAsFixed(1)} km',
                  _IconType.route, _brandBlue, _blueBg),
              pw.SizedBox(width: 8),
              _statCard('Duration', trip.durationLabel, _IconType.timer,
                  _orange, _orangeBg),
              pw.SizedBox(width: 8),
              _statCard('Max Speed', '${trip.maxSpeedKmh.toInt()} km/h',
                  _IconType.speedMax, _red, _redBg),
              pw.SizedBox(width: 8),
              _statCard('Avg Speed', '${trip.avgSpeedKmh.toInt()} km/h',
                  _IconType.speedAvg, _brandBlue, _blueBg),
            ],
          ),

          _sectionHeading('Score Breakdown'),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _borderColor),
            ),
            child: pw.Column(
              children: [
                _scoreBar('Braking', trip.score.braking),
                _scoreBar('Cornering', trip.score.cornering),
                _scoreBar('Acceleration', trip.score.acceleration),
                _scoreBar('Smoothness', trip.score.smoothness),
              ],
            ),
          ),

          _sectionHeading('Driving Behaviour'),
          pw.Row(
            children: [
              _behaviourTile('Harsh\nBraking', trip.harshBrakingCount, _red,
                  _redBg, _redBorder),
              _behaviourTile('Sharp\nTurns', trip.sharpTurnCount, _orange,
                  _orangeBg, _orangeBorder),
              _behaviourTile('Hard\nAccel', trip.hardAccelCount, _blue, _blueBg,
                  _blueBorder),
              _behaviourTile(
                  'Normal\nDriving',
                  allEvents
                      .where((e) => e.type == TripEventType.normalDriving)
                      .length,
                  _green,
                  _greenBg,
                  _greenBorder),
            ],
          ),
          pw.SizedBox(height: 10),
          _insightBubble(_insight(trip)),

          if (hasSpeed) ...[
            _sectionHeading('Speed Profile'),
            _speedChart(trip.route),
          ],

          if (harsh.isNotEmpty) ...[
            _sectionHeading('Harsh Events (${harsh.length})'),
            pw.Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (trip.harshBrakingCount > 0)
                  _eventBadge('${trip.harshBrakingCount}x Harsh Braking', _red,
                      _redBg, _redBorder),
                if (trip.sharpTurnCount > 0)
                  _eventBadge('${trip.sharpTurnCount}x Sharp Turns', _orange,
                      _orangeBg, _orangeBorder),
                if (trip.hardAccelCount > 0)
                  _eventBadge('${trip.hardAccelCount}x Hard Accel', _blue,
                      _blueBg, _blueBorder),
              ],
            ),
            pw.SizedBox(height: 8),
            ...harsh.map(_eventRow),
          ],

          if (hasRoute) ...[
            _sectionHeading('Route Summary'),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _bgLight,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _borderColor),
              ),
              child: pw.Column(
                children: [
                  _gpsRow('Start', _green, trip.route.first),
                  pw.Divider(color: _borderColor, height: 8),
                  _gpsRow('End', _red, trip.route.last),
                  pw.Divider(color: _borderColor, height: 8),
                  pw.Row(
                    children: [
                      pw.Text('GPS Points recorded',
                          style: const pw.TextStyle(
                              fontSize: 9, color: _textGrey)),
                      pw.Spacer(),
                      pw.Text('${trip.route.length}',
                          style: const pw.TextStyle(
                              fontSize: 9, color: _textDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (tips.isNotEmpty) ...[
            _sectionHeading('Recommendations'),
            ...tips.map((t) => _tipRow(t.title, t.body, t.color)),
          ],

          pw.SizedBox(height: 16),
        ],
      ),
    );

    return pdf.save();
  }

  // ---- Attractive Flutter Screen Card UI Configuration ----------------------

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final score = trip.score.overall;
    final scoreColor = _flutterScoreColor(score);
    final totalHarshEvents =
        trip.harshBrakingCount + trip.sharpTurnCount + trip.hardAccelCount;

    final timeRange = trip.endTime != null
        ? '${DateFormatter.time(trip.startTime)} - ${DateFormatter.time(trip.endTime!)}'
        : DateFormatter.time(trip.startTime);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B6C), Color(0xFF0049D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2463).withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Core Header Row Layout
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 82.r,
                  height: 82.r,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 3.5),
                    boxShadow: [
                      BoxShadow(color: scoreColor.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.toInt().toString(),
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          trip.score.grade,
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: scoreColor, height: 1.1),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14.r, color: Colors.amber[300]),
                          SizedBox(width: 4.w),
                          Text(
                            'DRIVE METRICS AI',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF90B4FF),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Trip Safety Report',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12.r, color: Colors.white60),
                          SizedBox(width: 5.w),
                          Text(
                            DateFormatter.tripDate(trip.startTime),
                            style: TextStyle(fontSize: 11.sp, color: Colors.white60, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(width: 10.w),
                          Icon(Icons.schedule_rounded, size: 12.r, color: Colors.white60),
                          SizedBox(width: 5.w),
                          Text(
                            timeRange,
                            style: TextStyle(fontSize: 11.sp, color: Colors.white60, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Metrics Dashboard Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricStat('Distance', '${trip.distanceKm.toStringAsFixed(1)} km', Icons.space_dashboard_rounded, const Color(0xFF4FA0FF)),
                  _buildDivider(),
                  _buildMetricStat('Duration', trip.durationLabel, Icons.timelapse_rounded, const Color(0xFFFFB236)),
                  _buildDivider(),
                  _buildMetricStat('Max Speed', '${trip.maxSpeedKmh.toInt()} km/h', Icons.speed_rounded, const Color(0xFFFF5252)),
                ],
              ),
            ),
          ),

          // 3. Info Pill Section
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 18.h),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildHeaderChip('Avg Speed: ${trip.avgSpeedKmh.toInt()} km/h', icon: Icons.analytics_outlined),
                if (trip.harshBrakingCount > 0)
                  _buildHeaderChip('${trip.harshBrakingCount} Braking Events', icon: Icons.front_hand_rounded, isDanger: true),
                if (trip.sharpTurnCount > 0)
                  _buildHeaderChip('${trip.sharpTurnCount} Sharp Turns', icon: Icons.turn_sharp_right_rounded, isWarning: true),
                if (trip.hardAccelCount > 0)
                  _buildHeaderChip('${trip.hardAccelCount} Hard Accels', icon: Icons.bolt_rounded, isInfo: true),
                if (totalHarshEvents > 0)
                  _buildHeaderChip('$totalHarshEvents Harsh Events Total', icon: Icons.warning_amber_rounded, isDanger: true),
                if (totalHarshEvents == 0 && trip.score.overall >= 85)
                  _buildHeaderChip('Perfect Smooth Drive', icon: Icons.verified_user_rounded, isSuccess: true)
                else if (totalHarshEvents == 0 && trip.score.overall < 85)
                  _buildHeaderChip('Harsh Events Detected', icon: Icons.check_circle_outline_rounded, isInfo: true),
              ],
            ),
          ),

          // 4. Download Footer Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: InkWell(
              onTap: _isDownloading ? null : _downloadReport,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isDownloading)
                      SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Icon(Icons.picture_as_pdf_rounded, size: 18.r, color: const Color(0xFF79A7FF)),
                    SizedBox(width: 8.w),
                    Text(
                      _isDownloading ? 'Generating Document...' : 'Download Full PDF Report',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18.r, color: color),
        SizedBox(height: 5.h),
        Text(
          value,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 9.sp, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 28.h,
      width: 1.w,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildHeaderChip(String text,
      {required IconData icon,
      bool isDanger = false,
      bool isWarning = false,
      bool isInfo = false,
      bool isSuccess = false}) {
    Color chipBg = Colors.black.withValues(alpha: 0.2);
    Color contentColor = Colors.white.withValues(alpha: 0.9);

    if (isDanger) {
      chipBg = const Color(0xFFBA1A1A).withValues(alpha: 0.5);
      contentColor = const Color(0xFFFFDAD6);
    } else if (isWarning) {
      chipBg = const Color(0xFF8B6200).withValues(alpha: 0.5);
      contentColor = const Color(0xFFFFE082);
    } else if (isInfo) {
      chipBg = const Color(0xFF0043CE).withValues(alpha: 0.4);
      contentColor = const Color(0xFFD0E1FF);
    } else if (isSuccess) {
      chipBg = const Color(0xFF006D35).withValues(alpha: 0.4);
      contentColor = const Color(0xFFB4F4C1);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: contentColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.r, color: contentColor),
          SizedBox(width: 5.w),
          Text(
            text,
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: contentColor),
          ),
        ],
      ),
    );
  }
}

// ---- Data classes ----------------------------------------------------------

class _PdfTip {
  final PdfColor color;
  final String title;
  final String body;
  const _PdfTip({required this.color, required this.title, required this.body});
}

enum _IconType {
  braking,
  cornering,
  acceleration,
  smoothness,
  route,
  timer,
  speedMax,
  speedAvg,
  warning,
  lightbulb,
  trophy,
  check,
}