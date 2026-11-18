package com.example.bridge_lab

import android.content.Intent
import android.os.Bundle
import com.example.bridge_lab.bridges.NotificationEvent
import com.example.bridge_lab.bridges.NotificationEventType
import com.example.bridge_lab.bridges.NotificationEvents
import com.example.bridge_lab.bridges.NotificationsBridge
import com.example.bridge_lab.bridges.NotificationsHostApi
import com.example.bridge_lab.bridges.ShareBridge
import com.example.bridge_lab.bridges.BenchBridge
import com.example.bridge_lab.bridges.StatusStreamHandler
import com.example.bridge_lab.bridges.SyncMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var shareBridge: ShareBridge? = null
    private var notifications: NotificationsBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, SyncMethodChannel.NAME)
            .setMethodCallHandler(SyncMethodChannel(applicationContext))

        EventChannel(messenger, StatusStreamHandler.NAME)
            .setStreamHandler(StatusStreamHandler(applicationContext))

        shareBridge = ShareBridge(messenger, applicationContext)

        // Pigeon: one generated call wires up every method of the interface.
        val bridge = NotificationsBridge(this, messenger)
        notifications = bridge
        NotificationsHostApi.setUp(messenger, bridge)
        BenchBridge.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shareBridge?.detach()
        shareBridge = null
        NotificationsHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        NotificationEvents.detach()
        notifications?.close()
        notifications = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) handleNotificationTap(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationTap(intent)
    }

    private fun handleNotificationTap(intent: Intent?) {
        val id = intent?.getIntExtra(NotificationsBridge.EXTRA_TAPPED_ID, -1) ?: -1
        if (id == -1) return
        intent?.removeExtra(NotificationsBridge.EXTRA_TAPPED_ID) // handle each tap once
        NotificationEvents.dispatch(NotificationEvent(id.toLong(), NotificationEventType.TAPPED, null))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        notifications?.onPermissionResult(requestCode, grantResults)
    }
}