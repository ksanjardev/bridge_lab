package com.example.bridge_lab.bridges

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_PRESSED = "com.example.bridge_lab.NOTIFICATION_ACTION"
        const val ACTION_DISMISSED = "com.example.bridge_lab.NOTIFICATION_DISMISSED"
        const val EXTRA_ID = "id"
        const val EXTRA_ACTION_ID = "action_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        when (intent.action) {
            ACTION_PRESSED -> {
                context.getSystemService(NotificationManager::class.java).cancel(id)
                NotificationEvents.dispatch(
                    NotificationEvent(
                        notificationId = id.toLong(),
                        type = NotificationEventType.ACTION_PRESSED,
                        actionId = intent.getStringExtra(EXTRA_ACTION_ID),
                    )
                )
            }
            ACTION_DISMISSED -> NotificationEvents.dispatch(
                NotificationEvent(id.toLong(), NotificationEventType.DISMISSED, null)
            )
        }
    }
}