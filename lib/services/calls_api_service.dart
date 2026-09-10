import 'package:banay/services/app_api_client.dart';

/// REST side of voice calls; the live state flows through the realtime
/// `calls:updated` events (see `VoiceCallService`).
class CallsApiService {
  final AppApiClient _client = AppApiClient();

  /// Rings the other participant of [conversationId]. Returns the call with
  /// the LiveKit `url` / `token` for the caller.
  Future<Map<String, dynamic>> startCall({
    required String conversationId,
  }) async {
    final data = await _client.post(
      '/calls',
      authenticated: true,
      body: {'conversationId': conversationId},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchCall(String callId) async {
    final data = await _client.get('/calls/$callId', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Callee only: "my phone is ringing", so the caller sees it reached.
  Future<Map<String, dynamic>> markRinging(String callId) async {
    final data = await _client.post(
      '/calls/$callId/ringing',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Callee only. Returns the LiveKit `url` / `token` for the callee.
  Future<Map<String, dynamic>> acceptCall(String callId) async {
    final data = await _client.post(
      '/calls/$callId/accept',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> declineCall(String callId) async {
    final data = await _client.post(
      '/calls/$callId/decline',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Either side: cancels a ringing call, ends an accepted one.
  Future<Map<String, dynamic>> endCall(String callId) async {
    final data = await _client.post('/calls/$callId/end', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }
}
