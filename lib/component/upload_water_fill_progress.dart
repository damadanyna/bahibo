import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated "liquid" upload progress shared by chat attachments and
/// stories. [WaterFillVisualState.uploading] is the lively default,
/// [WaterFillVisualState.waiting] the calmer "reprise automatique" look,
/// [WaterFillVisualState.failed] the still red one.
enum WaterFillVisualState { uploading, waiting, failed }

class WaterFillProgressLayer extends StatefulWidget {
  final double progress;
  final Color primary;
  final WaterFillVisualState visualState;

  const WaterFillProgressLayer({
    super.key,
    required this.progress,
    required this.primary,
    required this.visualState,
  });

  @override
  State<WaterFillProgressLayer> createState() => _WaterFillProgressLayerState();
}

class _WaterFillProgressLayerState extends State<WaterFillProgressLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _flowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _flowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flowAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaterFillPainter(
            progress: widget.progress.clamp(0, 1),
            phase: _controller.value,
            easedPhase: _flowAnimation.value,
            primary: widget.primary,
            visualState: widget.visualState,
          ),
        );
      },
    );
  }
}

class _WaterFillPainter extends CustomPainter {
  final double progress;
  final double phase;
  final double easedPhase;
  final Color primary;
  final WaterFillVisualState visualState;

  const _WaterFillPainter({
    required this.progress,
    required this.phase,
    required this.easedPhase,
    required this.primary,
    required this.visualState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final fillTop = size.height * (1 - clampedProgress);
    final liquidRect = Rect.fromLTWH(0, fillTop, size.width, size.height);
    final isUploading = visualState == WaterFillVisualState.uploading;
    final isWaiting = visualState == WaterFillVisualState.waiting;
    final topAlpha = isUploading ? 0.52 : (isWaiting ? 0.3 : 0.38);
    final midAlpha = isUploading ? 0.86 : (isWaiting ? 0.56 : 0.7);
    final bottomAlpha = isUploading ? 1.0 : (isWaiting ? 0.8 : 0.94);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withValues(alpha: topAlpha),
          primary.withValues(alpha: midAlpha),
          primary.withValues(alpha: bottomAlpha),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(liquidRect, bodyPaint);

    final depthShadeRect = Rect.fromLTWH(
      0,
      fillTop + (size.height * 0.08),
      size.width,
      size.height * 0.92,
    );
    canvas.drawRect(
      depthShadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(depthShadeRect),
    );

    final pulseOffset =
        math.sin(easedPhase * 2 * math.pi) *
        (size.height * (isUploading ? 0.018 : 0.012));
    final frontWaveBase = fillTop + pulseOffset;
    final backWaveBase = fillTop - (size.height * 0.018) + (pulseOffset * 0.65);
    final primaryWaveAmplitude = math.max(
      2.0,
      size.height * (isUploading ? 0.072 : 0.055),
    );
    final secondaryWaveAmplitude = math.max(
      1.5,
      size.height * (isUploading ? 0.04 : 0.03),
    );
    final primaryFrequency =
        (2 * math.pi * (isUploading ? 1.36 : 1.15)) / math.max(1, size.width);
    final secondaryFrequency =
        (2 * math.pi * (isUploading ? 2.18 : 1.9)) / math.max(1, size.width);
    final primaryShift = phase * (isUploading ? 2.7 : 2.0) * math.pi;
    final secondaryShift = -(phase * (isUploading ? 3.75 : 2.8) * math.pi);

    final backWavePath = Path()..moveTo(0, backWaveBase);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          backWaveBase +
          math.sin((x * primaryFrequency) + primaryShift) *
              primaryWaveAmplitude;
      backWavePath.lineTo(x, y);
    }
    backWavePath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final backWavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isUploading ? 0.1 : 0.05),
          primary.withValues(alpha: isUploading ? 0.24 : 0.16),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(backWavePath, backWavePaint);

