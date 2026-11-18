package com.example.bridge_lab.bridges

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.EventChannel

class StatusStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        const val NAME = "bridge_lab/status"
        private const val TAG = "StatusStream"
    }

    private val main = Handler(Looper.getMainLooper())
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val connectivity =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private var sink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private var lastBattery: Intent? = null
    private var networkType = "none"
    private var lastSent: Map<String, Any?>? = null

    // Dart started listening: this is where we start the native work.
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        Log.d(TAG, "onListen")
        sink = events
        lastSent = null
        try {
            networkType = currentNetworkType()
            registerBroadcasts()
            registerNetworkCallback()
            emit("initial")
        } catch (e: Exception) {
            events.error("REGISTER_FAILED", e.message, null)
        }
    }

    // Dart stopped listening: we MUST release everything or it leaks.
    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel")
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
        networkCallback?.let { connectivity.unregisterNetworkCallback(it) }
        networkCallback = null
        sink = null
    }

    private fun registerBroadcasts() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED)
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_BATTERY_CHANGED) lastBattery = intent
                emit(intent.action ?: "unknown")
            }
        }
        // ACTION_BATTERY_CHANGED is "sticky": registering returns the current value
        // immediately, so we have battery data before the first change happens.
        val sticky = if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(r, filter)
        }
        lastBattery = sticky
        receiver = r
    }

    private fun registerNetworkCallback() {
        val cb = object : ConnectivityManager.NetworkCallback() {
            // These callbacks arrive on a background thread, but an EventSink
            // must only be used on the main thread, so we hop over with post().
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                main.post { networkType = typeOf(caps); emit("network") }
            }

            override fun onLost(network: Network) {
                main.post { networkType = "none"; emit("network") }
            }
        }
        connectivity.registerDefaultNetworkCallback(cb)
        networkCallback = cb
    }

    private fun emit(reason: String) {
        val s = sink ?: return
        val data = snapshot()
        // The battery broadcast also fires for tiny temperature/voltage changes.
        // Skipping identical snapshots keeps the stream quiet.
        if (data == lastSent) return
        lastSent = data
        s.success(data + ("reason" to reason))
    }

    private fun snapshot(): Map<String, Any?> {
        val b = lastBattery
        val level = b?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = b?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val status = b?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = b?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val temp = b?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0

        val source = when {
            plugged and BatteryManager.BATTERY_PLUGGED_AC != 0 -> "ac"
            plugged and BatteryManager.BATTERY_PLUGGED_USB != 0 -> "usb"
            plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS != 0 -> "wireless"
            else -> "battery"
        }

        return mapOf(
            "batteryPercent" to if (level >= 0 && scale > 0) level * 100 / scale else -1,
            "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL),
            "powerSource" to source,
            "temperatureC" to temp / 10.0,
            "powerSave" to powerManager.isPowerSaveMode,
            "airplaneMode" to (Settings.Global.getInt(
                context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0
            ) == 1),
            "network" to networkType,
        )
    }

    private fun typeOf(caps: NetworkCapabilities?): String = when {
        caps == null -> "none"
        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
        else -> "other"
    }

    private fun currentNetworkType(): String {
        val n = connectivity.activeNetwork ?: return "none"
        return typeOf(connectivity.getNetworkCapabilities(n))
    }
}