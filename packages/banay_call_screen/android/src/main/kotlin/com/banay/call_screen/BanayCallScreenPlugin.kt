package com.banay.call_screen

import android.content.Context
import android.provider.Settings
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitIncomingActivity
import com.hiennv.flutter_callkit_incoming.Data
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Starts `flutter_callkit_incoming`'s ringing screen ourselves.
 *
 * The plugin normally lets the OS open that screen through the full-screen
 * intent of its notification; without USE_FULL_SCREEN_INTENT the OS ignores
 * it. Android 10+ still lets an app start an activity from the background
 * when the user granted it "Display over other apps" (SYSTEM_ALERT_WINDOW),
 * which is what this relies on. The notification stays as it is: the screen
 * is an addition, and both its buttons feed the same plugin actions.
 *
 * A FlutterPlugin rather than a MainActivity channel so it also exists in
 * the FCM background isolate, the one that rings a killed app.
 */
class BanayCallScreenPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "banay/call_screen")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "Plugin detached", null)
            return
        }
        when (call.method) {
            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(ctx))
            "show" -> result.success(show(ctx, call.arguments()))
            else -> result.notImplemented()
        }
    }

    /**
     * [params] is the same map `showCallkitIncoming` receives (CallKitParams
     * as JSON), so the screen shows the same caller, colours and texts, and
     * Accept / Decline carry the same call data as the notification's.
     */
    private fun show(ctx: Context, params: Map<String, Any?>?): Boolean {
        if (params == null || !Settings.canDrawOverlays(ctx)) {
            return false
        }
        return try {
            val data = Data(params)
            data.from = "notification"
            ctx.startActivity(CallkitIncomingActivity.getIntent(ctx, data.toBundle()))
            true
        } catch (error: Exception) {
            // Background start refused by the OEM, or the plugin changed its
            // internals: the ringing notification is still there.
            Log.w(TAG, "Call screen not opened: ${error.message}")
            false
        }
    }

    private companion object {
        const val TAG = "BanayCallScreen"
    }
}
