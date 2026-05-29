import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralised analytics facade.
/// Usage: AppAnalytics.instance.logScreenView('home');
///        AppAnalytics.instance.logMessageSent(conversationId: 'abc');
///
/// All methods are no-ops in debug mode so events don't pollute the dashboard
/// during development.
class AppAnalytics {
  AppAnalytics._();

  static final AppAnalytics instance = AppAnalytics._();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> logScreenView(String screenName) => _log(
    () => _fa.logScreenView(screenName: screenName),
  );

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> logOtpRequested() => _log(
    () => _fa.logEvent(name: 'otp_requested'),
  );

  Future<void> logOtpVerified() => _log(
    () => _fa.logEvent(name: 'otp_verified'),
  );

  Future<void> logProfileCreated() => _log(
    () => _fa.logEvent(name: 'profile_created'),
  );

  Future<void> logSignOut() => _log(
    () => _fa.logEvent(name: 'sign_out'),
  );

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> logConversationOpened({
    required String conversationId,
    String? source, // 'notification' | 'product' | 'profile' | 'list'
  }) => _log(
    () => _fa.logEvent(
      name: 'conversation_opened',
      parameters: {
        'conversation_id': conversationId,
        if (source != null) 'source': source,
      },
    ),
  );

  Future<void> logMessageSent({
    required String conversationId,
    required String kind, // 'text' | 'photo' | 'document'
  }) => _log(
    () => _fa.logEvent(
      name: 'message_sent',
      parameters: {'conversation_id': conversationId, 'kind': kind},
    ),
  );

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> logProductViewed({required String productId}) => _log(
    () => _fa.logViewItem(items: [AnalyticsEventItem(itemId: productId)]),
  );

  Future<void> logProductCreated({required String productId}) => _log(
    () => _fa.logEvent(
      name: 'product_created',
      parameters: {'product_id': productId},
    ),
  );

  Future<void> logProductLiked({required String productId}) => _log(
    () => _fa.logEvent(
      name: 'product_liked',
      parameters: {'product_id': productId},
    ),
  );

  Future<void> logSearchQuery({required String query}) => _log(
    () => _fa.logSearch(searchTerm: query),
  );

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> logNotificationOpened({required String type}) => _log(
    () => _fa.logEvent(
      name: 'notification_opened',
      parameters: {'notification_type': type},
    ),
  );

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _log(Future<void> Function() fn) async {
    if (kDebugMode) return; // keep the dashboard clean during dev
    try {
      await fn();
    } catch (e) {
      // Analytics must never crash the app.
      debugPrint('[AppAnalytics] error: $e');
    }
  }
}
