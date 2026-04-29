package com.banay.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "banay/notifications"
	private var pendingNotificationPayload: Map<String, String>? = null
	private var methodChannel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		methodChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			channelName,
		).apply {
			setMethodCallHandler { call, result ->
				when (call.method) {
					"getInitialNotificationPayload" -> {
						result.success(pendingNotificationPayload)
						pendingNotificationPayload = null
					}

					else -> result.notImplemented()
				}
			}
		}

		handleNotificationIntent(intent, fromNewIntent = false)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleNotificationIntent(intent, fromNewIntent = true)
	}

	private fun handleNotificationIntent(intent: Intent?, fromNewIntent: Boolean) {
		val payload = extractNotificationPayload(intent?.extras) ?: return

		if (fromNewIntent) {
			methodChannel?.invokeMethod("notificationOpened", payload)
		} else {
			pendingNotificationPayload = payload
		}
	}

	private fun extractNotificationPayload(extras: Bundle?): Map<String, String>? {
		if (extras == null) {
			return null
		}

		val payload = mutableMapOf<String, String>()
		for (key in extras.keySet()) {
			val value = extras.get(key)?.toString() ?: continue
			payload[key] = value
		}

		val hasConversation = !payload["conversationId"].isNullOrBlank()
		val hasChatType = payload["type"] == "chat_message"
		if (!hasConversation && !hasChatType) {
			return null
		}

		return payload
	}
}