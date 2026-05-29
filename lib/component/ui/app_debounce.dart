// Global tap debounce — prevents any DynamicIconButton from firing within
// _kWindow of the previous tap. Keeps double-tap / rapid-tap protection
// without per-screen boilerplate.
class AppDebounce {
  AppDebounce._();

  static const Duration _kWindow = Duration(milliseconds: 450);
  static DateTime? _lastAction;

  /// Returns true and records the timestamp if the debounce window has elapsed.
  /// Returns false (blocking the action) if called again too soon.
  static bool tryAcquire() {
    final now = DateTime.now();
    final last = _lastAction;
    if (last != null && now.difference(last) < _kWindow) return false;
    _lastAction = now;
    return true;
  }

  /// Force-release so that the next call to [tryAcquire] always succeeds.
  /// Useful after an async operation completes to restore normal responsiveness.
  static void release() => _lastAction = null;
}
