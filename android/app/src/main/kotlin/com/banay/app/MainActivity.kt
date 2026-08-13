package com.banay.app

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private val channelName = "banay/notifications"
	private val fileOpenerChannelName = "banay/file_opener"
	private val batteryOptimizationChannelName = "banay/battery_optimization"
	private var pendingNotificationPayload: Map<String, String>? = null
	private var methodChannel: MethodChannel? = null
	private var fileOpenerChannel: MethodChannel? = null
	private var batteryOptimizationChannel: MethodChannel? = null

	// OEM Android skins (ColorOS, MIUI, FuntouchOS, EMUI, ...) run their own
	// battery/auto-start manager on top of stock Android's battery
	// optimization system, and can still kill the app or block background
	// FCM delivery even after the user grants the standard
	// IGNORE_BATTERY_OPTIMIZATIONS permission. There is no public API for
	// this — component names are the same ones used across the open-source
	// Flutter/Android community for this exact purpose. Best-effort: many
	// OEM firmware forks rename/remove these across versions, hence the
	// try-each-then-fall-back-to-app-settings approach below.
	private val manufacturerAutostartActivities = listOf(
		// OPPO / ColorOS
		ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
		ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
		ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
		// Xiaomi / MIUI
		ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
		// Vivo / FuntouchOS
		ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
		ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
		// Huawei / EMUI
		ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
		// Samsung
		ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
		// Asus
		ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"),
	)

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

		batteryOptimizationChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			batteryOptimizationChannelName,
		).apply {
			setMethodCallHandler { call, result ->
				when (call.method) {
					"openManufacturerAutostartSettings" -> result.success(openManufacturerAutostartSettings())
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

	private fun openManufacturerAutostartSettings(): Boolean {
		for (component in manufacturerAutostartActivities) {
			val intent = Intent().apply {
				setComponent(component)
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			if (packageManager.queryIntentActivities(intent, 0).isEmpty()) {
				continue
			}

			try {
				startActivity(intent)
				return true
			} catch (_: ActivityNotFoundException) {
				continue
			} catch (_: SecurityException) {
				continue
			}
		}

		return try {
			startActivity(
				Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
					data = Uri.fromParts("package", packageName, null)
					addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				},
			)
			true
		} catch (_: ActivityNotFoundException) {
			false
		}
	}
}