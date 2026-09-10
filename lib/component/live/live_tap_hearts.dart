import 'dart:math' as math;

import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Drives a [LiveTapHeartsLayer] from the page: a heart blooms under the
/// finger on a tap, and likes arriving from the room rise from the corner
/// where the like button lives, TikTok-style.
class LiveTapHeartsController {
  _LiveTapHeartsLayerState? _state;

  /// Heart bloom at [position], in the layer's local coordinates.
  void burstAt(Offset position) => _state?._spawnBurst(position);

  /// One rising heart per like, capped so a wave stays a cascade rather
  /// than a wall.
  void celebrate(int count) => _state?._spawnFromCorner(count);
}

/// Full-bleed layer to place above the video (and its scrim) and below the
/// controls. Draws every heart in one [CustomPaint] driven by a single
/// ticker, so dozens of simultaneous hearts cost one repaint per frame.
class LiveTapHeartsLayer extends StatefulWidget {
  const LiveTapHeartsLayer({super.key, required this.controller, this.onTap});

  final LiveTapHeartsController controller;

  /// Receives every tap on the video (local position). Null makes the layer
  /// transparent to touches, for the host who only watches hearts arrive.
  final ValueChanged<Offset>? onTap;

  @override
  State<LiveTapHeartsLayer> createState() => _LiveTapHeartsLayerState();
}

class _LiveTapHeartsLayerState extends State<LiveTapHeartsLayer>
    with SingleTickerProviderStateMixin {
  static const int _maxHearts = 80;
  static const int _maxCornerWave = 6;
  static const Duration _cornerStagger = Duration(milliseconds: 110);

  final List<_Heart> _hearts = <_Heart>[];
  final math.Random _random = math.Random();
  // Monotonic clock shared by spawn and paint; the ticker only schedules
  // frames, so stopping it while idle costs nothing and drifts nothing.
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_onTick);
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(LiveTapHeartsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final now = _clock.elapsed;
    _hearts.removeWhere((heart) => now - heart.bornAt > heart.lifetime);
    if (_hearts.isEmpty) {
      _ticker.stop();
    }
    setState(() {});
  }

  List<Color> _palette() {
    final theme = Theme.of(context);
    return <Color>[
      theme.appColors.liveIndicator,
      theme.colorScheme.primary,
      const Color(0xFFFF4D8D),
      const Color(0xFFFF7A45),
      const Color(0xFFB36BFF),
      const Color(0xFFFFC53D),
    ];
  }

  double _between(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  _Heart _makeHeart({
    required Offset origin,
    required Duration bornAt,
    required Color color,
    required double size,
    required bool withRing,
  }) {
    return _Heart(
      origin: origin,
      bornAt: bornAt,
      lifetime: Duration(milliseconds: _between(1300, 1800).round()),
      color: color,
      size: size,
      rise: _between(180, 300),
      drift: _between(-30, 30),
      swayAmplitude: _between(10, 26),
      swayTurns: _between(1, 2),
      swayPhase: _between(0, math.pi * 2),
      tilt: _between(-0.28, 0.28),
      withRing: withRing,
    );
  }

  void _spawnBurst(Offset position) {
    if (!mounted) {
      return;
    }
    final palette = _palette();
    final now = _clock.elapsed;
    final color = palette[_random.nextInt(palette.length)];

    _add(
      _makeHeart(
        origin: position,
        bornAt: now,
        color: color,
        size: _between(34, 52),
        withRing: true,
      ),
    );
    // Two small satellites make the bloom read as a burst, not a sticker.
    for (var i = 0; i < 2; i++) {
      _add(
        _makeHeart(
          origin: position + Offset(_between(-26, 26), _between(-8, 14)),
          bornAt: now + Duration(milliseconds: 40 + i * 50),
          color: palette[_random.nextInt(palette.length)],
          size: _between(12, 20),
          withRing: false,
        ),
      );
    }
  }

  void _spawnFromCorner(int count) {
    if (!mounted || _size == Size.zero) {
      return;
    }
    final palette = _palette();
    final now = _clock.elapsed;
    final waveSize = count.clamp(1, _maxCornerWave);

    for (var i = 0; i < waveSize; i++) {
      _add(
        _makeHeart(
          // Just above the like button, bottom-right, with a little spread
          // so a wave does not stack on one pixel column.
          origin: Offset(
            _size.width - 42 - _between(0, 28),
            _size.height - 96 - _between(0, 18),
          ),
          bornAt: now + _cornerStagger * i,
          color: palette[_random.nextInt(palette.length)],
          size: _between(22, 34),
          withRing: false,
        ),
      );
    }
  }

  void _add(_Heart heart) {
    if (_hearts.length >= _maxHearts) {
      _hearts.removeAt(0);
    }
    _hearts.add(heart);
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final canvas = LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return CustomPaint(
          painter: _HeartsPainter(hearts: _hearts, now: _clock.elapsed),
          size: Size.infinite,
        );
      },
    );

    if (onTap == null) {
      return IgnorePointer(child: canvas);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => onTap(details.localPosition),
      child: canvas,
    );
  }
}

