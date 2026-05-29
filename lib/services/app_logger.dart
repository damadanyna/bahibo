import 'package:flutter/foundation.dart';

/// All methods are no-ops in release builds.
///
/// kDebugMode is a compile-time const — the AOT compiler eliminates every
/// call site in release builds, producing zero logcat output in production.
class AppLogger {
  const AppLogger._();

  static void debug(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void info(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] INFO: $message');
  }

  static void warning(String tag, String message, [Object? error]) {
    if (!kDebugMode) return;
    final suffix = error != null ? ' — $error' : '';
    debugPrint('[$tag] WARN: $message$suffix');
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!kDebugMode) return;
    final suffix = error != null ? ' — $error' : '';
    debugPrint('[$tag] ERROR: $message$suffix');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
