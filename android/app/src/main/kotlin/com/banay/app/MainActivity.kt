package com.banay.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Bundle
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private val channelName = "banay/notifications"
	private val fileOpenerChannelName = "banay/file_opener"
	private var pendingNotificationPayload: Map<String, String>? = null
	private var methodChannel: MethodChannel? = null
	private var fileOpenerChannel: MethodChannel? = null

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

		fileOpenerChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			fileOpenerChannelName,
		).apply {
			setMethodCallHandler { call, result ->
				when (call.method) {
					"openFileWithChooser" -> {
						val filePath = call.argument<String>("path")
						val mimeType = call.argument<String>("mimeType")
						val title = call.argument<String>("title")

						if (filePath.isNullOrBlank()) {
							result.success(false)
						} else {
							result.success(openFileWithChooser(filePath, mimeType, title))
						}
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

	private fun openFileWithChooser(
		filePath: String,
		mimeType: String?,
		title: String?,
	): Boolean {
		val file = File(filePath)
		if (!file.exists()) {
			return false
		}

		val contentUri = FileProvider.getUriForFile(
			this,
			"$packageName.fileprovider",
			file,
		)
		val resolvedMimeType = when {
			!mimeType.isNullOrBlank() -> mimeType
			else -> {
				val extension = file.extension.lowercase()
				MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
					?: "application/octet-stream"
			}
		}
		val viewIntent = Intent(Intent.ACTION_VIEW).apply {
			setDataAndType(contentUri, resolvedMimeType)
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
		}

		val supportedActivities = packageManager.queryIntentActivities(viewIntent, 0)
		if (supportedActivities.isEmpty()) {
			return false
		}

		return try {
			startActivity(Intent.createChooser(viewIntent, title ?: "Ouvrir avec"))
			true
		} catch (_: ActivityNotFoundException) {
			false
		}
	}
}