class _Heart {
  const _Heart({
    required this.origin,
    required this.bornAt,
    required this.lifetime,
    required this.color,
    required this.size,
    required this.rise,
    required this.drift,
    required this.swayAmplitude,
    required this.swayTurns,
    required this.swayPhase,
    required this.tilt,
    required this.withRing,
  });

  final Offset origin;
  final Duration bornAt;
  final Duration lifetime;
  final Color color;

  /// Width in logical pixels at full scale.
  final double size;

  /// Total upward travel over the lifetime.
  final double rise;

  /// Sideways drift over the lifetime, on top of the sway.
  final double drift;
  final double swayAmplitude;
  final double swayTurns;
  final double swayPhase;

  /// Peak tilt in radians; oscillates with the sway.
  final double tilt;

  /// Expanding ring at the origin during the first frames (tap bloom).
  final bool withRing;
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter({required this.hearts, required this.now});

  final List<_Heart> hearts;
  final Duration now;

  /// Heart centred on the origin, about one unit wide and tall.
  static final Path _unitHeart = Path()
    ..moveTo(0, 0.42)
    ..cubicTo(-0.55, 0.05, -0.55, -0.45, -0.25, -0.45)
    ..cubicTo(-0.08, -0.45, 0, -0.32, 0, -0.22)
    ..cubicTo(0, -0.32, 0.08, -0.45, 0.25, -0.45)
    ..cubicTo(0.55, -0.45, 0.55, 0.05, 0, 0.42)
    ..close();

  static const Rect _unitBounds = Rect.fromLTWH(-0.5, -0.5, 1, 1);

  @override
  void paint(Canvas canvas, Size size) {
    for (final heart in hearts) {
      final age = now - heart.bornAt;
      if (age.isNegative) {
        continue;
      }
      final t = (age.inMicroseconds / heart.lifetime.inMicroseconds).clamp(
        0.0,
        1.0,
      );

      if (heart.withRing && t < 0.28) {
        final ringT = t / 0.28;
        canvas.drawCircle(
          heart.origin,
          18 + 44 * Curves.easeOut.transform(ringT),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - ringT)
            ..color = heart.color.withValues(alpha: 0.6 * (1 - ringT)),
        );
      }

      final wave = math.sin(t * math.pi * 2 * heart.swayTurns + heart.swayPhase);
      final center = Offset(
        heart.origin.dx + heart.drift * t + wave * heart.swayAmplitude * t,
        heart.origin.dy - Curves.easeOutCubic.transform(t) * heart.rise,
      );
      // Pop in with a slight overshoot, hold, then shrink while fading.
      final pop = t < 0.14 ? Curves.easeOutBack.transform(t / 0.14) : 1.0;
      final shrink = t > 0.75 ? 1 - 0.35 * ((t - 0.75) / 0.25) : 1.0;
      final scale = heart.size * pop * shrink;
      if (scale <= 0) {
        continue;
      }
      final opacity = t < 0.62 ? 1.0 : 1 - ((t - 0.62) / 0.38);

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(heart.tilt * wave)
        ..scale(scale);

      // Soft drop shadow, then a two-tone body and a glossy highlight: reads
      // as a small glass heart rather than a flat icon.
      canvas.drawPath(
        _unitHeart,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.08),
      );
      canvas.drawPath(
        _unitHeart,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(heart.color, Colors.white, 0.3)!.withValues(
                alpha: opacity,
              ),
              heart.color.withValues(alpha: opacity),
            ],
          ).createShader(_unitBounds),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(-0.17, -0.22),
          width: 0.2,
          height: 0.12,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.55 * opacity),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeartsPainter oldDelegate) => true;
}
