import 'app_event_log_service.dart';
import 'app_logger.dart';
import 'notifications_api_service.dart';
import 'session_storage.dart';

/// Best-effort background sync of locally-recorded UI events (see
/// AppEventLogService) to the backend, so admins can review real user
/// behaviour without a tester manually exporting logs from the hidden QA
/// screen. Triggered when the app is paused/detached (see main.dart).
class AppEventLogSyncService {
  AppEventLogSyncService._();

  static final AppEventLogSyncService instance = AppEventLogSyncService._();

  // Keep each batch well under the backend's 1 MB JSON limit (~700 B/event).
  static const int _batchLimit = 100;

  final SessionStorage _sessionStorage = SessionStorage();
  final NotificationsApiService _notificationsApiService =
      NotificationsApiService();
  bool _isFlushing = false;

  Future<void> flushPendingEvents() async {
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;

    try {
      final hasSession = await _sessionStorage.hasValidSession();
      if (!hasSession) {
        return;
      }

      final events = await AppEventLogService.instance
          .readEventsSinceLastSync(limit: _batchLimit);
      if (events.isEmpty) {
        return;
      }

      await _notificationsApiService.sendEventLogBatch({
        'eventCount': events.length,
        'events': events,
        'syncedAt': DateTime.now().toIso8601String(),
      });

      // Events are newest-first, so the first entry is the sync watermark.
      final newestTimestamp = DateTime.tryParse(
        events.first['timestamp']?.toString() ?? '',
      );
      if (newestTimestamp != null) {
        await AppEventLogService.instance.markSyncedUpTo(newestTimestamp);
      }
    } catch (error) {
      // Best effort only: a failed background flush must never crash or
      // block the app lifecycle transition that triggered it.
      AppLogger.warning('AppEventLogSync', 'Background flush failed', error);
    } finally {
      _isFlushing = false;
    }
  }
}
