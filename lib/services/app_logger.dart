import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void debug(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void info(String tag, String message) {
    debugPrint('[$tag] INFO: $message');
  }

  static void warning(String tag, String message, [Object? error]) {
    final suffix = error != null ? ' — $error' : '';
    debugPrint('[$tag] WARN: $message$suffix');
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final suffix = error != null ? ' — $error' : '';
    debugPrint('[$tag] ERROR: $message$suffix');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }
}
