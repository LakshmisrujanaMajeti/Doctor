import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum MedicalBackgroundVariant {
  auth,
  clinical,
  dashboard,
  portal,
  empty,
  minimal,
}

/// A premium, resolution-independent vector background that renders subtle
/// medical illustrations, ECG heartbeat pulse waves, hospital watermarks,
/// and luminous ambient mesh glows.
class MedicalIllustratorBackground extends StatelessWidget {
  final Widget child;
  final MedicalBackgroundVariant variant;
  final bool showGrid;
  final bool showEcg;

  const MedicalIllustratorBackground({
    super.key,
    required this.child,
    this.variant = MedicalBackgroundVariant.dashboard,
    this.showGrid = true,
    this.showEcg = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 1. Base Ambient Canvas
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _MedicalCanvasPainter(
                variant: variant,
                isDark: isDark,
                showGrid: showGrid,
                showEcg: showEcg,
              ),
            ),
          ),
        ),

        // 2. Foreground Content
        child,
      ],
    );
  }
}

class _MedicalCanvasPainter extends CustomPainter {
  final MedicalBackgroundVariant variant;
  final bool isDark;
  final bool showGrid;
  final bool showEcg;

  _MedicalCanvasPainter({
    required this.variant,
    required this.isDark,
    required this.showGrid,
    required this.showEcg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Soft Ambient Luminous Radial Orbs
    _paintAmbientGradients(canvas, size);

    // 2. Subtle Medical Geometric Hex / Grid Lines
    if (showGrid) {
      _paintMedicalGrid(canvas, size);
    }

    // 3. Heartbeat ECG Rhythm Line (Cardiogram Wave)
    if (showEcg) {
      _paintHeartbeatWave(canvas, size);
    }

    // 4. Subtle Medical Cross / Shield Watermark
    _paintMedicalWatermark(canvas, size);
  }

  void _paintAmbientGradients(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, -0.7),
        radius: 0.9,
        colors: [
          AppColors.primaryBlue.withValues(alpha: isDark ? 0.12 : 0.07),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, 0.65),
        radius: 0.85,
        colors: [
          AppColors.accentTeal.withValues(alpha: isDark ? 0.08 : 0.05),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint2);

    if (variant == MedicalBackgroundVariant.auth || variant == MedicalBackgroundVariant.portal) {
      final centerPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.1),
          radius: 0.6,
          colors: [
            AppColors.primaryBlue.withValues(alpha: isDark ? 0.07 : 0.04),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, centerPaint);
    }
  }

  void _paintMedicalGrid(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : AppColors.primaryBlue).withValues(alpha: isDark ? 0.025 : 0.02)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  void _paintHeartbeatWave(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = AppColors.accentTeal.withValues(alpha: isDark ? 0.08 : 0.05)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final y = size.height * (variant == MedicalBackgroundVariant.auth ? 0.28 : 0.82);
    final path = Path();
    path.moveTo(0, y);

    final segWidth = size.width / 4;
    for (int i = 0; i < 4; i++) {
      final startX = i * segWidth;
      path.lineTo(startX + segWidth * 0.35, y);
      path.lineTo(startX + segWidth * 0.40, y - 6);
      path.lineTo(startX + segWidth * 0.45, y + 8);
      path.lineTo(startX + segWidth * 0.50, y - 28); // QRS peak
      path.lineTo(startX + segWidth * 0.55, y + 18);
      path.lineTo(startX + segWidth * 0.60, y - 4);
      path.lineTo(startX + segWidth * 0.65, y);
      path.lineTo(startX + segWidth, y);
    }

    canvas.drawPath(path, wavePaint);
  }

  void _paintMedicalWatermark(Canvas canvas, Size size) {
    final watermarkPaint = Paint()
      ..color = (isDark ? Colors.white : AppColors.primaryBlue).withValues(alpha: isDark ? 0.015 : 0.018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = (isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueLight).withValues(alpha: isDark ? 0.02 : 0.025)
      ..style = PaintingStyle.fill;

    // Draw stylized medical cross on bottom-right corner
    final cx = size.width * 0.85;
    final cy = size.height * 0.88;
    const s = 44.0;
    const t = 14.0;

    final crossPath = Path();
    crossPath.moveTo(cx - t, cy - s);
    crossPath.lineTo(cx + t, cy - s);
    crossPath.lineTo(cx + t, cy - t);
    crossPath.lineTo(cx + s, cy - t);
    crossPath.lineTo(cx + s, cy + t);
    crossPath.lineTo(cx + t, cy + t);
    crossPath.lineTo(cx + t, cy + s);
    crossPath.lineTo(cx - t, cy + s);
    crossPath.lineTo(cx - t, cy + t);
    crossPath.lineTo(cx - s, cy + t);
    crossPath.lineTo(cx - s, cy - t);
    crossPath.lineTo(cx - t, cy - t);
    crossPath.close();

    canvas.drawPath(crossPath, fillPaint);
    canvas.drawPath(crossPath, watermarkPaint);

    // Subtle decorative concentric health circle rings
    final ringPaint = Paint()
      ..color = AppColors.accentTeal.withValues(alpha: isDark ? 0.03 : 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(cx, cy), s * 1.5, ringPaint);
    canvas.drawCircle(Offset(cx, cy), s * 2.2, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _MedicalCanvasPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.variant != variant ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showEcg != showEcg;
  }
}
