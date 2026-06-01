import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'app_event_log_service.dart';

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

  Future<void> logUserEvent({
    required String name,
    Map<String, Object?> parameters = const <String, Object?>{},
    String source = 'ui',
    String status = 'success',
  }) => _log(
    name,
    () =>
        _fa.logEvent(name: name, parameters: _analyticsParameters(parameters)),
    parameters: parameters,
    source: source,
    status: status,
  );

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> logScreenView(String screenName) => _log(
    'screen_view',
    () => _fa.logScreenView(screenName: screenName),
    parameters: {'screen_name': screenName},
    source: 'navigation',
  );

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> logOtpRequested() =>
      _log('otp_requested', () => _fa.logEvent(name: 'otp_requested'));

  Future<void> logOtpVerified() =>
      _log('otp_verified', () => _fa.logEvent(name: 'otp_verified'));

  Future<void> logProfileCreated() =>
      _log('profile_created', () => _fa.logEvent(name: 'profile_created'));

  Future<void> logSignOut() =>
      _log('sign_out', () => _fa.logEvent(name: 'sign_out'));

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> logConversationOpened({
    required String conversationId,
    String? source, // 'notification' | 'product' | 'profile' | 'list'
  }) => _log(
    'conversation_opened',
    () => _fa.logEvent(
      name: 'conversation_opened',
      parameters: {
        'conversation_id': conversationId,
        if (source != null) 'source': source,
      },
    ),
    parameters: {
      'conversation_id': conversationId,
      if (source != null) 'source': source,
    },
    source: 'chat',
  );

  Future<void> logMessageSent({
    required String conversationId,
    required String kind, // 'text' | 'photo' | 'document'
  }) => _log(
    'message_sent',
    () => _fa.logEvent(
      name: 'message_sent',
      parameters: {'conversation_id': conversationId, 'kind': kind},
    ),
    parameters: {'conversation_id': conversationId, 'kind': kind},
    source: 'chat',
  );

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> logProductViewed({required String productId}) => _log(
    'product_viewed',
    () => _fa.logViewItem(items: [AnalyticsEventItem(itemId: productId)]),
    parameters: {'product_id': productId},
    source: 'catalog',
  );

  Future<void> logProductCreated({required String productId}) => _log(
    'product_created',
    () => _fa.logEvent(
      name: 'product_created',
      parameters: {'product_id': productId},
    ),
    parameters: {'product_id': productId},
    source: 'catalog',
  );

  Future<void> logProductLiked({required String productId}) => _log(
    'product_liked',
    () => _fa.logEvent(
      name: 'product_liked',
      parameters: {'product_id': productId},
    ),
    parameters: {'product_id': productId},
    source: 'catalog',
  );

  Future<void> logSearchQuery({required String query}) => _log(
    'search_executed',
    () => _fa.logSearch(searchTerm: query),
    parameters: {'query': query},
    source: 'search',
  );

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> logNotificationOpened({required String type}) => _log(
    'notification_opened',
    () => _fa.logEvent(
      name: 'notification_opened',
      parameters: {'notification_type': type},
    ),
    parameters: {'notification_type': type},
    source: 'notifications',
  );

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _log(
    String eventName,
    Future<void> Function() fn, {
    Map<String, Object?> parameters = const <String, Object?>{},
    String source = 'analytics',
    String status = 'success',
  }) async {
    await AppEventLogService.instance.record(
      name: eventName,
      parameters: parameters,
      source: source,
      status: status,
    );

    if (kDebugMode) return; // keep the dashboard clean during dev
    try {
      await fn();
    } catch (e) {
      // Analytics must never crash the app.
      debugPrint('[AppAnalytics] error: $e');
    }
  }

  Map<String, Object> _analyticsParameters(Map<String, Object?> parameters) {
    final normalized = <String, Object>{};
    parameters.forEach((key, value) {
      if (value is String || value is num || value is bool) {
        normalized[key] = value as Object;
      } else if (value != null) {
        normalized[key] = value.toString();
      }
    });
    return normalized;
  }
}
