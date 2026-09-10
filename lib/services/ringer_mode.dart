import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the phone asks for right now: ring, vibrate only, or stay silent.
/// Android reports it through a tiny channel in MainActivity; elsewhere it
/// is unknown and the caller behaves as if the phone could ring (iOS mutes
/// the sound itself with the side switch).
enum RingerMode { normal, vibrate, silent, unknown }

const MethodChannel _ringerChannel = MethodChannel('banay/ringer');

Future<RingerMode> currentRingerMode() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return RingerMode.unknown;
  }
  try {
    final mode = await _ringerChannel.invokeMethod<String>('getRingerMode');
    return switch (mode) {
      'silent' => RingerMode.silent,
      'vibrate' => RingerMode.vibrate,
      'normal' => RingerMode.normal,
      _ => RingerMode.unknown,
    };
  } catch (error) {
    debugPrint('Ringer mode unavailable: $error');
    return RingerMode.unknown;
  }
}
