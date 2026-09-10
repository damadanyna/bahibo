import 'dart:async';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/services/voice_call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen voice call, WhatsApp-style: peer at the centre, one status
/// line, and the controls at the bottom. Entirely driven by
/// [VoiceCallService.session]; pops itself once the session is cleared.
class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({super.key});

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage>
    with SingleTickerProviderStateMixin {
  static const Color _background = Color(0xFF0B1220);
  static const Color _hangUpRed = Color(0xFFE5484D);
  static const Color _acceptGreen = Color(0xFF2FBF71);

  final VoiceCallService _service = VoiceCallService.instance;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Full screen for the whole call: status and navigation bars hidden,
    // a swipe from an edge shows them for a moment (sticky immersive).
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _service.session.addListener(_onSessionChanged);
    // Drives the mm:ss counter; cheap, one rebuild per second.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _service.session.value?.phase == VoiceCallPhase.active) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _service.session.removeListener(_onSessionChanged);
    _clock?.cancel();
    _pulse.dispose();
    // Back to the app's normal chrome (Flutter's default on Android).
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    if (_service.session.value == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = _service.session.value;
    final scheme = Theme.of(context).colorScheme;
    final isRinging = session?.phase == VoiceCallPhase.ringing;

    return PopScope(
      // Back never drops a call by accident: the red button is the way out.
      canPop: session == null || session.isEnded,
      child: Scaffold(
        backgroundColor: _background,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(scheme.primary, _background, 0.55)!,
                _background,
              ],
            ),
          ),
          child: SafeArea(
            child: session == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.call_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Appel vocal Banay',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildAvatar(session, isRinging: isRinging),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          session.peerName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _statusText(session),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (session.phase == VoiceCallPhase.active) ...[
                        const SizedBox(height: 14),
                        _QualityPill(session: session),
                      ],
                      const Spacer(),
                      _buildControls(session),
                      const SizedBox(height: 36),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Avatar with two soft rings breathing outwards while it rings.
  Widget _buildAvatar(VoiceCallSession session, {required bool isRinging}) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (isRinging) ...[
                _ring(scale: 1 + 0.45 * t, opacity: 0.35 * (1 - t)),
                _ring(
                  scale: 1 + 0.45 * ((t + 0.5) % 1),
                  opacity: 0.35 * (1 - ((t + 0.5) % 1)),
                ),
              ],
              child!,
            ],
          );
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: AppCircleNetworkAvatar(
            radius: 66,
            imageUrl: session.peerAvatarUrl,
            userId: session.peerUserId,
          ),
        ),
      ),
    );
  }

  Widget _ring({required double scale, required double opacity}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildControls(VoiceCallSession session) {
    final isIncomingRinging =
        !session.isOutgoing && session.phase == VoiceCallPhase.ringing;

    if (isIncomingRinging) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'Refuser',
            background: _hangUpRed,
            onTap: () => unawaited(_service.decline()),
          ),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              final bump = 1 + 0.06 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Transform.scale(scale: bump, child: child);
            },
            child: _CallButton(
              icon: Icons.call_rounded,
              label: 'Accepter',
              background: _acceptGreen,
              onTap: () => unawaited(_service.accept()),
            ),
          ),
        ],
      );
    }

    final enabled = !session.isEnded;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallButton(
          icon: session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: session.isMuted ? 'Micro coupé' : 'Micro',
          background: session.isMuted
              ? Colors.white
              : Colors.white.withValues(alpha: 0.16),
          foreground: session.isMuted ? _background : Colors.white,
          onTap: enabled ? () => unawaited(_service.toggleMute()) : null,
        ),
        _CallButton(
          icon: Icons.call_end_rounded,
          label: session.isEnded ? 'Terminé' : 'Raccrocher',
          background: _hangUpRed,
          size: 74,
          onTap: enabled ? () => unawaited(_service.hangUp()) : null,
        ),
        _CallButton(
          icon: session.isSpeakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_down_rounded,
          label: 'Haut-parleur',
          background: session.isSpeakerOn
              ? Colors.white
              : Colors.white.withValues(alpha: 0.16),
          foreground: session.isSpeakerOn ? _background : Colors.white,
          onTap: enabled ? () => unawaited(_service.toggleSpeaker()) : null,
        ),
      ],
    );
  }

  String _statusText(VoiceCallSession session) {
    switch (session.phase) {
      case VoiceCallPhase.connecting:
        return session.isOutgoing ? 'Appel…' : 'Connexion…';
      case VoiceCallPhase.ringing:
        if (!session.isOutgoing) {
          return 'Appel vocal entrant';
        }
        // WhatsApp-style: "Appel…" until the other phone confirms the
        // invitation reached it, "Appel en cours…" once it rings there.
        return session.peerReached ? 'Appel en cours…' : 'Appel…';
      case VoiceCallPhase.active:
        if (session.isReconnecting) {
          return 'Reconnexion…';
        }
        return _formatDuration(session.elapsed);
      case VoiceCallPhase.ended:
        final message = session.endMessage?.trim() ?? '';
        if (message.isNotEmpty &&
            (session.endReason == VoiceCallEndReason.busy ||
                session.endReason == VoiceCallEndReason.failed)) {
          return message;
        }
        return switch (session.endReason) {
          VoiceCallEndReason.declined =>
            session.isOutgoing ? 'Appel refusé' : 'Appel refusé',
          VoiceCallEndReason.missed =>
            session.isOutgoing ? 'Pas de réponse' : 'Appel manqué',
          VoiceCallEndReason.cancelled => 'Appel annulé',
          VoiceCallEndReason.busy => 'Occupé',
          VoiceCallEndReason.failed => "Échec de l'appel",
          VoiceCallEndReason.disconnected => 'Connexion perdue',
          VoiceCallEndReason.noPermission => 'Microphone refusé',
          VoiceCallEndReason.ended || null =>
            session.connectedAt == null
                ? 'Appel terminé'
                : 'Appel terminé · ${_formatDuration(session.elapsed)}',
        };
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final hours = duration.inHours;
    final mm = (minutes % 60).toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}

/// Link quality of the other side, as the SFU sees it: three bars and a
/// word, so a choppy call reads as "their network" rather than "the app".
class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.session});

  final VoiceCallSession session;

  @override
  Widget build(BuildContext context) {
    final (label, bars, color) = switch (session.quality) {
      _ when session.isReconnecting => (
        'Connexion instable',
        0,
        const Color(0xFFFFB020),
      ),
      VoiceCallQuality.excellent => ('Bonne connexion', 3, Colors.white),
      VoiceCallQuality.good => ('Bonne connexion', 2, Colors.white),
      VoiceCallQuality.poor => ('Réseau faible', 1, const Color(0xFFFFB020)),
      VoiceCallQuality.lost => (
        'Connexion perdue',
        0,
        const Color(0xFFE5484D),
      ),
      VoiceCallQuality.unknown => ('Connexion…', 0, Colors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 4,
                  height: 6.0 + i * 4,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: i < bars
                        ? color
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
    this.foreground = Colors.white,
    this.size = 64,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: foreground, size: size * 0.46),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