    final frontWavePath = Path()..moveTo(0, frontWaveBase);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          frontWaveBase +
          math.sin((x * secondaryFrequency) + secondaryShift) *
              secondaryWaveAmplitude;
      frontWavePath.lineTo(x, y);
    }
    frontWavePath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final frontWavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isUploading ? 0.24 : 0.16),
          Colors.white.withValues(alpha: isUploading ? 0.06 : 0.03),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(frontWavePath, frontWavePaint);

    final shimmerWidth = size.width * (isUploading ? 0.34 : 0.28);
    final shimmerLeft =
        ((phase * (isUploading ? 1.95 : 1.2)) % 1.0) *
            (size.width + shimmerWidth) -
        shimmerWidth;
    final shimmerRect = Rect.fromLTWH(
      shimmerLeft,
      fillTop,
      shimmerWidth,
      size.height - fillTop,
    );
    canvas.save();
    canvas.clipRect(liquidRect);
    canvas.drawRect(
      shimmerRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: isUploading ? 0.12 : 0.07),
            Colors.white.withValues(alpha: isUploading ? 0.24 : 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.28, 0.58, 1.0],
        ).createShader(shimmerRect),
    );
    canvas.restore();

    final surfaceHighlight = Path()..moveTo(0, frontWaveBase);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          frontWaveBase +
          math.sin((x * secondaryFrequency) + secondaryShift) *
              secondaryWaveAmplitude;
      surfaceHighlight.lineTo(x, y);
    }

    canvas.drawPath(
      surfaceHighlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isUploading ? 1.55 : 1.25
        ..color = Colors.white.withValues(alpha: isUploading ? 0.38 : 0.26),
    );

    final foamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isUploading ? 2.5 : 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: isUploading ? 0.28 : 0.18);
    for (int index = 0; index < (isUploading ? 7 : 5); index++) {
      final x =
          ((index * 0.17) + (phase * (isUploading ? 0.62 : 0.35))) %
          1.0 *
          size.width;
      final arcWidth = size.width * (0.05 + (index * 0.006));
      final arcRect = Rect.fromCenter(
        center: Offset(x, frontWaveBase + (index.isEven ? -1.5 : 1.5)),
        width: arcWidth,
        height: size.height * 0.024,
      );
      canvas.drawArc(arcRect, math.pi * 1.04, math.pi * 0.88, false, foamPaint);
    }

    final bubblePaint = Paint()..style = PaintingStyle.fill;
    final bubbleData =
        <(double xFactor, double yFactor, double radiusFactor, double speed)>{
          (0.18, 0.22, 0.02, 0.85),
          (0.34, 0.58, 0.016, 1.1),
          (0.56, 0.36, 0.024, 0.74),
          (0.73, 0.68, 0.015, 1.25),
          (0.86, 0.44, 0.018, 0.93),
          if (isUploading) (0.1, 0.51, 0.013, 1.44),
          if (isUploading) (0.63, 0.18, 0.014, 1.62),
        };
    canvas.save();
    canvas.clipRect(liquidRect);
    for (final bubble in bubbleData) {
      final travel = ((phase * bubble.$4) + bubble.$2) % 1.0;
      final bubbleY = size.height - (travel * (size.height - fillTop));
      if (bubbleY < fillTop + 6) {
        continue;
      }
      final horizontalDrift =
          math.sin((phase * 2 * math.pi) + (bubble.$1 * 9)) *
          (size.width * 0.012);
      final center = Offset(
        (bubble.$1 * size.width) + horizontalDrift,
        bubbleY,
      );
      final radius = math.max(1.6, size.width * bubble.$3);
      bubblePaint.color = Colors.white.withValues(
        alpha: isUploading ? 0.2 : 0.14,
      );
      canvas.drawCircle(center, radius, bubblePaint);
      canvas.drawCircle(
        center.translate(-radius * 0.25, -radius * 0.25),
        radius * 0.38,
        Paint()
          ..color = Colors.white.withValues(alpha: isUploading ? 0.28 : 0.2),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: isUploading ? 0.32 : 0.22),
      );
    }
    canvas.restore();

    final glowRect = Rect.fromLTWH(
      0,
      fillTop - (size.height * 0.08),
      size.width,
      size.height * 0.22,
    );
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isUploading ? 0.2 : 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(glowRect),
    );

    if (isUploading) {
      final sparkPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.24);
      for (int index = 0; index < 4; index++) {
        final x = ((phase * (0.92 + (index * 0.21))) + (index * 0.24)) % 1.0;
        final y = fillTop + (size.height - fillTop) * (0.12 + (index * 0.11));
        canvas.drawCircle(
          Offset(x * size.width, y),
          1.2 + (index * 0.18),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaterFillPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.easedPhase != easedPhase ||
        oldDelegate.primary != primary ||
        oldDelegate.visualState != visualState;
  }
}
