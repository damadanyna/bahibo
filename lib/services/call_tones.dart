import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Call sounds from `assets/sounds`:
/// - `ringback.wav`: what the caller hears while the other phone rings,
///   looped;
/// - `ringtone.mp3`: the incoming ringtone while the in-app call screen
///   rings, looped (the native Android screen plays the same file from
///   `res/raw/banay_ringtone.mp3`);
/// - `rington_end_call.wav`: played once when a call ends.
///
/// All are configured to live next to the WebRTC audio session rather
/// than fight it: no audio-focus grab on the call route (earpiece unless
/// the speaker is on), mixing allowed on iOS.
class CallTones {
  CallTones._();

  static final CallTones instance = CallTones._();

  AudioPlayer? _player;

  /// Caller side: loops until [stop] (answer, hang-up, no answer).
  Future<void> startRingback({required bool speakerOn}) async {
    await stop();
    final player = await _createPlayer(_callRouteContext(speakerOn: speakerOn));
    if (player == null) {
      return;
    }
    await _quietly(player.setReleaseMode(ReleaseMode.loop));
    player.onPlayerComplete.listen((_) {
      if (identical(_player, player)) {
        unawaited(_restart(player));
      }
    });
    // Earpiece level: the file is already trimmed to -8 dBFS peak, the
    // player adds a little headroom so a small speaker never overdrives.
    await _quietly(player.setVolume(0.8));
    await _quietly(player.play(AssetSource('sounds/ringback.wav')));
  }

  /// Callee side, app on screen: loops until [stop] (answer, decline,
  /// caller gave up, no answer).
  Future<void> startRingtone() async {
    await stop();
    final player = await _createPlayer(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    );
    if (player == null) {
      return;
    }
    await _quietly(player.setReleaseMode(ReleaseMode.loop));
    // Belt and braces: should the platform ignore the loop flag for this
    // file, restart it by hand until stop() disposes the player.
    player.onPlayerComplete.listen((_) {
      if (identical(_player, player)) {
        unawaited(_restart(player));
      }
    });
    // The mp3 is mastered loud; a phone speaker at full ring volume
    // distorts on it, hence the headroom.
    await _quietly(player.setVolume(0.7));
    await _quietly(player.play(AssetSource('sounds/ringtone.mp3')));
  }

  /// One-shot "call over" cue on the call route. Uses its own player so a
  /// [stop] issued at the same moment does not cut it short.
  Future<void> playEndCall({required bool speakerOn}) async {
    AudioPlayer player;
    try {
      player = AudioPlayer();
      await player.setAudioContext(_callRouteContext(speakerOn: speakerOn));
      await player.setReleaseMode(ReleaseMode.release);
    } catch (error) {
      debugPrint('End-call tone unavailable: $error');
      return;
    }
    player.onPlayerComplete.listen((_) => unawaited(_quietly(player.dispose())));
    await _quietly(player.setVolume(0.8));
    await _quietly(player.play(AssetSource('sounds/rington_end_call.wav')));
  }

  Future<void> stop() async {
    final player = _player;
    _player = null;
    if (player != null) {
      await _quietly(player.stop());
      await _quietly(player.dispose());
    }
  }

  /// Same routing as the voice: earpiece, or the speaker when the user
  /// turned it on; never steals the audio focus from WebRTC.
  AudioContext _callRouteContext({required bool speakerOn}) {
    return AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: speakerOn,
        audioMode: AndroidAudioMode.inCommunication,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.voiceCommunication,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: const {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.allowBluetooth,
        },
      ),
    );
  }

  /// Manual loop for platforms that ignore [ReleaseMode.loop]: only reached
  /// when a completion event fires, which a looping player never emits.
  Future<void> _restart(AudioPlayer player) async {
    await _quietly(player.seek(Duration.zero));
    if (identical(_player, player)) {
      await _quietly(player.resume());
    }
  }

  Future<AudioPlayer?> _createPlayer(AudioContext context) async {
    try {
      final player = AudioPlayer();
      await player.setAudioContext(context);
      _player = player;
      return player;
    } catch (error) {
      // A missing audio device (desktop, odd emulator) must never break
      // the call itself: the screen still shows what is going on.
      debugPrint('Call tone player unavailable: $error');
      return null;
    }
  }

  Future<void> _quietly(Future<void> future) async {
    try {
      await future;
    } catch (error) {
      debugPrint('Call tone failed: $error');
    }
  }
}
