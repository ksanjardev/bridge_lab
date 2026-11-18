package com.example.bridge_lab.bridges

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.example.bridge_lab.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

class NotificationsBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : NotificationsHostApi {

    companion object {
        const val EXTRA_TAPPED_ID = "bridge_lab.tapped_id"
        private const val REQ_PERMISSION = 4711
        private const val TAG = "NotificationsBridge"
    }

    private val context = activity.applicationContext
    private val manager = context.getSystemService(NotificationManager::class.java)
    private val flutterApi = NotificationsFlutterApi(messenger)
    private var permissionContinuation: CancellableContinuation<Boolean>? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun hasPermission(): Boolean = manager.areNotificationsEnabled()

    // A suspend function: it pauses here until the user answers the system dialog.
    override suspend fun requestPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 33 || hasPermission()) return hasPermission()
        return suspendCancellableCoroutine { cont ->
            permissionContinuation = cont
            cont.invokeOnCancellation { permissionContinuation = null }
            activity.runOnUiThread {
                activity.requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_PERMISSION,
                )
            }
        }
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQ_PERMISSION) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val pending = permissionContinuation
        permissionContinuation = null
        pending?.resume(granted)
    }

    override fun show(request: NotificationRequest) {
        // FlutterError arrives in Dart as a PlatformException, same as result.error().
        if (request.title.isBlank()) {
            throw FlutterError("INVALID_TITLE", "Title must not be empty", null)
        }
        val id = request.id.toInt()
        val channelId = ensureChannel(request.importance)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(EXTRA_TAPPED_ID, id)
        }
        // Tap opens an Activity directly: Android 12+ forbids launching one from a receiver.
        val tapPending = PendingIntent.getActivity(
            context, id * 100 + 99, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = newBuilder(channelId, request.importance)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(request.title)
            .setContentText(request.body)
            .setStyle(Notification.BigTextStyle().bigText(request.body))
            .setContentIntent(tapPending)
            .setDeleteIntent(broadcast(NotificationReceiver.ACTION_DISMISSED, id, null, id * 100))
            .setAutoCancel(true)

        request.actions.forEachIndexed { index, action ->
            @Suppress("DEPRECATION")
            builder.addAction(
                0, action.label,
                // Unique requestCode per button: PendingIntents ignore extras when matching.
                broadcast(NotificationReceiver.ACTION_PRESSED, id, action.id, id * 100 + index + 1),
            )
        }
        manager.notify(id, builder.build())
    }

    override fun cancel(id: Long) = manager.cancel(id.toInt())

    override fun activeNotifications(): List<ActiveNotification> =
        manager.activeNotifications.map { sbn ->
            val extras = sbn.notification.extras
            ActiveNotification(
                id = sbn.id.toLong(),
                title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: "",
                body = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: "",
            )
        }

    override fun startListening() {
        NotificationEvents.attach { event ->
            // onEvent is a suspend function now, so it needs a coroutine.
            scope.launch {
                try {
                    flutterApi.onEvent(event)
                } catch (e: Throwable) {
                    Log.w(TAG, "Dart rejected event", e)
                }
            }
        }
    }

    fun close() {
        scope.cancel()
    }

    private fun broadcast(action: String, id: Int, actionId: String?, requestCode: Int): PendingIntent {
        val intent = Intent(context, NotificationReceiver::class.java)
            .setAction(action)
            .putExtra(NotificationReceiver.EXTRA_ID, id)
            .putExtra(NotificationReceiver.EXTRA_ACTION_ID, actionId)
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel(importance: Importance): String {
        val (id, name, level) = when (importance) {
            Importance.LOW -> Triple("bridge_lab_low", "Quiet", NotificationManager.IMPORTANCE_LOW)
            Importance.NORMAL -> Triple("bridge_lab_normal", "Standard", NotificationManager.IMPORTANCE_DEFAULT)
            Importance.HIGH -> Triple("bridge_lab_high", "Urgent", NotificationManager.IMPORTANCE_HIGH)
        }
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(id, name, level))
        }
        return id
    }

    @Suppress("DEPRECATION")
    private fun newBuilder(channelId: String, importance: Importance): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context).setPriority(
                when (importance) {
                    Importance.LOW -> Notification.PRIORITY_LOW
                    Importance.NORMAL -> Notification.PRIORITY_DEFAULT
                    Importance.HIGH -> Notification.PRIORITY_HIGH
                }
            )
        }
}