import 'package:flutter/material.dart';

import '../models/analysis.dart';

class SpectrumChart extends StatelessWidget {
  const SpectrumChart({
    super.key,
    required this.analysis,
    required this.minHz,
    required this.maxHz,
    required this.threshold,
    this.floorDb = -100,
    this.height = 210,
  });

  final Analysis? analysis;
  final int minHz;
  final int maxHz;
  final double threshold;
  final double floorDb;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SpectrumPainter(
          analysis: analysis,
          minHz: minHz.toDouble(),
          maxHz: maxHz.toDouble(),
          threshold: threshold,
          floorDb: floorDb,
          spectrum: theme.colorScheme.primary,
          band: theme.colorScheme.secondary.withValues(alpha: 0.14),
          thresholdColor: theme.colorScheme.error,
          axis: theme.hintColor,
          text: theme.textTheme.bodySmall?.color ?? theme.hintColor,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.analysis,
    required this.minHz,
    required this.maxHz,
    required this.threshold,
    required this.floorDb,
    required this.spectrum,
    required this.band,
    required this.thresholdColor,
    required this.axis,
    required this.text,
  });

  final Analysis? analysis;
  final double minHz;
  final double maxHz;
  final double threshold;
  final double floorDb;
  final Color spectrum;
  final Color band;
  final Color thresholdColor;
  final Color axis;
  final Color text;

  static const double _leftPad = 34;
  static const double _bottomPad = 18;
  static const double _topPad = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final a = analysis;
    final plotLeft = _leftPad;
    final plotRight = size.width;
    final plotTop = _topPad;
    final plotBottom = size.height - _bottomPad;
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;
    if (plotW <= 0 || plotH <= 0) return;

    final nyquist = a?.nyquist ?? 22050;

    double xForHz(double hz) => plotLeft + (hz / nyquist).clamp(0, 1) * plotW;
    double yForDb(double db) =>
        plotTop + (1 - ((db - floorDb) / (0 - floorDb)).clamp(0, 1)) * plotH;

    final gridPaint = Paint()
      ..color = axis.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (double db = 0; db >= floorDb; db -= 20) {
      final y = yForDb(db);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _label(canvas, '${db.toInt()}', Offset(2, y - 6), text, 10);
    }
    for (double hz = 5000; hz < nyquist; hz += 5000) {
      final x = xForHz(hz);
      canvas.drawLine(Offset(x, plotTop), Offset(x, plotBottom), gridPaint);
      _label(
        canvas,
        '${(hz / 1000).toInt()}k',
        Offset(x - 6, plotBottom + 3),
        text,
        10,
      );
    }

    canvas.drawRect(
      Rect.fromLTRB(xForHz(minHz), plotTop, xForHz(maxHz), plotBottom),
      Paint()..color = band,
    );

    if (a != null && a.bars.isNotEmpty) {
      final path = Path();
      final fill = Path();
      final n = a.bars.length;
      for (var i = 0; i < n; i++) {
        final hz = (i + 0.5) * nyquist / n;
        final x = xForHz(hz);
        final y = yForDb(a.bars[i]);
        if (i == 0) {
          path.moveTo(x, y);
          fill.moveTo(x, plotBottom);
          fill.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fill.lineTo(x, y);
        }
      }
      fill.lineTo(xForHz((n - 0.5) * nyquist / n), plotBottom);
      fill.close();
      canvas.drawPath(fill, Paint()..color = spectrum.withValues(alpha: 0.18));
      canvas.drawPath(
        path,
        Paint()
          ..color = spectrum
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );

      final peakX = xForHz(a.bandPeakHz);
      final peakY = yForDb(a.bandPeakDb);
      canvas.drawCircle(
        Offset(peakX, peakY),
        4,
        Paint()..color = thresholdColor,
      );
      _label(
        canvas,
        '${(a.bandPeakHz / 1000).toStringAsFixed(1)}k · ${a.bandPeakDb.toStringAsFixed(0)}dB',
        Offset(
          (peakX - 30).clamp(plotLeft, plotRight - 90),
          (peakY - 16).clamp(plotTop, plotBottom),
        ),
        text,
        11,
      );
    }

    final ty = yForDb(threshold);
    final dash = Paint()
      ..color = thresholdColor
      ..strokeWidth = 1.5;
    for (double x = plotLeft; x < plotRight; x += 10) {
      canvas.drawLine(
        Offset(x, ty),
        Offset((x + 5).clamp(plotLeft, plotRight), ty),
        dash,
      );
    }
  }

  void _label(Canvas canvas, String s, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.analysis != analysis ||
      old.minHz != minHz ||
      old.maxHz != maxHz ||
      old.threshold != threshold;
}
